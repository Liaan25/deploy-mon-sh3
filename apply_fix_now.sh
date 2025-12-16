#!/bin/bash

# Скрипт для применения исправления к функции create_service_account_via_api

echo "=== ПРИМЕНЕНИЕ ИСПРАВЛЕНИЯ К ФУНКЦИИ create_service_account_via_api ==="
echo

# Проверяем что файл существует
if [[ ! -f "deploy_monitoring_script.sh" ]]; then
    echo "❌ Файл deploy_monitoring_script.sh не найден"
    exit 1
fi

# Создаем backup
echo "Создаем backup файла..."
cp deploy_monitoring_script.sh deploy_monitoring_script.sh.backup.$(date +%s)
echo "✅ Backup создан"

# Читаем исправленную функцию
FIXED_FUNCTION=$(cat fixed_function_content.txt)

# Создаем временный файл с исправлениями
echo "Создаем исправленную версию файла..."

# Создаем новый файл
{
    # Копируем все до функции
    head -n 2164 deploy_monitoring_script.sh
    
    # Вставляем исправленную функцию
    echo "$FIXED_FUNCTION"
    
    # Копируем все после функции
    tail -n +2599 deploy_monitoring_script.sh
} > deploy_monitoring_script.sh.fixed

# Проверяем размеры
original_size=$(wc -l < deploy_monitoring_script.sh)
fixed_size=$(wc -l < deploy_monitoring_script.sh.fixed)

echo "Оригинальный файл: $original_size строк"
echo "Исправленный файл: $fixed_size строк"

# Проверяем что замена прошла успешно
if grep -q "HTTP_CODE:%{http_code}" deploy_monitoring_script.sh.fixed; then
    echo "✅ Исправление применено успешно"
    echo "   Найдено использование правильного формата HTTP_CODE"
else
    echo "❌ Ошибка: исправление не применено"
    exit 1
fi

# Заменяем оригинальный файл
echo "Заменяем оригинальный файл..."
mv deploy_monitoring_script.sh.fixed deploy_monitoring_script.sh

echo "✅ Файл успешно обновлен"
echo
echo "=== ИЗМЕНЕНИЯ ==="
echo "1. ✅ Исправлен формат curl запроса:"
echo "   Было: curl -k -s -w \"\\n%{http_code}\""
echo "   Стало: curl -k -s -w \"\\nHTTP_CODE:%{http_code}\""
echo
echo "2. ✅ Исправлено извлечение HTTP кода:"
echo "   Было: http_code=\$(echo \"\$response\" | tail -1)"
echo "   Стало: http_code=\$(echo \"\$response\" | grep \"HTTP_CODE:\" | cut -d: -f2)"
echo
echo "3. ✅ Исправлено извлечение тела ответа:"
echo "   Было: sa_body=\$(echo \"\$response\" | head -n -1)"
echo "   Стало: sa_body=\$(echo \"\$response\" | grep -v \"HTTP_CODE:\")"
echo
echo "4. ✅ Упрощена логика функции"
echo "5. ✅ Удалены лишние проверки и вложенные функции"
echo
echo "=== РЕЗУЛЬТАТ ==="
echo "Теперь функция будет работать так же как тестовый скрипт debug_grafana_api.sh"
echo "и перестанет получать ложные HTTP 400 ошибки"
echo
echo "=== СЛЕДУЮЩИЕ ШАГИ ==="
echo "1. Запустите пайплайн заново"
echo "2. Проверьте что создание сервисного аккаунта теперь работает"
echo "3. Если есть проблемы, проверьте логи в /tmp/grafana_api_debug_*.log"
