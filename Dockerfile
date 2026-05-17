FROM node:20-bookworm-slim

# Устанавливаем opencode и git
RUN npm install -g opencode-ai && \
    apt-get update -qq && apt-get install -y -qq git && \
    rm -rf /var/lib/apt/lists/*

# Конфигурация
COPY opencode.json /etc/opencode/config.json

ENTRYPOINT []

# Старт: клонируем/обновляем проект → запускаем opencode serve
CMD ["/bin/sh", "-c", "\
git config --global user.name 'opencode-server' && \
git config --global user.email 'server@opencode' && \
if [ -n \"$GITHUB_TOKEN\" ]; then \
  git clone --depth 1 https://ninamc4e:${GITHUB_TOKEN}@github.com/ninamc4e/my_ai_opencode_server.git /workspace 2>/dev/null || \
  (cd /workspace && git pull origin main 2>/dev/null); \
else \
  git clone --depth 1 https://github.com/ninamc4e/my_ai_opencode_server.git /workspace 2>/dev/null || \
  (cd /workspace && git pull origin main 2>/dev/null); \
fi && \
cd /workspace && \
export OPENCODE_CONFIG=/etc/opencode/config.json && \
opencode web --hostname 0.0.0.0 --port ${PORT:-10000}"]
