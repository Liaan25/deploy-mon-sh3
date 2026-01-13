#!/bin/bash
# Комплексный скрипт диагностики Grafana
# Запуск: sudo ./diagnose_grafana.sh

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Проверка прав
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Этот скрипт должен запускаться с правами root (sudo)"
        exit 1
    fi
}

# Основная функция диагностики
main() {
    check_root
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   ДИАГНОСТИКА GRAFANA - $(date)   ${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # 1. Проверка базовой системы
    print_section "1. БАЗОВАЯ СИСТЕМА"
    
    print_info "Проверка ОС и версии:"
    cat /etc/os-release | grep -E "PRETTY_NAME|VERSION_ID"
    
    print_info "Проверка свободной памяти:"
    free -h
    
    print_info "Проверка дискового пространства:"
    df -h / /opt /var
    
    # 2. Проверка сетевых настроек
    print_section "2. СЕТЕВЫЕ НАСТРОЙКИ"
    
    print_info "Хостнейм и IP адреса:"
    hostname
    hostname -I
    ip addr show | grep inet
    
    print_info "Проверка DNS:"
    grep -E "nameserver|search" /etc/resolv.conf
    
    # 3. Проверка Grafana процесса
    print_section "3. ПРОЦЕСС GRAFANA"
    
    print_info "Поиск процесса grafana-server:"
    if pgrep -f "grafana-server" >/dev/null; then
        print_success "Процесс grafana-server найден"
        ps aux | grep -E "grafana|PID" | head -5
    else
        print_error "Процесс grafana-server не найден"
    fi
    
    # 4. Проверка портов
    print_section "4. ПРОВЕРКА ПОРТОВ"
    
    local grafana_port=3000
    print_info "Проверка порта $grafana_port:"
    
    if ss -tln | grep -q ":$grafana_port "; then
        print_success "Порт $grafana_port слушается"
        ss -tlnp | grep ":$grafana_port"
    else
        print_error "Порт $grafana_port НЕ слушается"
        
        print_info "Проверка всех слушающих портов:"
        ss -tln | head -20
    fi
    
    # 5. Проверка сервисов systemd
    print_section "5. СЕРВИСЫ SYSTEMD"
    
    print_info "Проверка системных юнитов Grafana:"
    systemctl status grafana-server --no-pager 2>/dev/null || print_warning "Системный юнит grafana-server не найден"
    
    print_info "Поиск user-юнитов:"
    find /etc/systemd/system -name "*grafana*" -o -name "*monitoring*" 2>/dev/null | head -10
    
    # 6. Проверка файлов и директорий
    print_section "6. ФАЙЛЫ И ДИРЕКТОРИИ"
    
    print_info "Проверка директорий Grafana:"
    for dir in /etc/grafana /var/lib/grafana /var/log/grafana /usr/share/grafana; do
        if [[ -d "$dir" ]]; then
            print_success "Директория $dir существует"
            ls -la "$dir" | head -3
        else
            print_warning "Директория $dir не существует"
        fi
    done
    
    # 7. Проверка конфигурации
    print_section "7. КОНФИГУРАЦИЯ"
    
    print_info "Проверка конфигурационных файлов:"
    for config in /etc/grafana/grafana.ini /etc/grafana/ldap.toml; do
        if [[ -f "$config" ]]; then
            print_success "Файл $config существует"
            head -20 "$config"
        fi
    done
    
    # 8. Проверка логов
    print_section "8. ЛОГИ"
    
    print_info "Поиск лог-файлов Grafana:"
    find /var/log -name "*grafana*" -type f 2>/dev/null | head -10
    
    print_info "Последние 20 строк логов Grafana:"
    journalctl -u grafana-server --no-pager -n 20 2>/dev/null || \
    find /var/log -name "*grafana*" -exec tail -n 20 {} \; 2>/dev/null | head -40
    
    # 9. Проверка учетных данных Vault
    print_section "9. УЧЕТНЫЕ ДАННЫЕ VAULT"
    
    local cred_file="/opt/vault/conf/data_sec.json"
    print_info "Проверка файла с учетными данными: $cred_file"
    
    if [[ -f "$cred_file" ]]; then
        print_success "Файл существует"
        print_info "Размер файла: $(stat -c%s "$cred_file") байт"
        
        # Проверка формата JSON
        if jq empty "$cred_file" 2>/dev/null; then
            print_success "JSON файл валиден"
            
            print_info "Структура JSON:"
            jq 'keys' "$cred_file" 2>/dev/null || cat "$cred_file" | head -5
            
            print_info "Блок grafana_web:"
            jq '.grafana_web' "$cred_file" 2>/dev/null || print_warning "Блок grafana_web не найден"
            
            # Извлечение учетных данных
            local grafana_user grafana_password
            grafana_user=$(jq -r '.grafana_web.user // empty' "$cred_file" 2>/dev/null || echo "")
            grafana_password=$(jq -r '.grafana_web.pass // empty' "$cred_file" 2>/dev/null || echo "")
            
            if [[ -n "$grafana_user" && -n "$grafana_password" ]]; then
                print_success "Учетные данные получены"
                print_info "Пользователь: $grafana_user"
                print_info "Длина пароля: ${#grafana_password} символов"
            else
                print_error "Не удалось получить учетные данные"
            fi
        else
            print_error "JSON файл невалиден"
            print_info "Первые 200 символов:"
            head -c 200 "$cred_file" | cat -A
            echo
        fi
    else
        print_error "Файл не найден"
        
        print_info "Поиск альтернативных файлов:"
        find /opt/vault -name "*data*sec*" -type f 2>/dev/null | head -5
    fi
    
    # 10. Проверка сертификатов
    print_section "10. СЕРТИФИКАТЫ"
    
    print_info "Проверка клиентских сертификатов:"
    for cert in "/opt/vault/certs/grafana-client.crt" "/opt/vault/certs/grafana-client.key"; do
        if [[ -f "$cert" ]]; then
            print_success "Файл $cert существует"
            print_info "Размер: $(stat -c%s "$cert") байт"
            print_info "Права: $(stat -c "%A %U %G" "$cert")"
        else
            print_warning "Файл $cert не найден"
        fi
    done
    
    # 11. Проверка доступности Grafana API
    print_section "11. ПРОВЕРКА API GRAFANA"
    
    # Определяем домен
    local server_domain="localhost"
    if [[ -f "/opt/vault/conf/data_sec.json" ]]; then
        # Пробуем получить из скрипта или определить
        if [[ -f "deploy_monitoring_script.sh" ]]; then
            server_domain=$(grep -o "SERVER_DOMAIN=.*" deploy_monitoring_script.sh | head -1 | cut -d= -f2 | tr -d '"' || echo "localhost")
        fi
    fi
    
    local grafana_url="https://${server_domain}:3000"
    print_info "Grafana URL: $grafana_url"
    
    # Проверка доступности без аутентификации
    print_info "Проверка доступности (без аутентификации):"
    if curl -k -s -o /dev/null -w "HTTP код: %{http_code}\n" "$grafana_url" 2>/dev/null; then
        print_success "Grafana доступна"
    else
        print_error "Grafana недоступна"
    fi
    
    # Проверка с аутентификацией (если есть учетные данные)
    if [[ -n "$grafana_user" && -n "$grafana_password" ]]; then
        print_info "Проверка API с аутентификацией:"
        
        # Проверка /api/health
        print_info "Запрос к /api/health:"
        curl -k -s -w "HTTP код: %{http_code}\n" -u "${grafana_user}:${grafana_password}" "${grafana_url}/api/health" 2>/dev/null || true
        
        # Проверка /api/serviceaccounts
        print_info "Запрос к /api/serviceaccounts:"
        curl -k -s -w "HTTP код: %{http_code}\n" -u "${grafana_user}:${grafana_password}" "${grafana_url}/api/serviceaccounts" 2>/dev/null | head -c 200
        echo
        
        # Проверка /api/datasources
        print_info "Запрос к /api/datasources:"
        curl -k -s -w "HTTP код: %{http_code}\n" -u "${grafana_user}:${grafana_password}" "${grafana_url}/api/datasources" 2>/dev/null | head -c 200
        echo
    else
        print_warning "Нет учетных данных для проверки API"
    fi
    
    # 12. Проверка оберток и скриптов
    print_section "12. СКРИПТЫ И ОБЕРТКИ"
    
    print_info "Проверка обертки grafana_wrapper.sh:"
    if [[ -f "/opt/monitoring/wrappers/grafana_wrapper.sh" ]]; then
        print_success "Обертка найдена"
        ls -la "/opt/monitoring/wrappers/grafana_wrapper.sh"
        
        print_info "Проверка исполняемости:"
        if [[ -x "/opt/monitoring/wrappers/grafana_wrapper.sh" ]]; then
            print_success "Скрипт исполняемый"
        else
            print_error "Скрипт не исполняемый"
        fi
    else
        print_warning "Обертка не найдена в /opt/monitoring/wrappers/"
        
        # Поиск в других местах
        print_info "Поиск обертки в системе:"
        find /opt -name "*grafana*wrapper*" -type f 2>/dev/null | head -5
    fi
    
    # 13. Проверка переменных окружения
    print_section "13. ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ"
    
    print_info "Переменные связанные с Grafana:"
    env | grep -i grafana | sort
    
    print_info "Переменные связанные с мониторингом:"
    env | grep -i -E "monitor|prometheus|harvest" | sort
    
    # 14. Проверка зависимостей
    print_section "14. ЗАВИСИМОСТИ"
    
    print_info "Проверка установленных пакетов:"
    if command -v rpm >/dev/null; then
        rpm -qa | grep -i -E "grafana|prometheus|harvest" | sort
    elif command -v dpkg >/dev/null; then
        dpkg -l | grep -i -E "grafana|prometheus|harvest" | sort
    fi
    
    print_info "Проверка утилит:"
    for cmd in curl jq ss systemctl journalctl; do
        if command -v "$cmd" >/dev/null; then
            print_success "$cmd: $(which $cmd)"
        else
            print_error "$cmd: не найден"
        fi
    done
    
    # 15. Рекомендации
    print_section "15. РЕКОМЕНДАЦИИ И СЛЕДУЮЩИЕ ШАГИ"
    
    echo "На основе диагностики:"
    echo
    
    # Анализ результатов
    if pgrep -f "grafana-server" >/dev/null && ss -tln | grep -q ":3000 "; then
        print_success "Grafana запущена и слушает порт 3000"
        echo "  1. Проверьте логины через браузер: https://$(hostname):3000"
    else
        print_error "Grafana не запущена или не слушает порт"
        echo "  1. Запустите Grafana: sudo systemctl start grafana-server"
        echo "  2. Проверьте статус: sudo systemctl status grafana-server"
    fi
    
    if [[ -n "$grafana_user" && -n "$grafana_password" ]]; then
        print_success "Учетные данные получены из Vault"
        echo "  2. Проверьте аутентификацию:"
        echo "     curl -k -u '${grafana_user}:*****' https://localhost:3000/api/health"
    else
        print_error "Проблема с учетными данными"
        echo "  2. Проверьте файл: /opt/vault/conf/data_sec.json"
        echo "  3. Убедитесь что vault-agent работает"
    fi
    
    echo "  3. Для детальной диагностики API:"
    echo "     curl -k -v -u '${grafana_user}:*****' https://localhost:3000/api/serviceaccounts"
    
    echo "  4. Проверьте логи Grafana:"
    echo "     sudo journalctl -u grafana-server -f"
    
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}   ДИАГНОСТИКА ЗАВЕРШЕНА - $(date)   ${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # Создание файла с результатами
    local result_file="/tmp/grafana_diagnosis_$(date +%Y%m%d_%H%M%S).txt"
    echo "Результаты диагностики сохранены в: $result_file"
    
    # Запись результатов в файл
    {
        echo "=== ДИАГНОСТИКА GRAFANA - $(date) ==="
        echo "Хост: $(hostname)"
        echo "IP: $(hostname -I)"
        echo
        echo "1. Процесс Grafana: $(pgrep -f "grafana-server" | wc -l)"
        echo "2. Порт 3000: $(ss -tln | grep -c ":3000 ")"
        echo "3. Учетные данные: $( [[ -n "$grafana_user" && -n "$grafana_password" ]] && echo "ЕСТЬ" || echo "НЕТ" )"
        echo "4. JSON файл: $( [[ -f "$cred_file" ]] && echo "OK" || echo "НЕТ" )"
    } > "$result_file"
}

# Обработка ошибок
trap 'print_error "Скрипт завершился с ошибкой на строке $LINENO"; exit 1' ERR

# Запуск основной функции
main "$@"






