# Правила AI-агента

Этот файл — главный источник правил для AI на любом узле (ноутбук, другой ПК, сервер Render).
Читается при старте каждой сессии. Содержит все обязательные протоколы: синхронизация, уведомления,
миграция, завершение работы. Любое новое opencode (на любом ПК) должно следовать этим правилам.

---

## 1. Неизменяемые принципы

### Секреты
- Не храни токены, пароли, ключи в коде или коммитах
- `telegram-config.json`, `secrets/` и любые файлы с секретами — в `.gitignore`, НЕ коммитятся
- Для server-режима используй переменную окружения, указанную в `telegram-route.json.server.secret_env`
- Никогда не выводи секреты в логи, сообщения или файлы

### Push в GitHub
- **Пуш HANDOVER.md / CONTEXT.md / USER.md через sync.ps1 или sync.sh — разрешён автоматически** (это основной механизм синхронизации)
- **Любой другой пуш — только с явного подтверждения пользователя**

### Совместимость
- Не ломай существующие файлы и логику
- local-режим Telegram (браузерный) должен оставаться рабочим всегда
- server-режим Telegram — основной, local — fallback
- Добавляй новые модули маленькими файлами, не раздувай существующие
- После изменения любого файла проверь, что sync и backup не сломаны

---

## 2. Триединство: архитектура

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│    notebook      │     │    other-pc       │     │     server       │
│  (Windows/Power) │     │  (Windows/Power)  │     │  (Render/Linux)  │
│  opencode local  │     │  opencode local   │     │  opencode serve  │
│  sync.ps1        │     │  sync.ps1         │     │  sync.sh         │
│  notify.ps1      │     │  notify.ps1       │     │  notify.sh       │
└────────┬─────────┘     └────────┬──────────┘     └────────┬─────────┘
         │                        │                         │
         └────────────────────────┼─────────────────────────┘
                                  ▼
                     ┌─────────────────────┐
                     │  GitHub Репозиторий  │
                     │ ninamc4e/            │
                     │ my_ai_opencode_server│
                     │  ├── HANDOVER.md     │
                     │  ├── CONTEXT.md      │
                     │  ├── USER.md         │
                     │  └── AGENTS.md       │
                     └─────────────────────┘
```

Три узла синхронизируются через единый GitHub-репозиторий.
Пользователь может работать на любом из них — AI везде один и тот же,
с одинаковым контекстом и историей.

### Роли узлов
| Узел | ОС | opencode | Синхронизация | Telegram |
|------|----|----------|---------------|----------|
| **notebook** | Windows | локальный TUI | `sync.ps1` | `notify.ps1` |
| **other-pc** | Windows | локальный TUI | `sync.ps1` | `notify.ps1` |
| **server** | Linux (Alpine) | `opencode serve` (через `opencode attach`) | `sync.sh` | `notify.sh` |

### Репозитории
- **ninamc4e/my_ai_opencode_server** — основной: HANDOVER.md, CONTEXT.md, USER.md, AGENTS.md, конфиги, скрипты
- **alexsmy/test_opencode** — архивный: в `migrate/` лежат zip-архивы `my_best_work` для восстановления на новом ПК

---

## 3. Файлы и их назначение

| Файл | Назначение | Конфликты |
|------|-----------|-----------|
| `HANDOVER.md` | Лог сессий (append-only) | Мержится: новые строки дописываются |
| `CONTEXT.md` | Контекст проекта, окружение, структура | Last-writer-wins |
| `USER.md` | Профиль пользователя (имя, модель, предпочтения) | Last-writer-wins |
| `AGENTS.md` | Правила для AI (этот файл) | Last-writer-wins (только фактические изменения) |
| `telegram-hub/sync.json` | Конфиг синхронизации (repo, branch, node_name) | Не синхронизируется, у каждого узла свой |
| `telegram-hub/telegram-notify.json` | Вкл/выкл и уровень уведомлений | Last-writer-wins |
| `telegram-hub/telegram-route.json` | Маршрутизация уведомлений (mode, endpoint, secret_env) | У каждого узла свой |

---

## 4. Жизненный цикл сессии

### 4.1 Определение платформы

AI должен определить, на какой платформе он работает:

```powershell
# Windows (PowerShell) — есть эта команда
powershell -Command "Write-Host 'windows'"
```
```sh
# Linux — доступен sh
sh -c 'echo "linux"'
```

**Правила определения:**
- Если доступен `powershell` → **notebook** или **other-pc** (Windows)
- Если доступен `sh`, НЕТ `powershell` → **server** (Render Linux/Alpine)
- Если нет ни того, ни другого → **unknown** (работай минимально)

### 4.2 Старт сессии

При приветствии ("Привет", "Hi", "start", "Здравствуй") или команде `/start`:

#### Шаг 1. Чтение контекста
```
Прочитай файлы в следующем порядке:
1. CONTEXT.md  — контекст проекта
2. HANDOVER.md — история сессий (последняя — самая актуальная)
3. USER.md     — профиль пользователя
```

#### Шаг 2. Синхронизация с GitHub
```
Запусти скрипт синхронизации для своей платформы:

Windows (PowerShell):
  powershell -File telegram-hub\sync.ps1 -Verbose

Linux (сервер Render, Alpine):
  sh telegram-hub/sync.sh -v
```

Скрипт:
1. Клонирует `ninamc4e/my_ai_opencode_server` во временную папку
2. Сливает HANDOVER.md (append-only: дописывает локальные записи к удалённым)
3. Копирует CONTEXT.md и USER.md (last-writer-wins: локальная версия если новее)
4. Пушит изменения обратно в GitHub
5. Удаляет временную папку

После синхронизации — **перечитай HANDOVER.md, CONTEXT.md, USER.md** (они могли обновиться).

#### Шаг 3. Проверка облачного архива
```
Сравни последний коммит в test_opencode с сохранённым в AGENTS.md:

git ls-remote https://github.com/alexsmy/test_opencode.git HEAD
```
- Если хеш совпадает с `last_github_commit` в разделе "Последний backup" → архив актуален
- Если хеш НЕ совпадает → на GitHub есть новый архив:
  - Спроси: "На GitHub есть более свежий архив. Скачать и продолжить с того места?"
  - Если да → **Windows:** `restore.ps1 -Latest`, **Linux:** `restore.sh -Latest` (если есть скрипт)
  - Запиши новый хеш в AGENTS.md

#### Шаг 4. Уведомление
```
Отправь уведомление о старте сессии:

Windows:
  powershell -File telegram-hub\session-start.ps1 -Model "<модель>" -Verbose

Linux (сервер):
  sh telegram-hub/notify.sh "Сессия запущена. Модель: <модель>"
```

Уведомление содержит: модель, дату/время, платформу.

#### Шаг 5. Ответ пользователю
```
Сообщи пользователю кратко:
- Сессия запущена
- Синхронизировано (с платформы)
- Уведомление отправлено

Пример: "Сессия запущена. Синхронизировался с GitHub (notebook). Уведомление отправлено."
НЕ пересказывай всю историю — просто продолжай диалог.
```

### 4.3 Работа в сессии

#### Auto-sync после каждой задачи
После завершения каждой задачи (создание/изменение файлов, коммит, ответ на вопрос и т.д.):
```
Windows:
  powershell -File telegram-hub\sync.ps1 -Quiet

Linux:
  sh telegram-hub/sync.sh 2>/dev/null
```
**Проверяй `telegram-hub/sync.json.push_after_task`** — если `false`, не делай auto-sync.

#### Уведомления после задач
Если `telegram-notify.json.enabled = true` и `level = all`:
```
Windows:
  powershell -File telegram-hub\notify.ps1 -Message "<b>...</b>"
Linux:
  sh telegram-hub/notify.sh "<b>...</b>"
```

#### Команда `/sync` (в любой момент)
При словах "синхронизируйся", "sync", "обнови контекст" или команде `/sync`:
1. Запусти `sync.ps1` или `sync.sh` (по платформе)
2. Перечитай HANDOVER.md, CONTEXT.md, USER.md
3. Сообщи: "Обновил контекст из GitHub, продолжаем"
4. Отправь уведомление в Telegram (если enabled=true)

### 4.4 Завершение сессии

При прощании ("Пока", "до встречи", "bye", "goodbye", "всё") или команде `/end`:

#### Шаг 1. Резюме
```
Сформируй краткое резюме: что сделано, какие файлы изменены, текущие статусы задач.
```

#### Шаг 2. Обновление HANDOVER.md
```
Добавь в HANDOVER.md новую секцию:

## Что было сделано в этой сессии (ДД.ММ.ГГГГ)

### Краткое описание
- Пункт 1
- Пункт 2
...

### Изменённые файлы
- Путь/к/файлу.py
- Путь/к/файлу.md
...

### Текущее состояние
Статус проекта на момент завершения.
```

**Важно:** HANDOVER.md — append-only. НИЧЕГО не удаляй из предыдущих секций.

#### Шаг 3. Обновление AGENTS.md
Если появились новые правила, изменилась архитектура или backup ID — обнови.

#### Шаг 4. Уведомление о завершении
```
Windows:
  powershell -File telegram-hub\session-end.ps1 -Summary "<краткий итог>" -Verbose

Linux:
  sh telegram-hub/notify.sh "Сессия завершена: <краткий итог>"
```

#### Шаг 5. Синхронизация
```
Windows:
  powershell -File telegram-hub\sync.ps1 -Verbose

Linux:
  sh telegram-hub/sync.sh -v
```

#### Шаг 6. Сообщение пользователю
```
Сообщи: "HANDOVER.md обновлён, сессия завершена. Увидимся!"
```

### 4.5 Миграция на другой ПК

При запросе ("Новый компьютер", "переходим на другой opencode", "перенос", "миграция") или команде `/migrate`:

#### Шаг 1. Обновить HANDOVER.md
Добавь полное резюме всей работы: все проекты, статусы, что нужно знать новому AI.

#### Шаг 2. Обновить AGENTS.md
Запиши последний `file_id` backup (или обнови другие актуальные данные).

#### Шаг 3. Запустить cloud-migrate
```powershell
powershell -File telegram-hub\cloud-migrate.ps1 -Verbose
```
Этот скрипт:
1. Создаёт архив `my_best_work` через `backup.ps1 -Upload -Keep`
2. Загружает архив на Render FileVault (в папку "migrate")
3. Клонирует `alexsmy/test_opencode`
4. Копирует архив в `migrate/` и пушит на GitHub
5. Удаляет временные файлы
6. Отправляет уведомление в Telegram

#### Шаг 4. Вывод результата
```
Сообщи пользователю:
- file_id (из FileVault)
- public_url (прямая ссылка на архив)
- Статус GitHub пуша (OK/FAILED)
- Инструкцию: на новом ПК запустить restore.ps1 -Latest
```

### 4.6 Восстановление на новом ПК

На новом чистом ПК:

#### Если ничего не установлено (bootstrap):
```powershell
# 1. Установить Git, Python, Node.js, opencode
# 2. Открыть PowerShell в любой папке
powershell -File bootstrap.ps1 -FromScratch
```
Скрипт сам склонирует `test_opencode`, скачает последний архив из `migrate/`, распакует,
запросит мастер-пароль для расшифровки SSH-ключа и секретов, установит всё.

#### Если архив уже есть (restore):
```powershell
# Рекомендуемый способ: скачать с GitHub
powershell -File SCRIPTs\restore.ps1 -Latest

# Альтернатива: с Render FileVault по file_id
powershell -File SCRIPTs\restore.ps1 -FileId <file_id>
```

`restore.ps1 -Latest`:
1. Клонирует `alexsmy/test_opencode` (сначала SSH, при ошибке HTTPS)
2. Находит самый свежий zip в `migrate/`
3. Распаковывает в текущую папку
4. Выводит инструкцию по дальнейшей настройке

#### После восстановления:
```powershell
# Расшифровать SSH-ключ и секреты
powershell -File SCRIPTs\unseal.ps1

# Или одной командой:
powershell -File SCRIPTs\bootstrap.ps1
```

#### Восстановление облачного контекста:
При команде `/cloud-restore`:
1. Если HANDOVER.md и CONTEXT.md пусты или отсутствуют:
   - `restore.ps1 -Latest` (с GitHub)
   - или `restore.ps1 -FileId <file_id>` (с FileVault)
2. После распаковки — прочитай восстановленные CONTEXT.md, HANDOVER.md
3. Сообщи пользователю, что контекст восстановлен

---

## 5. Команды

| Команда | Алиасы | Действие |
|---------|--------|----------|
| `/start` | "Привет", "Hi", "start", "Здравствуй" | Старт сессии: чтение контекста → sync → проверка архива → уведомление |
| `/sync` | "синхронизируйся", "sync", "обнови контекст" | Pull HANDOVER.md/CONTEXT.md/USER.md → merge → push |
| `/tg on/off/status` | "включи уведомления", "выключи" | Управление `telegram-notify.json` |
| `/backup` | "сделай бэкап" | Создать локальный zip-архив |
| `/backup upload` | "залей в облако" | Создать архив + загрузить на Render FileVault |
| `/migrate` | "миграция", "новый компьютер", "перенос" | Полная миграция: архив → FileVault → GitHub |
| `/end` | "Пока", "bye", "goodbye", "до встречи" | Завершение: HANDOVER.md → уведомление → sync |
| `/cloud-restore` | "восстанови контекст" | Скачать архив (GitHub или FileVault), распаковать |

---

## 6. Sync System — протокол синхронизации

### Конфиг `telegram-hub/sync.json`
```json
{
  "repo": "ninamc4e/my_ai_opencode_server",
  "branch": "main",
  "files": ["HANDOVER.md", "CONTEXT.md", "USER.md"],
  "node_name": "notebook",
  "push_after_task": true,
  "auto_sync_on_start": true,
  "auto_sync_on_end": true
}
```

`node_name` у каждого узла свой: `notebook`, `other-pc`, `server`.

### Скрипты
| Файл | Платформа | Язык |
|------|-----------|------|
| `telegram-hub/sync.ps1` | Windows | PowerShell 5.1 |
| `telegram-hub/sync.sh` | Linux (Render, Alpine) | sh (без bash) |

### Алгоритм синхронизации HANDOVER.md
```
1. git clone --depth 1 репозитория во временную папку
2. Прочитать HANDOVER.md из клонированной папки (remote) и из локальной (local)
3. Сравнить:
   a) Если remote = local → ничего не делать (уже синхронизировано)
   b) Если remote начинается так же, как local → local новее:
      - Скопировать local → remote (перезаписать)
   c) Если local начинается так же, как remote → remote новее:
      - Найти строки в local, которых нет в remote
      - Дописать их в конец remote
   d) Иначе (полностью разные) → взять local (текущий узел важнее)
4. Скопировать CONTEXT.md и USER.md local → remote (если локальная версия новее)
5. Если были изменения: git add → git commit → git push
6. Удалить временную папку
```

### Auto-sync (автоматическая синхронизация)
- **При старте сессии** ("Привет", "/start"): sync после чтения HANDOVER.md/CONTEXT.md
- **После каждой задачи**: sync с флагом `-Quiet` (без лишнего вывода)
- **При завершении сессии** ("Пока", "/end"): sync после обновления HANDOVER.md
- **Отключение**: `push_after_task: false` в `sync.json`

---

## 7. Telegram-уведомления

### Конфиги
| Файл | Назначение |
|------|-----------|
| `telegram-route.json` | Маршрутизация: mode (server/local), endpoint, secret_env |
| `telegram-notify.json` | Вкл/выкл: `enabled` (true/false), `level` (all/errors) |
| `telegram-config.json` | Токен бота + chat_id (только для local-режима, НЕ в git) |

### Скрипты отправки

**Windows (PowerShell):**
```powershell
powershell -File telegram-hub/notify.ps1 -Message "<b>текст</b>"
powershell -File telegram-hub/notify.ps1 -Message "<b>текст</b>" -Verbose
```

**Linux (сервер Render):**
```sh
sh telegram-hub/notify.sh "<b>текст</b>"
```

`-Verbose` доступен только в PS-версии (для отладки).

### Форматирование сообщений
- Используй HTML-разметку: `<b>жирный</b>`, `<i>курсив</i>`, `<code>код</code>`
- Для переноса строки в PowerShell: `` `n `` (backtick-n) внутри двойных кавычек
- НЕ используй `%0A` — PowerShell закодирует `%` в `%25`
- Пример: `-Message "строка 1`nстрока 2"`

### Кодировка (важно для русских символов)
- `notify.ps1` сам конвертирует тело в UTF-8 bytes — проблем нет
- При прямом `Invoke-RestMethod` с `-Body $string` PowerShell шлёт в Windows-1252
- **Всегда** конвертируй в UTF-8 bytes:
```powershell
$jsonBody = '{"text":"сообщение на русском °C — €"}'
$utf8Body = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
Invoke-WebRequest -Uri "..." -Method Post -Body $utf8Body -ContentType "application/json; charset=utf-8" -Headers @{ "x-telegram-tunnel-secret" = $secret }
```
- Без этого `°`, `—`, `€`, русские буквы выдадут 422 ошибку

### Управление уведомлениями (команда `/tg`)
- `/tg on` — включить (для всех событий)
- `/tg off` — выключить
- `/tg status` — показать текущий статус
- `/tg on all` — все события (по умолчанию)
- `/tg on errors` — только ошибки

AI должен:
1. Прочитать `telegram-notify.json`
2. Изменить `enabled` и/или `level`
3. Сохранить
4. Сообщить результат

### Скрипты старта/завершения сессии

**Windows:**
- `session-start.ps1` — уведомление о старте (модель, дата, тема последней сессии)
- `session-end.ps1` — уведомление о завершении (краткое резюме)

**Linux (сервер):** нет PS-скриптов. Используй напрямую:
```sh
sh telegram-hub/notify.sh "Сессия запущена. Модель: ..."
sh telegram-hub/notify.sh "Сессия завершена: ..."
```

---

## 8. Backup / Restore

### Команды
- `/backup` — создать локальный zip-архив `my_best_work`
- `/backup upload` — создать архив + загрузить на Render FileVault (+ уведомление)

### Скрипты
| Скрипт | Назначение |
|--------|-----------|
| `SCRIPTs\backup.ps1` | Создать zip-архив, опционально загрузить на Render FileVault |
| `SCRIPTs\restore.ps1` | Скачать архив и восстановить (с GitHub или FileVault) |
| `SCRIPTs\seal.ps1` | Зашифровать SSH-ключ + env-секреты (мастер-пароль) |
| `SCRIPTs\unseal.ps1` | Расшифровать и установить SSH-ключ + env-секреты |
| `SCRIPTs\bootstrap.ps1` | Полная настройка нового ПК одной командой |

### backup.ps1
```
Параметры:
  -Upload     — загрузить архив на Render FileVault
  -Keep       — не удалять архив после Upload (нужен для GitHub пуша)
  -PassThru   — вернуть объект {file_id, url, path, name} вместо текста
  -Verbose    — подробный вывод

Примеры:
  backup.ps1                              # только локальный архив
  backup.ps1 -Upload -Verbose             # архив + загрузка на FileVault
  backup.ps1 -Upload -Keep -PassThru      # архив + FileVault + метаданные
```

### restore.ps1
```
Параметры:
  -Latest     — последний архив из GitHub (alexsmy/test_opencode/migrate/)
  -FileId     — архив из Render FileVault по file_id
  -Verbose    — подробный вывод

Примеры:
  restore.ps1 -Latest              # с GitHub (рекомендуется)
  restore.ps1 -FileId <id>         # с FileVault
```

При `-Latest`: сначала SSH, при ошибке — HTTPS (для новых ПК без SSH-ключа).

### seal.ps1 / unseal.ps1
- `seal.ps1` (на старом ПК): шифрует `~/.ssh/id_ed25519` → `secrets/ssh.enc`,
  читает `AGENTS_TUNNEL_SECRET` и `TELEGRAM_TUNNEL_SECRET` из системы → `secrets/env.enc`
  AES-256 + PBKDF2, мастер-пароль
- `unseal.ps1` (на новом ПК): расшифровывает, сохраняет SSH-ключ в `~/.ssh/`,
  добавляет в ssh-agent, через setx ставит env-переменные

### bootstrap.ps1
```
Параметры:
  -FromScratch — клонировать test_opencode, восстановить архив, настроить всё
  -MasterPassword <password> — мастер-пароль для unseal (для автоматизации)

Без параметров: только проверка Git/Python/Node.js/opencode + unseal
```

### Что переносится при миграции
- **В zip-архиве:** все конфиги, скрипты, навыки, инструкции, HANDOVER.md, CONTEXT.md, USER.md, AGENTS.md
- **На GitHub (mcp_agent_import):** серверные агенты (weather, MCP tools) — с ними ничего делать не надо
- **В `secrets/`:** SSH-ключ и env-переменные в зашифрованном виде

### Процесс backup (выполняет AI)
1. `backup.ps1 -Upload -Verbose`
2. Прочитать `file_id` из вывода
3. Сообщить пользователю `file_id` и public_url
4. Записать `file_id` в этот файл (AGENTS.md, раздел "Последний backup")
5. Отправить уведомление в Telegram

---

## 9. MCP (Model Context Protocol) — погодные агенты

### Конфигурация (локально)
В `.opencode/opencode.jsonc`:
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

### Инструменты
| Инструмент | Описание |
|---|---|
| `get_weather` | Погода в Уфе (температура, влажность, ветер) |
| `send_weather_to_telegram(action="update")` | Отправить/обновить погоду в Telegram. `action=reset` — сброс |

### Использование
- Напрямую: "получи погоду в Уфе"
- Через @-mention: `@weather_agents get_weather`

### Особенности
- Секрет `AGENTS_TUNNEL_SECRET` — переменная окружения пользователя
- MCP session ID передаётся в заголовке `mcp-session-id`
- `message_id` хранится на сервере — при деплое Render'а сбрасывается
- Старый протокол (`/api/agents/inbox`) тоже работает, но используй MCP

---

## 10. Dynamic Agents (ALM)

### Динамические агенты
- Загружаются через `POST /api/agents/upload` (код → сервер)
- Сохраняются в `data/agents/dynamic/{name}.py` на сервере
- Копия в FileVault (папка "Agents")
- При рестарте теряются (ephemeral storage) — восстанавливаются через `agent-deploy.json`

### Эндпоинты (сервер Render, ветка mcp_agent_import)
| Метод | Путь | Назначение |
|---|---|---|
| POST | `/api/agents/upload` | Загрузить динамического агента |
| GET | `/api/agents/list` | Список агентов |
| DELETE | `/api/agents/dynamic/{name}` | Удалить |
| POST | `/api/agents/mcp-tools/register` | Загрузить MCP-инструмент |
| GET | `/api/agents/mcp-tools/list` | Список MCP-инструментов |
| DELETE | `/api/agents/mcp-tools/{name}` | Удалить MCP-инструмент |
| GET | `/api/agents/responses` | История ответов агентов |
| GET | `/api/agents/responses/{file_id}` | Конкретный ответ |
| POST | `/api/agents/inbox` | Вызов агента (старый протокол) |
| GET | `/api/agents/health` | Статус |

Все (кроме health) требуют заголовок `X-Agents-Tunnel-Secret`.

### Формат MCP-инструмента
```python
async def tool_name(param1: str, param2: int = 0) -> str:
    """Описание — станет MCP tool description"""
    return f"Результат: {param1}, {param2}"
```
Параметры → inputSchema MCP.
Встроенные тулы (get_weather, send_weather_to_telegram) — нельзя перезаписать.

---

## 11. Приложение: актуальные ссылки и ID

### Последний backup
- **file_id:** 1aa908bf550a45109a7e9861f900d032
- **дата:** 2026-05-18
- **url:** https://bot-29-nx0w.onrender.com/files/open/1aa908bf550a45109a7e9861f900d032
- **GitHub:** https://github.com/alexsmy/test_opencode/tree/main/migrate
- **last_github_commit:** 2d61e29

### Render сервер
- **URL:** https://bot-29-nx0w.onrender.com
- **FileVault:** https://bot-29-nx0w.onrender.com/files
- **MyTelegram:** https://bot-29-nx0w.onrender.com/mytelegram
- **MCP:** https://bot-29-nx0w.onrender.com/mcp
- **Ветка:** mcp_agent_import (деплой Render), alpine-experiment (деплой Render server брат)

### GitHub
- **Основной:** https://github.com/ninamc4e/my_ai_opencode_server
- **Архивный:** https://github.com/alexsmy/test_opencode
- **Агенты:** https://github.com/alexsmy/bot_29/tree/mcp_agent_import

### Telegram
- **Бот:** @imgtestlivebot
- **Chat ID:** 1252058698
- **Режим:** server (основной), local (fallback)
