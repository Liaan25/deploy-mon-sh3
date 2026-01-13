#!/bin/bash

# Быстрое исправление проблемы HTTP 400 при создании сервисного аккаунта

echo "=== БЫСТРОЕ ИСПРАВЛЕНИЕ HTTP 400 ОШИБКИ ==="
echo

# Вариант 1: Использовать localhost вместо доменного имени
echo "Вариант 1: Использовать localhost (рекомендуется)"
echo "-----------------------------------------------"
echo "Эта опция обходит проблемы с SSL/доменным именем:"
echo
echo "export USE_GRAFANA_LOCALHOST=true"
echo "sudo ./deploy_monitoring_script.sh"
echo
echo "Или в одну строку:"
echo "USE_GRAFANA_LOCALHOST=true sudo ./deploy_monitoring_script.sh"
echo

# Вариант 2: Изменить формат payload
echo "Вариант 2: Изменить формат payload"
echo "----------------------------------"
echo "Текущий формат: {\"name\":\"имя\",\"role\":\"Admin\"}"
echo "Пробуем другие форматы:"
echo
echo "1. Изменить role с \"Admin\" на \"admin\" (маленькие буквы):"
echo "   sed -i \"s/--arg role \\\"Admin\\\"/--arg role \\\"admin\\\"/\" deploy_monitoring_script.sh"
echo
echo "2. Убрать role полностью:"
echo "   sed -i \"s/jq -n --arg name \\\"\\\$service_account_name\\\" --arg role \\\"Admin\\\" '{name:\\\$name, role:\\\$role}'/jq -n --arg name \\\"\\\$service_account_name\\\" '{name:\\\$name}'/\" deploy_monitoring_script.sh"
echo
echo "3. Использовать role как число (2 = Admin):"
echo "   sed -i \"s/jq -n --arg name \\\"\\\$service_account_name\\\" --arg role \\\"Admin\\\" '{name:\\\$name, role:\\\$role}'/jq -n --arg name \\\"\\\$service_account_name\\\" '{name:\\\$name, role:2}'/\" deploy_monitoring_script.sh"
echo

# Вариант 3: Проверить и исправить функцию
echo "Вариант 3: Проверить и исправить функцию"
echo "----------------------------------------"
echo "Запустите диагностический скрипт:"
echo "./test_payload_formats.sh"
echo
echo "Или проверьте вручную:"
echo "1. Проверьте учетные данные:"
echo "   cat /opt/vault/conf/data_sec.json | jq '.grafana_web'"
echo
echo "2. Проверьте доступность Grafana:"
echo "   curl -k https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/health"
echo
echo "3. Проверьте существующие сервисные аккаунты:"
echo "   curl -k -u 'пользователь:пароль' https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/serviceaccounts"
echo

# Вариант 4: Временное решение - пропустить создание SA
echo "Вариант 4: Временное решение"
echo "----------------------------"
echo "Если нужно срочно запустить пайплайн:"
echo "1. Пропустить создание сервисного аккаунта:"
echo "   export SKIP_SERVICE_ACCOUNT_CREATION=true"
echo "   sudo ./deploy_monitoring_script.sh"
echo
echo "2. Создать сервисный аккаунт вручную позже:"
echo "   # Войдите в Grafana через веб-интерфейс"
echo "   # Настройки → Service accounts → Add service account"
echo "   # Создайте аккаунт с ролью Admin"
echo "   # Создайте токен и сохраните его"
echo

# Вариант 5: Использовать исправленную версию функции
echo "Вариант 5: Использовать исправленную версию функции"
echo "---------------------------------------------------"
echo "Запустите исправленную версию функции:"
echo "./fixed_create_service_account.sh"
echo
echo "Или примените патч:"
echo "./apply_fix_now.sh"
echo

# Анализ логов
echo "=== АНАЛИЗ ВАШИХ ЛОГОВ ==="
echo "Из ваших логов видно:"
echo "1. ✅ Health check проходит успешно (HTTP 200)"
echo "2. ❌ Создание сервисного аккаунта возвращает HTTP 400"
echo "3. ❌ Тело ошибки: {\"message\":\"Bad request data\"}"
echo
echo "Это означает:"
echo "- Grafana доступен и работает"
echo "- Проблема в данных запроса (payload)"
echo "- Возможные причины:"
echo "  • Неправильный формат JSON"
echo "  • Неподдерживаемое значение role"
echo "  • Проблема с кодировкой"
echo "  • Проблема с SSL/доменным именем"
echo

# Рекомендации
echo "=== РЕКОМЕНДАЦИИ ==="
echo "1. Сначала попробуйте Вариант 1 (USE_GRAFANA_LOCALHOST=true)"
echo "   Это обходит проблемы с доменным именем/SSL"
echo
echo "2. Если не поможет, запустите диагностику:"
echo "   ./test_payload_formats.sh"
echo "   ./debug_400_problem.sh"
echo
echo "3. Проверьте версию Grafana:"
echo "   curl -k https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/health | jq ."
echo
echo "4. Проверьте настройки Grafana на сервере:"
echo "   sudo -u CI10742292-lnx-mon_sys cat /etc/grafana/grafana.ini | grep -i service"
echo

# Команды для быстрого тестирования
echo "=== КОМАНДЫ ДЛЯ БЫСТРОГО ТЕСТИРОВАНИЯ ==="
echo "# Получить учетные данные:"
echo "USER=\$(jq -r '.grafana_web.user' /opt/vault/conf/data_sec.json)"
echo "PASS=\$(jq -r '.grafana_web.pass' /opt/vault/conf/data_sec.json)"
echo
echo "# Тест 1: Проверка health"
echo "curl -k -s -w \"\\nHTTP:%{http_code}\" -u \"\$USER:\$PASS\" https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/health"
echo
echo "# Тест 2: Создание SA с role=\"admin\" (маленькие буквы)"
echo "curl -k -s -w \"\\nHTTP:%{http_code}\" -X POST -H \"Content-Type: application/json\" -u \"\$USER:\$PASS\" -d '{\"name\":\"test-sa\",\"role\":\"admin\"}' https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/serviceaccounts"
echo
echo "# Тест 3: Создание SA без role"
echo "curl -k -s -w \"\\nHTTP:%{http_code}\" -X POST -H \"Content-Type: application/json\" -u \"\$USER:\$PASS\" -d '{\"name\":\"test-sa\"}' https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/serviceaccounts"
echo
echo "# Тест 4: С localhost"
echo "curl -k -s -w \"\\nHTTP:%{http_code}\" -X POST -H \"Content-Type: application/json\" -u \"\$USER:\$PASS\" -d '{\"name\":\"test-sa\",\"role\":\"Admin\"}' https://localhost:3000/api/serviceaccounts"
echo

echo "=== ВЫВОД ==="
echo "Самый быстрый способ решить проблему:"
echo "USE_GRAFANA_LOCALHOST=true sudo ./deploy_monitoring_script.sh"
echo
echo "Если это не поможет, запустите диагностику для определения точной причины."



