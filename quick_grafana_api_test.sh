#!/bin/bash
# Быстрый тест API Grafana
# Запуск: sudo ./quick_grafana_api_test.sh

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

echo -e "${BLUE}=== БЫСТРЫЙ ТЕСТ API GRAFANA ===${NC}"

# 1. Получение учетных данных
CRED_FILE="/opt/vault/conf/data_sec.json"
if [[ ! -f "$CRED_FILE" ]]; then
    print_error "Файл $CRED_FILE не найден"
    exit 1
fi

print_info "Извлечение учетных данных из $CRED_FILE"
USER=$(jq -r '.grafana_web.user // empty' "$CRED_FILE" 2>/dev/null || echo "")
PASS=$(jq -r '.grafana_web.pass // empty' "$CRED_FILE" 2>/dev/null || echo "")

if [[ -z "$USER" || -z "$PASS" ]]; then
    print_error "Не удалось получить учетные данные"
    echo "Содержимое grafana_web:"
    jq '.grafana_web' "$CRED_FILE" 2>/dev/null || cat "$CRED_FILE" | grep -A5 -B5 "grafana_web"
    exit 1
fi

print_success "Учетные данные получены: $USER"

# 2. Определение URL
DOMAIN="localhost"
if [[ -f "deploy_monitoring_script.sh" ]]; then
    DOMAIN=$(grep -o "SERVER_DOMAIN=.*" deploy_monitoring_script.sh | head -1 | cut -d= -f2 | tr -d '"' || echo "localhost")
fi

URL="https://${DOMAIN}:3000"
print_info "Используем URL: $URL"

# 3. Проверка доступности порта
print_info "Проверка порта 3000..."
if ss -tln | grep -q ":3000 "; then
    print_success "Порт 3000 слушается"
else
    print_error "Порт 3000 НЕ слушается"
    print_info "Текущие порты:"
    ss -tln | grep -E ":3000|LISTEN" | head -10
fi

# 4. Проверка процесса
print_info "Проверка процесса grafana-server..."
if pgrep -f "grafana-server" >/dev/null; then
    print_success "Процесс grafana-server запущен"
else
    print_error "Процесс grafana-server не найден"
fi

# 5. Тестирование API endpoints
echo -e "\n${BLUE}=== ТЕСТИРОВАНИЕ API ENDPOINTS ===${NC}"

test_api() {
    local endpoint="$1"
    local description="$2"
    
    print_info "Тест: $description ($endpoint)"
    
    local response
    response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
        -u "${USER}:${PASS}" \
        "${URL}${endpoint}" 2>&1)
    
    local http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    local body=$(echo "$response" | grep -v "HTTP_CODE:")
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        print_success "HTTP $http_code"
        echo "Ответ (первые 200 символов):"
        echo "$body" | head -c 200
        echo -e "\n"
    else
        print_error "HTTP $http_code"
        echo "Ответ:"
        echo "$body" | head -c 500
        echo -e "\n"
    fi
}

# Тестируем основные endpoints
test_api "/api/health" "Health check"
test_api "/api/serviceaccounts" "List service accounts"
test_api "/api/datasources" "List data sources"
test_api "/api/folders" "List folders"

# 6. Попытка создания сервисного аккаунта
echo -e "\n${BLUE}=== ТЕСТ СОЗДАНИЯ СЕРВИСНОГО АККАУНТА ===${NC}"

TIMESTAMP=$(date +%s)
SA_NAME="test-service-account_$TIMESTAMP"
TOKEN_NAME="test-token_$TIMESTAMP"

print_info "Создание сервисного аккаунта: $SA_NAME"

# Создание payload
SA_PAYLOAD=$(jq -n --arg name "$SA_NAME" --arg role "Admin" '{name:$name, role:$role}')

# Отправка запроса
CREATE_RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -u "${USER}:${PASS}" \
    -d "$SA_PAYLOAD" \
    "${URL}/api/serviceaccounts" 2>&1)

CREATE_HTTP_CODE=$(echo "$CREATE_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
CREATE_BODY=$(echo "$CREATE_RESPONSE" | grep -v "HTTP_CODE:")

echo "Запрос: POST ${URL}/api/serviceaccounts"
echo "Payload: $SA_PAYLOAD"

if [[ "$CREATE_HTTP_CODE" == "200" || "$CREATE_HTTP_CODE" == "201" ]]; then
    print_success "Сервисный аккаунт создан: HTTP $CREATE_HTTP_CODE"
    
    # Извлекаем ID
    SA_ID=$(echo "$CREATE_BODY" | jq -r '.id // empty' 2>/dev/null || echo "")
    if [[ -n "$SA_ID" ]]; then
        print_success "ID сервисного аккаунта: $SA_ID"
        
        # Создание токена
        print_info "Создание токена: $TOKEN_NAME"
        TOKEN_PAYLOAD=$(jq -n --arg name "$TOKEN_NAME" '{name:$name}')
        
        TOKEN_RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -u "${USER}:${PASS}" \
            -d "$TOKEN_PAYLOAD" \
            "${URL}/api/serviceaccounts/${SA_ID}/tokens" 2>&1)
        
        TOKEN_HTTP_CODE=$(echo "$TOKEN_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
        TOKEN_BODY=$(echo "$TOKEN_RESPONSE" | grep -v "HTTP_CODE:")
        
        if [[ "$TOKEN_HTTP_CODE" == "200" || "$TOKEN_HTTP_CODE" == "201" ]]; then
            print_success "Токен создан: HTTP $TOKEN_HTTP_CODE"
            TOKEN=$(echo "$TOKEN_BODY" | jq -r '.key // empty' 2>/dev/null || echo "")
            if [[ -n "$TOKEN" ]]; then
                print_success "Токен получен (первые 20 символов): ${TOKEN:0:20}..."
                echo "Полный токен: $TOKEN"
            else
                print_error "Токен пустой"
            fi
        else
            print_error "Ошибка создания токена: HTTP $TOKEN_HTTP_CODE"
            echo "Ответ: $TOKEN_BODY"
        fi
    else
        print_error "Не удалось получить ID сервисного аккаунта"
        echo "Ответ: $CREATE_BODY"
    fi
    
elif [[ "$CREATE_HTTP_CODE" == "409" ]]; then
    print_warning "Сервисный аккаунт уже существует (HTTP 409)"
    
    # Получение списка сервисных аккаунтов
    print_info "Получение списка сервисных аккаунтов..."
    LIST_RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
        -u "${USER}:${PASS}" \
        "${URL}/api/serviceaccounts" 2>&1)
    
    LIST_HTTP_CODE=$(echo "$LIST_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
    LIST_BODY=$(echo "$LIST_RESPONSE" | grep -v "HTTP_CODE:")
    
    if [[ "$LIST_HTTP_CODE" == "200" ]]; then
        print_success "Список получен"
        echo "Количество сервисных аккаунтов: $(echo "$LIST_BODY" | jq '.serviceAccounts | length' 2>/dev/null || echo "неизвестно")"
    else
        print_error "Ошибка получения списка: HTTP $LIST_HTTP_CODE"
    fi
    
else
    print_error "Ошибка создания сервисного аккаунта: HTTP $CREATE_HTTP_CODE"
    echo "Полный ответ:"
    echo "$CREATE_RESPONSE"
fi

# 7. Проверка с клиентскими сертификатами
echo -e "\n${BLUE}=== ПРОВЕРКА КЛИЕНТСКИХ СЕРТИФИКАТОВ ===${NC}"

CERT_FILE="/opt/vault/certs/grafana-client.crt"
KEY_FILE="/opt/vault/certs/grafana-client.key"

if [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]]; then
    print_success "Клиентские сертификаты найдены"
    print_info "Размеры: $(stat -c%s "$CERT_FILE") / $(stat -c%s "$KEY_FILE") байт"
    
    # Тест с сертификатами
    print_info "Тест API с клиентскими сертификатами..."
    CERT_RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
        --cert "$CERT_FILE" \
        --key "$KEY_FILE" \
        -u "${USER}:${PASS}" \
        "${URL}/api/health" 2>&1)
    
    CERT_HTTP_CODE=$(echo "$CERT_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
    
    if [[ "$CERT_HTTP_CODE" == "200" ]]; then
        print_success "API работает с клиентскими сертификатами: HTTP $CERT_HTTP_CODE"
    else
        print_warning "Проблема с клиентскими сертификатами: HTTP $CERT_HTTP_CODE"
    fi
else
    print_warning "Клиентские сертификаты не найдены"
    print_info "Ожидаемые пути:"
    echo "  $CERT_FILE"
    echo "  $KEY_FILE"
fi

# 8. Итоги
echo -e "\n${BLUE}=== ИТОГИ ДИАГНОСТИКИ ===${NC}"

echo "1. Учетные данные: $( [[ -n "$USER" && -n "$PASS" ]] && echo "✅" || echo "❌" )"
echo "2. Порт 3000: $(ss -tln | grep -q ":3000 " && echo "✅" || echo "❌")"
echo "3. Процесс Grafana: $(pgrep -f "grafana-server" >/dev/null && echo "✅" || echo "❌")"
echo "4. API /api/health: $( [[ "$(curl -k -s -o /dev/null -w "%{http_code}" -u "${USER}:${PASS}" "${URL}/api/health" 2>/dev/null)" == "200" ]] && echo "✅" || echo "❌")"
echo "5. Клиентские сертификаты: $( [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]] && echo "✅" || echo "❌")"

echo -e "\n${BLUE}=== РЕКОМЕНДАЦИИ ===${NC}"

if curl -k -s -o /dev/null -w "%{http_code}" -u "${USER}:${PASS}" "${URL}/api/health" 2>/dev/null | grep -q "200"; then
    print_success "API Grafana работает"
    echo "1. Проверьте логи основного скрипта на наличие других ошибок"
    echo "2. Убедитесь что токен сохраняется в переменной GRAFANA_BEARER_TOKEN"
    echo "3. Проверьте вызовы функций в основном скрипте"
else
    print_error "Проблема с API Grafana"
    echo "1. Проверьте логи Grafana: sudo journalctl -u grafana-server -n 50"
    echo "2. Проверьте аутентификацию вручную:"
    echo "   curl -k -v -u '${USER}:*****' ${URL}/api/health"
    echo "3. Проверьте настройки аутентификации в grafana.ini"
fi

echo -e "\n${BLUE}=== ДИАГНОСТИКА ЗАВЕРШЕНА ===${NC}"

