#!/bin/bash
# Отправка уведомления в Telegram (Linux-версия для сервера)
# Использование: ./notify.sh "Текст сообщения"

MESSAGE="$1"
if [ -z "$MESSAGE" ]; then
  echo "Usage: $0 \"message\""
  exit 1
fi

# Читаем конфиг
ROUTE_FILE="telegram-hub/telegram-route.json"
NOTIFY_FILE="telegram-hub/telegram-notify.json"

# Проверяем включены ли уведомления
if [ -f "$NOTIFY_FILE" ]; then
  ENABLED=$(grep -o '"enabled": *[a-z]*' "$NOTIFY_FILE" | grep -o '[a-z]*$')
  if [ "$ENABLED" != "true" ]; then
    echo "SKIPPED"
    exit 0
  fi
fi

# Читаем endpoint
if [ ! -f "$ROUTE_FILE" ]; then
  echo "ERROR: telegram-route.json not found"
  exit 1
fi

ENDPOINT=$(grep -o '"endpoint": *"[^"]*"' "$ROUTE_FILE" | cut -d'"' -f4)
SECRET_ENV=$(grep -o '"secret_env": *"[^"]*"' "$ROUTE_FILE" | cut -d'"' -f4)

if [ -z "$ENDPOINT" ]; then
  echo "ERROR: endpoint not found"
  exit 1
fi

# Берём секрет из переменной окружения
SECRET="${!SECRET_ENV}"
if [ -z "$SECRET" ]; then
  echo "ERROR: secret $SECRET_ENV not set"
  exit 1
fi

# Формируем тело запроса (UTF-8)
JSON_BODY=$(echo "{\"text\":\"$MESSAGE\"}" | iconv -t utf-8 2>/dev/null || echo "{\"text\":\"$MESSAGE\"}")

# Отправляем
curl -s -X POST "$ENDPOINT" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "X-Telegram-Tunnel-Secret: $SECRET" \
  -d "$JSON_BODY"

echo ""
echo "OK"
