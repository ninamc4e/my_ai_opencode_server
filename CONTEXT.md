# Контекст работы с серверной версией Opencode

Этот файл автозагружается при старте каждой сессии. AI читает его автоматически.

## Пользователь
- Имя: alexs
- GitHub: ninamc4e (https://github.com/ninamc4e)
- Email: уточнить
- Уровень: начинающий программист

## Репозиторий сервера
- `ninamc4e/my_ai_opencode_server` — серверная версия opencode на Render
- Роуминг: HANDOVER.md обновляется и пушится в GitHub при завершении сессии

## Настройка окружения (Render)
- **Платформа:** Render (Debian Linux), Docker образ `ghcr.io/anomalyco/opencode`
- **Модель по умолчанию:** `opencode/deepseek-v4-flash-free` (Zen, бесплатно)
- **Провайдер:** OpenCode Zen (через OPENCODE_API_KEY)
- **Серверная аутентификация:** OPENCODE_SERVER_PASSWORD

## Структура проекта
```
my_ai_opencode_server/
├── CONTEXT.md              # (этот файл)
├── AGENTS.md               # Правила для AI
├── HANDOVER.md             # Журнал сессий для роуминга
├── opencode.json           # Конфигурация opencode
├── Dockerfile              # Образ для Render
├── start.sh                # Точка входа
├── telegram-hub/           # Telegram уведомления (копия)
├── SCRIPTs/                # Скрипты (backup, restore и др.)
├── agents-hub/             # Управление агентами
├── .opencode/              # Конфигурация
└── secrets/                # Зашифрованные ключи
```

## Роуминг-контекст (единый проект на GitHub)

Серверная и локальная версии работают с ОДНИМ проектом через GitHub:

```
Локально (my_best_work) ── git push/pull ──► GitHub (test_opencode)
Сервер (Render)         ── git push/pull ──► GitHub (my_ai_opencode_server)
```

HANDOVER.md — единая точка входа: кто где работал, что сделано, с чего продолжить.

## Telegram
- Бот: @imgtestlivebot
- Chat ID: 1252058698
- Уведомления через `telegram-hub/notify.ps1`

## Как продолжить в новой сессии
Контекст загружается автоматически. Для роуминга используй HANDOVER.md.
