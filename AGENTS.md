# Правила для AI-агента

## Telegram-hub

### Секреты
- Не храни токены, пароли или ключи в коде
- Не коммить `telegram-config.json` или любые файлы с секретами
- Для server-режима используй переменную окружения, указанную в `telegram-route.json.server.secret_env`
- Никогда не выводи секреты в логи или сообщения

### Совместимость
- Не ломай существующие файлы и логику
- local-режим (браузерный) должен оставаться рабочим всегда
- server-режим — основной, local — fallback
- Добавляй новые модули маленькими файлами, не раздувай существующие

### Конфиги
- `telegram-route.json` — маршрутизация (mode, параметры server/local)
- `telegram-notify.json` — вкл/выкл и уровень уведомлений
- `telegram-config.json` — токен и chat_id (только для local-режима)

### Команды
- `/start` — старт сессии: загрузка контекста + приветственное уведомление в Telegram
- `/sync` — синхронизация с GitHub: пуллит HANDOVER.md/CONTEXT.md/USER.md, мержит, пушит
- `/tg` — управление уведомлениями через `telegram-notify.json`
- Не меняй `telegram-route.json` при обработке `/tg`
- `notify.ps1` читает `telegram-notify.json.enabled` — если false, отправка скипается (вывод SKIPPED)
- `notify.ps1` поддерживает `-Verbose` для отладки

### Старт новой сессии
При приветствии пользователя ("Привет", "Hi", "start") или команде `/start`:
1. Прочитай `CONTEXT.md` и `HANDOVER.md` в корне проекта
2. Определи свою модель ИИ (из системного контекста, например "deepseek-v4-flash-free")
3. **Синхронизируйся с GitHub** — запусти скрипт синхронизации, если доступен:
   - Если есть `powershell`: `powershell -File telegram-hub\sync.ps1 -Verbose`
   - Если есть `sh` (Linux, Alpine): `sh telegram-hub/sync.sh -v`
   - После синхронизации перечитай `HANDOVER.md`, `CONTEXT.md`, `USER.md`
4. **Проверь облачный архив** — сравни с последним коммитом на GitHub:
   ```
   git ls-remote https://github.com/alexsmy/test_opencode.git HEAD
   ```
   - Если хеш отличается от `last_github_commit` в AGENTS.md → на сервере есть новые данные
   - Спроси пользователя: «На GitHub есть более свежий архив. Скачать и продолжить с того места?»
   - Если да → на Windows запусти `restore.ps1 -Latest`, на Linux `restore.sh -Latest` (если есть)
   - Запиши новый хеш коммита в AGENTS.md
5. Запусти уведомление (если возможно):
   - На Windows: `powershell -File telegram-hub\session-start.ps1 -Model "<модель>" -Verbose`
   - На Linux (сервер): `sh telegram-hub/notify.sh "Сессия запущена. Модель: <модель>"`
6. Сообщи пользователю, что сессия запущена, синхронизирована и уведомление отправлено

### Завершение сессии
При прощании пользователя ("Пока", "до встречи", "bye", "goodbye") или команде `/end`:
1. Сформируй краткое резюме сессии: что было сделано, какие файлы изменены, текущее состояние
2. Обнови `HANDOVER.md` — добавь секцию "Что было сделано в этой сессии" с датой и итогами
3. Обнови `AGENTS.md` — если появились новые правила или изменения
4. Запусти скрипт уведомления:
   - На Windows: `powershell -File telegram-hub\session-end.ps1 -Summary "<краткий итог>" -Verbose`
   - На Linux (сервер): `sh telegram-hub/notify.sh "Сессия завершена: <краткий итог>"`
5. Выполни синхронизацию:
   - На Windows: `powershell -File telegram-hub\sync.ps1 -Verbose`
   - На Linux: `sh telegram-hub/sync.sh -v`
6. Сообщи пользователю, что HANDOVER.md обновлён и сессия завершена

### Миграция на другой ПК / другой opencode
При запросе пользователя ("Новый компьютер", "переходим на другой opencode", "перенос", "миграция") или команде `/migrate`:
1. Обнови `HANDOVER.md` — полное резюме всей работы, текущее состояние, что знать
2. Обнови `AGENTS.md` — запиши последний `file_id` backup
3. Запусти `powershell -File telegram-hub\cloud-migrate.ps1 -Verbose`
4. Скрипт создаст архив, **загрузит на Render FileVault + запушит в `test_opencode/migrate/` на GitHub**, отправит уведомление
5. Сообщи пользователю `file_id`, URL и статус GitHub пуша

### Восстановление облачного контекста
При запросе пользователя ("вспомни весь облачный контекст", "загрузи контекст из облака", "restore cloud") или команде `/cloud-restore`:
1. Проверь наличие `HANDOVER.md` и `CONTEXT.md` в текущей папке
2. Если их нет или они пустые — скачай последний бэкап:
   - **С GitHub (рекомендуется):** `restore.ps1 -Latest`
   - **С Render FileVault:** `restore.ps1 -FileId <file_id>` (file_id из AGENTS.md)
3. Распакуй архив, восстанови файлы
4. Загрузи контекст из восстановленных `CONTEXT.md` и `HANDOVER.md`
5. Сообщи пользователю, что контекст восстановлен

### Форматирование сообщений
- Для переноса строки используй `` `n `` (backtick-n) внутри двойных кавычек PowerShell
- НЕ используй `%0A` — PowerShell закодирует `%` в `%25`, и перевод строки не сработает
- Пример: `-Message "строка 1`nстрока 2"`

### Кодировка (важно!)
- `notify.ps1` сам конвертирует тело в UTF-8 bytes — проблем нет
- При прямом `Invoke-RestMethod` с `-Body $string` PowerShell шлёт в Windows-1252, а не UTF-8
- **ОБЯЗАТЕЛЬНО** конвертировать в UTF-8 bytes перед отправкой:
```powershell
$jsonBody = '{"text":"сообщение на русском °C"}'
$utf8Body = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
Invoke-WebRequest -Uri "https://..." -Method Post -Body $utf8Body -ContentType "application/json; charset=utf-8" -Headers @{ "x-telegram-tunnel-secret" = $secret }
```
- Без этого русские буквы, `°`, `—`, `€` и др. символы за пределами ASCII выдадут 422 ошибку.

## MCP (Model Context Protocol) — стандартный доступ к погодным агентам

Погодные агенты (weather_monitor, weather_notifier) доступны через **MCP (Model Context Protocol)** — отраслевой стандарт, поддерживаемый opencode, Claude, Cursor и др.

### Конфигурация (локальная)
Прописана в `.opencode/opencode.jsonc`:
```json
"mcp": {
  "weather_agents": {
    "type": "remote",
    "url": "https://bot-29-nx0w.onrender.com/mcp",
    "headers": {
      "x-agents-tunnel-secret": "{env:AGENTS_TUNNEL_SECRET}"
    },
    "enabled": true
  }
}
```

### Доступные MCP-инструменты
| Инструмент | Описание |
|---|---|
| `get_weather` | Получить текущую погоду в Уфе (температура, влажность, ветер, описание) |
| `send_weather_to_telegram(action="update")` | Отправить/обновить погоду в Telegram. `action=reset` — сбросить message_id |

### Использование в opencode
**Напрямую:** просто попроси — «получи погоду в Уфе» или «отправь погоду в телеграм». Opencode сам вызовет нужный инструмент.

**Через @-mention:** `@weather_agents get_weather`

### Особенности
- Секрет `AGENTS_TUNNEL_SECRET` — переменная окружения пользователя
- MCP session ID передаётся в заголовке `mcp-session-id` (opencode управляет автоматически)
- message_id хранится на сервере в `data/weather/telegram_message_id.txt`. При деплое Render'а сбрасывается — следующий вызов создаст новое сообщение
- Старый протокол (`/api/agents/inbox`) тоже работает на сервере, но для новых задач используй MCP

### Агенты
- `weather_monitor` — получает погоду с open-meteo.com (бесплатно, без ключа)
- `weather_notifier` — получает погоду + отправляет/обновляет в Telegram через localhost-туннель `/mytelegram`

### Архитектура
```
Opencode (local) --MCP--> Render /mcp --> FastMCP
  ├── get_weather() → WeatherMonitorAgent
  ├── send_weather_to_telegram() → WeatherNotifierAgent → /mytelegram → Telegram
  └── [dynamic tools] ← загружаются через REST API
```

### Ветка на GitHub
- Ветка: `mcp_agent_import` (актуальная, деплой на Render)
- Предыдущая: `mcp-migration` (стабильная, backup)
- Файлы: `services/agents/weather_monitor.py`, `services/agents/weather_notifier.py`, `services/agents/mcp_server.py`
- Registry: `services/agents/registry.py`

### Протокол (MCP)
- `POST /mcp` — Streamable HTTP transport
- Content-Type: `application/json`
- Accept: `application/json`
- Заголовок сессии: `mcp-session-id` (из ответа на initialize)
- Секрет: заголовок `x-agents-tunnel-secret` из `{env:AGENTS_TUNNEL_SECRET}`

## Dynamic Agents (ALM — Agent Lifecycle Management)

### Динамические агенты
- Агенты загружаются на сервер через `POST /api/agents/upload` (не через GitHub)
- Код сохраняется в `data/agents/dynamic/{name}.py` на сервере
- Копия кода также сохраняется в FileVault (папка "Agents") для просмотра через `/files`
- При рестарте Render динамические агенты теряются (ephemeral storage)
- Для автовосстановления используй `agent-deploy.json` (локальный конфиг)

### Интерфейс динамического агента
```python
NAME = "my_agent"  # обязательное имя

async def run(query: str, args: dict) -> dict:
    # логика агента
    return {"ok": True, "result": "..."}
```

### Эндпоинты (серверные, ветка mcp_agent_import)

| Метод | Путь | Назначение |
|---|---|---|
| `POST` | `/api/agents/upload` | Загрузить динамического агента (старый протокол) |
| `GET` | `/api/agents/list` | Список агентов (builtin + dynamic) |
| `DELETE` | `/api/agents/dynamic/{name}` | Удалить динамического агента |
| `POST` | `/api/agents/mcp-tools/register` | **Загрузить MCP-инструмент (новый протокол)** |
| `GET` | `/api/agents/mcp-tools/list` | **Список загруженных MCP-инструментов** |
| `DELETE` | `/api/agents/mcp-tools/{name}` | **Удалить MCP-инструмент** |
| `GET` | `/api/agents/responses` | Список ответов агентов из FileVault |
| `GET` | `/api/agents/responses/{file_id}` | Детальный ответ агента |
| `POST` | `/api/agents/inbox` | Вызов агента (старый протокол) |
| `GET` | `/api/agents/health` | Статус |

Все эндпоинты (кроме health) требуют заголовок `X-Agents-Tunnel-Secret`.

### Формат MCP-инструмента (новый протокол)

Загружается через `POST /api/agents/mcp-tools/register`:

```python
# Код — простая async-функция с type hints
async def tool_name(param1: str, param2: int = 0) -> str:
    """Описание — станет MCP tool description"""
    return f"Результат: {param1}, {param2}"
```

Параметры функции автоматически становятся inputSchema MCP.  
Встроенные тулы (`get_weather`, `send_weather_to_telegram`) нельзя перезаписать или удалить.  
При рестарте Render'а тулы автоматически восстанавливаются с диска.

### Примеры MCP-тулов для загрузки

| Инструмент | Что делает |
|---|---|
| `current_time` | Текущее время в любом часовом поясе |
| `random_quote` | Случайная цитата |
| `text_counter` | Счётчик слов, символов, предложений |
| `password_gen` | Генератор безопасных паролей |
| `echo_bot` | Эхо-ответ (для отладки MCP) |

### Чтение ответов агентов (правила для AI)

После вызова агента:
1. Ответ приходит напрямую (через MCP или `/api/agents/inbox`)
2. Копия ответа сохраняется в FileVault в папку "Agents"
3. Чтобы прочитать историю ответов: `GET /api/agents/responses` (список)
4. Чтобы прочитать конкретный ответ: `GET /api/agents/responses/{file_id}`
5. FileVault доступен через веб-интерфейс: `https://bot-29-nx0w.onrender.com/files`
6. Для долгих агентов можно периодически проверять `/api/agents/responses`

### Структура FileVault для агентов

```
FileVault (data/filevault_uploads/)
├── _folders.json          # метаданные папок
├── fld_xxx...json         # мета папки Agents
├── {uuid}.bin             # blob ответа агента
├── {uuid}.json            # мета ответа агента (folder_id указывает на Agents)
└── ...
```

В веб-интерфейсе `/files` папка "Agents" отображается в дереве папок слева.

## Backup / Restore (перенос на другой ПК)

### Команды Opencode
- `/backup` — создать локальный архив `my_best_work`
- `/backup upload` — создать архив + загрузить на Render FileVault

### Скрипты
- `SCRIPTs\backup.ps1` — создаёт zip и (опционально) выгружает
  - `-Upload` — загрузить на Render
  - `-Keep` — не удалять архив после Upload (нужен для GitHub пуша)
  - `-PassThru` — вернуть объект с метаданными вместо текстового вывода
  - `-Verbose` — подробный вывод
- `SCRIPTs\restore.ps1` — скачивает и восстанавливает
  - `-Latest` — последний архив с GitHub (рекомендуется)
  - `-FileId <id>` — с Render FileVault по file_id
  - `-Verbose` — подробный вывод
  - При `-Latest` сначала пробует SSH, при ошибке — HTTPS (для новых ПК без ключа)
- `SCRIPTs\seal.ps1` — **зашифровать SSH-ключ и env-секреты** (выполнить на старом ПК)
  - Шифрует `~/.ssh/id_ed25519` → `secrets/ssh.enc`
  - Читает `AGENTS_TUNNEL_SECRET` и `TELEGRAM_TUNNEL_SECRET` из системы и шифрует → `secrets/env.enc`
  - Использует AES-256 + PBKDF2 (мастер-пароль)
  - Зашифрованные файлы попадают в backup автоматически
- `SCRIPTs\unseal.ps1` — **расшифровать и установить SSH + секреты** (на новом ПК)
  - Спрашивает мастер-пароль, расшифровывает SSH-ключ
  - Сохраняет в `~/.ssh/id_ed25519`, добавляет в ssh-agent
  - Расшифровывает env-переменные, устанавливает через setx
  - Поддерживает `-MasterPassword` для автоматизации
- `SCRIPTs\bootstrap.ps1` — **полная настройка нового ПК одной командой**
  - Проверяет Git, Python, Node.js, opencode
  - `-FromScratch` — клонирует `test_opencode` (HTTPS), восстанавливает архив, настраивает всё
  - Запускает `unseal.ps1` для SSH + секретов
  - Выводит готовые инструкции
- `secrets/` — папка с зашифрованными данными (автоматически в backup)

### Процесс backup (выполняет AI)
1. Запустить `backup.ps1 -Upload -Verbose`
2. Прочитать `file_id` из вывода
3. Сообщить пользователю `file_id` и public_url
4. Записать `file_id` в этот файл (AGENTS.md)
5. Отправить уведомление в Telegram

### Процесс migrate (выполняет AI — команда `/migrate`)
1. Обновить HANDOVER.md
2. Запустить `cloud-migrate.ps1 -Verbose`
3. Прочитать `file_id` и статус GitHub пуша из вывода
4. Записать `file_id` в этот файл (AGENTS.md)
5. Сообщить пользователю результат

### Процесс restore (на новом ПК)
1. Установить Python + Node.js + Git + Opencode
2. Запустить `restore.ps1 -Latest` — скачает последний архив из GitHub и распакует
3. Настроить SSH ключ и добавить в GitHub
4. Установить env-переменные (см. вывод restore.ps1)
5. Открыть `opencode` в распакованной папке

### Процесс bootstrap (на новом ПК, максимально автоматизированно)
Если уже есть распакованная папка `my_best_work` (из архива или restore):
1. Открыть PowerShell в папке `my_best_work`
2. Запустить: `powershell -File SCRIPTs\bootstrap.ps1`
3. Ввести мастер-пароль (который задавали на старом ПК через seal.ps1)
4. Всё — SSH ключ восстановлен, секреты установлены, можно открывать opencode

Если ничего нет (чистый ПК):
1. Установить Git + Python + Node.js
2. `powershell -File bootstrap.ps1 -FromScratch`
3. Скрипт сам склонирует `test_opencode`, распакует последний архив и настроит всё

### Что переносится
- Все конфиги, скрипты, навыки, инструкции — **в zip-архиве**
- Серверные агенты — **на GitHub** (ветка mcp_agent_import), с ним ничего делать не надо
- SSH-ключ и переменные окружения — **зашифрованы в `secrets/`**, расшифровываются через master-пароль
- Переменные окружения (`AGENTS_TUNNEL_SECRET`) — **в зашифрованном виде в архиве**, НЕ ставятся вручную

### Последний backup
- file_id: 1aa908bf550a45109a7e9861f900d032
- дата: 2026-05-18
- url: https://bot-29-nx0w.onrender.com/files/open/1aa908bf550a45109a7e9861f900d032
- GitHub: https://github.com/alexsmy/test_opencode/tree/main/migrate
- last_github_commit: 2d61e29

## Sync System — триединство (ноутбук / другой ПК / сервер)

### Архитектура
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  notebook    │    │  other-pc   │    │   server    │
│  (Win/PS)   │    │  (Win/PS)   │    │   (Linux)   │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │                  │                  │
       └──────────────────┼──────────────────┘
                          ▼
                 ┌─────────────────┐
                 │  GitHub Repo    │
                 │ ninamc4e/       │
                 │ my_ai_opencode_ │
                 │ server          │
                 │                 │
                 │ HANDOVER.md     │
                 │ CONTEXT.md      │
                 │ USER.md         │
                 └─────────────────┘
```

Все три узла синхронизируются через единый GitHub-репозиторий.  
Пользователь видит одного AI независимо от того, где работает.

### Файлы
| Файл | Назначение | Конфликты |
|---|---|---|
| `HANDOVER.md` | Лог сессий (append-only) | Мержится: новые строки дописываются |
| `CONTEXT.md` | Контекст проекта | Last-writer-wins |
| `USER.md` | Профиль пользователя | Last-writer-wins |

### Протокол синхронизации
1. `git clone --depth 1` репозитория во временную папку
2. Pull `HANDOVER.md`:
   - Если remote — префикс local → local новее, пушим local
   - Если local — префикс remote → remote новее, дописываем новые строки
   - Если разные → берём local (текущий узел важнее)
3. `CONTEXT.md` и `USER.md` — копируются local → remote если local новее
4. `git add`, `git commit`, `git push`
5. Временная папка удаляется

### Скрипты
- `telegram-hub/sync.ps1` — для Windows (PowerShell)
- `telegram-hub/sync.sh` — для сервера/ Linux (sh, без bash)
- `telegram-hub/sync.json` — конфиг (repository, branch, node_name)

### Команда `/sync`
При словах "синхронизируйся", "sync", "обнови контекст" или команде `/sync`:
1. Запусти `powershell -File telegram-hub\sync.ps1` (на Windows) или `sh telegram-hub/sync.sh` (на сервере)
2. Прочитай обновлённые `HANDOVER.md`, `CONTEXT.md`, `USER.md`
3. Сообщи пользователю результат синхронизации
4. Если enabled=true — отправь уведомление в Telegram

### Auto-sync (автоматическая синхронизация)
- **При старте сессии** ("Привет", "/start"): после чтения HANDOVER.md/CONTEXT.md выполни `/sync` (pull latest)
- **После каждой задачи**: выполни `sync.ps1`/`sync.sh` автоматически перед следующим ответом
- **При завершении сессии** ("Пока", "/end"): выполни `sync.ps1`/`sync.sh` после обновления HANDOVER.md
- Проверяй `telegram-hub/sync.json.push_after_task` — если `false`, не делай auto-sync после задач

### USER.md
- Читай `USER.md` при старте сессии (после CONTEXT.md и HANDOVER.md)
- Содержит: имя пользователя, модель по умолчанию, предпочтения, часовой пояс, контакты
- Используй эти данные для персонализации ответов

### Как вести себя как единый AI
- **На старте сессии**: прочитай HANDOVER.md (последние события), CONTEXT.md (контекст), USER.md (кто я). Ответь так, будто та же сессия продолжается.
- **При `/sync`**: скажи "Обновил контекст из GitHub, продолжаем" (не рассказывай всю историю заново).
- **Формат HANDOVER.md** — append-only: каждая сессия дописывает новые секции, ничего не удаляет.
- **Не путай узлы** — пользователь может быть на любом из трёх. HANDOVER.md покажет, откуда был предыдущий разговор.

### Правила
- Новые возможности — маленькими файлами, не раздувай существующие
- Сохраняй совместимость старых и новых конфигураций
- **После завершения каждой задачи отправляй уведомление в Telegram** через `notify.ps1` (если enabled=true)
- Проверяй `telegram-notify.json.enabled` перед отправкой
- **Пуш HANDOVER.md/CONTEXT.md/USER.md через sync.ps1/sync.sh — разрешён автоматически**
- **Любой другой пуш в GitHub — только с явного подтверждения пользователя**
