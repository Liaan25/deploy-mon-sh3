#!/bin/bash
# Проверка структуры файла с учетными данными

echo "=== ПРОВЕРКА СТРУКТУРЫ ФАЙЛА С УЧЕТНЫМИ ДАННЫМИ ==="

CRED_FILE="/opt/vault/conf/data_sec.json"

if [[ ! -f "$CRED_FILE" ]]; then
    echo "❌ Файл $CRED_FILE не найден"
    exit 1
fi

echo "✅ Файл существует"
echo "Размер файла: $(stat -c%s "$CRED_FILE" 2>/dev/null || wc -c < "$CRED_FILE") байт"

echo ""
echo "=== СОДЕРЖАНИЕ ФАЙЛА (первые 500 символов) ==="
head -c 500 "$CRED_FILE"
echo -e "\n..."

echo ""
echo "=== ПОЛНАЯ СТРУКТУРА JSON ==="
if command -v jq >/dev/null 2>&1; then
    jq '.' "$CRED_FILE" 2>/dev/null || {
        echo "❌ Невалидный JSON"
        echo "Сырое содержимое:"
        cat "$CRED_FILE"
    }
else
    echo "⚠️  jq не установлен, показываем сырое содержимое:"
    cat "$CRED_FILE"
fi

echo ""
echo "=== ПОИСК КЛЮЧЕЙ GRAFANA ==="
if command -v jq >/dev/null 2>&1; then
    echo "Все ключи в JSON:"
    jq 'keys' "$CRED_FILE" 2>/dev/null || echo "Не удалось получить ключи"
    
    echo ""
    echo "Поиск grafana_web:"
    jq '.grafana_web' "$CRED_FILE" 2>/dev/null || echo "Ключ grafana_web не найден"
    
    echo ""
    echo "Поиск grafana:"
    jq '.grafana' "$CRED_FILE" 2>/dev/null || echo "Ключ grafana не найден"
    
    echo ""
    echo "Поиск учетных данных по паттерну:"
    jq '.[] | select(type=="object") | with_entries(select(.key | test("user|pass|login|password|cred"; "i")))' "$CRED_FILE" 2>/dev/null || echo "Не найдено объектов с учетными данными"
else
    echo "Поиск строк с grafana:"
    grep -i "grafana" "$CRED_FILE" || echo "Не найдено"
    
    echo ""
    echo "Поиск строк с user/pass:"
    grep -i -E "user|pass|login|password" "$CRED_FILE" || echo "Не найдено"
fi

echo ""
echo "=== АЛЬТЕРНАТИВНЫЕ МЕСТОПОЛОЖЕНИЯ ФАЙЛОВ ==="
ALTERNATIVE_PATHS=(
    "/etc/grafana/grafana.ini"
    "/home/CI10742292-lnx-mon_sys/.config/grafana/credentials.json"
    "/opt/monitoring/credentials.json"
    "/tmp/grafana_credentials.json"
)

for path in "${ALTERNATIVE_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        echo "✅ Найден файл: $path"
        echo "   Размер: $(stat -c%s "$path" 2>/dev/null || wc -c < "$path") байт"
        if [[ "$path" == *.ini ]]; then
            echo "   Содержимое (первые 5 строк):"
            head -5 "$path"
        elif [[ "$path" == *.json ]]; then
            echo "   Это JSON файл"
        fi
    else
        echo "❌ Не найден: $path"
    fi
done

echo ""
echo "=== ПРОВЕРКА ДОСТУПНОСТИ GRAFANA БЕЗ АУТЕНТИФИКАЦИИ ==="
echo "Проверка health endpoint без аутентификации:"
curl -k -s -o /dev/null -w "HTTP код: %{http_code}\n" "http://localhost:3000/api/health" || echo "Ошибка curl"

echo ""
echo "Проверка login page:"
curl -k -s -o /dev/null -w "HTTP код: %{http_code}\n" "http://localhost:3000/login" || echo "Ошибка curl"

echo ""
echo "=== РЕКОМЕНДАЦИИ ==="
echo "1. Проверьте правильность пути к файлу с учетными данными"
echo "2. Убедитесь что файл содержит правильную структуру JSON с ключами grafana_web.user и grafana_web.pass"
echo "3. Если файл не содержит учетные данные, найдите правильный файл или создайте его"
echo "4. Проверьте права доступа к файлу: ls -la $CRED_FILE"
