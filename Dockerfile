FROM ghcr.io/anomalyco/opencode:latest

# Конфигурация opencode
COPY opencode.json /etc/opencode/config.json

# Скрипт запуска
COPY start.sh /start.sh
RUN chmod +x /start.sh

ENTRYPOINT []
CMD ["/start.sh"]
