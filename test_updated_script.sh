#!/bin/bash
# Тестирование обновленного скрипта

echo "=== Тестирование обновленного deploy_monitoring_script.sh ==="
echo

# 1. Проверка синтаксиса
echo "1. Проверка синтаксиса..."
if bash -n deploy_monitoring_script.sh; then
    echo "   ✅ Синтаксис правильный"
else
    echo "   ❌ Ошибка синтаксиса"
    exit 1
fi

echo
echo "2. Проверка наличия новых функций..."

# Проверяем наличие новой функции
if grep -q "setup_grafana_datasource_and_dashboards()" deploy_monitoring_script.sh; then
    echo "   ✅ Функция setup_grafana_datasource_and_dashboards найдена"
else
    echo "   ❌ Функция setup_grafana_datasource_and_dashboards не найдена"
fi

# Проверяем что старые функции все еще есть (для обратной совместимости)
if grep -q "ensure_grafana_token()" deploy_monitoring_script.sh; then
    echo "   ✅ Функция ensure_grafana_token найдена (для обратной совместимости)"
else
    echo "   ⚠️ Функция ensure_grafana_token не найдена"
fi

if grep -q "configure_grafana_datasource()" deploy_monitoring_script.sh; then
    echo "   ✅ Функция configure_grafana_datasource найдена (для обратной совместимости)"
else
    echo "   ⚠️ Функция configure_grafana_datasource не найдена"
fi

echo
echo "3. Проверка вызова новой функции в main..."

# Проверяем что в main вызывается новая функция
if grep -A5 -B5 "setup_grafana_datasource_and_dashboards" deploy_monitoring_script.sh | grep -q "main"; then
    echo "   ✅ Новая функция вызывается в main"
else
    # Проверяем конкретно в блоке if
    if grep -B10 -A10 "check_grafana_availability" deploy_monitoring_script.sh | grep -q "setup_grafana_datasource_and_dashboards"; then
        echo "   ✅ Новая функция вызывается после проверки доступности Grafana"
    else
        echo "   ❌ Новая функция не вызывается в правильном месте"
    fi
fi

echo
echo "4. Проверка исправлений для Jenkins..."

# Проверяем исправленную функцию verify_installation
if grep -q "check_system_services()" deploy_monitoring_script.sh; then
    echo "   ✅ Функция check_system_services найдена"
else
    echo "   ❌ Функция check_system_services не найдена"
fi

# Проверяем что verify_installation проверяет user-юниты
if grep -B5 -A10 "verify_installation()" deploy_monitoring_script.sh | grep -q "monitoring-prometheus.service"; then
    echo "   ✅ verify_installation проверяет user-юниты"
else
    echo "   ❌ verify_installation не проверяет user-юниты"
fi

echo
echo "5. Проверка исправлений прав Grafana..."

# Проверяем что функция adjust_grafana_permissions_for_mon_sys настраивает provisioning
if grep -B5 -A10 "adjust_grafana_permissions_for_mon_sys()" deploy_monitoring_script.sh | grep -q "grafana_provisioning_dir"; then
    echo "   ✅ Права на provisioning директорию настраиваются"
else
    echo "   ❌ Права на provisioning директорию не настраиваются"
fi

echo
echo "=== Результаты тестирования ==="
echo
echo "Обновленный скрипт должен:"
echo "1. ✅ Иметь правильный синтаксис"
echo "2. ✅ Содержать новую функцию setup_grafana_datasource_and_dashboards"
echo "3. ✅ Вызывать новую функцию в main"
echo "4. ✅ Правильно проверять сервисы для Jenkins"
echo "5. ✅ Настраивать права на provisioning директорию"
echo
echo "Для полного тестирования запустите на сервере:"
echo "  export SKIP_GRAFANA_DATA_CLEANUP=true"
echo "  sudo ./deploy_monitoring_script.sh"
echo
echo "Или только настройку Grafana:"
echo "  sudo bash -c 'source deploy_monitoring_script.sh; setup_grafana_datasource_and_dashboards'"
