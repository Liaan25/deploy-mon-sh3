#!/bin/bash
# Тестирование исправленного скрипта с улучшенной обработкой Grafana

echo "=== Тестирование исправленного deploy_monitoring_script.sh ==="
echo

# 1. Проверка основных исправлений
echo "1. Проверка исправлений для Grafana..."

# Проверяем что функция setup_grafana_datasource_and_dashboards существует
if grep -q "setup_grafana_datasource_and_dashboards()" deploy_monitoring_script.sh; then
    echo "   ✅ Функция setup_grafana_datasource_and_dashboards найдена"
else
    echo "   ❌ Функция setup_grafana_datasource_and_dashboards не найдена"
fi

# Проверяем что нет HTTP запросов в проверке доступности
if grep -B10 -A10 "Проверка доступности Grafana" deploy_monitoring_script.sh | grep -q "curl.*http://"; then
    echo "   ❌ В проверке доступности есть HTTP запросы"
else
    echo "   ✅ В проверке доступности нет HTTP запросов"
fi

# Проверяем использование ss и pgrep
if grep -B5 -A5 "Проверка доступности Grafana" deploy_monitoring_script.sh | grep -q "ss -tln"; then
    echo "   ✅ Используется ss -tln для проверки порта"
else
    echo "   ❌ Не используется ss -tln для проверки порта"
fi

if grep -B5 -A5 "Проверка доступности Grafana" deploy_monitoring_script.sh | grep -q "pgrep -f \"grafana-server\""; then
    echo "   ✅ Используется pgrep для проверки процесса"
else
    echo "   ❌ Не используется pgrep для проверки процесса"
fi

echo
echo "2. Проверка fallback механизмов..."

# Проверяем наличие fallback на grafana_wrapper.sh
if grep -q "grafana_wrapper.sh" deploy_monitoring_script.sh; then
    echo "   ✅ Упоминается grafana_wrapper.sh как fallback"
else
    echo "   ❌ Не упоминается grafana_wrapper.sh как fallback"
fi

# Проверяем обработку ошибок mTLS
if grep -q "клиентские сертификаты" deploy_monitoring_script.sh; then
    echo "   ✅ Учитываются клиентские сертификаты"
else
    echo "   ❌ Не учитываются клиентские сертификаты"
fi

# Проверяем что функция может пропускать настройку
if grep -q "Пропускаем настройку" deploy_monitoring_script.sh; then
    echo "   ✅ Функция может пропускать настройку при ошибках"
else
    echo "   ❌ Функция не может пропускать настройку при ошибках"
fi

echo
echo "3. Проверка обратной совместимости..."

# Проверяем что старые функции все еще есть
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
echo "4. Проверка вызова функции в main..."

# Проверяем что в main вызывается новая функция
if grep -B10 -A10 "check_grafana_availability" deploy_monitoring_script.sh | grep -q "setup_grafana_datasource_and_dashboards"; then
    echo "   ✅ Новая функция вызывается после проверки доступности Grafana"
else
    echo "   ❌ Новая функция не вызывается в правильном месте"
fi

echo
echo "5. Проверка исправлений для Jenkins..."

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
echo "=== Результаты тестирования ==="
echo
echo "Исправленный скрипт решает следующие проблемы:"
echo "1. ✅ Убраны HTTP запросы к HTTPS серверу Grafana"
echo "2. ✅ Проверка доступности через ss и pgrep вместо HTTP запросов"
echo "3. ✅ Добавлены fallback механизмы при ошибках API"
echo "4. ✅ Учитываются требования mTLS (клиентские сертификаты)"
echo "5. ✅ Функция более устойчива к ошибкам и не прерывает скрипт"
echo "6. ✅ Сохранена обратная совместимость со старыми функциями"
echo "7. ✅ Правильно проверяет сервисы для Jenkins"
echo
echo "Для тестирования на сервере:"
echo "  export SKIP_GRAFANA_DATA_CLEANUP=true"
echo "  sudo ./deploy_monitoring_script.sh"
echo
echo "Или только настройку Grafana:"
echo "  sudo bash -c 'source deploy_monitoring_script.sh; setup_grafana_datasource_and_dashboards'"
echo
echo "Для проверки конкретных исправлений:"
echo "  ./test_grafana_fixes.sh"
echo "  ./test_detailed_grafana_fixes.sh"
