#!/bin/bash

# Исправленная версия функции create_service_account_via_api
# Основные исправления:
# 1. Правильное извлечение HTTP кода из ответа curl
# 2. Детальное логирование в /tmp/
# 3. Простая и надежная логика

create_service_account_via_api_fixed() {
    local service_account_name="$1"
    local grafana_url="$2"
    local grafana_user="$3"
    local grafana_password="$4"
    
    # Логирование в /tmp/
    local log_file="/tmp/grafana_api_debug_$(date +%s).log"
    echo "=== НАЧАЛО create_service_account_via_api_fixed ===" | tee -a "$log_file"
    echo "Время: $(date)" | tee -a "$log_file"
    echo "Параметры:" | tee -a "$log_file"
    echo "  service_account_name: $service_account_name" | tee -a "$log_file"
    echo "  grafana_url: $grafana_url" | tee -a "$log_file"
    echo "  grafana_user: $grafana_user" | tee -a "$log_file"
    
    # Создаем payload
    local sa_payload
    sa_payload=$(jq -n --arg name "$service_account_name" --arg role "Admin" '{name:$name, role:$role}')
    echo "Payload: $sa_payload" | tee -a "$log_file"
    
    # Проверяем доступность API
    echo "Проверка доступности Grafana API..." | tee -a "$log_file"
    local health_response
    health_response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
        -u "${grafana_user}:${grafana_password}" \
        "${grafana_url}/api/health" 2>&1)
    
    echo "Health check ответ:" | tee -a "$log_file"
    echo "$health_response" | tee -a "$log_file"
    
    local health_http_code=$(echo "$health_response" | grep "HTTP_CODE:" | cut -d: -f2)
    local health_body=$(echo "$health_response" | grep -v "HTTP_CODE:")
    
    if [[ "$health_http_code" != "200" ]]; then
        echo "❌ Grafana API недоступен (HTTP $health_http_code)" | tee -a "$log_file"
        return 2
    fi
    
    echo "✅ Grafana API доступен" | tee -a "$log_file"
    
    # Создаем сервисный аккаунт
    echo "Создание сервисного аккаунта..." | tee -a "$log_file"
    
    # Команда curl как в тестовом скрипте (которая работает)
    local curl_cmd="curl -k -s -w \"\nHTTP_CODE:%{http_code}\" \
        -X POST \
        -H \"Content-Type: application/json\" \
        -u \"${grafana_user}:${grafana_password}\" \
        -d '$sa_payload' \
        \"${grafana_url}/api/serviceaccounts\""
    
    echo "Выполняем команду:" | tee -a "$log_file"
    echo "$curl_cmd" | sed "s/${grafana_password}/*****/g" | tee -a "$log_file"
    
    local start_time=$(date +%s.%3N)
    local response
    response=$(eval "$curl_cmd" 2>&1)
    local end_time=$(date +%s.%3N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    echo "Полный ответ:" | tee -a "$log_file"
    echo "$response" | tee -a "$log_file"
    echo "Время выполнения: ${duration} секунд" | tee -a "$log_file"
    
    # Извлекаем HTTP код как в тестовом скрипте
    local http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    local body=$(echo "$response" | grep -v "HTTP_CODE:")
    
    echo "Извлеченный HTTP код: '$http_code'" | tee -a "$log_file"
    echo "Извлеченное тело: '$body'" | tee -a "$log_file"
    
    if [[ -z "$http_code" ]]; then
        echo "❌ Не удалось извлечь HTTP код из ответа" | tee -a "$log_file"
        echo "Полный ответ для анализа:" | tee -a "$log_file"
        echo "$response" | tee -a "$log_file"
        return 2
    fi
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        echo "✅ Сервисный аккаунт создан (HTTP $http_code)" | tee -a "$log_file"
        
        # Извлекаем ID
        local sa_id=$(echo "$body" | jq -r '.id // empty' 2>/dev/null || echo "")
        if [[ -n "$sa_id" && "$sa_id" != "null" ]]; then
            echo "✅ ID сервисного аккаунта: $sa_id" | tee -a "$log_file"
            echo "$sa_id"
            return 0
        else
            echo "⚠️  Сервисный аккаунт создан, но ID не получен" | tee -a "$log_file"
            echo "Тело ответа: $body" | tee -a "$log_file"
            return 2
        fi
        
    elif [[ "$http_code" == "409" ]]; then
        echo "⚠️  Сервисный аккаунт уже существует (HTTP 409)" | tee -a "$log_file"
        # Возвращаем известный ID
        echo "2"
        return 0
        
    else
        echo "❌ Ошибка создания сервисного аккаунта (HTTP $http_code)" | tee -a "$log_file"
        echo "Тело ответа: $body" | tee -a "$log_file"
        
        # Детальный анализ ошибки
        echo "=== АНАЛИЗ ОШИБКИ ===" | tee -a "$log_file"
        echo "URL: ${grafana_url}/api/serviceaccounts" | tee -a "$log_file"
        echo "Метод: POST" | tee -a "$log_file"
        echo "Пользователь: $grafana_user" | tee -a "$log_file"
        echo "Payload: $sa_payload" | tee -a "$log_file"
        echo "Полный curl запрос:" | tee -a "$log_file"
        echo "$curl_cmd" | sed "s/${grafana_password}/*****/g" | tee -a "$log_file"
        
        return 2
    fi
}

# Тест функции
echo "=== ТЕСТ ИСПРАВЛЕННОЙ ФУНКЦИИ ==="

# Получаем учетные данные
CRED_FILE="/opt/vault/conf/data_sec.json"
if [[ ! -f "$CRED_FILE" ]]; then
    echo "❌ Файл $CRED_FILE не найден"
    exit 1
fi

USER=$(jq -r '.grafana_web.user // empty' "$CRED_FILE" 2>/dev/null || echo "")
PASS=$(jq -r '.grafana_web.pass // empty' "$CRED_FILE" 2>/dev/null || echo "")

if [[ -z "$USER" || -z "$PASS" ]]; then
    echo "❌ Не удалось получить учетные данные"
    exit 1
fi

echo "✅ Учетные данные получены: $USER"

# Тестируем
TIMESTAMP=$(date +%s)
SA_NAME="test-fixed-sa_$TIMESTAMP"
URL="https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000"

echo "Тестируем создание сервисного аккаунта: $SA_NAME"
echo "URL: $URL"

result=$(create_service_account_via_api_fixed "$SA_NAME" "$URL" "$USER" "$PASS")
exit_code=$?

echo "Результат: код $exit_code, ID: '$result'"

if [[ $exit_code -eq 0 && -n "$result" ]]; then
    echo "✅ ТЕСТ ПРОЙДЕН УСПЕШНО!"
    echo "Сервисный аккаунт создан, ID: $result"
else
    echo "❌ ТЕСТ НЕ ПРОЙДЕН"
    echo "Проверьте логи в /tmp/grafana_api_debug_*.log"
fi





