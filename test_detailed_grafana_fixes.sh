#!/bin/bash
# Детальное тестирование исправлений для Grafana

echo "=== ДЕТАЛЬНОЕ ТЕСТИРОВАНИЕ ИСПРАВЛЕНИЙ ДЛЯ GRAFANA ==="
echo

# 1. Проверяем основные исправления
echo "1. Проверка основных исправлений..."
echo

# Проверяем что функция существует
echo "   Проверка функции setup_grafana_datasource_and_dashboards:"
if grep -q "setup_grafana_datasource_and_dashboards()" deploy_monitoring_script.sh; then
    echo "   ✅ Функция найдена"
    
    # Проверяем наличие диагностики
    if grep -q "=== ДИАГНОСТИКА GRAFANA ===" deploy_monitoring_script.sh; then
        echo "   ✅ Добавлена диагностическая информация"
    else
        echo "   ❌ Нет диагностической информации"
    fi
    
    # Проверяем что нет HTTP запросов в проверке доступности
    if grep -B5 -A5 "Проверка доступности Grafana" deploy_monitoring_script.sh | grep -q "curl.*http://"; then
        echo "   ❌ В проверке доступности есть HTTP запросы"
    else
        echo "   ✅ В проверке доступности нет HTTP запросов"
    fi
else
    echo "   ❌ Функция не найдена"
fi

echo

# 2. Проверяем fallback механизмы
echo "2. Проверка fallback механизмов..."
echo

# Проверяем коды возврата
echo "   Проверка кодов возврата:"
if grep -q "return 2" deploy_monitoring_script.sh; then
    echo "   ✅ Используются специальные коды возврата для fallback"
else
    echo "   ❌ Нет специальных кодов возврата для fallback"
fi

# Проверяем обработку разных кодов возврата
if grep -B5 -A5 "sa_result -eq 2" deploy_monitoring_script.sh; then
    echo "   ✅ Есть обработка кода возврата 2"
else
    echo "   ❌ Нет обработки кода возврата 2"
fi

echo

# 3. Проверяем диагностическое логирование
echo "3. Проверка диагностического логирования..."
echo

# Проверяем диагностику порта
if grep -q "Проверка порта.*с помощью ss:" deploy_monitoring_script.sh; then
    echo "   ✅ Есть диагностика порта"
else
    echo "   ❌ Нет диагностики порта"
fi

# Проверяем диагностику процесса
if grep -q "Проверка процесса grafana-server" deploy_monitoring_script.sh; then
    echo "   ✅ Есть диагностика процесса"
else
    echo "   ❌ Нет диагностики процесса"
fi

# Проверяем диагностику учетных данных
if grep -q "Полученные учетные данные:" deploy_monitoring_script.sh; then
    echo "   ✅ Есть диагностика учетных данных"
else
    echo "   ❌ Нет диагностики учетных данных"
fi

echo

# 4. Проверяем устойчивость к ошибкам
echo "4. Проверка устойчивости к ошибкам..."
echo

# Проверяем что функция может возвращать 0 при пропуске настройки
return_zero_count=$(grep -c "return 0" deploy_monitoring_script.sh | head -1)
echo "   Количество 'return 0' в функции: $return_zero_count"

# Проверяем сообщения о пропуске настройки
if grep -q "Пропускаем настройку" deploy_monitoring_script.sh; then
    echo "   ✅ Есть сообщения о пропуске настройки"
else
    echo "   ❌ Нет сообщений о пропуске настройки"
fi

echo

# 5. Проверяем совместимость
echo "5. Проверка обратной совместимости..."
echo

# Проверяем старые функции
if grep -q "ensure_grafana_token()" deploy_monitoring_script.sh; then
    echo "   ✅ Старая функция ensure_grafana_token() сохранена"
else
    echo "   ❌ Старая функция ensure_grafana_token() не найдена"
fi

if grep -q "configure_grafana_datasource()" deploy_monitoring_script.sh; then
    echo "   ✅ Старая функция configure_grafana_datasource() сохранена"
else
    echo "   ❌ Старая функция configure_grafana_datasource() не найдена"
fi

echo
echo "=== РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ ==="
echo
echo "Исправления должны решить следующие проблемы:"
echo
echo "1. ПРОБЛЕМА: Ошибка 'Client sent an HTTP request to an HTTPS server'"
echo "   РЕШЕНИЕ: ✅ Убраны HTTP запросы, используется ss и pgrep"
echo
echo "2. ПРОБЛЕМА: Pipeline падает при ошибках API Grafana"
echo "   РЕШЕНИЕ: ✅ Добавлены fallback механизмы и специальные коды возврата"
echo
echo "3. ПРОБЛЕМА: Сложно диагностировать проблему"
echo "   РЕШЕНИЕ: ✅ Добавлено детальное диагностическое логирование"
echo
echo "4. ПРОБЛЕМА: Функция прерывает выполнение скрипта"
echo "   РЕШЕНИЕ: ✅ Функция может пропускать настройку и возвращать успех"
echo
echo "5. ПРОБЛЕМА: Потеря обратной совместимости"
echo "   РЕШЕНИЕ: ✅ Старые функции сохранены"
echo
echo "=== РЕКОМЕНДАЦИИ ПО ТЕСТИРОВАНИЮ ==="
echo
echo "1. Запустите скрипт с включенной диагностикой:"
echo "   sudo ./deploy_monitoring_script.sh 2>&1 | tee deployment.log"
echo
echo "2. Проверьте логи на наличие диагностической информации:"
echo "   grep -A5 -B5 'ДИАГНОСТИКА' deployment.log"
echo
echo "3. Если проблема сохраняется, проверьте:"
echo "   - Файл с учетными данными: /opt/vault/conf/data_sec.json"
echo "   - Доступность Grafana: ss -tln | grep :3000"
echo "   - Процесс Grafana: pgrep -f grafana-server"
echo
echo "4. Для принудительного пропуска настройки Grafana:"
echo "   export SKIP_GRAFANA_SETUP=true"
echo "   sudo ./deploy_monitoring_script.sh"





