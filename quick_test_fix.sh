#!/bin/bash
# Быстрый тест исправлений

echo "=== БЫСТРЫЙ ТЕСТ ИСПРАВЛЕНИЙ ==="

# Проверяем, что файл существует
if [[ ! -f "deploy_monitoring_script.sh" ]]; then
    echo "❌ Файл deploy_monitoring_script.sh не найден"
    exit 1
fi

echo "✅ Файл deploy_monitoring_script.sh найден"

# Проверяем, что исправления применены
echo ""
echo "=== ПРОВЕРКА ИСПРАВЛЕНИЙ ==="

# Проверяем наличие отладочной информации
if grep -q "Текущий каталог: \$(pwd)" deploy_monitoring_script.sh; then
    echo "✅ Отладочная информация добавлена"
else
    echo "❌ Отладочная информация не найдена"
fi

# Проверяем исправление обработки HTTP 409
if grep -q "Используем известный ID: \$known_id" deploy_monitoring_script.sh; then
    echo "✅ Исправление обработки HTTP 409 применено"
else
    echo "❌ Исправление обработки HTTP 409 не найдено"
fi

# Проверяем улучшенное логирование health check
if grep -q "Health check ответ: HTTP \$test_code" deploy_monitoring_script.sh; then
    echo "✅ Улучшенное логирование health check добавлено"
else
    echo "❌ Улучшенное логирование health check не найдено"
fi

# Проверяем, что старая проблемная строка удалена
if grep -q "log_diagnosis \"Код возврата: \$sa_result\"" deploy_monitoring_script.sh; then
    echo "❌ Старая проблемная строка все еще присутствует"
else
    echo "✅ Проблемная строка с sa_result удалена"
fi

echo ""
echo "=== ПРОВЕРКА СИНТАКСИСА ==="

# Быстрая проверка синтаксиса
if bash -n deploy_monitoring_script.sh 2>/dev/null; then
    echo "✅ Синтаксис скрипта корректен"
else
    echo "❌ Обнаружены синтаксические ошибки"
    echo "Проверка:"
    bash -n deploy_monitoring_script.sh
fi

echo ""
echo "=== РЕКОМЕНДАЦИИ ==="
echo "1. Запустите пайплайн для проверки исправлений"
echo "2. Если проблема останется, проверьте логи пайплайна"
echo "3. Обратите внимание на новые сообщения отладки в логах"
echo ""
echo "Основные изменения:"
echo "- Исправлена обработка HTTP 409 (сервисный аккаунт уже существует)"
echo "- Добавлена отладочная информация для диагностики"
echo "- Улучшено логирование health check"
echo "- Удалена проблемная строка с неопределенной переменной sa_result"
