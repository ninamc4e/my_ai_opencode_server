# Контекст работы с Opencode

Этот файл автозагружается при старте каждой сессии (через `instructions` в `.opencode/opencode.jsonc`).
AI читает его автоматически — пользователю не нужно просить об этом.

## Пользователь
- Имя: alexs
- GitHub: alexsmy (https://github.com/alexsmy)
- Email: alex.smyslov@mail.ru
- Уровень: начинающий программист, опыт только через веб-интерфейс GitHub, начальные знания по общим вопросам кодирования.

## Настройка окружения
- **ОС:** Windows (PowerShell 5.1)
- **Python:** C:\Python312\python.exe
- **Node.js:** v20.12.2
- **SSH ключ:** id_ed25519 (добавлен в GitHub аккаунт alexsmy)
- **SSH работает:** подтверждено (Hi alexsmy! ...)
- **Git config:** user.name=alexs, user.email=alex.smyslov@mail.ru
- **GitHub CLI (gh):** не установлен

## Репозитории
- test_opencode (git@github.com:alexsmy/test_opencode.git) — тестовый репозиторий, есть README.md

## Структура проекта (my_best_work)
```
my_best_work/
├── CONTEXT.md              # Автозагружаемый контекст (этот файл)
├── AGENTS.md               # Правила для AI-агента
├── docs/
│   ├── opencode-guide.html # Пульт управления Opencode
│   └── telegram-hub.md     # Документация Telegram-хаба
├── .opencode/
│   ├── opencode.jsonc      # Конфигурация Opencode (команды, навыки, инструкции)
│   ├── .gitignore          # Защита от коммита secrets
│   └── skills/
│       └── code-reviewer.json  # Пример навыка
├── telegram-hub/            # Telegram: уведомления + синхронизация
│   ├── notify.ps1          # Скрипт отправки (server-режим через Render / local-режим браузер)
│   ├── notify.sh           # Linux-версия notify (для сервера Render, Alpine)
│   ├── session-start.ps1   # Уведомление о старте сессии (Windows)
│   ├── session-end.ps1     # Уведомление о завершении сессии (Windows)
│   ├── sync.ps1            # Движок синхронизации (PowerShell 5.1, для Windows)
│   ├── sync.sh             # Движок синхронизации (sh, для Linux/Render)
│   ├── sync.json           # Конфиг sync: repo, branch, node_name, push_after_task
│   ├── cloud-migrate.ps1   # Миграция: backup + FileVault + GitHub
│   ├── telegram-route.json # Маршрутизация: mode, endpoint, secret_env, формат
│   ├── telegram-config.json # Токен бота + chat_id (только для local-режима)
│   └── telegram-notify.json # Настройки: enabled, level (all/errors)
├── agents-hub/              # Управление серверными агентами
│   ├── agent-call.ps1      # Вызов агента на сервере через туннель
│   ├── agents-tunnel.json  # Эндпоинт /api/agents/inbox + secret_env
│   └── agent-deploy.json   # Конфиг авто-деплоя динамических агентов
├── SCRIPTs/
│   ├── setup-github.sh     # Скрипт настройки GitHub
│   ├── update-skills.sh    # Скрипт управления навыками
│   ├── backup.ps1          # Бэкап my_best_work (локально + на Render FileVault)
│   ├── restore.ps1         # Восстановление на новом ПК (GitHub или FileVault)
│   ├── seal.ps1            # Шифрование SSH-ключа и env-секретов
│   ├── unseal.ps1          # Расшифровка и установка на новом ПК
│   └── bootstrap.ps1       # Полная настройка нового ПК одной командой
├── templates/
│   └── pr-template.md      # Шаблон Pull Request
├── secrets/                # Зашифрованные SSH-ключ и секреты (авто-бэкап)
└── projects/               # Папка для будущих проектов
```

## Telegram — односторонние уведомления (AI → Пользователь)

### Важные данные
- **Бот:** @imgtestlivebot
- **Режим:** server (основной) / local (fallback) — задаётся в `telegram-route.json`
- **Chat ID:** 1252058698

### Как это работает

**Два режима отправки:**

1. **Server-режим (основной):** `notify.ps1` отправляет POST-запрос на сервер Render (`/mytelegram`), сервер отправляет через Telegram Bot API. Не требует браузера. Тело запроса конвертируется в UTF-8 bytes.
2. **Local-режим (fallback):** Браузер Chrome/Edge выполняет GET-запрос к API Telegram через `Image()`. Прокси НЕ требуется.

**Язык уведомлений:** русский. Все сообщения в Telegram отправляются на русском языке.

#### Кастомная команда `/tg`

Пользователь может управлять уведомлениями через команду `/tg`:
- `/tg on` — включить уведомления (для всех событий)
- `/tg off` — выключить уведомления
- `/tg status` — показать текущий статус
- `/tg on all` — обо всём (создание файлов, коммиты, ошибки, статусы)
- `/tg on errors` — только об ошибках и важных событиях

**AI (я) должен:**
1. Прочитать telegram-notify.json
2. Выполнить команду (изменить enabled/level)
3. Сохранить изменения в telegram-notify.json
4. Сообщить пользователю результат

Если enabled=false — НЕ отправлять уведомления в Telegram.
Если level=errors — отправлять только об ошибках и критических событиях.
По умолчанию: enabled=true, level=all.
Язык уведомлений: русский.

#### Отправка уведомления

Из PowerShell:
```powershell
powershell -File telegram-hub/notify.ps1 -Message "<b>текст сообщения</b>"
```

Из сессии Opencode (через bash):
```
powershell -File C:\Users\alexs\.opencode\my_best_work\telegram-hub\notify.ps1 -Message "<b>текст</b>"
```

**Как работает (server-режим):**
1. notify.ps1 читает настройки из `telegram-route.json`
2. Берёт секрет из `TELEGRAM_TUNNEL_SECRET` (User env)
3. Формирует JSON-тело, конвертирует в UTF-8 bytes (важно для русских символов и °C)
4. POST на `https://bot-29-nx0w.onrender.com/mytelegram` с заголовком `X-Telegram-Tunnel-Secret`
5. Сервер отправляет сообщение через Telegram Bot API

**Как работает (local-режим, fallback):**
1. notify.ps1 читает токен из `telegram-config.json`
2. Создаёт временный HTML-файл с невидимым `Image()`
3. Открывает в Chrome/Edge через `--new-window`
4. `Image()` делает GET-запрос → сообщение уходит в Telegram
5. Через 3 секунды окно закрывается, файл удаляется

## Что уже изучено
1. **Opencode** — запуск, настройка, конфиги, команды
2. **Git + SSH** — настроен доступ к GitHub, цикл clone/add/commit/push
3. **Навыки (skills)** — создан code-reviewer
4. **Telegram-уведомления** — server-режим через Render (основной) + local-режим (fallback)
   - Бот: @imgtestlivebot
   - Скрипт: `telegram-hub/notify.ps1`
   - Команда: `/tg on|off|status|on all|on errors`
   - Конфиги: `telegram-route.json` + `telegram-notify.json`
5. **Серверные агенты** — Dynamic Agents (ALM)
   - Эндпоинты: upload, list, delete, inbox, responses
   - Ветка GitHub: `dynamic_agents`
   - Локальные скрипты: `agents-hub/agent-call.ps1`
   - FileVault: папка "Agents" с ответами
6. **Backup/Resore** — `SCRIPTs/backup.ps1` + `restore.ps1`, команда `/backup`
7. **Render** — сервер `bot-29-nx0w.onrender.com`, ветка `dynamic_agents`

## Sync System — триединство (18.05.2026)
- Три узла синхронизируются через GitHub: notebook, other-pc, server
- `telegram-hub/sync.ps1` (PowerShell) / `sync.sh` (sh) — движки синхронизации
- `telegram-hub/sync.json` — конфиг (node_name, branch, push_after_task)
- `USER.md` — профиль пользователя (читается при старте, персонализация)
- Команда `/sync` — принудительная синхронизация
- Auto-sync: после каждой задачи, при старте и завершении сессии
- Пуш HANDOVER.md / CONTEXT.md / USER.md — автоматический, остальное — с разрешения
- Алгоритм merge HANDOVER.md: append-only (новые строки дописываются)
- Определение платформы: `powershell` есть → Windows, `sh` есть → Linux

### Изменённые файлы
- `telegram-hub/sync.ps1` — движок синхронизации (PowerShell 5.1)

## Планы на будущее
- Pull Request через gh (GitHub CLI)
- Плагины для Opencode
- Google Drive интеграция для backup

## Как продолжить в новой сессии
Контекст загружается автоматически. Можно сразу начинать работать.
Для синхронизации: `/sync` (или "синхронизируйся", "sync", "обнови контекст")
Для управления уведомлениями: `/tg on`, `/tg off`, `/tg status`, `/tg on all`, `/tg on errors`.
Для бэкапа: `/backup` или `/backup upload`.
