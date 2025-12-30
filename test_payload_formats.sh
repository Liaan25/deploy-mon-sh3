#!/bin/bash

# Тестирование разных форматов payload для создания сервисного аккаунта в Grafana

echo "=== ТЕСТИРОВАНИЕ ФОРМАТОВ PAYLOAD ДЛЯ GRAFANA API ==="
echo

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
echo

# URL для тестирования
URL="https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000"
TIMESTAMP=$(date +%s)
SA_NAME="test-payload-$TIMESTAMP"

echo "URL: $URL"
echo "Имя сервисного аккаунта: $SA_NAME"
echo

# Сначала проверяем доступность API
echo "=== ПРОВЕРКА ДОСТУПНОСТИ API ==="
health_response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
    -u "${USER}:${PASS}" \
    "${URL}/api/health" 2>&1)

health_code=$(echo "$health_response" | grep "HTTP_CODE:" | cut -d: -f2)
health_body=$(echo "$health_response" | grep -v "HTTP_CODE:")

if [[ "$health_code" == "200" ]]; then
    echo "✅ Health check успешен (HTTP $health_code)"
    echo "   Версия Grafana: $(echo "$health_body" | jq -r '.version // .Version // "неизвестна"')"
    echo "   Коммит: $(echo "$health_body" | jq -r '.commit // .Commit // "неизвестен"')"
    echo "   База данных: $(echo "$health_body" | jq -r '.database // .Database // "неизвестна"')"
else
    echo "❌ Health check не прошел (HTTP $health_code)"
    echo "   Ответ: $health_body"
    exit 1
fi

echo

# Проверяем версию API
echo "=== ПРОВЕРКА ВЕРСИИ API ==="
api_version_response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
    -u "${USER}:${PASS}" \
    "${URL}/api/health" 2>&1)

api_version_code=$(echo "$api_version_response" | grep "HTTP_CODE:" | cut -d: -f2)
api_version_body=$(echo "$api_version_response" | grep -v "HTTP_CODE:")

if [[ "$api_version_code" == "200" ]]; then
    echo "✅ API доступен"
    # Пробуем получить информацию о версии из разных полей
    version=$(echo "$api_version_body" | jq -r '.version // .Version // empty' 2>/dev/null || echo "")
    if [[ -n "$version" ]]; then
        echo "   Версия Grafana: $version"
        
        # Определяем мажорную версию
        major_version=$(echo "$version" | cut -d. -f1)
        echo "   Мажорная версия: $major_version"
        
        # Проверяем, какая версия API поддерживается
        if [[ "$major_version" -ge 10 ]]; then
            echo "   ✅ Используется Grafana 10+ (поддерживает новый API сервисных аккаунтов)"
        else
            echo "   ⚠️  Используется Grafana <10 (возможно устаревший API)"
        fi
    else
        echo "   ⚠️  Не удалось определить версию Grafana"
    fi
else
    echo "❌ Не удалось проверить версию API (HTTP $api_version_code)"
fi

echo

# Тестируем разные форматы payload
echo "=== ТЕСТИРОВАНИЕ РАЗНЫХ ФОРМАТОВ PAYLOAD ==="
echo

# Формат 1: Текущий формат (с большой буквы Admin)
PAYLOAD1=$(jq -n --arg name "$SA_NAME" --arg role "Admin" '{name:$name, role:$role}')
echo "Формат 1 (Admin с большой буквы):"
echo "  Payload: $PAYLOAD1"
response1=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -u "${USER}:${PASS}" \
    -d "$PAYLOAD1" \
    "${URL}/api/serviceaccounts" 2>&1)
code1=$(echo "$response1" | grep "HTTP_CODE:" | cut -d: -f2)
body1=$(echo "$response1" | grep -v "HTTP_CODE:")
echo "  Результат: HTTP $code1"
if [[ "$code1" == "400" ]]; then
    echo "  Тело ошибки: $body1"
fi
echo

# Формат 2: С маленькой буквы admin
PAYLOAD2=$(jq -n --arg name "$SA_NAME" --arg role "admin" '{name:$name, role:$role}')
echo "Формат 2 (admin с маленькой буквы):"
echo "  Payload: $PAYLOAD2"
response2=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -u "${USER}:${PASS}" \
    -d "$PAYLOAD2" \
    "${URL}/api/serviceaccounts" 2>&1)
code2=$(echo "$response2" | grep "HTTP_CODE:" | cut -d: -f2)
body2=$(echo "$response2" | grep -v "HTTP_CODE:")
echo "  Результат: HTTP $code2"
if [[ "$code2" == "400" ]]; then
    echo "  Тело ошибки: $body2"
fi
echo

# Формат 3: Без role (только name)
PAYLOAD3=$(jq -n --arg name "$SA_NAME" '{name:$name}')
echo "Формат 3 (без role):"
echo "  Payload: $PAYLOAD3"
response3=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -u "${USER}:${PASS}" \
    -d "$PAYLOAD3" \
    "${URL}/api/serviceaccounts" 2>&1)
code3=$(echo "$response3" | grep "HTTP_CODE:" | cut -d: -f2)
body3=$(echo "$response3" | grep -v "HTTP_CODE:")
echo "  Результат: HTTP $code3"
if [[ "$code3" == "400" ]]; then
    echo "  Тело ошибки: $body3"
fi
echo

# Формат 4: С role в виде числа (2 = Admin)
PAYLOAD4=$(jq -n --arg name "$SA_NAME" '{name:$name, role:2}')
echo "Формат 4 (role как число 2):"
echo "  Payload: $PAYLOAD4"
response4=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -u "${USER}:${PASS}" \
    -d "$PAYLOAD4" \
    "${URL}/api/serviceaccounts" 2>&1)
code4=$(echo "$response4" | grep "HTTP_CODE:" | cut -d: -f2)
body4=$(echo "$response4" | grep -v "HTTP_CODE:")
echo "  Результат: HTTP $code4"
if [[ "$code4" == "400" ]]; then
    echo "  Тело ошибки: $body4"
fi
echo

# Формат 5: С role в виде строки "Editor"
PAYLOAD5=$(jq -n --arg name "$SA_NAME" --arg role "Editor" '{name:$name, role:$role}')
echo "Формат 5 (role=Editor):"
echo "  Payload: $PAYLOAD5"
response5=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -u "${USER}:${PASS}" \
    -d "$PAYLOAD5" \
    "${URL}/api/serviceaccounts" 2>&1)
code5=$(echo "$response5" | grep "HTTP_CODE:" | cut -d: -f2)
body5=$(echo "$response5" | grep -v "HTTP_CODE:")
echo "  Результат: HTTP $code5"
if [[ "$code5" == "400" ]]; then
    echo "  Тело ошибки: $body5"
fi
echo

# Формат 6: С isDisabled=false
PAYLOAD6=$(jq -n --arg name "$SA_NAME" --arg role "Admin" '{name:$name, role:$role, isDisabled:false}')
echo "Формат 6 (с isDisabled:false):"
echo "  Payload: $PAYLOAD6"
response6=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -u "${USER}:${PASS}" \
    -d "$PAYLOAD6" \
    "${URL}/api/serviceaccounts" 2>&1)
code6=$(echo "$response6" | grep "HTTP_CODE:" | cut -d: -f2)
body6=$(echo "$response6" | grep -v "HTTP_CODE:")
echo "  Результат: HTTP $code6"
if [[ "$code6" == "400" ]]; then
    echo "  Тело ошибки: $body6"
fi
echo

# Формат 7: Проверяем существующие сервисные аккаунты
echo "=== ПРОВЕРКА СУЩЕСТВУЮЩИХ СЕРВИСНЫХ АККАУНТОВ ==="
existing_response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
    -u "${USER}:${PASS}" \
    "${URL}/api/serviceaccounts?perpage=5" 2>&1)
existing_code=$(echo "$existing_response" | grep "HTTP_CODE:" | cut -d: -f2)
existing_body=$(echo "$existing_response" | grep -v "HTTP_CODE:")

if [[ "$existing_code" == "200" ]]; then
    echo "✅ Существующие сервисные аккаунты:"
    echo "$existing_body" | jq -r '.serviceAccounts[] | "  - \(.name) (ID: \(.id), роль: \(.role))"' 2>/dev/null || echo "  Не удалось распарсить ответ"
else
    echo "❌ Не удалось получить список сервисных аккаунтов (HTTP $existing_code)"
    echo "  Ответ: $existing_body"
fi

echo

# Формат 8: Проверяем документацию API
echo "=== ПРОВЕРКА ДОКУМЕНТАЦИИ API ==="
echo "Пробуем получить OpenAPI спецификацию..."
swagger_response=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
    -u "${USER}:${PASS}" \
    "${URL}/api/swagger.json" 2>&1)
swagger_code=$(echo "$swagger_response" | grep "HTTP_CODE:" | cut -d: -f2)

if [[ "$swagger_code" == "200" ]]; then
    echo "✅ OpenAPI спецификация доступна"
    # Ищем endpoint для создания сервисных аккаунтов
    echo "  Ищем endpoint /api/serviceaccounts в спецификации..."
    if echo "$swagger_response" | grep -q "/api/serviceaccounts"; then
        echo "  ✅ Endpoint найден в спецификации"
    else
        echo "  ⚠️  Endpoint не найден в спецификации"
    fi
else
    echo "❌ OpenAPI спецификация недоступна (HTTP $swagger_code)"
fi

echo

# Анализ результатов
echo "=== АНАЛИЗ РЕЗУЛЬТАТОВ ==="
echo "Проверенные форматы payload:"
echo "1. {name:..., role:\"Admin\"} - HTTP $code1"
echo "2. {name:..., role:\"admin\"} - HTTP $code2"
echo "3. {name:...} - HTTP $code3"
echo "4. {name:..., role:2} - HTTP $code4"
echo "5. {name:..., role:\"Editor\"} - HTTP $code5"
echo "6. {name:..., role:\"Admin\", isDisabled:false} - HTTP $code6"
echo

# Рекомендации
echo "=== РЕКОМЕНДАЦИИ ==="
if [[ "$code1" == "200" || "$code1" == "201" ]]; then
    echo "✅ Текущий формат payload работает правильно"
    echo "   Используйте: {name:\"имя\", role:\"Admin\"}"
elif [[ "$code2" == "200" || "$code2" == "201" ]]; then
    echo "✅ Формат с role=\"admin\" работает"
    echo "   Измените payload на: {name:\"имя\", role:\"admin\"}"
elif [[ "$code3" == "200" || "$code3" == "201" ]]; then
    echo "✅ Формат без role работает"
    echo "   Измените payload на: {name:\"имя\"}"
elif [[ "$code4" == "200" || "$code4" == "201" ]]; then
    echo "✅ Формат с role как число работает"
    echo "   Измените payload на: {name:\"имя\", role:2}"
elif [[ "$code5" == "200" || "$code5" == "201" ]]; then
    echo "✅ Формат с role=\"Editor\" работает"
    echo "   Измените payload на: {name:\"имя\", role:\"Editor\"}"
elif [[ "$code6" == "200" || "$code6" == "201" ]]; then
    echo "✅ Формат с isDisabled работает"
    echo "   Измените payload на: {name:\"имя\", role:\"Admin\", isDisabled:false}"
else
    echo "❌ Ни один из форматов не работает"
    echo "   Возможные причины:"
    echo "   1. Проблема с правами доступа"
    echo "   2. Неправильный endpoint"
    echo "   3. Проблема с версией Grafana API"
    echo "   4. Сервисные аккаунты отключены в настройках Grafana"
    echo ""
    echo "   Попробуйте:"
    echo "   1. Проверить настройки Grafana (Service Accounts)"
    echo "   2. Использовать USE_GRAFANA_LOCALHOST=true"
    echo "   3. Проверить логи Grafana на сервере"
fi

echo
echo "=== КОМАНДА ДЛЯ БЫСТРОГО ИСПРАВЛЕНИЯ ==="
echo "Если нужно изменить формат payload в основном скрипте:"
echo "sed -i 's/--arg role \"Admin\"/--arg role \"admin\"/' deploy_monitoring_script.sh"
echo
echo "Или использовать переменную окружения:"
echo "export USE_GRAFANA_LOCALHOST=true"
echo "sudo ./deploy_monitoring_script.sh"
