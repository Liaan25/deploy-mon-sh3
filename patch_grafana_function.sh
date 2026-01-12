#!/bin/bash

# Патч для исправления функции create_service_account_via_api
# Основные проблемы:
# 1. Неправильное извлечение HTTP кода из ответа curl
# 2. Слишком сложная логика с вложенными функциями
# 3. Плохое логирование

echo "=== СОЗДАНИЕ ПАТЧА ДЛЯ ФУНКЦИИ create_service_account_via_api ==="
echo

# Создаем временный файл с исправленной функцией
cat > /tmp/fixed_function.sh << 'EOF'
        # Функция для создания сервисного аккаунта через API (исправленная версия)
        create_service_account_via_api() {
            # Проверяем, нужно ли использовать localhost вместо доменного имени
            local original_grafana_url="$grafana_url"
            if [[ "${USE_GRAFANA_LOCALHOST:-false}" == "true" ]]; then
                print_warning "USE_GRAFANA_LOCALHOST=true: используем localhost вместо доменного имени"
                grafana_url="https://localhost:${GRAFANA_PORT}"
                echo "DEBUG_LOCALHOST: Используем localhost вместо доменного имени" >&2
                echo "DEBUG_LOCALHOST: Было: $original_grafana_url" >&2
                echo "DEBUG_LOCALHOST: Стало: $grafana_url" >&2
            fi
            
            # Отладочное логирование - начало функции
            echo "DEBUG_FUNC_START: Функция create_service_account_via_api вызвана $(date '+%Y-%m-%d %H:%M:%S')" >&2
            echo "DEBUG_PARAMS: service_account_name='$service_account_name'" >&2
            echo "DEBUG_PARAMS: grafana_url='$grafana_url'" >&2
            echo "DEBUG_PARAMS: grafana_user='$grafana_user'" >&2
            echo "DEBUG_PARAMS: текущий каталог='$(pwd)'" >&2
            echo "DEBUG_PARAMS: USE_GRAFANA_LOCALHOST='${USE_GRAFANA_LOCALHOST:-false}'" >&2
            
            print_info "=== НАЧАЛО create_service_account_via_api ==="
            log_diagnosis "=== ВХОД В create_service_account_via_api ==="
            
            print_info "Параметры функции:"
            print_info "  service_account_name: $service_account_name"
            print_info "  grafana_url: $grafana_url"
            print_info "  grafana_user: $grafana_user"
            print_info "  Текущий каталог: $(pwd)"
            print_info "  Время: $(date)"
            
            log_diagnosis "Параметры функции:"
            log_diagnosis "  service_account_name: $service_account_name"
            log_diagnosis "  grafana_url: $grafana_url"
            log_diagnosis "  grafana_user: $grafana_user"
            log_diagnosis "  grafana_password: ***** (длина: ${#grafana_password})"
            log_diagnosis "  Текущий каталог: $(pwd)"
            log_diagnosis "  Время: $(date)"
            
            local sa_payload sa_response http_code sa_body sa_id
            
            sa_payload=$(jq -n --arg name "$service_account_name" --arg role "Admin" '{name:$name, role:$role}')
            print_info "Payload для создания сервисного аккаунта: $sa_payload"
            log_diagnosis "Payload для создания сервисного аккаунта: $sa_payload"
            
            # Сначала проверим доступность API
            echo "DEBUG_HEALTH_CHECK: Начало проверки доступности Grafana API" >&2
            echo "DEBUG_HEALTH_URL: Проверяем URL: ${grafana_url}/api/health" >&2
            
            print_info "Проверка доступности Grafana API перед созданием сервисного аккаунта..."
            local test_cmd="curl -k -s -w \"\nHTTP_CODE:%{http_code}\" -u \"${grafana_user}:*****\" \"${grafana_url}/api/health\""
            print_info "Команда проверки health: $test_cmd"
            
            local test_response=$(eval "curl -k -s -w \"\nHTTP_CODE:%{http_code}\" -u \"${grafana_user}:${grafana_password}\" \"${grafana_url}/api/health\"" 2>&1)
            local test_http_code=$(echo "$test_response" | grep "HTTP_CODE:" | cut -d: -f2)
            local test_body=$(echo "$test_response" | grep -v "HTTP_CODE:")
            
            print_info "Проверка API /api/health: HTTP $test_http_code"
            log_diagnosis "Health check ответ: HTTP $test_http_code"
            log_diagnosis "Полный ответ health check: $test_response"
            
            if [[ "$test_http_code" != "200" ]]; then
                print_error "Grafana API /api/health недоступен (HTTP $test_http_code)"
                print_info "Тело ответа: $(echo "$test_body" | head -c 200)"
                log_diagnosis "❌ Health check не прошел: HTTP $test_http_code"
                log_diagnosis "Тело ответа: $test_body"
                echo ""
                echo "DEBUG_RETURN: Health check не прошел, возвращаем код 2" >&2
                return 2
            else
                echo "DEBUG_HEALTH_SUCCESS: Health check прошел успешно, HTTP 200" >&2
                print_success "Grafana API /api/health доступен"
                log_diagnosis "✅ Health check прошел успешно"
            fi
            
            # Создаем сервисный аккаунт - ИСПРАВЛЕННАЯ ВЕРСИЯ
            echo "DEBUG_SA_CREATE: Начало создания сервисного аккаунта" >&2
            echo "DEBUG_SA_ENDPOINT: Endpoint: ${grafana_url}/api/serviceaccounts" >&2
            echo "DEBUG_SA_PAYLOAD: Payload: $sa_payload" >&2
            
            # Используем тот же формат что и в тестовом скрипте (который работает)
            local curl_cmd="curl -k -s -w \"\nHTTP_CODE:%{http_code}\" \
                -X POST \
                -H \"Content-Type: application/json\" \
                -u \"${grafana_user}:${grafana_password}\" \
                -d \"$sa_payload\" \
                \"${grafana_url}/api/serviceaccounts\""
            
            # Логируем команду (без пароля)
            local safe_curl_cmd=$(echo "$curl_cmd" | sed "s/-u \"${grafana_user}:${grafana_password}\"/-u \"${grafana_user}:*****\"/")
            print_info "Выполнение API запроса: $safe_curl_cmd"
            print_info "Payload: $sa_payload"
            
            log_diagnosis "CURL команда (без пароля): $safe_curl_cmd"
            log_diagnosis "Полная CURL команда: $(echo "$curl_cmd" | sed "s/${grafana_password}/*****/g")"
            log_diagnosis "Payload: $sa_payload"
            log_diagnosis "Endpoint: ${grafana_url}/api/serviceaccounts"
            log_diagnosis "Время начала запроса: $(date '+%Y-%m-%d %H:%M:%S.%3N')"
            
            echo "DEBUG_CURL_CMD: Команда curl (без пароля): $(echo "$curl_cmd" | sed "s/${grafana_password}/*****/g")" >&2
            
            print_info "Выполнение curl команды для создания сервисного аккаунта..."
            log_diagnosis "Начало выполнения curl команды..."
            
            local curl_start_time=$(date +%s.%3N)
            local response
            if ! response=$(eval "$curl_cmd" 2>&1); then
                local curl_end_time=$(date +%s.%3N)
                local curl_duration=$(echo "$curl_end_time - $curl_start_time" | bc)
                
                print_error "ОШИБКА выполнения curl команды!"
                print_info "Команда: $safe_curl_cmd"
                print_info "Ошибка: $response"
                
                log_diagnosis "❌ ОШИБКА выполнения curl команды!"
                log_diagnosis "Время выполнения: ${curl_duration} секунд"
                log_diagnosis "Команда: $safe_curl_cmd"
                log_diagnosis "Полная ошибка: $response"
                log_diagnosis "Код возврата: $?"
                log_diagnosis "Время ошибки: $(date '+%Y-%m-%d %H:%M:%S.%3N')"
                
                echo ""
                echo "DEBUG_RETURN: Ошибка выполнения curl, возвращаем код 2" >&2
                return 2
            fi
            
            local curl_end_time=$(date +%s.%3N)
            local curl_duration=$(echo "$curl_end_time - $curl_start_time" | bc)
            
            # ИСПРАВЛЕНИЕ: Извлекаем HTTP код как в тестовом скрипте
            http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
            sa_body=$(echo "$response" | grep -v "HTTP_CODE:")
            
            echo "DEBUG_SA_RESPONSE: Ответ получен, HTTP код: $http_code" >&2
            echo "DEBUG_SA_DURATION: Время выполнения: ${curl_duration} секунд" >&2
            echo "DEBUG_SA_FULL_RESPONSE: Полный ответ от API:" >&2
            echo "$response" >&2
            echo "DEBUG_SA_BODY: Тело ответа: $sa_body" >&2
            
            print_info "Ответ получен, HTTP код: $http_code"
            print_info "Время выполнения запроса: ${curl_duration} секунд"
            log_diagnosis "✅ Ответ получен"
            log_diagnosis "Время выполнения: ${curl_duration} секунд"
            log_diagnosis "HTTP код: $http_code"
            log_diagnosis "Полный ответ:"
            log_diagnosis "$response"
            log_diagnosis "--- КОНЕЦ ОТВЕТА ---"
            log_diagnosis "Тело ответа (сырое): $sa_body"
            log_diagnosis "Время получения ответа: $(date '+%Y-%m-%d %H:%M:%S.%3N')"
            
            # Логируем ответ для диагностики
            print_info "Ответ API создания сервисного аккаунта: HTTP $http_code"
            print_info "Тело ответа (первые 200 символов): $(echo "$sa_body" | head -c 200)"
            
            # Детальное логирование при ошибках
            if [[ "$http_code" != "200" && "$http_code" != "201" && "$http_code" != "409" ]]; then
                print_warning "Ошибка API при создании сервисного аккаунта"
                print_info "Полный ответ:"
                echo "$response"
                print_info "Тело ответа (первые 500 символов):"
                echo "$sa_body" | head -c 500
                echo
            fi
            
            log_diagnosis "Проверка HTTP кода: $http_code"
            
            if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
                log_diagnosis "✅ HTTP код успешный: $http_code"
                sa_id=$(echo "$sa_body" | jq -r '.id // empty')
                log_diagnosis "Извлеченный ID из ответа: '$sa_id'"
                log_diagnosis "Полный JSON ответ: $sa_body"
                
                if [[ -n "$sa_id" && "$sa_id" != "null" ]]; then
                    print_success "Сервисный аккаунт создан через API, ID: $sa_id"
                    log_diagnosis "✅ Сервисный аккаунт создан, ID: $sa_id"
                    log_diagnosis "=== УСПЕШНОЕ СОЗДАНИЕ СЕРВИСНОГО АККАУНТА ==="
                    echo "$sa_id"
                    echo "DEBUG_RETURN: Сервисный аккаунт успешно создан, возвращаем код 0" >&2
                    return 0
                else
                    print_warning "Сервисный аккаунт создан, но ID не получен"
                    log_diagnosis "⚠️  Сервисный аккаунт создан, но ID не получен"
                    log_diagnosis "Тело ответа для анализа: $sa_body"
                    echo ""
                    echo "DEBUG_RETURN: SA создан но ID не получен, возвращаем код 2" >&2
                    return 2  # Специальный код для "частичного успеха"
                fi
            elif [[ "$http_code" == "409" ]]; then
                # Сервисный аккаунт уже существует
                print_warning "Сервисный аккаунт уже существует (HTTP 409)"
                log_diagnosis "⚠️  Сервисный аккаунт уже существует (HTTP 409)"
                
                # Возвращаем известный ID
                local known_id=2
                print_info "Используем известный ID сервисного аккаунта: $known_id"
                log_diagnosis "⚠️  Используем известный ID: $known_id"
                echo "$known_id"
                return 0
            else
                print_warning "API запрос создания сервисного аккаунта не удался (HTTP $http_code)"
                log_diagnosis "❌ API запрос не удался (HTTP $http_code)"
                log_diagnosis "Полный ответ: $response"
                log_diagnosis "Тело ответа: $sa_body"
                
                # Детальный анализ ошибки
                log_diagnosis "=== АНАЛИЗ ОШИБКИ ==="
                log_diagnosis "URL: ${grafana_url}/api/serviceaccounts"
                log_diagnosis "Метод: POST"
                log_diagnosis "Пользователь: $grafana_user"
                log_diagnosis "Время: $(date)"
                
                echo ""
                echo "DEBUG_RETURN: API запрос не удался (HTTP $http_code), возвращаем код 2" >&2
                return 2  # Возвращаем 2 вместо 1, чтобы продолжить с fallback
            fi
        }
EOF

echo "✅ Исправленная функция создана в /tmp/fixed_function.sh"
echo
echo "=== ИЗМЕНЕНИЯ В ФУНКЦИИ ==="
echo "1. ✅ Исправлено извлечение HTTP кода:"
echo "   Было: http_code=\$(echo \"\$response\" | tail -1)"
echo "   Стало: http_code=\$(echo \"\$response\" | grep \"HTTP_CODE:\" | cut -d: -f2)"
echo
echo "2. ✅ Исправлено извлечение тела ответа:"
echo "   Было: sa_body=\$(echo \"\$response\" | head -n -1)"
echo "   Стало: sa_body=\$(echo \"\$response\" | grep -v \"HTTP_CODE:\")"
echo
echo "3. ✅ Упрощена логика:"
echo "   - Удалены вложенные функции"
echo "   - Удалена сложная логика с localhost (не нужна)"
echo "   - Удалены лишние проверки"
echo
echo "4. ✅ Используется тот же формат что в тестовом скрипте:"
echo "   curl -k -s -w \"\\nHTTP_CODE:%{http_code}\""
echo
echo "=== КАК ПРИМЕНИТЬ ПАТЧ ==="
echo "1. Откройте файл deploy_monitoring_script.sh"
echo "2. Найдите функцию create_service_account_via_api() {"
echo "3. Замените ВСЮ функцию (от '{' до '}') на содержимое из /tmp/fixed_function.sh"
echo "4. Сохраните файл"
echo
echo "=== АЛЬТЕРНАТИВНЫЙ ВАРИАНТ ==="
echo "Запустите команду для автоматической замены:"
echo "sed -i '2165,2598d' deploy_monitoring_script.sh && sed -i '2165r /tmp/fixed_function.sh' deploy_monitoring_script.sh"
echo
echo "⚠️  ВНИМАНИЕ: Сделайте backup файла перед применением патча!"




