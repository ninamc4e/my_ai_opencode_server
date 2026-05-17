FROM alpine:3.19

# Устанавливаем curl, git, libstdc++ (нужна для opencode musl-бинарника)
RUN apk add --no-cache curl git ca-certificates libstdc++ libgcc

# Скачиваем opencode (musl-сборка для Alpine, ~50MB вместо 160MB через npm)
ARG OPENCODE_VERSION=v1.15.4
RUN curl -sL "https://github.com/anomalyco/opencode/releases/download/${OPENCODE_VERSION}/opencode-linux-x64-musl.tar.gz" \
    | tar xz -C /usr/local/bin/ opencode

# Конфигурация
COPY opencode.json /etc/opencode/config.json

EXPOSE 10000

# Старт: клонируем проект → запускаем opencode serve
CMD ["/bin/sh", "-c", "\
echo '=== Opencode Server Startup ===' && \
git config --global user.name 'opencode-server' && \
git config --global user.email 'server@opencode' && \
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
exec opencode serve --hostname 0.0.0.0 --port ${PORT:-10000}"]
