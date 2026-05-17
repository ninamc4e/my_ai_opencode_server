#!/bin/bash
# Скрипт для помощи в создании и управлении персональными навыками Opencode

echo "Управление навыками Opencode"
echo "============================"

SKILLS_DIR=".opencode/skills"

# Проверяем, существует ли директория для навыков
if [ ! -d "$SKILLS_DIR" ]; then
    echo "Создаю директорию для навыков: $SKILLS_DIR"
    mkdir -p "$SKILLS_DIR"
fi

echo ""
echo "Доступные навыки:"
ls -la "$SKILLS_DIR"/*.json 2>/dev/null | wc -l

if [ "$(ls -la "$SKILLS_DIR"/*.json 2>/dev/null | wc -l)" -gt 0 ]; then
    echo "Список навыков:"
    ls -la "$SKILLS_DIR"/*.json
else
    echo "Навыки не найдены. Создайте первый навык с помощью этого скрипта."
fi

echo ""
echo "Выберите действие:"
echo "1. Создать новый навык"
echo "2. Просмотреть существующий навык"
echo "3. Удалить навык"
echo "4. Выход"

read -p "Введите номер действия: " choice

case $choice in
    1)
        echo ""
        echo "Создание нового навыка"
        echo "---------------------"
        read -p "Введите название навыка (например, code-reviewer): " skill_name
        read -p "Введите описание навыка: " skill_desc
        read -p "Введите триггеры через запятую (например, review code,check quality): " skill_triggers
        read -p "Введите инструкции для навыка: " skill_instructions
        
        # Преобразуем триггеры в массив JSON
        IFS=',' read -ra TRIGGERS <<< "$skill_triggers"
        triggers_json=""
        for trigger in "${TRIGGERS[@]}"; do
            trigger=$(echo "$trigger" | xargs) # trim
            if [ -z "$triggers_json" ]; then
                triggers_json="\"$trigger\""
            else
                triggers_json="$triggers_json, \"$trigger\""
            fi
        done
        
        cat > "$SKILLS_DIR/$skill_name.json" << EOF
{
  "name": "$skill_name",
  "description": "$skill_desc",
  "trigger": [$triggers_json],
  "instructions": "$skill_instructions"
}
EOF
        
        echo ""
        echo "Навык '$skill_name' успешно создан в $SKILLS_DIR/$skill_name.json"
        ;;
        
    2)
        echo ""
        echo "Просмотр существующего навыка"
        echo "-----------------------------"
        ls "$SKILLS_DIR"/*.json
        if [ "$(ls "$SKILLS_DIR"/*.json 2>/dev/null | wc -l)" -eq 0 ]; then
            echo "Навыки не найдены."
        else
            read -p "Введите название навыка для просмотра (без расширения .json): " skill_to_view
            if [ -f "$SKILLS_DIR/$skill_to_view.json" ]; then
                echo ""
                echo "Содержание навыка '$skill_to_view':"
                cat "$SKILLS_DIR/$skill_to_view.json"
            else
                echo "Навык '$skill_to_view' не найден."
            fi
        fi
        ;;
        
    3)
        echo ""
        echo "Удаление навыка"
        echo "---------------"
        ls "$SKILLS_DIR"/*.json
        if [ "$(ls "$SKILLS_DIR"/*.json 2>/dev/null | wc -l)" -eq 0 ]; then
            echo "Навыки не найдены."
        else
            read -p "Введите название навыка для удаления (без расширения .json): " skill_to_delete
            if [ -f "$SKILLS_DIR/$skill_to_delete.json" ]; then
                rm "$SKILLS_DIR/$skill_to_delete.json"
                echo "Навык '$skill_to_delete' удален."
            else
                echo "Навык '$skill_to_delete' не найден."
            fi
        fi
        ;;
        
    4)
        echo "Выход из скрипта управления навыками."
        exit 0
        ;;
        
    *)
        echo "Неверный выбор. Пожалуйста, выберите число от 1 до 4."
        ;;
esac

echo ""
echo "Для применения изменений перезапустите Opencode или выполните команду:"
echo "  opencode reload skills"