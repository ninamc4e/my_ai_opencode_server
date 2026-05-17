FROM node:20-bookworm-slim

# Устанавливаем opencode, git и curl
RUN npm install -g opencode-ai && \
    apt-get update -qq && apt-get install -y -qq git curl && \
    rm -rf /var/lib/apt/lists/*

# Конфигурация
COPY opencode.json /etc/opencode/config.json

ENTRYPOINT []

# Старт: клонируем/обновляем проект → запускаем opencode serve с логами
CMD ["/bin/sh", "-c", "\
echo '=== Opencode Server Startup ===' && \
echo 'Git config...' && \
git config --global user.name 'opencode-server' && \
git config --global user.email 'server@opencode' && \
echo 'Cloning/pulling repository...' && \
if [ -n \"$GITHUB_TOKEN\" ]; then \
  git clone https://ninamc4e:${GITHUB_TOKEN}@github.com/ninamc4e/my_ai_opencode_server.git /workspace 2>&1 || \
  (cd /workspace && git pull origin main 2>&1); \
else \
  git clone https://github.com/ninamc4e/my_ai_opencode_server.git /workspace 2>&1 || \
  (cd /workspace && git pull origin main 2>&1); \
fi && \
echo 'Repository ready.' && \
cd /workspace && \
export OPENCODE_CONFIG=/etc/opencode/config.json && \
echo 'Starting opencode serve...' && \
exec opencode serve --hostname 0.0.0.0 --port ${PORT:-10000} --log-level DEBUG --print-logs"]
