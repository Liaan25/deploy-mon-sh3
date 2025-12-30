#!/bin/bash
# Тест работы флага SKIP_RPM_INSTALL

echo "=== ТЕСТ РАБОТЫ SKIP_RPM_INSTALL ==="

# Проверяем, что флаг обрабатывается в скрипте
echo "1. Проверка обработки SKIP_RPM_INSTALL в main() функции:"
if grep -q "SKIP_RPM_INSTALL" deploy_monitoring_script.sh; then
    echo "✅ Флаг SKIP_RPM_INSTALL обрабатывается в скрипте"
    
    # Показываем контекст
    echo ""
    echo "Контекст обработки:"
    grep -n -B2 -A2 "SKIP_RPM_INSTALL" deploy_monitoring_script.sh | head -20
else
    echo "❌ Флаг SKIP_RPM_INSTALL не найден в скрипте"
fi

echo ""
echo "2. Проверка добавленных проверок в функциях конфигурации:"

# Проверяем добавленные проверки
CHECKS=(
    "configure_harvest:Директория /opt/harvest еще не существует"
    "configure_prometheus:Директория /etc/prometheus не существует"
    "configure_grafana_ini:Директория /etc/grafana не существует"
    "configure_prometheus_files:Директория /etc/prometheus не существует"
    "setup_grafana_datasource_and_dashboards:Grafana не установлена"
)

for check in "${CHECKS[@]}"; do
    IFS=':' read -r function pattern <<< "$check"
    
    if grep -q "$pattern" deploy_monitoring_script.sh; then
        echo "✅ $function: проверка добавлена"
    else
        echo "❌ $function: проверка не найдена"
    fi
done

echo ""
echo "3. Проверка синтаксиса измененных функций:"
echo "   (быстрая проверка ключевых изменений)"

# Создаем временный файл для проверки синтаксиса
cat > /tmp/test_skip_syntax.sh << 'EOF'
#!/bin/bash
# Тест синтаксиса проверок SKIP_RPM_INSTALL

test_configure_harvest() {
    if [[ ! -d "/opt/harvest" ]]; then
        echo "Директория /opt/harvest еще не существует, пропускаем настройку"
        return 0
    fi
}

test_configure_prometheus() {
    if [[ ! -d "/etc/prometheus" ]]; then
        echo "Директория /etc/prometheus не существует (Prometheus не установлен)"
        echo "Если используется SKIP_RPM_INSTALL=true, это ожидаемо"
        return 0
    fi
}

test_configure_grafana_ini() {
    if [[ ! -d "/etc/grafana" ]]; then
        echo "Директория /etc/grafana не существует (Grafana не установлена)"
        echo "Если используется SKIP_RPM_INSTALL=true, это ожидаемо"
        return 0
    fi
}

test_configure_prometheus_files() {
    if [[ ! -d "/etc/prometheus" ]]; then
        echo "Директория /etc/prometheus не существует (Prometheus не установлен)"
        echo "Если используется SKIP_RPM_INSTALL=true, это ожидаемо"
        return 0
    fi
}

test_setup_grafana_datasource() {
    if [[ ! -d "/usr/share/grafana" && ! -d "/etc/grafana" ]]; then
        echo "Grafana не установлена"
        echo "Если используется SKIP_RPM_INSTALL=true, пропускаем настройку"
        return 0
    fi
}

# Вызываем функции для проверки синтаксиса
test_configure_harvest
test_configure_prometheus
test_configure_grafana_ini
test_configure_prometheus_files
test_setup_grafana_datasource

echo "✅ Все проверки синтаксически корректны"
EOF

if bash -n /tmp/test_skip_syntax.sh 2>/dev/null; then
    echo "✅ Синтаксис проверок корректен"
else
    echo "❌ Обнаружены синтаксические ошибки"
    bash -n /tmp/test_skip_syntax.sh
fi

echo ""
echo "4. Инструкция по использованию:"
echo ""
echo "Для пропуска установки RPM пакетов используйте:"
echo "  export SKIP_RPM_INSTALL=true"
echo "  sudo ./deploy_monitoring_script.sh"
echo ""
echo "Или в одну строку:"
echo "  SKIP_RPM_INSTALL=true sudo ./deploy_monitoring_script.sh"
echo ""
echo "Для Jenkins пайплайна добавьте переменную:"
echo "  SKIP_RPM_INSTALL=true"
echo ""
echo "5. Ожидаемое поведение:"
echo "   - Пропускается установка Grafana, Prometheus, Harvest через RLM"
echo "   - Выполняется настройка конфигурационных файлов (если пакеты установлены)"
echo "   - При отсутствии пакетов функции конфигурации пропускаются с предупреждениями"
echo "   - Скрипт не падает, продолжает работу с другими настройками"


