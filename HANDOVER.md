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

### Sync System — триединство (ноутбук / другой ПК / сервер)
- Создана полная архитектура синхронизации трёх узлов через GitHub
- Создан `telegram-hub/sync.ps1` — PowerShell-скрипт (для Windows), клонирует репозиторий, мержит HANDOVER.md, пушит
- Создан `telegram-hub/sync.sh` — Bash-скрипт (для Linux/serber), аналогичная логика
- Создан `telegram-hub/sync.json` — конфиг (repository, branch, node_name, push_after_task)
- Создан `USER.md` — профиль пользователя (имя, модель, предпочтения, контакты, настройки нод)
- Обновлён `AGENTS.md`:
  - Добавлена команда `/sync`
  - Добавлен раздел Sync System с архитектурой и протоколом
  - Добавлены правила auto-sync (при старте/после задачи/при завершении)
  - Обновлено правило пуша: sync-файлы можно пушить автоматически, остальное — только с разрешения

### Render — alpine-experiment OOM тест
- Установлена `OPENCODE_MEMORY_LIMIT=0.4` в Render Dashboard
- Запушен коммит в `alpine-experiment` с заметкой о переменной
- Серверный брат успешно стартовал на Alpine, создал time.html, отправил код в Telegram

## Полезные ссылки
- GitHub: https://github.com/alexsmy/bot_29/tree/mcp_agent_import
- Render: https://bot-29-nx0w.onrender.com
- FileVault: https://bot-29-nx0w.onrender.com/files
- MCP SDK Python: https://github.com/modelcontextprotocol/python-sdk
