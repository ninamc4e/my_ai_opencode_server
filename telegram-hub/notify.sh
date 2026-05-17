#!/bin/sh
# Отправка уведомления в Telegram (Linux-версия для opencode сервера)
# Использование: ./notify.sh "Текст сообщения"

MESSAGE="$1"
if [ -z "$MESSAGE" ]; then
  echo "Usage: $0 \"message\""
  exit 1
fi

# Читаем конфиг
ROUTE_FILE="/workspace/telegram-hub/telegram-route.json"
NOTIFY_FILE="/workspace/telegram-hub/telegram-notify.json"

# Проверяем включены ли уведомления
if [ -f "$NOTIFY_FILE" ]; then
  ENABLED=$(grep -o '"enabled": *[a-z]*' "$NOTIFY_FILE" | grep -o '[a-z]*$')
  if [ "$ENABLED" != "true" ]; then
    echo "SKIPPED"
    exit 0
  fi
fi

# Читаем endpoint
ENDPOINT=$(grep -o '"endpoint": *"[^"]*"' "$ROUTE_FILE" | cut -d'"' -f4)
SECRET_ENV=$(grep -o '"secret_env": *"[^"]*"' "$ROUTE_FILE" | cut -d'"' -f4)

# Берём секрет из переменной окружения
eval "SECRET=\${$SECRET_ENV}"
if [ -z "$SECRET" ]; then
  echo "ERROR: secret $SECRET_ENV not set"
  exit 1
fi

# Формируем тело запроса и отправляем
JSON_BODY=$(printf '{"text":"%s"}' "$MESSAGE")

curl -s -X POST "$ENDPOINT" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "X-Telegram-Tunnel-Secret: $SECRET" \
  -d "$JSON_BODY"

echo ""
echo "OK"
