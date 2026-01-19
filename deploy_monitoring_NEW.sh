# НОВАЯ УПРОЩЕННАЯ ФУНКЦИЯ create_service_account_via_api
# Используем grafana_wrapper.sh (требование ИБ) + проверенный подход

        create_service_account_via_api() {
            # ============================================================================
            # УПРОЩЕННАЯ ВЕРСИЯ - используем grafana_wrapper.sh (требование ИБ)
            # Правила ИБ (SECURITY_IB_NOTES.md строка 70-71):
            # "Во всех случаях исходный скрипт deploy_monitoring_script.sh **не вызывает curl напрямую**:
            #  он использует только вышеуказанные обёртки с жёсткой валидацией параметров и whitelists."
            # ============================================================================
            print_info "=== Создание Service Account через wrapper ==="
            log_diagnosis "=== ВХОД В create_service_account_via_api (через wrapper) ==="
            
            local sa_payload sa_response http_code sa_body sa_id
            
            # Создаем payload для Service Account (Grafana 11.x не поддерживает поле "role")
            sa_payload=$(jq -c -n --arg name "$service_account_name" '{name:$name}')
            print_info "Payload для создания сервисного аккаунта: $sa_payload"
            log_diagnosis "Payload для создания сервисного аккаунта: $sa_payload"
            
            # Создаём Service Account через grafana_wrapper.sh (требование ИБ)
            print_info "Создание Service Account через wrapper..."
            sa_response=$(echo "$sa_payload" | "$WRAPPERS_DIR/grafana_wrapper.sh" sa_create "$grafana_url" "$grafana_user" "$grafana_password" 2>&1) || true
            http_code="${sa_response##*$'\n'}"
            sa_body="${sa_response%$'\n'*}"
            
            print_info "Ответ Grafana API: HTTP $http_code"
            log_diagnosis "HTTP код: $http_code"
            log_diagnosis "Тело ответа: $sa_body"
            
            # Обработка ответа
            if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
                sa_id=$(echo "$sa_body" | jq -r '.id // empty')
                log_diagnosis "Извлеченный ID из ответа: '$sa_id'"
                
                if [[ -n "$sa_id" && "$sa_id" != "null" ]]; then
                    print_success "Сервисный аккаунт создан через API, ID: $sa_id"
                    log_diagnosis "✅ Сервисный аккаунт создан, ID: $sa_id"
                    echo "$sa_id"
                    return 0
                else
                    print_warning "Сервисный аккаунт создан, но ID не получен"
                    log_diagnosis "⚠️  Сервисный аккаунт создан, но ID не получен"
                    return 2
                fi
            elif [[ "$http_code" == "409" ]] || [[ "$http_code" == "400" && "$sa_body" == *"ErrAlreadyExists"* ]]; then
                # Сервисный аккаунт уже существует (Grafana 11.x возвращает 400 вместо 409)
                print_warning "Сервисный аккаунт уже существует (HTTP $http_code)"
                log_diagnosis "⚠️  Сервисный аккаунт уже существует, пробуем получить ID"
                
                # Пробуем получить ID через /api/serviceaccounts/search
                print_info "Получение ID существующего сервисного аккаунта..."
                local list_response=$(echo "" | "$WRAPPERS_DIR/grafana_wrapper.sh" sa_list "$grafana_url" "$grafana_user" "$grafana_password" 2>&1) || true
                local list_code="${list_response##*$'\n'}"
                local list_body="${list_response%$'\n'*}"
                
                if [[ "$list_code" == "200" ]]; then
                    # Пробуем найти по имени в ответе
                    sa_id=$(echo "$list_body" | jq -r '.[] | select(.name=="'"$service_account_name"'") | .id' | head -1)
                    
                    if [[ -n "$sa_id" && "$sa_id" != "null" ]]; then
                        print_success "Найден существующий сервисный аккаунт, ID: $sa_id"
                        log_diagnosis "✅ Найден существующий сервисный аккаунт, ID: $sa_id"
                        echo "$sa_id"
                        return 0
                    fi
                fi
                
                # Если не удалось получить ID, возвращаем ошибку
                print_error "Не удалось получить ID существующего сервисного аккаунта"
                log_diagnosis "❌ Не удалось получить ID существующего SA"
                return 2
            else
                print_error "Не удалось создать сервисный аккаунт (HTTP $http_code)"
                log_diagnosis "❌ Ошибка создания SA: HTTP $http_code"
                log_diagnosis "Тело ответа: $sa_body"
                return 2
            fi
        }
        
        # Функция для создания токена через API (через wrapper)
        create_token_via_api() {
            local sa_id="$1"
            local token_payload token_response token_code token_body bearer_token
            
            print_info "Создание токена для Service Account ID: $sa_id"
            token_payload=$(jq -c -n --arg name "$token_name" '{name:$name}')
            
            # Создаём токен через grafana_wrapper.sh (требование ИБ)
            token_response=$(echo "$token_payload" | "$WRAPPERS_DIR/grafana_wrapper.sh" sa_token_create "$grafana_url" "$grafana_user" "$grafana_password" "$sa_id" 2>&1) || true
            token_code="${token_response##*$'\n'}"
            token_body="${token_response%$'\n'*}"
            
            print_info "Ответ API создания токена: HTTP $token_code"
            log_diagnosis "HTTP код токена: $token_code"
            
            if [[ "$token_code" == "200" || "$token_code" == "201" ]]; then
                bearer_token=$(echo "$token_body" | jq -r '.key // empty')
                
                if [[ -n "$bearer_token" && "$bearer_token" != "null" ]]; then
                    GRAFANA_BEARER_TOKEN="$bearer_token"
                    export GRAFANA_BEARER_TOKEN
                    print_success "Токен создан через API"
                    log_diagnosis "✅ Токен успешно создан"
                    return 0
                else
                    print_warning "Токен создан, но значение пустое"
                    log_diagnosis "⚠️  Токен создан, но значение пустое"
                    return 2
                fi
            else
                print_warning "Создание токена не удалось (HTTP $token_code)"
                log_diagnosis "❌ Ошибка создания токена: HTTP $token_code"
                return 2
            fi
        }
