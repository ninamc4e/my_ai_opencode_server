# Handover: MCP Agent Import — вводная для новой сессии

## Что было сделано в предыдущей сессии

### 1. Локальный MCP-тест
- Написан `agents-hub/local_mcp_server.py` — FastMCP-сервер с `calculate` (add, multiply, sqrt, sin, cos)
- Запущен локально на `127.0.0.1:8765/mcp`, проверен через MCP-протокол: `6 * 7 = 42`
- Opencode подключается через `"type": "remote"` (сейчас `enabled: false`)

### 2. Проверка MCP-совместимости
- Установлен официальный `@modelcontextprotocol/server-everything` (Anthropic)
- Проверен stdio-режим: INIT + tools/list (12 тулов) + tools/call (echo) — всё работает
- MCP SDK 1.27.1 (Python), server-everything v2.0.0 (TypeScript) — полная совместимость
- В opencode.jsonc добавлен `mcp_everything` (local stdio, enabled: false)

### 3. Серверные изменения (ветка `mcp_agent_import`)
Создана новая ветка от `mcp-migration`, запушена в GitHub.
Render деплоит с этой ветки.

**Что добавлено в `services/agents/mcp_server.py`:**
- `register_dynamic_tool(name, code)` — регистрация MCP-тула из Python-кода
- `remove_dynamic_tool(name)` — удаление
- `list_dynamic_tools()` — список
- `load_dynamic_tools()` — восстановление с диска при старте
- Код тулов сохраняется в `data/agents/mcp_tools/`
- Встроенные тулы (`get_weather`, `send_weather_to_telegram`) защищены

**Что добавлено в `routers/agents_api.py`:**
- `POST /api/agents/mcp-tools/register` — загрузить MCP-тул
- `GET /api/agents/mcp-tools/list` — список
- `DELETE /api/agents/mcp-tools/{name}` — удалить

### 4. Проверено на Render (всё работает)
| Тест | Статус |
|---|---|
| MCP initialize + tools/list | ✅ `get_weather`, `send_weather_to_telegram`, `echo_bot`, `current_time` |
| Upload echo_bot | ✅ |
| tools/call echo_bot | ✅ |
| Upload current_time | ✅ |
| tools/call current_time | ✅ Current time (UTC+3): 2026-05-17 18:13:56 |
| Delete echo_bot | ✅ |
| get_weather (built-in MCP) | ✅ 25.3°C |
| /api/agents/inbox (old) | ✅ accepted: true |

## Текущее состояние

### Render (bot-29-nx0w.onrender.com)
- Ветка: `mcp_agent_import`
- Загруженный MCP-тул: `current_time` (остался на сервере)
- Старые агенты: работают
- Web: `/files`, `/mytelegram` — работают

### Локально (my_best_work)
- `AGENTS.md` — обновлён: новые эндпоинты, формат MCP-тулов, архитектура
- `opencode.jsonc` — MCP: weather_agents (remote, enabled), mcp_everything (local, disabled)
- `agents-hub/mcp_tools_examples/` — 5 готовых примеров + скрипт загрузки:
  - `current_time.py` — время в любом часовом поясе
  - `echo_bot.py` — эхо для отладки
  - `password_gen.py` — генератор паролей
  - `random_quote.py` — случайные цитаты
  - `text_counter.py` — счётчик слов/символов
  - `upload_mcp_tool.ps1` — скрипт загрузки

## Архитектура (текущая)

### MCP
```
Opencode (local) --MCP--> Render /mcp --> FastMCP
  ├── get_weather() → WeatherMonitorAgent
  ├── send_weather_to_telegram() → WeatherNotifierAgent → /mytelegram → Telegram
  └── [dynamic tools] ← загружаются через REST API
```

### REST-эндпоинты
```
POST   /api/agents/mcp-tools/register   # загрузить MCP-тул
GET    /api/agents/mcp-tools/list       # список MCP-тулов
DELETE /api/agents/mcp-tools/{name}     # удалить MCP-тул
POST   /api/agents/upload               # старый dynamic agent
GET    /api/agents/list                 # список агентов
DELETE /api/agents/dynamic/{name}       # удалить dynamic agent
POST   /api/agents/inbox                # старый протокол
GET    /api/agents/health               # статус
```

## Быстрый старт для новой сессии

### Проверить, что сервер жив
```powershell
curl.exe -s https://bot-29-nx0w.onrender.com/api/agents/health
```

### Загрузить MCP-тул
```powershell
.\agents-hub\mcp_tools_examples\upload_mcp_tool.ps1 -Name text_counter -CodeFile .\agents-hub\mcp_tools_examples\text_counter.py -Verbose
```

### Вызвать MCP-тул (через curl)
```powershell
# Инициализация сессии
curl.exe -s -X POST https://bot-29-nx0w.onrender.com/mcp -H "Content-Type: application/json" -H "Accept: application/json" -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-03-26\",\"capabilities\":{},\"clientInfo\":{\"name\":\"test\",\"version\":\"1.0\"}}}"

# tools/list (с mcp-session-id из предыдущего ответа)
curl.exe -s -X POST https://bot-29-nx0w.onrender.com/mcp -H "Content-Type: application/json" -H "Accept: application/json" -H "mcp-session-id: xxx" -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\",\"params\":{}}"
```

### Включить локальный MCP-калькулятор
Раскомментировать `enabled: true` для `local_calculator` в `.opencode/opencode.jsonc`

## Ключевые моменты
- Все изменения сервера — в ветке `mcp_agent_import`, стабильная `mcp-migration` сохранена
- Старый протокол (`/api/agents/inbox`) и новый (MCP) работают параллельно
- На Render ephemeral storage — при рестарте dynamic agents теряются, но MCP-тулы восстанавливаются с диска
- Встроенные MCP-тулы нельзя удалить или перезаписать (защита на уровне кода)
- **Никогда не пушить без подтверждения пользователя**

## Что было сделано в этой сессии (17.05.2026)

### GitHub push для /migrate
- В `SCRIPTs\backup.ps1` добавлен параметр `-Keep` — архив не удаляется после Upload
- В `telegram-hub\cloud-migrate.ps1` добавлен шаг: после FileVault — клонировать `test_opencode`, скопировать архив в `migrate/`, закоммитить и запушить
- Обновлён `AGENTS.md`: описание новой логики `/migrate`

### Restore с GitHub (`-Latest`)
- `SCRIPTs\restore.ps1` полностью переписан:
  - `-Latest` — клонирует `test_opencode`, находит самый свежий архив в `migrate/`, распаковывает
  - `-FileId` — старый способ: скачать с Render FileVault по file_id
  - Подробная справка и инструкция после восстановления
- `AGENTS.md` и `HANDOVER.md` обновлены

### Bootstrap — полная автоматизация нового ПК
- Создан `SCRIPTs\seal.ps1` — шифрует SSH-ключ (`~/.ssh/id_ed25519`) и env-секреты (AGENTS_TUNNEL_SECRET, TELEGRAM_TUNNEL_SECRET) в папку `secrets/`
  - AES-256 + PBKDF2, мастер-пароль
- Создан `SCRIPTs\unseal.ps1` — расшифровывает и устанавливает SSH-ключ в `~/.ssh/`, добавляет в ssh-agent, через setx ставит env-переменные
- Создан `SCRIPTs\bootstrap.ps1` — проверяет Git/Python/Node.js/opencode, запускает `unseal.ps1`
  - `-FromScratch` — клонирует `test_opencode` через HTTPS, восстанавливает последний архив, настраивает всё
- `restore.ps1 -Latest` теперь при ошибке SSH автоматически пробует HTTPS (для новых ПК без ключа)
- `AGENTS.md` обновлён: новая структура backup/restore/bootstrap

## Что было сделано в этой сессии (18.05.2026)

### 1. AGENTS.md — полная переработка (главный итог сессии)
AGENTS.md полностью переписан как единый центр правил для всех трёх узлов.
Новая структура:
- **Неизменяемые принципы** — секреты, push, совместимость
- **Триединство** — архитектура трёх узлов, таблица ролей
- **Файлы и назначение** — все синхронизируемые файлы с политикой конфликтов
- **Жизненный цикл сессии** — пошаговые протоколы для каждого узла:
  - 4.1 Определение платформы (powershell vs sh)
  - 4.2 Старт сессии (контекст → sync → проверка архива → уведомление → ответ)
  - 4.3 Работа в сессии (auto-sync, notify, /sync)
  - 4.4 Завершение сессии (резюме → HANDOVER.md → уведомление → sync)
  - 4.5 Миграция на другой ПК (cloud-migrate.ps1)
  - 4.6 Восстановление на новом ПК (restore/bootstrap/unseal)
- **Команды** — полная таблица с алиасами
- **Sync System** — алгоритм merge HANDOVER.md, auto-sync
- **Telegram-уведомления** — конфиги, скрипты, кодировка, /tg
- **Backup / Restore** — детальные описания скриптов и процессов
- **MCP / Dynamic Agents** — полная справка
- **Приложение** — актуальные ссылки и ID

### 2. Sync System (создана с нуля)
- `telegram-hub/sync.ps1` — движок синхронизации (PowerShell 5.1, для Windows)
- `telegram-hub/sync.sh` — движок синхронизации (sh для Alpine/Linux)
- `telegram-hub/sync.json` — конфиг (repo, branch, node_name, push_after_task)
- `USER.md` — профиль пользователя (имя, модель, предпочтения)
- Авто-синхронизация: при старте, после каждой задачи, при завершении
- Протокол: clone → merge HANDOVER.md (append-only) → push

### 3. Архив (бэкап) — обновлён
- Создан свежий архив `my_best_work_2026-05-18_014728.zip`
- **Render FileVault:** file_id=1aa908bf550a45109a7e9861f900d032 (папка "migrate")
- **GitHub:** https://github.com/alexsmy/test_opencode/migrate/ commit 2d61e29
- Предыдущий archive (17.05) заменён

### 4. Render — alpine-experiment OOM тест
- Установлена `OPENCODE_MEMORY_LIMIT=0.4` в Render Dashboard
- Запушен коммит в `alpine-experiment`
- Серверный брат успешно стартовал на Alpine, создал time.html, отправил код в Telegram
- Серверный брат не синхронизировался с GitHub на старте (исправлено в AGENTS.md)

### 5. Исправления
- **Старт на сервере:** теперь сначала sync.sh (pull), потом проверка архива
- **Завершение на сервере:** теперь sync.sh + notify.sh (без PowerShell)
- **Правило пуша:** HANDOVER.md/CONTEXT.md/USER.md — автоматически, остальное — с разрешения

### Изменённые файлы
- `AGENTS.md` — полная переработка (новая структура, 11 разделов)
- `telegram-hub/sync.ps1` — новый файл
- `telegram-hub/sync.sh` — новый файл
- `telegram-hub/sync.json` — новый файл
- `USER.md` — новый файл
- `HANDOVER.md` — обновлён
- `CONTEXT.md` — обновлён
- `my_ai_opencode_server/Dockerfile` — добавлена заметка о OPENCODE_MEMORY_LIMIT

### Текущее состояние
- AGENTS.md — полная документация, читается при старте любой сессии
- Sync System — работает на Windows (проверено) и Linux
- Архив на двух носителях: Render FileVault + GitHub
- Серверный брат на Alpine, OPENCODE_MEMORY_LIMIT=0.4, работает стабильно
- Триединство: notebook ↔ GitHub ↔ server — настроено

## Что было сделано в этой сессии (18.05.2026)

### Настройка нового ПК (notebook-win11) с нуля
1. **Определение состояния** — на новом ПК отсутствовали Git, Node.js, opencode, SSH-ключ, секреты
2. **Установка ПО:**
   - Git 2.54.0 (через winget)
   - Node.js v24.15.0 + npm (через winget)
   - opencode v1.15.4 (Desktop Installer, уже был скачан)
   - Python 3.13.3 (уже был в AppData, добавлен в PATH)
3. **Восстановление секретов:**
   - SSH-ключ и env-секреты расшифрованы из `secrets/` (AES-256 + PBKDF2)
   - Мастер-пароль получен от пользователя
   - GitHub аутентификация: `Hi alexsmy!` — работает
4. **Настройка узлов** — обновлена архитектура триединства:
   - Старые имена `notebook`/`other-pc` → `notebook-win10`/`notebook-win11`
   - Синхронизация через HANDOVER.md/CONTEXT.md/USER.md (GitHub) + архивы (FileVault + GitHub migrate)
5. **Telegram-уведомления** — настроены и проверены (server-режим, `OK`)
6. **Обновлены файлы:** CONTEXT.md, AGENTS.md, HANDOVER.md, USER.md, sync.json

### 6. Свежий архив (cloud-migrate)
- Создан и загружен новый архив `my_best_work_2026-05-18_100832.zip` (63 КБ)
- **Render FileVault:** file_id=bb3288ac9d764d278595b5ae5877e18f
- **GitHub:** https://github.com/alexsmy/test_opencode/commit/0ac0aa6

### 7. Очистка старых архивов
- **FileVault:** удалены 4 старых архива (3ebec6d8..., 1aa908bf..., 749842f1..., d6d74076...)
- **GitHub:** удалены 3 старых архива (020651.zip, 014728.zip, 213644.zip), коммит a7fd31d
- Оставлены только 3 последних архива на обоих носителях
- AGENTS.md обновлён (file_id, commit, политика хранения)

### Изменённые файлы
- `CONTEXT.md` — обновлён (три узла, настройки notebook-win11, Sync System)
- `AGENTS.md` — переименование узлов (notebook→notebook-win10, other-pc→notebook-win11), file_id
- `USER.md` — переименование узлов
- `telegram-hub/sync.json` — node_name: notebook → notebook-win11
- `HANDOVER.md` — добавлена секция этой сессии

### Текущее состояние
- Три узла: notebook-win10 (Win10), notebook-win11 (Win11, текущий), server (Alpine/Render)
- Все инструменты установлены (Git, Node, Python, opencode, SSH)
- Синхронизация работает (GitHub push HANDOVER.md/CONTEXT.md/USER.md)
- Telegram-уведомления работают (server-режим)
- Backup/restore: готов к миграциям между устройствами

### 7. Универсальный MCP-инструмент `send_telegram_message`
- Создан `agents-hub/mcp_tools_examples/send_telegram_message.py` — универсальный Telegram-сендер
- Возможности: текст (HTML/MarkdownV2/plain), редактирование, файлы по URL (PDF/JPG/MP4/...)
- Использует прямой Telegram Bot API (не через тоннель)
- Автоопределение типа файла: фото → sendPhoto, видео → sendVideo, остальное → sendDocument
- Загружен на сервер через `POST /api/agents/mcp-tools/register`
- Успешно протестирован:
  - Текстовое сообщение (id: 680)
  - Файл AGENTS.md (через FileVault → Telegram)
  - Файл perf-test.json через FileVault
- **Бенчмарк (call time, без создания сессии):**
  - Только текст: **832ms** best, 1094ms avg (3 runs)
  - Текст + файл: **1331ms** best, 1519ms avg (3 runs)
  - Полный цикл (сессия + файл): ~2.55s
- Ключевые находки:
  - При загрузке MCP-тулов через PowerShell были проблемы с кодировкой (PowerShell ConvertTo-Json ломает код). Нужно использовать Python для отправки JSON.
  - `\u` в docstring вызывает SyntaxError из-за unicodeescape — нужно использовать `r"""..."""`
  - MCP session создаётся через GET /mcp/ с Accept: text/event-stream
- **Проверены все медиа-типы (18.05.2026):**
  - Фото (реальный JPG) → `sendPhoto` ✅ (180KB, GigaChat.jpg)
  - Видео (MP4) → `sendVideo` ✅ (BigBuckBunny sample)
  - Аудио (MP3) → `sendAudio` ✅ (SoundHelix sample)
  - Голос (MP3 + media_type="voice") → `sendVoice` ✅
  - ОGG → `sendVoice` по умолчанию (определение по расширению)
  - FileVault URL без расширения → определение по `file_name` параметру
- **Добавлен параметр `media_type`** для принудительного выбора типа
- **Инструмент повышен до built-in** в mcp_server.py (ветка mcp_agent_import)

## Что было сделано в этой сессии (18.05.2026) — продолжение

### 8. Telegram Duplex — двусторонняя связь

**Багфикс:** при деплое упал ImportError — импортировал `_check_secret`, а в `tunnel.py` функция называется `_require_secret`. Исправлено (коммит `7bc11fe`), убрал дублирование `_check_auth`.
Создана инфраструктура для full-duplex: сообщения из Telegram → opencode и наоборот.

**Серверные компоненты (ветка mcp_agent_import, коммит 5b16208):**
- `services/telegram_listener.py` — асинхронный polling Telegram Bot API (long-poll getUpdates)
  - Фильтр по `TELEGRAM_CHAT_ID` (игнорирует чужие чаты)
  - Сохраняет входящие сообщения в `data/telegram_inbox/msg_{update_id}.json`
  - offset-трекинг через `data/telegram_inbox/_offset.txt` (переживает рестарты)
  - Запускается как background task в `bot.py` (lifespan)
- `routers/telegram_inbox_api.py` — REST API для чтения inbox (все требуют `X-Agents-Tunnel-Secret`):
  - `GET /api/telegram/inbox` — непрочитанные сообщения
  - `POST /api/telegram/inbox/ack` — отметить все как прочитанные
  - `POST /api/telegram/inbox/{update_id}/ack` — отметить конкретное
  - `GET /api/telegram/inbox/status` — статистика (total, unread)
  - `GET /api/telegram/inbox/all` — все сообщения с историей
- `AGENTS.md` — добавлен раздел 12 "Duplex: двусторонняя связь через Telegram"

**Как это работает:**
1. Telegram пользователь пишет боту (@imgtestlivebot)
2. Сервер (listener) ловит сообщение через getUpdates
3. Сообщение сохраняется в data/telegram_inbox/
4. AI (в opencode) периодически проверяет GET /api/telegram/inbox
5. AI отвечает через @weather_agents send_telegram_message
6. Всё дублируется: ответ есть и в Telegram, и в opencode

**Схема:**
```
Telegram → bot → Render (listener) → data/telegram_inbox/ → API → opencode → send_telegram_message → Telegram
```

## Полезные ссылки
- GitHub: https://github.com/alexsmy/bot_29/tree/mcp_agent_import
- Render: https://bot-29-nx0w.onrender.com
- FileVault: https://bot-29-nx0w.onrender.com/files
- MCP SDK Python: https://github.com/modelcontextprotocol/python-sdk
