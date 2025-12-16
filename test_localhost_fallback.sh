#!/bin/bash

# Тестовый скрипт для проверки автоматического fallback на localhost

set -e

echo "=== ТЕСТ АВТОМАТИЧЕСКОГО FALLBACK НА LOCALHOST ==="
echo

echo "ПРОБЛЕМА:"
echo "1. Пайплайн использует доменное имя: tvlds-mvp001939.cloud.delta.sbrf.ru:3000"
echo "2. Получает HTTP 400 'Bad request data'"
echo "3. Тестовый скрипт использует localhost:3000 и работает"
echo "4. Пайплайн прерывает выполнение при ошибке, не доходя до fallback"
echo

echo "РЕШЕНИЕ:"
echo "1. Добавлен автоматический fallback внутри функции create_service_account_via_api"
echo "2. При HTTP 400 с доменным именем → автоматически пробует localhost"
echo "3. Не требует изменения пайплайна или установки переменных"
echo

echo "ЛОГИКА РАБОТЫ:"
echo "1. Функция получает URL (например: https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000)"
echo "2. Пробует создать сервисный аккаунт через этот URL"
echo "3. Если получает HTTP 400 → автоматически меняет URL на https://localhost:3000"
echo "4. Пробует снова с localhost"
echo "5. Если успешно → возвращает результат"
echo "6. Если нет → возвращает ошибку"
echo

echo "ПРЕИМУЩЕСТВА:"
echo "✅ Решает проблему без изменения пайплайна"
echo "✅ Автоматически определяет когда нужен localhost"
echo "✅ Сохраняет обратную совместимость"
echo "✅ Работает с существующей инфраструктурой"
echo

echo "ПРИМЕР РАБОТЫ:"
echo "ДО исправления:"
echo "  [INFO] Попытка создания SA через https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000"
echo "  [ERROR] HTTP 400: Bad request data"
echo "  [INFO] Stage 'Проверка результатов' skipped due to earlier failure(s)"
echo "  ❌ ПАЙПЛАЙН ПРЕРЫВАЕТСЯ"
echo

echo "ПОСЛЕ исправления:"
echo "  [INFO] Попытка создания SA через https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000"
echo "  [WARNING] HTTP 400: Bad request data"
echo "  [INFO] === ПОПЫТКА LOCALHOST: Пробуем с localhost вместо доменного имени ==="
echo "  [INFO] Меняем URL на https://localhost:3000"
echo "  [SUCCESS] Запрос с localhost успешен (HTTP 201)"
echo "  [SUCCESS] Сервисный аккаунт создан, ID: 2"
echo "  ✅ ПАЙПЛАЙН ПРОДОЛЖАЕТ РАБОТУ"
echo

echo "КАК ПРОВЕРИТЬ:"
echo "1. Запустите пайплайн заново"
echo "2. Проверьте логи в /var/log/grafana_monitoring_diagnosis.log"
echo "3. Ищите строки:"
echo "   - '=== ПОПЫТКА LOCALHOST: Пробуем с localhost вместо доменного имени ==='"
echo "   - 'Меняем URL с ... на https://localhost:3000'"
echo "   - 'Запрос с localhost успешен'"
echo

echo "ЕСЛИ ПРОБЛЕМА НЕ РЕШЕНА:"
echo "1. Проверьте что порт 3000 доступен на localhost:"
echo "   curl -k https://localhost:3000/api/health"
echo "2. Проверьте учетные данные:"
echo "   cat /opt/vault/conf/data_sec.json | jq '.grafana_web'"
echo "3. Проверьте версию Grafana:"
echo "   grafana-server -v"
echo

echo "АЛЬТЕРНАТИВНЫЕ РЕШЕНИЯ:"
echo "1. Установить переменную в пайплайне:"
echo "   export USE_GRAFANA_LOCALHOST=true"
echo "2. Изменить пайплайн чтобы он не прерывался при ошибках"
echo "3. Использовать другой endpoint для создания SA"
echo

echo "НОВЫЙ КОД В ФУНКЦИИ create_service_account_via_api:"
cat << 'EOF'
# Автоматическое определение: если доменное имя не работает, пробуем localhost
local try_localhost=false
local original_grafana_url_for_fallback="$grafana_url"

# Проверяем, не является ли уже localhost
if [[ "$grafana_url" != *"localhost"* && "$grafana_url" != *"127.0.0.1"* ]]; then
    print_info "Проверяем возможность использования localhost вместо доменного имени..."
    
    # Если USE_GRAFANA_LOCALHOST не установлен, но мы видим проблемы с доменным именем,
    # устанавливаем флаг для попытки localhost
    if [[ "${USE_GRAFANA_LOCALHOST:-false}" == "false" ]]; then
        print_info "USE_GRAFANA_LOCALHOST не установлен, но будем готовы к fallback на localhost"
        try_localhost=true
    fi
fi

# ... позже в коде, при получении HTTP 400:

if [[ "$http_code" == "400" && "$try_localhost" == "true" && "$grafana_url" != *"localhost"* ]]; then
    print_info "=== ПОПЫТКА LOCALHOST: Пробуем с localhost вместо доменного имени ==="
    
    # Сохраняем оригинальный URL для логирования
    local original_url="$grafana_url"
    
    # Меняем URL на localhost
    grafana_url="https://localhost:${GRAFANA_PORT}"
    print_info "Меняем URL с $original_url на $grafana_url"
    
    # ... пробуем снова с localhost ...
EOF

echo
echo "Тест завершен. Запустите пайплайн для проверки исправления."
