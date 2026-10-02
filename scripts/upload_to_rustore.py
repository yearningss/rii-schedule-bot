#!/usr/bin/env python3
# Скрипт автоматической загрузки и публикации приложения в RuStore через официальный RuStore Open API
import os
import sys
import base64
import argparse
from datetime import datetime, timezone
import requests
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives.serialization import load_pem_private_key

API_BASE_URL = "https://public-api.rustore.ru"

def normalize_pem_key(raw_key: str) -> bytes:
    raw_key = raw_key.strip().replace("\\n", "\n")
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

def checked_body(response, action):
    if response.status_code not in (200, 201):
        raise RuntimeError(f"{action}: HTTP {response.status_code}: {response.text}")
    data = response.json()
    if str(data.get("code", "OK")).upper() != "OK":
        raise RuntimeError(f"{action}: {data.get('message', 'RuStore вернул ошибку')}")
    return data.get("body")


def get_or_create_draft_version(token: str, package_name: str, publish_type: str, whats_new: str) -> int:
    headers = {"Public-Token": token}
    url = f"{API_BASE_URL}/public/v1/application/{package_name}/version"
    payload = {"publishType": publish_type, "whatsNew": whats_new[:5000]}
    # Проверяем черновик до создания: повторное создание может удалить прежний.
    response = requests.get(url, headers=headers,
                            params={"versionStatuses": "DRAFT", "size": 100}, timeout=30)
    body = checked_body(response, "Проверка черновиков") or {}
    versions = body.get("content", [])
    for version in versions:
        if version.get("versionStatus") in ("DRAFT", "DRAFT_EDITING"):
            version_id = int(version["versionId"])
            response = requests.patch(
                f"{API_BASE_URL}/public/v2/application/{package_name}/version/{version_id}",
                headers=headers, json=payload, timeout=30)
            checked_body(response, "Обновление черновика")
            print(f"Обновлён существующий черновик: {version_id}")
            return version_id
    response = requests.post(url, headers=headers, json=payload, timeout=30)
    body = checked_body(response, "Создание черновика")
    version_id = body.get("versionId") if isinstance(body, dict) else body
    if not version_id:
        raise RuntimeError("RuStore не вернул идентификатор черновика")
    print(f"Создан черновик: {version_id}")
    return int(version_id)


def upload_apk(token: str, package_name: str, version_id: int, apk_path: str):
    if not os.path.isfile(apk_path):
        raise FileNotFoundError(f"Файл APK не найден: {apk_path}")
    
    file_size_mb = os.path.getsize(apk_path) / (1024 * 1024)
    print(f"Загрузка APK файла '{apk_path}' ({file_size_mb:.2f} МБ) в RuStore...")
    
    url = f"{API_BASE_URL}/public/v1/application/{package_name}/version/{version_id}/apk"
    with open(apk_path, "rb") as apk:
        response = requests.post(
            url, headers={"Public-Token": token},
            params={"servicesType": "Unknown", "isMainApk": "true"},
            files={"file": (os.path.basename(apk_path), apk, "application/vnd.android.package-archive")},
            timeout=300,
        )
    checked_body(response, "Загрузка APK")
    print("APK файл успешно загружен в RuStore.")


def commit_version(token: str, package_name: str, version_id: int):
    print(f"Отправка версии {version_id} на модерацию и публикацию...")
    url = f"{API_BASE_URL}/public/v1/application/{package_name}/version/{version_id}/commit"
    response = requests.post(url, headers={"Public-Token": token},
                             params={"priorityUpdate": 0}, timeout=60)
    checked_body(response, "Отправка на модерацию")
    print("Версия успешно отправлена на модерацию в RuStore!")


def main():
    parser = argparse.ArgumentParser(description="Автодеплой APK в RuStore")
    parser.add_argument("--key-id", default=os.environ.get("RUSTORE_KEY_ID"), help="Key ID из RuStore")
    parser.add_argument("--private-key", default=os.environ.get("RUSTORE_PRIVATE_KEY"), help="Приватный ключ PEM или путь к файлу")
    parser.add_argument("--package-name", default=os.environ.get("RUSTORE_PACKAGE_NAME", "com.yearnings.rii"), help="ID пакета приложения")
    parser.add_argument("--publish-type", default=os.environ.get("RUSTORE_PUBLISH_TYPE", "INSTANTLY"), choices=["MANUAL", "INSTANTLY"], help="Тип публикации")
    parser.add_argument("--apk", default=os.environ.get("APK_PATH", "dist/RiiSchedule.apk"), help="Путь к файлу APK")
    parser.add_argument("--whats-new", default=os.environ.get("WHATS_NEW"), help="Описание изменений")
    
    args = parser.parse_args()
    if not args.whats_new:
        from pathlib import Path
        import re
        root = Path(__file__).resolve().parent.parent
        version = re.search(r"^version:\s*([^+\s]+)", (root / "app/pubspec.yaml").read_text(encoding="utf-8"), re.MULTILINE).group(1)
        changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
        match = re.search(rf"## \[{re.escape(version)}\][^\n]*\n(.*?)(?=\n## |\Z)", changelog, re.DOTALL)
        args.whats_new = match.group(1).strip() if match else "Обновление расписания и оптимизация работы приложения."
    
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
        print("Обновление отправлено на модерацию. Тип публикации: " + args.publish_type)
        if os.environ.get("GITHUB_STEP_SUMMARY"):
            with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
                summary.write(f"Версия RuStore **{version_id}** отправлена на модерацию. Публикация: **{args.publish_type}**.\n")
    except Exception as e:
        print(f"Критическая ошибка при деплое в RuStore: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
