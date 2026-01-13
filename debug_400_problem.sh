#!/bin/bash
# Диагностика проблемы HTTP 400 при создании сервисного аккаунта

echo "=== ДИАГНОСТИКА ПРОБЛЕМЫ HTTP 400 ==="

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

echo "✅ Учетные данные получены: пользователь=$USER"

# Тестируем разные URL
URLS=(
    "https://localhost:3000"
    "https://127.0.0.1:3000"
    "https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000"
)

TIMESTAMP=$(date +%s)
SA_NAME="debug-sa-$TIMESTAMP"
SA_PAYLOAD="{\"name\":\"$SA_NAME\",\"role\":\"Admin\"}"

echo ""
echo "=== ТЕСТ 1: ПРОВЕРКА HEALTH CHECK ==="
for url in "${URLS[@]}"; do
    echo -n "  $url/api/health: "
    RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -u "${USER}:${PASS}" "${url}/api/health" 2>&1)
    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
    
    if [[ "$HTTP_CODE" == "200" ]]; then
        echo "✅ HTTP $HTTP_CODE"
    else
        echo "❌ HTTP $HTTP_CODE"
        echo "    Ответ: $(echo "$RESPONSE" | head -c 100)"
    fi
done

echo ""
echo "=== ТЕСТ 2: СОЗДАНИЕ СЕРВИСНОГО АККАУНТА ==="
for url in "${URLS[@]}"; do
    echo ""
    echo "🔍 Тестируем URL: $url"
    echo "   Имя SA: $SA_NAME"
    echo "   Payload: $SA_PAYLOAD"
    
    # Выполняем запрос с подробным логированием
    echo "   Выполняем запрос..."
    
    START_TIME=$(date +%s.%3N)
    RESPONSE=$(curl -k -v -s -w "\nHTTP_CODE:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -u "${USER}:${PASS}" \
        -d "$SA_PAYLOAD" \
        "${url}/api/serviceaccounts" 2>&1)
    END_TIME=$(date +%s.%3N)
    DURATION=$(echo "$END_TIME - $START_TIME" | bc)
    
    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")
    
    echo "   Результат:"
    echo "   - HTTP код: $HTTP_CODE"
    echo "   - Время выполнения: ${DURATION} секунд"
    
    if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
        echo "   ✅ УСПЕХ!"
        SA_ID=$(echo "$BODY" | jq -r '.id // empty' 2>/dev/null || echo "")
        echo "   - ID сервисного аккаунта: $SA_ID"
        break
    elif [[ "$HTTP_CODE" == "400" ]]; then
        echo "   ❌ ОШИБКА 400 Bad Request"
        echo "   - Полный ответ:"
        echo "$RESPONSE" | head -50
        echo "   - Тело ответа: $BODY"
        
        # Пробуем с другими вариантами payload
        echo ""
        echo "   🔧 Пробуем альтернативные форматы payload..."
        
        # Вариант 1: Без role
        PAYLOAD1="{\"name\":\"$SA_NAME\"}"
        echo "   Вариант 1 (без role): $PAYLOAD1"
        RESPONSE1=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -u "${USER}:${PASS}" \
            -d "$PAYLOAD1" \
            "${url}/api/serviceaccounts" 2>&1)
        CODE1=$(echo "$RESPONSE1" | grep "HTTP_CODE:" | cut -d: -f2)
        echo "   Результат: HTTP $CODE1"
        
        # Вариант 2: С role в lowercase
        PAYLOAD2="{\"name\":\"$SA_NAME\",\"role\":\"admin\"}"
        echo "   Вариант 2 (role=admin): $PAYLOAD2"
        RESPONSE2=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -u "${USER}:${PASS}" \
            -d "$PAYLOAD2" \
            "${url}/api/serviceaccounts" 2>&1)
        CODE2=$(echo "$RESPONSE2" | grep "HTTP_CODE:" | cut -d: -f2)
        echo "   Результат: HTTP $CODE2"
        
        # Вариант 3: С role в lowercase и isDisabled
        PAYLOAD3="{\"name\":\"$SA_NAME\",\"role\":\"admin\",\"isDisabled\":false}"
        echo "   Вариант 3 (с isDisabled): $PAYLOAD3"
        RESPONSE3=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -u "${USER}:${PASS}" \
            -d "$PAYLOAD3" \
            "${url}/api/serviceaccounts" 2>&1)
        CODE3=$(echo "$RESPONSE3" | grep "HTTP_CODE:" | cut -d: -f2)
        echo "   Результат: HTTP $CODE3"
        
    elif [[ "$HTTP_CODE" == "409" ]]; then
        echo "   ⚠️  Сервисный аккаунт уже существует"
    else
        echo "   ❌ Другая ошибка: HTTP $HTTP_CODE"
        echo "   - Ответ: $(echo "$BODY" | head -c 200)"
    fi
done

echo ""
echo "=== ТЕСТ 3: ПРОВЕРКА С КЛИЕНТСКИМИ СЕРТИФИКАТАМИ ==="
CERT_FILE="/opt/vault/certs/grafana-client.crt"
KEY_FILE="/opt/vault/certs/grafana-client.key"

if [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]]; then
    echo "✅ Клиентские сертификаты найдены"
    
    for url in "${URLS[@]}"; do
        echo -n "  $url с сертификатами: "
        RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
            --cert "$CERT_FILE" \
            --key "$KEY_FILE" \
            -u "${USER}:${PASS}" \
            "${url}/api/health" 2>&1)
        HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
        
        if [[ "$HTTP_CODE" == "200" ]]; then
            echo "✅ HTTP $HTTP_CODE"
        else
            echo "❌ HTTP $HTTP_CODE"
        fi
    done
else
    echo "⚠️  Клиентские сертификаты не найдены"
fi

echo ""
echo "=== ВЫВОДЫ И РЕКОМЕНДАЦИИ ==="
echo "1. Если localhost работает, а доменное имя нет - проблема в SSL/доменном имени"
echo "2. HTTP 400 означает неправильный запрос - проверьте:"
echo "   - Формат JSON в payload"
echo "   - Content-Type заголовок"
echo "   - Кодировку символов"
echo "   - Поддерживаемые роли (Admin vs admin)"
echo "3. Попробуйте использовать localhost вместо доменного имени"
echo "4. Проверьте версию Grafana API (возможно изменился формат запроса)"





