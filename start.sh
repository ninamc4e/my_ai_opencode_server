#!/bin/bash
set -e

# Настроим git
git config --global user.name "opencode-server"
git config --global user.email "server@opencode"

# Клонируем проект (если ещё не склонирован)
if [ ! -d /workspace/.git ]; then
  git clone https://github.com/ninamc4e/my_ai_opencode_server.git /workspace
fi

cd /workspace

# Если есть GITHUB_TOKEN — настраиваем аутентификацию для push
if [ -n "$GITHUB_TOKEN" ]; then
  git remote set-url origin https://ninamc4e:$GITHUB_TOKEN@github.com/ninamc4e/my_ai_opencode_server.git 2>/dev/null
fi

# Подтягиваем последние изменения (HANDOVER.md и т.д.)
git pull origin main 2>/dev/null || echo "git pull skipped"

# Устанавливаем конфиг
export OPENCODE_CONFIG=/etc/opencode/config.json

# Запускаем сервер
exec opencode serve --hostname 0.0.0.0 --port $PORT
