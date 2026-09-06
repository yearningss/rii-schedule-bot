import os
import re
import subprocess

def main():
    text = ''
    if os.path.exists('CHANGELOG.md'):
        with open('CHANGELOG.md', 'r', encoding='utf-8') as f:
            text = f.read()

    ver = os.environ.get('APP_VERSION', '').strip()
    build = os.environ.get('APP_BUILD', '').strip()

    changes = ''
    if ver and text:
        pattern = rf'## \[{re.escape(ver)}\][^\n]*\n(.*?)(?=\n## |\Z)'
        m = re.search(pattern, text, re.DOTALL)
        if m:
            changes = m.group(1).strip()

    if not changes:
        try:
            res = subprocess.run(
                ['git', 'log', '-n', '10', '--pretty=format:%s'],
                capture_output=True,
                check=False
            )
            log = res.stdout.decode('utf-8', errors='replace')
            lines = [f"* {l}" for l in log.splitlines() if l.strip() and not l.startswith("Merge ")][:8]
            changes = "\n".join(lines)
        except Exception:
            changes = "* Плановое обновление приложения и исправления ошибок."

    body = f"""Официальный релиз мобильного приложения РИИ АлтГТУ (версия {ver}, сборка {build}).

### Что нового в этом обновлении:
{changes}

### Файлы для загрузки:
* **RiiSchedule.apk** - Релизный подписанный APK для Android (рекомендуется для установки и обновления поверх старых версий).
* **RiiSchedule-debug.apk** - Отладочный APK со встроенными логами для тестирования.
* **RiiSchedule.ipa** - Пакет приложения для iOS (установка через AltStore, Sideloadly, TrollStore или личный сертификат Apple ID).
"""

    with open('release_body.md', 'w', encoding='utf-8') as f:
        f.write(body.strip() + "\n")
    print("Generated release_body.md successfully.")

if __name__ == '__main__':
    main()
