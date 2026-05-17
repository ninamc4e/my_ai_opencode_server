# Правила для AI-агента (серверная версия, Render)

## Режим работы
- Я работаю **на сервере Render** (Linux, Docker)
- Пользователь подключается через `opencode attach`
- Операции с файлами — в `/workspace/`
- PowerShell скрипты НЕ работают (Linux). Использую bash-аналоги

## Роуминг-контекст (единый проект на GitHub)

### Принцип
Сервер и локальный ПК работают с ОДНИМ репозиторием `ninamc4e/my_ai_opencode_server`. 
HANDOVER.md — журнал, который пушится на GitHub при завершении сессии и пуллится при старте.

### Старт сессии
При подключении пользователя ("Привет", "Hi", "/start"):
1. Прочитай CONTEXT.md и HANDOVER.md
2. Определи модель ИИ (из системного контекста)
3. Выполни `git pull origin main` — подтяни HANDOVER.md и другие файлы
4. Сообщи пользователю, что сессия запущена

### Завершение сессии
При прощании ("Пока", "до встречи", "bye", "/end"):
1. Сформируй краткое резюме сессии
2. Обнови HANDOVER.md — добавь секцию "Что было сделано в этой сессии"
3. Обнови AGENTS.md если нужно
4. Закоммитить и запушить в GitHub:
   ```
   git add HANDOVER.md AGENTS.md
   git commit -m "сессия: краткое описание"
   git push origin main
   ```
5. Сообщи пользователю, что HANDOVER.md обновлён и запущен

### Важно
- **НИКОГДА не пушить** без явного подтверждения пользователя, кроме HANDOVER.md и AGENTS.md при завершении сессии
- При пуше HANDOVER.md — только этот файл и AGENTS.md, НЕ конфиги с секретами
- При конфликте git pull — предупреди пользователя

## Telegram-hub (адаптировано для Linux)

### Уведомления
- Скрипты в `telegram-hub/` — PowerShell, на сервере не работают
- Для отправки уведомлений с сервера использую curl напрямую
- `notify.ps1` заменяется `notify.sh` (или прямым curl)

### curl-версия notify для Linux:
```bash
curl -s -X POST "https://bot-29-nx0w.onrender.com/mytelegram" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "X-Telegram-Tunnel-Secret: $TELEGRAM_TUNNEL_SECRET" \
  -d "$(echo '{"text":"сообщение"}' | iconv -t utf-8)"
```

### Telegram-конфиги
- `telegram-route.json` — режим, endpoint, secret_env
- `telegram-notify.json` — вкл/выкл, уровень

## Модель
- По умолчанию: `opencode/deepseek-v4-flash-free` (через Zen)
- Можно переключать через `/models` в TUI или естественным языком
- Все модели через Zen API (не нужны отдельные API ключи)

## Backup / Restore
- Скрипты в `SCRIPTs/` — PowerShell, на сервере не запускаются
- Для бекапа на сервере использую git push (все файлы уже в GitHub)
- Команда `/backup` на сервере = git add + git commit + git push
