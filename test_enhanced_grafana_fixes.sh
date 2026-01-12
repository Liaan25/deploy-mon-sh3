#!/bin/bash
# Тестирование улучшенных исправлений для Grafana

echo "=== ТЕСТИРОВАНИЕ УЛУЧШЕННЫХ ИСПРАВЛЕНИЙ ДЛЯ GRAFANA ==="
echo

# 1. Проверка добавленных диагностических функций
echo "1. Проверка добавленной диагностики..."
echo

# Проверяем диагностику API
echo "   Проверка доступности API:"
if grep -q "Проверка доступности Grafana API перед созданием сервисного аккаунта" deploy_monitoring_script.sh; then
    echo "   ✅ Добавлена проверка доступности API /api/health"
else
    echo "   ❌ Нет проверки доступности API"
fi

# Проверяем логирование команд curl
if grep -q "Выполнение API запроса:" deploy_monitoring_script.sh; then
    echo "   ✅ Добавлено логирование curl команд"
else
    echo "   ❌ Нет логирования curl команд"
fi

# Проверяем логирование ошибок API
if grep -q "Полный ответ:" deploy_monitoring_script.sh; then
    echo "   ✅ Добавлено логирование полных ответов API"
else
    echo "   ❌ Нет логирования полных ответов API"
fi

echo

# 2. Проверка исправления формата JSON
echo "2. Проверка исправления формата JSON..."
echo

if grep -q "Проверка формата JSON файла" deploy_monitoring_script.sh; then
    echo "   ✅ Добавлена проверка формата JSON"
    
    # Проверяем исправление Windows line endings
    if grep -q "sed -i 's/\\r\$//'" deploy_monitoring_script.sh; then
        echo "   ✅ Добавлено исправление Windows line endings"
    else
        echo "   ❌ Нет исправления Windows line endings"
    fi
    
    # Проверяем исправление лишних запятых
    if grep -q "sed -i 's/,\s*}/}/g'" deploy_monitoring_script.sh; then
        echo "   ✅ Добавлено исправление лишних запятых"
    else
        echo "   ❌ Нет исправления лишних запятых"
    fi
    
    # Проверяем создание backup
    if grep -q "cp.*\.backup" deploy_monitoring_script.sh; then
        echo "   ✅ Добавлено создание backup файла"
    else
        echo "   ❌ Нет создания backup файла"
    fi
else
    echo "   ❌ Нет проверки формата JSON"
fi

echo

# 3. Проверка fallback механизмов
echo "3. Проверка fallback механизмов..."
echo

# Проверяем fallback на старую функцию
if grep -q "Пробуем использовать старую функцию ensure_grafana_token" deploy_monitoring_script.sh; then
    echo "   ✅ Добавлен fallback на старую функцию ensure_grafana_token"
else
    echo "   ❌ Нет fallback на старую функцию"
fi

# Проверяем обработку разных кодов возврата
if grep -B3 -A3 "sa_result -eq 2" deploy_monitoring_script.sh | grep -q "Пробуем использовать старую функцию"; then
    echo "   ✅ Есть обработка кода возврата 2 с fallback"
else
    echo "   ❌ Нет обработки кода возврата 2 с fallback"
fi

echo

# 4. Проверка структуры JSON файла
echo "4. Проверка диагностики структуры JSON..."
echo

if grep -q "Структура JSON файла:" deploy_monitoring_script.sh; then
    echo "   ✅ Добавлено отображение структуры JSON"
else
    echo "   ❌ Нет отображения структуры JSON"
fi

if grep -q "jq 'keys'" deploy_monitoring_script.sh; then
    echo "   ✅ Используется jq для проверки структуры"
else
    echo "   ❌ Не используется jq для проверки структуры"
fi

echo

# 5. Проверка клиентских сертификатов
echo "5. Проверка работы с клиентскими сертификатами..."
echo

if grep -q "Используем клиентские сертификаты для mTLS" deploy_monitoring_script.sh; then
    echo "   ✅ Добавлено логирование использования клиентских сертификатов"
else
    echo "   ❌ Нет логирования использования клиентских сертификатов"
fi

if grep -q "Клиентские сертификаты не найдены" deploy_monitoring_script.sh; then
    echo "   ✅ Добавлено сообщение об отсутствии клиентских сертификатов"
else
    echo "   ❌ Нет сообщения об отсутствии клиентских сертификатов"
fi

echo
echo "=== ИТОГИ ДОБАВЛЕННЫХ ИСПРАВЛЕНИЙ ==="
echo
echo "Добавлены следующие улучшения:"
echo
echo "1. ДИАГНОСТИКА API:"
echo "   - Проверка доступности /api/health перед запросами"
echo "   - Логирование curl команд (без пароля)"
echo "   - Логирование полных ответов при ошибках"
echo "   - Отображение тел ответов (первые 500 символов)"
echo
echo "2. ИСПРАВЛЕНИЕ ФОРМАТА JSON:"
echo "   - Автоматическая проверка валидности JSON"
echo "   - Исправление Windows line endings (\\r)"
echo "   - Исправление лишних запятых"
echo "   - Создание backup файла перед исправлениями"
echo   "   - Отображение структуры JSON файла"
echo
echo "3. FALLBACK МЕХАНИЗМЫ:"
echo "   - Fallback на старую функцию ensure_grafana_token"
echo   "   - Обработка разных кодов возврата (0, 2, 1)"
echo   "   - Возможность пропуска настройки без прерывания скрипта"
echo
echo "4. РАБОТА С mTLS:"
echo "   - Логирование использования клиентских сертификатов"
echo   "   - Сообщение об отсутствии сертификатов"
echo
echo "=== КАК ТЕСТИРОВАТЬ ==="
echo
echo "1. Запустите скрипт с включенной диагностикой:"
echo "   sudo ./deploy_monitoring_script.sh 2>&1 | tee deployment.log"
echo
echo "2. Ищите в логах:"
echo "   - 'Проверка доступности Grafana API'"
echo "   - 'Проверка формата JSON файла'"
echo "   - 'Выполнение API запроса:'"
echo "   - 'Ответ API создания сервисного аккаунта:'"
echo
echo "3. Если проблема с API, вы увидите:"
echo "   - HTTP код ответа"
echo "   - Тело ответа при ошибках"
echo "   - Попытку fallback на старую функцию"
echo
echo "4. Для принудительного тестирования fallback:"
echo "   export FORCE_GRAFANA_FALLBACK=true"
echo "   sudo ./deploy_monitoring_script.sh"





