<p align="center">
  <img src="assets/banner.png" alt="РИИ Расписание" width="100%">
</p>

# Цифровая экосистема расписания РИИ АлтГТУ (RII Schedule)

Комплексная цифровая экосистема для быстрого и удобного доступа к расписанию учебных занятий Рубцовского индустриального института (РИИ АлтГТУ).

Проект объединяет Telegram-бота, встроенное веб-приложение (Telegram Mini App), кроссплатформенное мобильное приложение на Flutter (Android и iOS) с нативным виджетом рабочего стола, серверный бэкенд синхронизации и систему автоматической доставки обновлений.

Разработчик: yearningss (Влад) (https://github.com/yearningss)

Бот в Telegram: @rubinst_bot

Последние сборки приложения: https://github.com/yearningss/rii-schedule-bot/releases/latest

---

## Компоненты экосистемы

### 1. Мобильное приложение Flutter (Android и iOS)

Полноценное клиентское приложение с современным интерфейсом и глубокой интеграцией в систему:

* Нативный виджет на рабочий стол Android:
  * Отображение текущей пары, статуса перемены, следующей пары и номера аудитории.
  * Интерактивная кнопка ручного обновления и автоматическая синхронизация.
  * Совместимость со сторонними лаунчерами и оболочками (включая MagicOS, One UI, MIUI, Pixel Launcher).
* Офлайн-кэширование:
  * Расписание доступно для просмотра даже без доступа к сети Интернет.
* Синхронизация с аккаунтом:
  * Быстрая привязка по Telegram ID или одноразовому токену аутентификации.
  * Общий профиль: выбранная группа, подгруппа и настройки синхронизируются между ботом и приложением.
* Проверка обновлений:
  * Автоматическое уведомление о выходе новых версий при старте приложения и ручная проверка в разделе настроек.
* Оформление и темы:
  * Полноценная поддержка системной, темной и светлой тем.
  * Расписание звонков и экзаменационных сессий.

#### Доступные файлы в релизах:
* `RiiSchedule.apk` — подписанная релизная сборка для Android (рекомендуется для установки и обновления без потери данных).
* `RiiSchedule-debug.apk` — отладочная версия APK с расширенным выводом логов.
* `RiiSchedule.ipa` — пакет для устройств Apple iOS (установка через AltStore, Sideloadly, TrollStore или личный сертификат).

### 2. Telegram-бот (@rubinst_bot)

* Асинхронное ядро на базе aiogram 3.
* Моментальные оповещения об изменениях расписания на завтра: бот отслеживает правки на сайте института и оповещает студентов в случае переноса или отмены пар.
* Уведомления перед парами (за 10 или 5 минут), по звонку и во время перемен.
* Умный поиск групп по текстовым запросам («ИВТ-61», «руп» и т.д.).
* Определение четности недели (I и II недели) с переключением на понедельник в выходные дни.
* Выбор подгруппы для лабораторных занятий.

### 3. Telegram Mini App (Web App)

* Легковесный веб-интерфейс, запускаемый внутри Telegram.
* Адаптивная верстка, поддержка свайпов между днями недели и тактильного отклика (Haptic Feedback).
* Быстрый доступ к расписанию звонков и выбору учебных групп.

### 4. Серверная часть и REST API

* Встроенный HTTP-сервер на aiohttp.web, обслуживающий Telegram Mini App и мобильные клиенты.
* Мониторинг изменений расписания с сайта РИИ (`https://www.rubinst.ru/schedule.php`).
* Основные эндпоинты API:
  * `GET /api/schedule` — получение актуальной сетки занятий группы.
  * `POST /api/app/auth/request` — генерация токена привязки Telegram-аккаунта.
  * `GET /api/app/auth/check` — подтверждение входа в мобильном приложении.
  * `GET /api/app/profile`, `POST /api/app/profile` — получение и сохранение профиля пользователя.
  * `GET /api/app/version` — проверка актуальной версии мобильного приложения и получение ссылки на загрузку обновления.

---

## Стек технологий

* Сервер и бот: Python 3.10+, aiogram 3.x, aiohttp, aiosqlite, python-dotenv.
* База данных: SQLite с асинхронным драйвером.
* Мобильное приложение: Flutter 3.x, Dart 3.x, Android SDK (Java 17 / Gradle), iOS (Xcode).
* Веб-приложение: Vanilla JS, HTML5, CSS3, Telegram WebApp SDK.
* CI/CD: GitHub Actions (автоматическая сборка Android APK, отладочного APK, iOS IPA и публикация в GitHub Releases).

---

## Структура репозитория

```text
rii-schedule-bot/
├── .github/
│   └── workflows/
│       └── build-mobile.yml    # CI/CD: сборка Android APK, Debug APK, iOS IPA и публикация релиза
├── assets/
│   ├── banner.png              # Баннер проекта
│   └── logo.png                # Логотип
├── app/                        # Исходный код мобильного приложения (Flutter)
│   ├── android/                # Android-модуль, настройки подписи и код виджета
│   │   └── app/src/main/kotlin/com/yearnings/rii/
│   │       ├── MainActivity.kt
│   │       └── ScheduleWidgetProvider.kt # Нативный виджет рабочего стола
│   ├── ios/                    # iOS-модуль проекта
│   ├── lib/                    # Исходный код Dart
│   │   ├── models/             # Модели расписания, профиля и информации о версии
│   │   ├── screens/            # Экраны расписания, звонков, настроек, авторизации
│   │   ├── services/           # Сервисы API, кэширования и обновления виджета
│   │   ├── theme/              # Темы оформления (светлая и темная)
│   │   └── main.dart           # Точка входа Flutter-приложения
│   └── pubspec.yaml            # Зависимости и версия мобильного приложения
├── config.py                   # Конфигурация и переменные окружения
├── database.py                 # Асинхронная работа с базой данных (SQLite)
├── keyboards.py                # Клавиатуры и инлайн-кнопки бота
├── main.py                     # Точка входа: бот, веб-сервер aiohttp и воркер уведомлений
├── requirements.txt            # Зависимости Python
├── handlers/                   # Обработчики Telegram-бота
│   ├── start.py                # Команды /start, /help, /app, выбор и поиск группы
│   ├── schedule.py             # Расписание на сегодня, завтра, недели, звонки
│   └── settings.py             # Настройки уведомлений и подгрупп
├── services/                   # Сервисные модули
│   ├── api.py                  # Парсер и клиент сайта РИИ, учет часового пояса Рубцовска
│   ├── notifier.py             # Фоновый воркер уведомлений о парах, переменах и заменах
│   └── web_server.py           # Веб-сервер Mini App и REST API для мобильного приложения
└── webapp/                     # Фронтенд Telegram Mini App
    ├── index.html              # Разметка Mini App
    ├── style.css               # Стилистика Telegram Design System
    └── app.js                  # Клиентская логика Mini App
```

---

## Установка и запуск

### 1. Клонирование репозитория

```bash
git clone https://github.com/yearningss/rii-schedule-bot.git
cd rii-schedule-bot
```

### 2. Настройка серверной части (Python)

1. Создайте и активируйте виртуальное окружение:

```bash
python -m venv venv

# Windows:
venv\Scripts\activate

# Linux / macOS:
source venv/bin/activate
```

2. Установите зависимости:

```bash
pip install -r requirements.txt
```

3. Настройте файл переменных окружения:

```bash
cp .env.example .env
```

В файле `.env` укажите токен вашего бота от BotFather и параметры веб-сервера:

```env
BOT_TOKEN=ваш_токен_от_BotFather
DB_PATH=data/bot.db
API_BASE_URL=https://www.rubinst.ru/schedule.php
CACHE_TTL_SECONDS=300
CHANGE_CHECK_INTERVAL_SECONDS=900

WEBAPP_URL=https://rii-bot.yearnings.ru
WEB_HOST=127.0.0.1
WEB_PORT=8080
```

4. Запустите сервис:

```bash
python main.py
```

---

### 3. Сборка мобильного приложения (Flutter)

Для сборки мобильного приложения локально требуется установленный Flutter SDK (версии 3.x+).

1. Перейдите в каталог приложения и установите зависимости:

```bash
cd app
flutter pub get
```

2. Сборка для Android:

```bash
# Релизный подписанный APK:
flutter build apk --release

# Отладочный APK:
flutter build apk --debug
```

3. Сборка для iOS (на macOS с Xcode):

```bash
flutter build ios --release --no-codesign
```

---

## Автоматическая сборка (CI/CD)

В репозитории настроен пайплайн GitHub Actions (`.github/workflows/build-mobile.yml`):

При отправке изменений в ветку `main` запускается сборка:
* Релизного подписанного APK (`RiiSchedule.apk`).
* Отладочного APK (`RiiSchedule-debug.apk`).
* Пакета для iOS (`RiiSchedule.ipa`).

Собранные файлы автоматически публикуются на странице [GitHub Releases](https://github.com/yearningss/rii-schedule-bot/releases).

---

## Разработчик

yearningss (Влад):
* GitHub: https://github.com/yearningss
* Связь и почта: yearwist@gmail.com, doki@dotirr.ru

---

## Лицензия

MIT. Разрешается свободное использование, модификация и распространение.
