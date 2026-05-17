#!/bin/bash
# Скрипт для настройки доступа к GitHub для Opencode

echo "Настройка доступа к GitHub для Opencode"
echo "======================================"

# Проверяем, установлен ли git
if ! command -v git &> /dev/null; then
    echo "Ошибка: git не установлен. Пожалуйста, установите git сначала."
    exit 1
fi

# Проверяем, установлен ли GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "Предупреждение: GitHub CLI (gh) не установлен."
    echo "Для полной функциональности рекомендуется установить его:"
    echo "  https://cli.github.com/"
    read -p "Продолжить без GitHub CLI? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Настройка git пользователя (если еще не настроена)
echo "Настройка git пользователя..."
git config --global user.name "$(git config user.name || echo "Ваше Имя")"
git config --global user.email "$(git config user.email || echo "ваш.email@example.com")"

# Инструкции по настройке доступа
echo ""
echo "Для работы с приватными репозиториями вам нужно настроить один из методов доступа:"
echo ""
echo "1. SSH ключ (рекомендуется):"
echo "   - Проверьте существующие ключи: ls -la ~/.ssh/"
echo "   - Если ключей нет, создайте новый: ssh-keygen -t ed25519 -C \"ваш.email@example.com\""
echo "   - Добавьте публичный ключ в ваш GitHub аккаунт:"
echo "     https://github.com/settings/keys"
echo ""
echo "2. Personal Access Token (PAT):"
echo "   - Создайте токен здесь: https://github.com/settings/tokens"
echo "   - Выберите scopes: repo (полный доступ к приватным репозиториям)"
echo "   - Сохраните токен в безопасном месте"
echo ""
echo "После настройки доступа Opencode сможет:"
echo "  - Клонировать ваши репозитории"
echo "  - Создавать ветки и коммиты"
echo "  - Отправлять изменения в удаленные репозитории"
echo "  - Создавать Pull Requests автоматически"

# Проверяем текущую директорию
echo ""
echo "Текущая рабочая директория: $(pwd)"
echo "Вы можете начать работу с Opencode в этой директории или перейти в ваш проект."

echo ""
echo "Настройка завершена!"