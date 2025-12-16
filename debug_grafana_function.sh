#!/bin/bash
# Отладка функции setup_grafana_datasource_and_dashboards
# Запуск: sudo ./debug_grafana_function.sh

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

echo -e "${BLUE}=== ОТЛАДКА ФУНКЦИИ setup_grafana_datasource_and_dashboards ===${NC}"

# Проверяем наличие основного скрипта
if [[ ! -f "deploy_monitoring_script.sh" ]]; then
    print_error "Файл deploy_monitoring_script.sh не найден"
    exit 1
fi

# 1. Извлекаем функцию для анализа
print_info "1. Анализ функции setup_grafana_datasource_and_dashboards..."

# Находим начало и конец функции
START_LINE=$(grep -n "setup_grafana_datasource_and_dashboards()" deploy_monitoring_script.sh | head -1 | cut -d: -f1)
if [[ -z "$START_LINE" ]]; then
    print_error "Функция не найдена в скрипте"
    exit 1
fi

# Ищем закрывающую скобку функции
END_LINE=$(awk -v start="$START_LINE" 'NR > start && /^[[:space:]]*}/ {print NR; exit}' deploy_monitoring_script.sh)

if [[ -z "$END_LINE" ]]; then
    print_error "Не найдена закрывающая скобка функции"
    exit 1
fi

print_info "Функция находится на строках: $START_LINE - $END_LINE"

# 2. Анализируем структуру функции
print_info "\n2. Структура функции:"

# Считаем вложенные функции
NESTED_FUNCTIONS=$(sed -n "${START_LINE},${END_LINE}p" deploy_monitoring_script.sh | grep -c "() {")
print_info "Количество вложенных функций: $NESTED_FUNCTIONS"

# Ищем вложенные функции
print_info "Вложенные функции:"
sed -n "${START_LINE},${END_LINE}p" deploy_monitoring_script.sh | grep -n "() {" | while read line; do
    echo "  $line"
done

# 3. Проверяем вызовы функций
print_info "\n3. Вызовы функций внутри:"
sed -n "${START_LINE},${END_LINE}p" deploy_monitoring_script.sh | grep -n "create_service_account_via_api\|create_token_via_api" | while read line; do
    echo "  $line"
done

# 4. Создаем тестовую среду
print_info "\n4. Создание тестовой среды..."

# Создаем временный файл с функцией
TEMP_SCRIPT="/tmp/test_grafana_function.sh"
cat > "$TEMP_SCRIPT" << 'EOF'
#!/bin/bash
# Тестовая среда для отладки

# Имитируем функции из основного скрипта
print_info() { echo "[INFO] $1"; }
print_success() { echo "[SUCCESS] $1"; }
print_warning() { echo "[WARNING] $1"; }
print_error() { echo "[ERROR] $1"; }
print_step() { echo "[STEP] $1"; }

ensure_working_directory() {
    echo "[INFO] ensure_working_directory called"
}

# Извлекаем функцию setup_grafana_datasource_and_dashboards
EOF

# Добавляем функцию в тестовый скрипт
sed -n "${START_LINE},${END_LINE}p" deploy_monitoring_script.sh >> "$TEMP_SCRIPT"

# Добавляем код для тестирования
cat >> "$TEMP_SCRIPT" << 'EOF'

# Тестовые переменные
export GRAFANA_PORT="3000"
export SERVER_DOMAIN="localhost"
export WRAPPERS_DIR="/opt/monitoring/wrappers"

# Создаем mock для ensure_grafana_token
ensure_grafana_token() {
    echo "[MOCK] ensure_grafana_token called"
    return 0
}

# Основной тест
echo "=== ТЕСТ ФУНКЦИИ setup_grafana_datasource_and_dashboards ==="
echo

# Вызываем функцию
if setup_grafana_datasource_and_dashboards; then
    echo "✅ Функция завершилась успешно"
else
    echo "❌ Функция завершилась с ошибкой, код: $?"
fi
EOF

chmod +x "$TEMP_SCRIPT"
print_info "Тестовый скрипт создан: $TEMP_SCRIPT"

# 5. Анализируем потенциальные проблемы
print_info "\n5. Поиск потенциальных проблем..."

# Проверяем return statements
print_info "Операторы return в функции:"
sed -n "${START_LINE},${END_LINE}p" deploy_monitoring_script.sh | grep -n "return " | while read line; do
    echo "  $line"
    
    # Анализируем условия return
    line_num=$(echo "$line" | cut -d: -f1)
    relative_line=$((line_num - START_LINE + 1))
    
    # Смотрим контекст
    context_start=$((relative_line - 2))
    context_end=$((relative_line + 2))
    if [[ $context_start -lt 1 ]]; then
        context_start=1
    fi
    
    echo "    Контекст (строки $context_start-$context_end):"
    sed -n "${START_LINE},${END_LINE}p" deploy_monitoring_script.sh | sed -n "${context_start},${context_end}p" | sed 's/^/      /'
done

# 6. Проверяем переменные
print_info "\n6. Используемые переменные:"

# Ищем объявления локальных переменных
print_info "Локальные переменные:"
sed -n "${START_LINE},${END_LINE}p" deploy_monitoring_script.sh | grep -n "local " | while read line; do
    echo "  $line"
done

# 7. Создаем упрощенный тест
print_info "\n7. Создание упрощенного теста..."

cat > "/tmp/simple_grafana_test.sh" << 'EOF'
#!/bin/bash
# Упрощенный тест API Grafana

echo "=== УПРОЩЕННЫЙ ТЕСТ ==="

# Базовые проверки
echo "1. Проверка порта 3000:"
if ss -tln | grep -q ":3000 "; then
    echo "   ✅ Порт 3000 слушается"
else
    echo "   ❌ Порт 3000 НЕ слушается"
fi

echo "2. Проверка процесса grafana-server:"
if pgrep -f "grafana-server" >/dev/null; then
    echo "   ✅ Процесс найден"
else
    echo "   ❌ Процесс не найден"
fi

# Проверка файла с учетными данными
CRED_FILE="/opt/vault/conf/data_sec.json"
echo "3. Проверка файла $CRED_FILE:"
if [[ -f "$CRED_FILE" ]]; then
    echo "   ✅ Файл существует"
    
    # Быстрая проверка JSON
    if jq empty "$CRED_FILE" 2>/dev/null; then
        echo "   ✅ JSON валиден"
        
        USER=$(jq -r '.grafana_web.user // empty' "$CRED_FILE" 2>/dev/null || echo "")
        PASS=$(jq -r '.grafana_web.pass // empty' "$CRED_FILE" 2>/dev/null || echo "")
        
        if [[ -n "$USER" && -n "$PASS" ]]; then
            echo "   ✅ Учетные данные получены"
            echo "   👤 Пользователь: $USER"
            
            # Быстрый тест API
            echo "4. Быстрый тест API:"
            RESPONSE=$(curl -k -s -o /dev/null -w "%{http_code}" \
                -u "${USER}:${PASS}" \
                "https://localhost:3000/api/health" 2>&1)
            
            if [[ "$RESPONSE" == "200" ]]; then
                echo "   ✅ API работает: HTTP 200"
            else
                echo "   ❌ API не работает: HTTP $RESPONSE"
                
                # Пробуем без аутентификации
                echo "5. Тест без аутентификации:"
                curl -k -s -o /dev/null -w "HTTP: %{http_code}\n" "https://localhost:3000"
            fi
        else
            echo "   ❌ Не удалось получить учетные данные"
        fi
    else
        echo "   ❌ JSON невалиден"
    fi
else
    echo "   ❌ Файл не найден"
fi

echo "=== ТЕСТ ЗАВЕРШЕН ==="
EOF

chmod +x "/tmp/simple_grafana_test.sh"
print_info "Упрощенный тест создан: /tmp/simple_grafana_test.sh"

# 8. Рекомендации по отладке
print_info "\n8. РЕКОМЕНДАЦИИ ПО ОТЛАДКЕ:"

echo "1. Запустите упрощенный тест:"
echo "   sudo /tmp/simple_grafana_test.sh"
echo
echo "2. Проверьте логи Grafana в реальном времени:"
echo "   sudo journalctl -u grafana-server -f"
echo
echo "3. Запустите функцию в изоляции:"
echo "   sudo bash -c 'source deploy_monitoring_script.sh; setup_grafana_datasource_and_dashboards'"
echo
echo "4. Добавьте отладочный вывод в функцию:"
echo "   а) Найдите функцию в deploy_monitoring_script.sh"
echo "   б) Добавьте 'set -x' в начало функции"
echo "   в) Добавьте 'echo \"DEBUG: ...\"' в ключевые места"
echo
echo "5. Проверьте конкретный API запрос:"
echo "   USER=\$(jq -r '.grafana_web.user' /opt/vault/conf/data_sec.json)"
echo "   PASS=\$(jq -r '.grafana_web.pass' /opt/vault/conf/data_sec.json)"
echo "   curl -k -v -u \"\${USER}:\${PASS}\" https://localhost:3000/api/serviceaccounts"

echo -e "\n${BLUE}=== ОТЛАДКА ЗАВЕРШЕНА ===${NC}"
echo "Созданы файлы для тестирования:"
echo "1. $TEMP_SCRIPT - тестовый скрипт с функцией"
echo "2. /tmp/simple_grafana_test.sh - упрощенный тест"
echo "3. diagnose_grafana.sh - комплексная диагностика"
echo "4. quick_grafana_api_test.sh - быстрый тест API"

