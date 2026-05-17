#!/bin/bash
set -e

# Pull последней версии из GitHub (HANDOVER.md, CONTEXT.md и т.д.)
cd /workspace

# Настроим git для пуша
git config --global user.name "opencode-server"
git config --global user.email "server@opencode"

# Клонируем или пуллим
if [ -d .git ]; then
  git pull origin main 2>/dev/null || echo "git pull failed, continuing"
fi

# Устанавливаем конфиг
export OPENCODE_CONFIG=/etc/opencode/config.json

# Запускаем сервер
exec opencode serve --hostname 0.0.0.0 --port $PORT
