# Правила для AI-агента (серверная версия, Render)

## Режим работы
- Я работаю **на сервере Render** (Linux, Docker)
- Пользователь подключается через `opencode attach`
- Bash-команды и Node.js — выполняются на сервере (в контейнере)
- Репозиторий — в `/workspace/`

## Старт сессии
При "Привет", "Hi", "/start":
1. Прочитай CONTEXT.md и HANDOVER.md
2. Определи модель ИИ
3. `cd /workspace && git pull origin main` — подтяни HANDOVER.md
4. Отправь уведомление в Telegram через `/workspace/telegram-hub/notify.sh`
5. Сообщи пользователю: сессия запущена

## Завершение сессии
При "Пока", "до встречи", "bye", "/end":
1. Обнови HANDOVER.md: добавь секцию "Что было сделано в этой сессии"
2. Отправь уведомление в Telegram о завершении
3. Выполни:
   ```
   cd /workspace
   git add HANDOVER.md AGENTS.md
   git commit -m "сессия: краткое описание"
   git push origin main
   ```
4. Сообщи пользователю — HANDOVER.md запушен, сессия завершена

## Telegram-уведомления
- Используй `/workspace/telegram-hub/notify.sh`:
  ```
  bash /workspace/telegram-hub/notify.sh "сообщение"
  ```
- Перед отправкой проверь `telegram-notify.json.enabled`
- Отправляй при старте, завершении и после задач (если enabled && level=all)

## Git на сервере
- В контейнере настроен `GITHUB_TOKEN` для пуша
- При старте opencode делает `git clone/pull`
- Для коммита с сервера:
  ```
  cd /workspace && git add <файлы> && git commit -m "..." && git push origin main
  ```

## Модель
- По умолчанию: `opencode/deepseek-v4-flash-free` (Zen, бесплатно)
- Переключение: `/models` в TUI или естественным языком

## Особенности Render free tier
- Сервер "засыпает" через 15 мин бездействия
- При первом запросе просыпается за 30-50 секунд
- Эфемерное хранилище — все данные только в GitHub
