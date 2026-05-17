#!/bin/sh
# Тест уведомления в Telegram с сервера

ENDPOINT="https://bot-29-nx0w.onrender.com/mytelegram"

if [ -z "$TELEGRAM_TUNNEL_SECRET" ]; then
  echo "ERROR: TELEGRAM_TUNNEL_SECRET не задан"
  exit 1
fi

curl -s -X POST "$ENDPOINT" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "X-Telegram-Tunnel-Secret: $TELEGRAM_TUNNEL_SECRET" \
  -d '{"text":"<b>Сервер opencode запущен</b>\nRender: my-ai-opencode-server\nМодель: deepseek-v4-flash-free"}'

echo ""
echo "ГОТОВО"
