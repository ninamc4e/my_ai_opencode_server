FROM ghcr.io/anomalyco/opencode:latest-debian

# Конфигурация opencode
COPY opencode.json /etc/opencode/config.json

# Скрипт запуска
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Скрипты и конфиги проекта
COPY telegram-hub/ /workspace/telegram-hub/
COPY SCRIPTs/ /workspace/SCRIPTs/
COPY agents-hub/ /workspace/agents-hub/
COPY .opencode/ /workspace/.opencode/
COPY CONTEXT.md /workspace/CONTEXT.md
COPY AGENTS.md /workspace/AGENTS.md
COPY HANDOVER.md /workspace/HANDOVER.md

WORKDIR /workspace

CMD ["/start.sh"]
