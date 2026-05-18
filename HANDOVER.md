# Handover: MCP Agent Import — вводная для новой сессии

## Текущее состояние

### Локально (my_best_work) — модульная структура
- `AGENTS.md` — 38 строк, маршрутизация по тематическим файлам
- `docs/opencode/*.md` — 7 файлов: project, nodes, workflow, sync, telegram, backup-restore, mcp-agents
- `CONTEXT.md` — 35 строк, чистый снэпшот
- `USER.md` — предпочтения пользователя
- `HANDOVER.md` — лог действий (этот файл, append-only)
- `opencode.jsonc` — instructions: AGENTS.md + CONTEXT.md + USER.md + docs/opencode/*.md; MCP: weather_agents (remote, enabled)
- `agents-hub/mcp_tools_examples/` — 6 примеров + скрипт загрузки
- `telegram-hub/` — notify, sync, session-start/end, конфиги

## Архитектура

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
GET    /api/agents/responses            # история ответов
GET    /api/agents/responses/{file_id}  # конкретный ответ
GET    /api/agents/health               # статус
```

### Документация
| Файл | Назначение |
|------|-----------|
| `AGENTS.md` | Правила и маршрутизация |
| `docs/opencode/project.md` | Структура проекта |
| `docs/opencode/nodes.md` | Узлы и переносимость |
| `docs/opencode/workflow.md` | Жизненный цикл сессии, команды |
| `docs/opencode/sync.md` | Алгоритм слияния, auto-sync |
| `docs/opencode/telegram.md` | Уведомления, параметры, конфиги |
| `docs/opencode/backup-restore.md` | Бэкап и восстановление |
| `docs/opencode/mcp-agents.md` | MCP, REST API, dynamic agents |

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

## Ключевые моменты
- Все изменения сервера — в ветке `mcp_agent_import`, стабильная `mcp-migration` сохранена
- Старый протокол (`/api/agents/inbox`) и новый (MCP) работают параллельно
- На Render ephemeral storage — при рестарте dynamic agents теряются, но MCP-тулы восстанавливаются с диска
- Встроенные MCP-тулы нельзя удалить или перезаписать (защита на уровне кода)
- **Никогда не пушить без подтверждения пользователя ни в main ветку, ни в задеплоиную!**


## Что было сделано в этой сессии (18.05.2026)

### AGENTS.md — полная переработка (главный итог сессии)
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


## Что было сделано в этой сессии (18.05.2026) — реструктуризация и доработка

### Задача: дополнить модульную структуру недостающей информацией
После сравнения текущей (модульной) структуры с предыдущим монолитным AGENTS.md (610 строк) выявлены и устранены пробелы:

### 1. Создан `docs/opencode/sync.md`
- Алгоритм слияния HANDOVER.md (построчный merge из предыдущей версии)
- Параметры конфига sync.json
- Auto-sync: на старте, после задач, при завершении
- Команда `/sync` и её протокол

### 2. Дополнен `docs/opencode/telegram.md`
- notify.ps1: полная таблица параметров (-Message, -Kind, -DeleteAfterSeconds, -DisableWebPagePreview, -MessageId)
- Серверный контракт: POST /mytelegram, тело и заголовки
- Конфиги: telegram-route.json, telegram-notify.json с полным описанием полей
- Переменные окружения
- Добавлены ссылки на session-start.ps1 / session-end.ps1

### 3. Дополнен `docs/opencode/mcp-agents.md`
- Конфигурация MCP-подключения в opencode.jsonc
- Полная таблица REST API эндпоинтов (MCP-тулы + старые агенты)
- Примечание: старый протокол всё ещё работает, скрипты agent-call.ps1/agents-tunnel.json не обязательны
- agent-deploy.json: восстановление dynamic agents при рестарте Render

### 4. Дополнен `docs/opencode/workflow.md`
- Определение платформы (powershell vs sh)
- Полная таблица команд с алиасами
- Auto-sync и уведомления в работе сессии
- Append-only правило для HANDOVER.md

### 5. Обновлены маршрутизация и индексы
- AGENTS.md: добавлена ссылка на sync.md и REST API
- CONTEXT.md: добавлена ссылка на sync.md
- docs/opencode/README.md: sync.md добавлен в порядок чтения (поз. 7)

### 6. Полный цикл cloud-migrate (FileVault + GitHub)
- **Render FileVault:** file_id=`f44ccd6d9f8343eeb376bd382137b16a`
- **Render URL:** https://bot-29-nx0w.onrender.com/files/open/f44ccd6d9f8343eeb376bd382137b16a
- **GitHub:** https://github.com/alexsmy/test_opencode/commit/d1e2a96 (migrate/)
- **Telegram:** уведомление отправлено

### Изменённые файлы
- `docs/opencode/sync.md` — новый файл
- `docs/opencode/telegram.md` — расширен
- `docs/opencode/mcp-agents.md` — расширен
- `docs/opencode/workflow.md` — расширен
- `docs/opencode/README.md` — обновлён
- `AGENTS.md` — обновлён
- `CONTEXT.md` — обновлён
- `HANDOVER.md` — обновлён

## Полезные ссылки
- GitHub: https://github.com/alexsmy/bot_29/tree/mcp_agent_import
- Render: https://bot-29-nx0w.onrender.com
- FileVault: https://bot-29-nx0w.onrender.com/files
- MCP SDK Python: https://github.com/modelcontextprotocol/python-sdk
