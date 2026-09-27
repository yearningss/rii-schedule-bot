#!/usr/bin/env python3
# Скрипт автоматической загрузки и публикации приложения в RuStore через официальный RuStore Open API
import os
import sys
import json
import base64
import argparse
from datetime import datetime, timezone
import requests
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives.serialization import load_pem_private_key

API_BASE_URL = "https://public-api.rustore.ru"

def normalize_pem_key(raw_key: str) -> bytes:
    raw_key = raw_key.strip()
    if os.path.isfile(raw_key):
        with open(raw_key, "r", encoding="utf-8") as f:
            raw_key = f.read().strip()

    if "-----BEGIN PRIVATE KEY-----" in raw_key:
        return raw_key.encode("utf-8")
    
    # Если ключ передан сплошной строкой Base64 без заголовков PEM
    clean_b64 = "".join(raw_key.split())
    # Разбиваем по 64 символа в строке для стандартного PEM
    chunked = "\n".join(clean_b64[i:i+64] for i in range(0, len(clean_b64), 64))
    pem_str = f"-----BEGIN PRIVATE KEY-----\n{chunked}\n-----END PRIVATE KEY-----\n"
    return pem_str.encode("utf-8")

def get_auth_token(key_id: str, private_key_pem: bytes) -> str:
    print(f"Авторизация в RuStore API для Key ID: {key_id}...")
    private_key = load_pem_private_key(private_key_pem, password=None)
    
    timestamp = datetime.now(timezone.utc).isoformat(timespec='milliseconds')
    data_to_sign = f"{key_id}{timestamp}".encode("utf-8")
    
    signature = private_key.sign(
        data_to_sign,
        padding.PKCS1v15(),
        hashes.SHA512()
    )
    signature_b64 = base64.b64encode(signature).decode("utf-8")
    
    url = f"{API_BASE_URL}/public/auth"
    payload = {
        "keyId": str(key_id),
        "timestamp": timestamp,
        "signature": signature_b64
    }
    
    resp = requests.post(url, json=payload, timeout=30)
    if resp.status_code != 200:
        raise RuntimeError(f"Ошибка авторизации RuStore (HTTP {resp.status_code}): {resp.text}")
    
    data = resp.json()
    token = data.get("body", {}).get("jwe")
    if not token:
        raise RuntimeError(f"Не получен токен jwe из ответа RuStore: {data}")
    
    print("Авторизация в RuStore успешно пройдена.")
    return token

def get_or_create_draft_version(token: str, package_name: str, publish_type: str, whats_new: str) -> int:
    headers = {"Public-Token": token}
    
    # 1. Проверяем, есть ли уже открытый черновик
    check_url = f"{API_BASE_URL}/public/v1/application/{package_name}/version"
    try:
        resp = requests.get(check_url, headers=headers, timeout=30)
        if resp.status_code == 200:
            versions = resp.json().get("body", {}).get("content", [])
            for v in versions:
                if v.get("versionStatus") in ("DRAFT", "DRAFT_EDITING"):
                    version_id = v.get("versionId")
                    print(f"Найден существующий черновик версии ID: {version_id}. Будет использован он.")
                    return int(version_id)
    except Exception as e:
        print(f"Примечание при проверке черновика: {e}")
    
    # 2. Создаем новый черновик версии
    create_url = f"{API_BASE_URL}/public/v1/application/{package_name}/version"
    payload = {
        "publishType": publish_type,
        "whatsNew": whats_new[:500] if whats_new else "Плановое обновление приложения и расписания."
    }
    
    print(f"Создание новой версии приложения (тип публикации: {publish_type})...")
    resp = requests.post(create_url, headers=headers, json=payload, timeout=30)
    if resp.status_code not in (200, 201):
        raise RuntimeError(f"Ошибка создания версии (HTTP {resp.status_code}): {resp.text}")
    
    body = resp.json().get("body")
    if isinstance(body, dict):
        version_id = body.get("versionId")
    else:
        version_id = body
        
    if not version_id:
        raise RuntimeError(f"Не получен versionId из ответа: {resp.text}")
    
    print(f"Черновик версии успешно создан: ID {version_id}")
    return int(version_id)

def upload_apk(token: str, package_name: str, version_id: int, apk_path: str):
    if not os.path.isfile(apk_path):
        raise FileNotFoundError(f"Файл APK не найден: {apk_path}")
    
    file_size_mb = os.path.getsize(apk_path) / (1024 * 1024)
    print(f"Загрузка APK файла '{apk_path}' ({file_size_mb:.2f} МБ) в RuStore...")
    
    url = f"{API_BASE_URL}/public/v1/application/{package_name}/version/{version_id}/apk?servicesType=Unknown&isMainApk=true"
    headers = {"Public-Token": token}
    
    with open(apk_path, "rb") as f:
        files = {"file": (os.path.basename(apk_path), f, "application/vnd.android.package-archive")}
        resp = requests.post(url, headers=headers, files=files, timeout=300)
    
    if resp.status_code != 200:
        raise RuntimeError(f"Ошибка загрузки APK (HTTP {resp.status_code}): {resp.text}")
    
    print("APK файл успешно загружен в RuStore.")

def commit_version(token: str, package_name: str, version_id: int):
    print(f"Отправка версии {version_id} на модерацию и публикацию...")
    url = f"{API_BASE_URL}/public/v1/application/{package_name}/version/{version_id}/commit?priorityUpdate=0"
    headers = {"Public-Token": token}
    
    resp = requests.post(url, headers=headers, timeout=60)
    if resp.status_code != 200:
        raise RuntimeError(f"Ошибка отправки на модерацию (HTTP {resp.status_code}): {resp.text}")
    
    print("Версия успешно отправлена на модерацию в RuStore!")

def main():
    parser = argparse.ArgumentParser(description="Автодеплой APK в RuStore")
    parser.add_argument("--key-id", default=os.environ.get("RUSTORE_KEY_ID"), help="Key ID из RuStore")
    parser.add_argument("--private-key", default=os.environ.get("RUSTORE_PRIVATE_KEY"), help="Приватный ключ PEM или путь к файлу")
    parser.add_argument("--package-name", default=os.environ.get("RUSTORE_PACKAGE_NAME", "com.yearnings.rii"), help="ID пакета приложения")
    parser.add_argument("--publish-type", default=os.environ.get("RUSTORE_PUBLISH_TYPE", "AUTOMATICALLY"), choices=["AUTOMATICALLY", "MANUALLY"], help="Тип публикации")
    parser.add_argument("--apk", default=os.environ.get("APK_PATH", "dist/RiiSchedule.apk"), help="Путь к файлу APK")
    parser.add_argument("--whats-new", default=os.environ.get("WHATS_NEW", "Обновление расписания и оптимизация работы приложения."), help="Описание изменений")
    
    args = parser.parse_args()
    
    if not args.key_id:
        print("Ошибка: не указан RUSTORE_KEY_ID (передайте через аргумент --key-id или переменную окружения RUSTORE_KEY_ID)")
        sys.exit(1)
        
    if not args.private_key:
        print("Ошибка: не указан RUSTORE_PRIVATE_KEY (передайте через аргумент --private-key или переменную окружения RUSTORE_PRIVATE_KEY)")
        sys.exit(1)
        
    if not os.path.exists(args.apk):
        print(f"Ошибка: APK файл не найден по пути: {args.apk}")
        sys.exit(1)
        
    try:
        pem_bytes = normalize_pem_key(args.private_key)
        token = get_auth_token(args.key_id, pem_bytes)
        version_id = get_or_create_draft_version(token, args.package_name, args.publish_type, args.whats_new)
        upload_apk(token, args.package_name, version_id, args.apk)
        commit_version(token, args.package_name, version_id)
        print("Автодеплой в RuStore полностью завершен успешно!")
    except Exception as e:
        print(f"Критическая ошибка при деплое в RuStore: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
