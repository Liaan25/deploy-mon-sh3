#!/bin/bash
# Тест исправлений для Grafana

echo "=== ТЕСТ ИСПРАВЛЕНИЙ ДЛЯ GRAFANA ==="
echo

# 1. Проверка процесса
echo "1. Проверка поиска процесса grafana:"
echo

echo "   Поиск 'grafana-server':"
if pgrep -f "grafana-server" >/dev/null; then
    echo "   ✅ Найден процесс grafana-server"
else
    echo "   ❌ Процесс grafana-server не найден"
fi

echo
echo "   Поиск 'grafana':"
if pgrep -f "grafana" >/dev/null; then
    echo "   ✅ Найден процесс grafana"
    echo "   Детали:"
    ps aux | grep grafana | grep -v grep
else
    echo "   ❌ Процесс grafana не найден"
fi

echo
echo "2. Проверка порта 3000:"
if ss -tln | grep -q ":3000 "; then
    echo "   ✅ Порт 3000 слушается"
    ss -tlnp | grep ":3000"
else
    echo "   ❌ Порт 3000 не слушается"
fi

echo
echo "3. Проверка user-юнита:"
echo "   Команда проверки user-юнита:"
echo "   sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR=\"/run/user/\$(id -u CI10742292-lnx-mon_sys)\" systemctl --user status monitoring-grafana.service"

echo
echo "4. Проверка исправлений в скрипте:"
echo

# Проверяем исправления в deploy_monitoring_script.sh
if [[ -f "deploy_monitoring_script.sh" ]]; then
    echo "   Проверка функции setup_grafana_datasource_and_dashboards:"
    
    # Ищем старую проверку
    if grep -q "pgrep -f \"grafana-server\"" deploy_monitoring_script.sh; then
        echo "   ❌ Найдена старая проверка 'grafana-server'"
    else
        echo "   ✅ Старая проверка 'grafana-server' не найдена"
    fi
    
    # Ищем новую проверку
    if grep -q "pgrep -f \"grafana\"" deploy_monitoring_script.sh; then
        echo "   ✅ Найдена новая проверка 'grafana'"
    else
        echo "   ❌ Новая проверка 'grafana' не найдена"
    fi
    
    echo
    echo "   Проверка функции check_grafana_availability:"
    if grep -q "print_info \"Проверка процесса grafana\"" deploy_monitoring_script.sh; then
        echo "   ✅ Добавлено логирование проверки процесса"
    else
        echo "   ❌ Нет логирования проверки процесса"
    fi
else
    echo "   ❌ Файл deploy_monitoring_script.sh не найден"
fi

echo
echo "=== РЕКОМЕНДАЦИИ ==="
echo
echo "1. Запустите обновленный скрипт:"
echo "   sudo ./deploy_monitoring_script.sh"
echo
echo "2. Если проблема сохраняется, проверьте:"
echo "   - Что функция check_grafana_availability() возвращает успех"
echo "   - Что процесс действительно называется 'grafana' (а не 'grafana-server')"
echo "   - Логи в реальном времени: sudo journalctl -f"
echo
echo "3. Для принудительного обхода проверки (временное решение):"
echo "   export SKIP_GRAFANA_PROCESS_CHECK=true"
echo "   sudo ./deploy_monitoring_script.sh"

echo
echo "=== ТЕСТ ЗАВЕРШЕН ==="
