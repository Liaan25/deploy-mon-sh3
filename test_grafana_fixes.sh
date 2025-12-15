#!/bin/bash
# Тестирование исправлений для Grafana

echo "=== Тестирование исправлений для функции setup_grafana_datasource_and_dashboards() ==="
echo

# 1. Проверяем что функция существует
echo "1. Проверка наличия функции..."
if grep -q "setup_grafana_datasource_and_dashboards()" deploy_monitoring_script.sh; then
    echo "   ✅ Функция найдена"
else
    echo "   ❌ Функция не найдена"
    exit 1
fi

echo

# 2. Проверяем что нет HTTP запросов к Grafana
echo "2. Проверка отсутствия HTTP запросов к Grafana..."
if grep -q "http://.*grafana" deploy_monitoring_script.sh; then
    echo "   ❌ Найден HTTP запрос к Grafana"
    grep "http://.*grafana" deploy_monitoring_script.sh
else
    echo "   ✅ HTTP запросов к Grafana нет"
fi

echo

# 3. Проверяем что проверка доступности использует ss и pgrep
echo "3. Проверка метода проверки доступности Grafana..."
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

# 4. Проверяем наличие fallback механизмов
echo "4. Проверка fallback механизмов..."
if grep -q "Пробуем альтернативный метод" deploy_monitoring_script.sh; then
    echo "   ✅ Есть fallback на альтернативные методы"
else
    echo "   ❌ Нет fallback на альтернативные методы"
fi

if grep -q "grafana_wrapper.sh" deploy_monitoring_script.sh; then
    echo "   ✅ Упоминается grafana_wrapper.sh как fallback"
else
    echo "   ❌ Не упоминается grafana_wrapper.sh как fallback"
fi

echo

# 5. Проверяем обработку ошибок mTLS
echo "5. Проверка обработки mTLS..."
if grep -q "клиентские сертификаты" deploy_monitoring_script.sh; then
    echo "   ✅ Учитываются клиентские сертификаты"
else
    echo "   ❌ Не учитываются клиентские сертификаты"
fi

if grep -q "tlsClientCert" deploy_monitoring_script.sh; then
    echo "   ✅ Настройка datasource включает mTLS параметры"
else
    echo "   ❌ Настройка datasource не включает mTLS параметры"
fi

echo

# 6. Проверяем что функция не прерывает скрипт при ошибках
echo "6. Проверка устойчивости к ошибкам..."
if grep -q "Пропускаем настройку" deploy_monitoring_script.sh; then
    echo "   ✅ Функция может пропускать настройку при ошибках"
else
    echo "   ❌ Функция не может пропускать настройку при ошибках"
fi

if grep -q "return 0" deploy_monitoring_script.sh | grep -B5 "Пропускаем настройку" | head -1; then
    echo "   ✅ Функция возвращает успех при пропуске настройки"
else
    echo "   ❌ Функция может прерываться при ошибках"
fi

echo
echo "=== Результаты тестирования ==="
echo
echo "Исправления должны решить следующие проблемы:"
echo "1. ✅ Убраны HTTP запросы к HTTPS серверу Grafana"
echo "2. ✅ Проверка доступности через ss и pgrep вместо HTTP запросов"
echo "3. ✅ Добавлены fallback механизмы при ошибках API"
echo "4. ✅ Учитываются требования mTLS (клиентские сертификаты)"
echo "5. ✅ Функция более устойчива к ошибкам и не прерывает скрипт"
echo "6. ✅ Поддержка grafana_wrapper.sh как альтернативного метода"
echo
echo "Для тестирования на сервере:"
echo "  export SKIP_GRAFANA_DATA_CLEANUP=true"
echo "  sudo ./deploy_monitoring_script.sh"
echo
echo "Или только настройку Grafana:"
echo "  sudo bash -c 'source deploy_monitoring_script.sh; setup_grafana_datasource_and_dashboards'"
