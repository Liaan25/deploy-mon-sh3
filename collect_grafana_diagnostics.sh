#!/bin/bash
# Сбор ВСЕХ диагностических данных Grafana
# Запуск: sudo ./collect_grafana_diagnostics.sh

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DIAG_DIR="/tmp/grafana_full_diagnosis_${TIMESTAMP}"
LOG_FILE="${DIAG_DIR}/full_diagnosis.log"

mkdir -p "$DIAG_DIR"
print_info "Диагностика сохраняется в: $DIAG_DIR"

# Функция для записи в лог
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

echo -e "${BLUE}=== ПОЛНАЯ ДИАГНОСТИКА GRAFANA ===${NC}"
log "=== НАЧАЛО ПОЛНОЙ ДИАГНОСТИКИ GRAFANA ==="
log "Время: $(date)"
log "Хост: $(hostname)"
log "Пользователь: $(whoami)"
log "PID: $$"

# 1. Системная информация
print_info "1. Сбор системной информации..."
{
    echo "=== СИСТЕМНАЯ ИНФОРМАЦИЯ ==="
    echo "Дата: $(date)"
    echo "Хостнейм: $(hostname)"
    echo "ОС: $(cat /etc/os-release | grep PRETTY_NAME)"
    echo "Ядро: $(uname -r)"
    echo "Память:"
    free -h
    echo "Диски:"
    df -h
    echo "Сеть:"
    ip addr show
    echo "DNS:"
    cat /etc/resolv.conf
} > "${DIAG_DIR}/01_system_info.txt"

# 2. Процессы Grafana
print_info "2. Сбор информации о процессах..."
{
    echo "=== ПРОЦЕССЫ GRAFANA ==="
    echo "Поиск процессов grafana:"
    ps aux | grep -i grafana
    echo ""
    echo "Детали процессов:"
    for pid in $(pgrep -f grafana); do
        echo "--- PID $pid ---"
        ps -p "$pid" -o pid,ppid,user,group,start_time,cmd
        echo ""
    done
} > "${DIAG_DIR}/02_processes.txt"

# 3. Порты и сеть
print_info "3. Проверка портов и сети..."
{
    echo "=== ПОРТЫ И СЕТЬ ==="
    echo "Порт 3000:"
    ss -tlnp | grep ":3000" || echo "Порт 3000 не слушается"
    echo ""
    echo "Все слушающие порты:"
    ss -tln | head -20
    echo ""
    echo "Сетевые соединения Grafana:"
    ss -tnp | grep -i grafana || echo "Нет сетевых соединений Grafana"
} > "${DIAG_DIR}/03_network.txt"

# 4. Сервисы systemd
print_info "4. Проверка сервисов systemd..."
{
    echo "=== СЕРВИСЫ SYSTEMD ==="
    echo "Системные юниты:"
    systemctl status grafana-server --no-pager 2>/dev/null || echo "Системный юнит grafana-server не найден"
    echo ""
    echo "User-юниты:"
    sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user status monitoring-grafana.service --no-pager 2>/dev/null || echo "User-юнит не найден"
    echo ""
    echo "Все юниты Grafana:"
    systemctl list-units --all | grep -i grafana
} > "${DIAG_DIR}/04_services.txt"

# 5. Файлы и директории
print_info "5. Проверка файлов и директорий..."
{
    echo "=== ФАЙЛЫ И ДИРЕКТОРИИ ==="
    echo "Директории Grafana:"
    for dir in /etc/grafana /var/lib/grafana /var/log/grafana /usr/share/grafana /opt/vault; do
        if [[ -d "$dir" ]]; then
            echo "--- $dir ---"
            ls -la "$dir"
            echo ""
        fi
    done
    
    echo "Конфигурационные файлы:"
    for file in /etc/grafana/grafana.ini /opt/vault/conf/data_sec.json; do
        if [[ -f "$file" ]]; then
            echo "--- $file ---"
            head -100 "$file"
            echo ""
        fi
    done
} > "${DIAG_DIR}/05_files.txt"

# 6. Учетные данные Vault
print_info "6. Проверка учетных данных Vault..."
{
    echo "=== УЧЕТНЫЕ ДАННЫЕ VAULT ==="
    CRED_FILE="/opt/vault/conf/data_sec.json"
    if [[ -f "$CRED_FILE" ]]; then
        echo "Файл: $CRED_FILE"
        echo "Размер: $(stat -c%s "$CRED_FILE") байт"
        echo "Права: $(stat -c "%A %U %G" "$CRED_FILE")"
        echo ""
        echo "Содержимое (без паролей):"
        jq 'walk(if type == "object" and (.pass or .password or .secret) then . |= "*****" else . end)' "$CRED_FILE" 2>/dev/null || cat "$CRED_FILE"
        echo ""
        echo "Блок grafana_web:"
        jq '.grafana_web' "$CRED_FILE" 2>/dev/null || echo "Блок не найден"
    else
        echo "Файл не найден: $CRED_FILE"
    fi
} > "${DIAG_DIR}/06_vault_creds.txt"

# 7. Сертификаты
print_info "7. Проверка сертификатов..."
{
    echo "=== СЕРТИФИКАТЫ ==="
    echo "Клиентские сертификаты:"
    for cert in "/opt/vault/certs/grafana-client.crt" "/opt/vault/certs/grafana-client.key"; do
        if [[ -f "$cert" ]]; then
            echo "--- $cert ---"
            echo "Размер: $(stat -c%s "$cert") байт"
            echo "Права: $(stat -c "%A %U %G" "$cert")"
            echo "Первые 200 символов:"
            head -c 200 "$cert"
            echo -e "\n"
        else
            echo "Не найден: $cert"
        fi
    done
} > "${DIAG_DIR}/07_certificates.txt"

# 8. Логи
print_info "8. Сбор логов..."
{
    echo "=== ЛОГИ ==="
    echo "Журнал systemd (последние 100 строк):"
    journalctl -u grafana-server --no-pager -n 100 2>/dev/null || echo "Нет логов systemd"
    echo ""
    echo "Файлы логов Grafana:"
    find /var/log -name "*grafana*" -type f 2>/dev/null | while read logfile; do
        echo "--- $logfile (последние 50 строк) ---"
        tail -n 50 "$logfile" 2>/dev/null || echo "Не удалось прочитать"
        echo ""
    done
} > "${DIAG_DIR}/08_logs.txt"

# 9. Тест API
print_info "9. Тестирование API Grafana..."
{
    echo "=== ТЕСТ API GRAFANA ==="
    
    # Получение учетных данных
    CRED_FILE="/opt/vault/conf/data_sec.json"
    if [[ -f "$CRED_FILE" ]]; then
        USER=$(jq -r '.grafana_web.user // empty' "$CRED_FILE" 2>/dev/null || echo "")
        PASS=$(jq -r '.grafana_web.pass // empty' "$CRED_FILE" 2>/dev/null || echo "")
        
        if [[ -n "$USER" && -n "$PASS" ]]; then
            echo "Учетные данные получены: пользователь=$USER"
            
            # Тестируем разные URL
            for url in "https://localhost:3000" "https://127.0.0.1:3000" "https://$(hostname):3000"; do
                echo "--- Тест $url ---"
                echo "Health check:"
                curl -k -s -w "HTTP: %{http_code}\n" -u "${USER}:${PASS}" "${url}/api/health" 2>&1 || echo "Ошибка"
                echo ""
            done
            
            # Детальный тест localhost
            echo "--- Детальный тест localhost ---"
            echo "1. /api/health:"
            curl -k -v -u "${USER}:${PASS}" "https://localhost:3000/api/health" 2>&1 | head -50
            echo ""
            
            echo "2. /api/serviceaccounts:"
            curl -k -v -u "${USER}:${PASS}" "https://localhost:3000/api/serviceaccounts" 2>&1 | head -50
            echo ""
            
            echo "3. Попытка создания сервисного аккаунта:"
            SA_NAME="diagnostic-sa_${TIMESTAMP}"
            SA_PAYLOAD="{\"name\":\"$SA_NAME\",\"role\":\"Admin\"}"
            curl -k -v -X POST \
                -H "Content-Type: application/json" \
                -u "${USER}:${PASS}" \
                -d "$SA_PAYLOAD" \
                "https://localhost:3000/api/serviceaccounts" 2>&1 | head -100
        else
            echo "Не удалось получить учетные данные"
        fi
    else
        echo "Файл с учетными данными не найден"
    fi
} > "${DIAG_DIR}/09_api_test.txt" 2>&1

# 10. Переменные окружения
print_info "10. Сбор переменных окружения..."
{
    echo "=== ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ ==="
    echo "Все переменные (фильтровано):"
    env | grep -i -E "grafana|prometheus|harvest|vault|monitor" | sort
    echo ""
    echo "Переменные из deploy_monitoring_script.sh:"
    if [[ -f "deploy_monitoring_script.sh" ]]; then
        grep -o "export [A-Z_]*=" deploy_monitoring_script.sh | sort | uniq
    fi
} > "${DIAG_DIR}/10_environment.txt"

# 11. Создание архива
print_info "11. Создание архива диагностики..."
tar -czf "${DIAG_DIR}.tar.gz" -C "$DIAG_DIR" .
chmod 644 "${DIAG_DIR}.tar.gz"

# Итоги
print_success "Диагностика завершена!"
echo ""
echo "📁 Диагностические файлы:"
ls -la "$DIAG_DIR"/*.txt
echo ""
echo "📦 Архив: ${DIAG_DIR}.tar.gz"
echo ""
echo "📋 Содержимое диагностики:"
echo "  01_system_info.txt     - Системная информация"
echo "  02_processes.txt       - Процессы Grafana"
echo "  03_network.txt         - Порты и сеть"
echo "  04_services.txt        - Сервисы systemd"
echo "  05_files.txt           - Файлы и директории"
echo "  06_vault_creds.txt     - Учетные данные Vault"
echo "  07_certificates.txt    - Сертификаты"
echo "  08_logs.txt            - Логи"
echo "  09_api_test.txt        - Тест API"
echo "  10_environment.txt     - Переменные окружения"
echo ""
echo "🚀 Для отправки диагностики:"
echo "  scp '${DIAG_DIR}.tar.gz' user@host:/path/"
echo "  или"
echo "  cat '${DIAG_DIR}.tar.gz' | base64"
echo ""
echo "🔍 Для быстрого просмотра ошибок:"
echo "  grep -i -E 'error|fail|denied|refused|timeout' ${DIAG_DIR}/*.txt"

log "=== ЗАВЕРШЕНИЕ ДИАГНОСТИКИ ==="
log "Архив создан: ${DIAG_DIR}.tar.gz"
log "Размер архива: $(stat -c%s "${DIAG_DIR}.tar.gz") байт"



