#!/bin/bash
# Тест отладочного вывода

echo "=== ТЕСТ ОТЛАДОЧНОГО ВЫВОДА ==="

# Проверяем, что отладочные сообщения добавлены
echo "Проверка добавленных отладочных сообщений в deploy_monitoring_script.sh:"
echo ""

# Проверяем ключевые отладочные сообщения
DEBUG_MESSAGES=(
    "DEBUG_FUNC_START"
    "DEBUG_PARAMS"
    "DEBUG_HEALTH_CHECK"
    "DEBUG_HEALTH_URL"
    "DEBUG_HEALTH_SUCCESS"
    "DEBUG_SA_CREATE"
    "DEBUG_SA_ENDPOINT"
    "DEBUG_SA_PAYLOAD"
    "DEBUG_SA_RESPONSE"
    "DEBUG_SA_DURATION"
    "DEBUG_RETURN"
)

for msg in "${DEBUG_MESSAGES[@]}"; do
    if grep -q "$msg" deploy_monitoring_script.sh; then
        echo "✅ Найдено: $msg"
    else
        echo "❌ Не найдено: $msg"
    fi
done

echo ""
echo "=== ПРОВЕРКА СИНТАКСИСА ==="

# Быстрая проверка синтаксиса ключевых частей
echo "Проверка синтаксиса функции create_service_account_via_api..."

# Извлекаем функцию для проверки
awk '/create_service_account_via_api\(\) \{/,/^        \}/' deploy_monitoring_script.sh > /tmp/test_function.sh 2>/dev/null

if [[ -s /tmp/test_function.sh ]]; then
    echo "Функция извлечена для проверки"
    
    # Добавляем shebang и минимальный контекст для проверки
    cat > /tmp/test_syntax.sh << 'EOF'
#!/bin/bash
# Тестовая оболочка для проверки синтаксиса
test_function() {
EOF
    cat /tmp/test_function.sh >> /tmp/test_syntax.sh
    echo "}" >> /tmp/test_syntax.sh
    
    if bash -n /tmp/test_syntax.sh 2>/dev/null; then
        echo "✅ Синтаксис функции корректен"
    else
        echo "❌ Обнаружены синтаксические ошибки в функции"
        bash -n /tmp/test_syntax.sh
    fi
else
    echo "⚠️  Не удалось извлечь функцию для проверки"
fi

echo ""
echo "=== ИНСТРУКЦИЯ ПО ИСПОЛЬЗОВАНИЮ ==="
echo "1. Запустите пайплайн для проверки отладочного вывода"
echo "2. В логах пайплайна ищите строки начинающиеся с 'DEBUG_'"
echo "3. Отладочные сообщения выводятся в stderr (>&2)"
echo ""
echo "Ожидаемые отладочные сообщения:"
echo "- DEBUG_FUNC_START - функция вызвана"
echo "- DEBUG_PARAMS - параметры функции"
echo "- DEBUG_HEALTH_CHECK - начало проверки health"
echo "- DEBUG_HEALTH_SUCCESS - health check прошел"
echo "- DEBUG_SA_CREATE - начало создания SA"
echo "- DEBUG_SA_RESPONSE - ответ от API"
echo "- DEBUG_RETURN - возврат из функции"
echo ""
echo "Эти сообщения помогут определить, на каком этапе падает функция."
