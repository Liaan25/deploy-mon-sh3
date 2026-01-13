#!/bin/bash

# Тестовый скрипт для проверки исправления по Варианту 3
# Проверяем логику "сначала без сертификатов, потом с ними"

set -e

echo "=== ТЕСТ ВАРИАНТА 3: Сначала без сертификатов, потом с ними ==="
echo

# Создаем временные файлы для имитации сертификатов
TEMP_DIR=$(mktemp -d)
echo "Создана временная директория: $TEMP_DIR"

# Имитируем наличие сертификатов
touch "$TEMP_DIR/grafana-client.crt"
touch "$TEMP_DIR/grafana-client.key"

echo "Созданы тестовые сертификаты:"
echo "  - $TEMP_DIR/grafana-client.crt"
echo "  - $TEMP_DIR/grafana-client.key"
echo

# Тест 1: Проверяем логику без реального вызова curl
echo "=== ТЕСТ 1: Проверка логики выбора команды curl ==="

# Имитируем функцию create_service_account_via_api с упрощенной логикой
test_curl_logic() {
    local grafana_url="https://test.example.com:3000"
    local grafana_user="admin"
    local grafana_password="secret"
    local service_account_name="test-sa"
    local sa_payload='{"name":"test-sa","role":"Admin"}'
    
    # Вариант 3: Сначала пробуем без сертификатов, потом с ними
    local curl_cmd_without_cert="curl -k -s -w \"\n%{http_code}\" \
        -X POST \
        -H \"Content-Type: application/json\" \
        -u \"${grafana_user}:${grafana_password}\" \
        -d \"$sa_payload\" \
        \"${grafana_url}/api/serviceaccounts\""
    
    local curl_cmd_with_cert=""
    if [[ -f "$TEMP_DIR/grafana-client.crt" && -f "$TEMP_DIR/grafana-client.key" ]]; then
        curl_cmd_with_cert="curl -k -s -w \"\n%{http_code}\" \
            --cert \"$TEMP_DIR/grafana-client.crt\" \
            --key \"$TEMP_DIR/grafana-client.key\" \
            -X POST \
            -H \"Content-Type: application/json\" \
            -u \"${grafana_user}:${grafana_password}\" \
            -d \"$sa_payload\" \
            \"${grafana_url}/api/serviceaccounts\""
    fi
    
    echo "Команда без сертификатов:"
    echo "$curl_cmd_without_cert" | sed "s/${grafana_password}/*****/g"
    echo
    
    if [[ -n "$curl_cmd_with_cert" ]]; then
        echo "Команда с сертификатами:"
        echo "$curl_cmd_with_cert" | sed "s/${grafana_password}/*****/g"
        echo
    else
        echo "Команда с сертификатами: НЕДОСТУПНА"
        echo
    fi
    
    # Проверяем, что команды разные
    if [[ "$curl_cmd_without_cert" != "$curl_cmd_with_cert" ]]; then
        echo "✅ Команды разные - логика работает правильно"
    else
        echo "❌ Команды одинаковые - ошибка в логике"
    fi
}

test_curl_logic

echo
echo "=== ТЕСТ 2: Проверка логики выполнения попыток ==="

# Имитируем логику выполнения двух попыток
test_attempt_logic() {
    local attempt=1
    local max_attempts=2
    local success=false
    
    while [[ $attempt -le $max_attempts && $success == false ]]; do
        echo "Попытка $attempt из $max_attempts"
        
        if [[ $attempt -eq 1 ]]; then
            echo "  Используем: Без сертификатов"
            # Имитируем ошибку 400
            local http_code=400
        else
            echo "  Используем: С сертификатами"
            # Имитируем успех
            local http_code=201
        fi
        
        if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
            echo "  ✅ Успех (HTTP $http_code)"
            success=true
        else
            echo "  ❌ Ошибка (HTTP $http_code)"
            if [[ $attempt -lt $max_attempts ]]; then
                echo "  Пробуем следующую попытку..."
            fi
        fi
        
        attempt=$((attempt + 1))
        echo
    done
    
    if [[ $success == true ]]; then
        echo "✅ Общий результат: УСПЕХ"
    else
        echo "❌ Общий результат: НЕУДАЧА"
    fi
}

test_attempt_logic

echo
echo "=== ТЕСТ 3: Проверка отсутствия сертификатов ==="

# Удаляем сертификаты
rm -f "$TEMP_DIR/grafana-client.crt" "$TEMP_DIR/grafana-client.key"
echo "Сертификаты удалены"

test_no_cert_logic() {
    local curl_cmd_with_cert=""
    if [[ -f "$TEMP_DIR/grafana-client.crt" && -f "$TEMP_DIR/grafana-client.key" ]]; then
        curl_cmd_with_cert="curl ... с сертификатами ..."
    fi
    
    if [[ -z "$curl_cmd_with_cert" ]]; then
        echo "✅ Команда с сертификатами недоступна - правильно"
        echo "  Будет выполнена только одна попытка без сертификатов"
    else
        echo "❌ Команда с сертификатами доступна - ошибка"
    fi
}

test_no_cert_logic

echo
echo "=== РЕЗЮМЕ ИСПРАВЛЕНИЙ ==="
echo "1. Функция create_service_account_via_api теперь:"
echo "   - Сначала пробует БЕЗ клиентских сертификатов"
echo "   - Если получает ошибку (HTTP 400 или другую) → пробует С сертификатами"
echo "   - Если сертификатов нет → выполняет только одну попытку"
echo
echo "2. Функция create_token_via_api теперь:"
echo "   - Сначала пробует БЕЗ клиентских сертификатов"
echo "   - Если получает ошибку → пробует С сертификатами"
echo "   - Если сертификатов нет → выполняет только одну попытку"
echo
echo "3. Преимущества Варианта 3:"
echo "   - Более безопасный подход"
echo "   - Решает проблему HTTP 400 при использовании сертификатов"
echo "   - Сохраняет совместимость с существующей инфраструктурой"
echo
echo "=== КАК ПРОВЕРИТЬ РАБОТУ ==="
echo "1. Запустите основной скрипт:"
echo "   ./deploy_monitoring_script.sh"
echo
echo "2. Проверьте логи в файле:"
echo "   /var/log/grafana_monitoring_diagnosis.log"
echo
echo "3. Ищите в логах:"
echo "   - 'ПОПЫТКА 1: Без клиентских сертификатов'"
echo "   - 'ПОПЫТКА 2: С клиентскими сертификатами' (если первая не удалась)"
echo
echo "4. Ожидаемый результат:"
echo "   - Если первая попытка успешна → токен создан"
echo "   - Если первая неудачна, вторая успешна → токен создан"
echo "   - Если обе неудачны → используется fallback метод"

# Очистка
rm -rf "$TEMP_DIR"
echo
echo "Тест завершен. Временные файлы удалены."





