FROM ghcr.io/anomalyco/opencode:latest

COPY opencode.json /etc/opencode/config.json

ENTRYPOINT []

CMD ["sh", "-c", "\
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
opencode serve --hostname 0.0.0.0 --port $PORT"]
