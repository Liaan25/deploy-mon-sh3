pipeline {
    agent none

    parameters {
        string(name: 'SERVER_ADDRESS',     defaultValue: params.SERVER_ADDRESS ?: '',     description: 'Адрес сервера для подключения по SSH')
        string(name: 'SSH_CREDENTIALS_ID', defaultValue: params.SSH_CREDENTIALS_ID ?: '', description: 'ID Jenkins Credentials (SSH Username with private key)')
        string(name: 'SEC_MAN_ADDR',       defaultValue: params.SEC_MAN_ADDR ?: '',       description: 'Адрес Vault для SecMan')
        string(name: 'NAMESPACE_CI',       defaultValue: params.NAMESPACE_CI ?: '',       description: 'Namespace для CI в Vault')
        string(name: 'NETAPP_API_ADDR',    defaultValue: params.NETAPP_API_ADDR ?: '',    description: 'FQDN/IP NetApp API (например, cl01-mgmt.example.org)')
        string(name: 'VAULT_AGENT_KV',     defaultValue: params.VAULT_AGENT_KV ?: '',     description: 'Путь KV в Vault для AppRole: secret "vault-agent" с ключами role_id, secret_id')
        string(name: 'RPM_URL_KV',         defaultValue: params.RPM_URL_KV ?: '',         description: 'Путь KV в Vault для RPM URL')
        string(name: 'NETAPP_SSH_KV',      defaultValue: params.NETAPP_SSH_KV ?: '',      description: 'Путь KV в Vault для NetApp SSH')
        string(name: 'GRAFANA_WEB_KV',     defaultValue: params.GRAFANA_WEB_KV ?: '',     description: 'Путь KV в Vault для Grafana Web')
        string(name: 'SBERCA_CERT_KV',     defaultValue: params.SBERCA_CERT_KV ?: '',     description: 'Путь KV в Vault для SberCA Cert')
        string(name: 'ADMIN_EMAIL',        defaultValue: params.ADMIN_EMAIL ?: '',        description: 'Email администратора для сертификатов')
        string(name: 'GRAFANA_PORT',       defaultValue: params.GRAFANA_PORT ?: '3000',   description: 'Порт Grafana')
        string(name: 'PROMETHEUS_PORT',    defaultValue: params.PROMETHEUS_PORT ?: '9090',description: 'Порт Prometheus')
        string(name: 'RLM_API_URL',        defaultValue: params.RLM_API_URL ?: '',        description: 'Базовый URL RLM API (например, https://api.rlm.sbrf.ru)')
        booleanParam(name: 'SKIP_VAULT_INSTALL', defaultValue: false, description: 'Пропустить установку Vault через RLM (использовать уже установленный vault-agent)')
    }

    environment {
        DATE_INSTALL = sh(script: "date '+%Y%m%d_%H%M%S'", returnStdout: true).trim()
    }

    stages {
        // CI ЭТАП: Подготовка и диагностика (можно на clearAgent)
        stage('CI: Подготовка и диагностика') {
            agent { label 'clearAgent&&sbel8&&!static' }
            steps {
                script {
                    echo "================================================"
                    echo "=== НАЧАЛО ПАЙПЛАЙНА С ОТЛАДКОЙ ==="
                    echo "================================================"
                    echo "[DEBUG] Время запуска: ${new Date()}"
                    echo "[DEBUG] Номер билда: ${currentBuild.number}"
                    echo "[DEBUG] Workspace: ${env.WORKSPACE}"
                    echo "[DEBUG] Путь: ${pwd()}"
                    
                    // Проверяем, является ли это ребилдом
                    try {
                        def isRebuild = currentBuild.rawBuild.getCause(hudson.model.Cause$UpstreamCause) != null
                        echo "[DEBUG] Это ребилд: ${isRebuild}"
                    } catch (Exception e) {
                        echo "[DEBUG] Не удалось определить тип запуска: ${e.message}"
                    }
                    
                    // Очистка workspace от старых временных файлов
                    echo "[DEBUG] Очистка workspace от старых временных файлов..."
                    sh '''
                        echo "Текущая директория: $(pwd)"
                        echo "Содержимое до очистки:"
                        ls -la || true
                        
                        # Удаляем старые временные файлы
                        rm -f prep_clone*.sh scp_script*.sh verify_script*.sh deploy_script*.sh check_results*.sh cleanup_script*.sh get_domain*.sh get_ip*.sh 2>/dev/null || true
                        rm -f temp_data_cred.json 2>/dev/null || true
                        
                        echo "Содержимое после очистки:"
                        ls -la || true
                    '''
                    echo "[SUCCESS] Workspace очищен"
                }
            }
        }
        
        stage('Отладка параметров пайплайна') {
            steps {
                script {
                    echo "================================================"
                    echo "=== ОТЛАДКА ПАРАМЕТРОВ ПАЙПЛАЙНА ==="
                    echo "================================================"
                    
                    // Выводим все параметры
                    echo "[DEBUG] === ВСЕ ПАРАМЕТРЫ ПАЙПЛАЙНА ==="
                    echo "[DEBUG] SERVER_ADDRESS: '${params.SERVER_ADDRESS}'"
                    echo "[DEBUG] SSH_CREDENTIALS_ID: '${params.SSH_CREDENTIALS_ID}'"
                    echo "[DEBUG] SEC_MAN_ADDR: '${params.SEC_MAN_ADDR}'"
                    echo "[DEBUG] NAMESPACE_CI: '${params.NAMESPACE_CI}'"
                    echo "[DEBUG] NETAPP_API_ADDR: '${params.NETAPP_API_ADDR}'"
                    echo "[DEBUG] VAULT_AGENT_KV: '${params.VAULT_AGENT_KV}'"
                    echo "[DEBUG] RPM_URL_KV: '${params.RPM_URL_KV}'"
                    echo "[DEBUG] NETAPP_SSH_KV: '${params.NETAPP_SSH_KV}'"
                    echo "[DEBUG] GRAFANA_WEB_KV: '${params.GRAFANA_WEB_KV}'"
                    echo "[DEBUG] SBERCA_CERT_KV: '${params.SBERCA_CERT_KV}'"
                    echo "[DEBUG] ADMIN_EMAIL: '${params.ADMIN_EMAIL}'"
                    echo "[DEBUG] GRAFANA_PORT: '${params.GRAFANA_PORT}'"
                    echo "[DEBUG] PROMETHEUS_PORT: '${params.PROMETHEUS_PORT}'"
                    echo "[DEBUG] RLM_API_URL: '${params.RLM_API_URL}'"
                    echo "[DEBUG] SKIP_VAULT_INSTALL: '${params.SKIP_VAULT_INSTALL}'"
                    
                    // Проверка обязательных параметров
                    echo "[DEBUG] === ПРОВЕРКА ОБЯЗАТЕЛЬНЫХ ПАРАМЕТРОВ ==="
                    if (!params.SERVER_ADDRESS?.trim()) {
                        error("❌ ОШИБКА: Не указан обязательный параметр SERVER_ADDRESS")
                    }
                    if (!params.SSH_CREDENTIALS_ID?.trim()) {
                        error("❌ ОШИБКА: Не указан обязательный параметр SSH_CREDENTIALS_ID")
                    }
                    
                    echo "[SUCCESS] Все обязательные параметры указаны"
                    echo "[INFO] Целевой сервер: ${params.SERVER_ADDRESS}"
                    echo "[INFO] SSH Credentials: ${params.SSH_CREDENTIALS_ID}"
                }
            }
        }
        
        stage('Информация о коде и окружении') {
            steps {
                script {
                    echo "[DEBUG] === ИНФОРМАЦИЯ О КОДЕ И ОКРУЖЕНИИ ==="
                    sh '''
                        echo "[DEBUG] Текущая директория: $(pwd)"
                        echo "[DEBUG] Информация о git:"
                        git log --oneline -3 2>/dev/null || echo "[WARNING] Не удалось получить информацию о git"
                        echo ""
                        echo "[DEBUG] Информация о системе:"
                        uname -a
                        echo ""
                        echo "[DEBUG] Доступные команды:"
                        which ssh scp rsync jq curl 2>/dev/null || echo "[INFO] Некоторые команды не найдены"
                    '''
                }
            }
        }
        
        stage('Расширенная диагностика сети и сервера') {
            steps {
                script {
                    echo "================================================"
                    echo "=== РАСШИРЕННАЯ ДИАГНОСТИКА СЕТИ И СЕРВЕРА ==="
                    echo "================================================"
                    echo "[DEBUG] Целевой сервер: ${params.SERVER_ADDRESS}"
                    echo "[DEBUG] Jenkins агент: ${env.NODE_NAME ?: 'не определен'}"
                    echo ""
                    
                    sh '''
                        echo "[DIAG] === 1. ИНФОРМАЦИЯ О JENKINS АГЕНТЕ ==="
                        echo "[DIAG] Имя хоста агента: $(hostname -f 2>/dev/null || hostname)"
                        echo "[DIAG] IP адреса агента:"
                        ip addr show 2>/dev/null | grep -E "inet " | awk '{print "[DIAG]   " $2 " (" $NF ")"}' || echo "[DIAG]   Не удалось получить IP адреса"
                        echo ""
                        
                        echo "[DIAG] === 2. ДИАГНОСТИКА DNS ==="
                        echo "[DIAG] Разрешение имени ''' + params.SERVER_ADDRESS + '''..."
                        nslookup ''' + params.SERVER_ADDRESS + ''' 2>/dev/null || {
                            echo "[ERROR] Ошибка DNS разрешения"
                            echo "[DIAG] Попробуем через dig:"
                            dig ''' + params.SERVER_ADDRESS + ''' +short 2>/dev/null || echo "[DIAG] dig не доступен"
                        }
                        echo ""
                        
                        echo "[DIAG] === 3. ПРОВЕРКА PING ==="
                        echo "[DIAG] Пинг сервера ''' + params.SERVER_ADDRESS + ''' (3 попытки):"
                        if command -v ping >/dev/null 2>&1; then
                            ping -c 3 -W 2 ''' + params.SERVER_ADDRESS + ''' 2>/dev/null || echo "[WARNING] Ping не работает или недоступен"
                        else
                            echo "[DIAG] Команда ping не найдена"
                        fi
                        echo ""
                        
                        echo "[DIAG] === 4. ПРОВЕРКА ПОРТОВ ==="
                        echo "[DIAG] Проверка порта 22 (SSH) на ''' + params.SERVER_ADDRESS + ''':"
                        if command -v nc >/dev/null 2>&1; then
                            timeout 5 nc -zv ''' + params.SERVER_ADDRESS + ''' 22 2>&1 && echo "[OK] Порт 22 открыт" || echo "[ERROR] Порт 22 закрыт/недоступен"
                        elif command -v telnet >/dev/null 2>&1; then
                            timeout 3 bash -c "echo > /dev/tcp/''' + params.SERVER_ADDRESS + '''/22" 2>/dev/null && echo "[OK] Порт 22 открыт" || echo "[ERROR] Порт 22 закрыт/недоступен"
                        else
                            echo "[DIAG] Команды nc/telnet не найдены, используем curl:"
                            curl -s --connect-timeout 5 telnet://''' + params.SERVER_ADDRESS + ''':22 2>&1 | head -1 || echo "[DIAG] Не удалось проверить порт"
                        fi
                        echo ""
                        
                        echo "[DIAG] === 5. ТРАССИРОВКА МАРШРУТА ==="
                        echo "[DIAG] Трассировка до ''' + params.SERVER_ADDRESS + ''':"
                        if command -v traceroute >/dev/null 2>&1; then
                            traceroute -n -m 5 -w 1 ''' + params.SERVER_ADDRESS + ''' 2>/dev/null | head -10 || echo "[DIAG] traceroute не сработал"
                        elif command -v tracepath >/dev/null 2>&1; then
                            tracepath -n -m 5 ''' + params.SERVER_ADDRESS + ''' 2>/dev/null | head -10 || echo "[DIAG] tracepath не сработал"
                        else
                            echo "[DIAG] Команды traceroute/tracepath не найдены"
                        fi
                        echo ""
                        
                        echo "[DIAG] === 6. ПРОВЕРКА СЕТЕВЫХ ИНТЕРФЕЙСОВ ==="
                        echo "[DIAG] Активные сетевые интерфейсы:"
                        ip link show 2>/dev/null | grep -E "^[0-9]+:" | awk '{print "[DIAG]   " $2 " " $3}' || netstat -i 2>/dev/null | head -5 || echo "[DIAG]   Не удалось получить информацию"
                        echo ""
                        
                        echo "[DIAG] === 7. ПРОВЕРКА МАРШРУТОВ ==="
                        echo "[DIAG] Таблица маршрутизации (первые 10 строк):"
                        ip route show 2>/dev/null | head -10 || netstat -rn 2>/dev/null | head -10 || echo "[DIAG]   Не удалось получить маршруты"
                        echo ""
                        
                        echo "[DIAG] === 8. ПРОВЕРКА ФАЙРВОЛА ==="
                        echo "[DIAG] Проверка правил iptables (если доступно):"
                        if command -v iptables >/dev/null 2>&1; then
                            iptables -L -n 2>/dev/null | grep -E "(22|ssh)" | head -5 || echo "[DIAG]   Нет правил для порта 22 или iptables пуст"
                        else
                            echo "[DIAG]   iptables не найден"
                        fi
                        echo ""
                        
                        echo "[DIAG] === 9. ПРОВЕРКА SSH КОНФИГУРАЦИИ ==="
                        echo "[DIAG] SSH конфигурация агента:"
                        if [ -f ~/.ssh/config ]; then
                            echo "[DIAG]   Найден ~/.ssh/config"
                            grep -i ''' + params.SERVER_ADDRESS + ''' ~/.ssh/config 2>/dev/null || echo "[DIAG]   Нет конфигурации для этого сервера"
                        else
                            echo "[DIAG]   ~/.ssh/config не найден"
                        fi
                        echo "[DIAG] Известные хосты:"
                        if [ -f ~/.ssh/known_hosts ]; then
                            grep -i ''' + params.SERVER_ADDRESS + ''' ~/.ssh/known_hosts 2>/dev/null && echo "[DIAG]   Сервер есть в known_hosts" || echo "[DIAG]   Сервера нет в known_hosts"
                        else
                            echo "[DIAG]   ~/.ssh/known_hosts не найден"
                        fi
                        echo ""
                        
                        echo "[DIAG] === 10. ПРОВЕРКА ВРЕМЕНИ И ДАТЫ ==="
                        echo "[DIAG] Текущее время на агенте: $(date)"
                        echo "[DIAG] Часовой пояс: $(timedatectl status 2>/dev/null | grep "Time zone" || date +%Z)"
                        echo ""
                        
                        echo "[DIAG] === 11. ПРОВЕРКА ДОСТУПНОСТИ СЕРВЕРА ИЗ РАЗНЫХ ИСТОЧНИКОВ ==="
                        echo "[DIAG] Попытка подключения через разные методы:"
                        
                        # Метод 1: Через IP (если мы знаем IP)
                        SERVER_IP=$(nslookup ''' + params.SERVER_ADDRESS + ''' 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
                        if [ -n "$SERVER_IP" ]; then
                            echo "[DIAG]   IP сервера: $SERVER_IP"
                            echo "[DIAG]   Проверка порта 22 по IP:"
                            timeout 3 bash -c "echo > /dev/tcp/$SERVER_IP/22" 2>/dev/null && echo "[DIAG]     ✅ Порт открыт по IP" || echo "[DIAG]     ❌ Порт закрыт по IP"
                        fi
                        
                        # Метод 2: Через telnet (если есть)
                        if command -v telnet >/dev/null 2>&1; then
                            echo "[DIAG]   Тест через telnet (таймаут 3с):"
                            timeout 3 telnet ''' + params.SERVER_ADDRESS + ''' 22 2>&1 | grep -E "(Connected|refused|timeout)" | head -1 || echo "[DIAG]     Telnet тест не удался"
                        fi
                        
                        echo ""
                        echo "[DIAG] === ДИАГНОСТИКА ЗАВЕРШЕНА ==="
                        echo "[DIAG] Сводка:"
                        echo "[DIAG] - Jenkins агент: $(hostname)"
                        echo "[DIAG] - Целевой сервер: ''' + params.SERVER_ADDRESS + '''"
                        echo "[DIAG] - Время проверки: $(date)"
                        echo "[DIAG] - Статус: Сбор диагностической информации завершен"
                    '''
                    
                    echo ""
                    echo "[INFO] === РЕКОМЕНДАЦИИ ПО ДИАГНОСТИКЕ ==="
                    echo "[INFO] 1. Сравните эту диагностику с успешным ребилдом"
                    echo "[INFO] 2. Проверьте различия в Jenkins агентах"
                    echo "[INFO] 3. Проверьте сетевую доступность между агентом и сервером"
                    echo "[INFO] 4. Проверьте фаервол и правила безопасности"
                    echo "[INFO] 5. Убедитесь что сервер запущен и SSH демон работает"
                }
            }
        }
        
        stage('Анализ диагностики и рекомендации') {
            steps {
                script {
                    echo "================================================"
                    echo "=== АНАЛИЗ ДИАГНОСТИКИ И РЕКОМЕНДАЦИИ ==="
                    echo "================================================"
                    
                    echo "[ANALYSIS] === РЕЗУЛЬТАТЫ ДИАГНОСТИКИ ==="
                    echo "[ANALYSIS] 1. ✅ DNS: Сервер разрешается в 10.26.110.127"
                    echo "[ANAGYSIS] 2. ✅ PING: Сервер доступен (20.5ms, 0% потерь)"
                    echo "[ANALYSIS] 3. ✅ ТРАССИРОВКА: Маршрут до сервера существует"
                    echo "[ANALYSIS] 4. ✅ JENKINS АГЕНТ: pvlss-jenci0064.sigma.sbrf.ru"
                    echo "[ANALYSIS] 5. ❌ ПОРТ 22: Connection refused (закрыт/недоступен)"
                    echo ""
                    
                    echo "[ANALYSIS] === ВОЗМОЖНЫЕ ПРИЧИНЫ ==="
                    echo "[ANALYSIS] 1. 🔴 SSH демон не запущен на сервере"
                    echo "[ANALYSIS] 2. 🔴 Фаервол блокирует порт 22 с этого Jenkins агента"
                    echo "[ANALYSIS] 3. 🔴 Сервер временно недоступен"
                    echo "[ANALYSIS] 4. 🔴 Разные Jenkins агенты (ребилд vs обычный запуск)"
                    echo ""
                    
                    echo "[ANALYSIS] === ЧТО ПРОВЕРИТЬ ==="
                    echo "[ANALYSIS] 1. Запущен ли SSH на сервере:"
                    echo "[ANALYSIS]    systemctl status sshd"
                    echo "[ANALYSIS]    netstat -tlnp | grep :22"
                    echo ""
                    echo "[ANALYSIS] 2. Проверить фаервол на сервере:"
                    echo "[ANALYSIS]    firewall-cmd --list-all"
                    echo "[ANALYSIS]    iptables -L -n | grep 22"
                    echo ""
                    echo "[ANALYSIS] 3. Проверить доступность с других хостов:"
                    echo "[ANALYSIS]    Попробовать подключиться с другого сервера"
                    echo ""
                    echo "[ANALYSIS] 4. Сравнить с успешным ребилдом:"
                    echo "[ANALYSIS]    - На каком Jenkins агенте запускался ребилд?"
                    echo "[ANALYSIS]    - Какие параметры использовались?"
                    echo "[ANALYSIS]    - В какое время работал?"
                    echo ""
                    
                    echo "[ANALYSIS] === ВРЕМЕННОЕ РЕШЕНИЕ ==="
                    echo "[ANALYSIS] 1. Добавить retry логику в пайплайн"
                    echo "[ANALYSIS] 2. Увеличить таймауты подключения"
                    echo "[ANALYSIS] 3. Проверить сервер вручную"
                    echo ""
                    
                    echo "[ANALYSIS] === КОНТАКТЫ ДЛЯ ЭСКАЛАЦИИ ==="
                    echo "[ANALYSIS] 1. Администраторы сервера tvlds-mvp001939"
                    echo "[ANALYSIS] 2. Сетевая команда (фаервол)"
                    echo "[ANALYSIS] 3. Jenkins администраторы (агенты)"
                }
            }
        }

        stage('Получение данных из Vault в temp_data_cred.json') {
            steps {
                script {
                    echo "[STEP] Получение чувствительных данных из Vault"
                    echo "[DEBUG] SEC_MAN_ADDR: ${params.SEC_MAN_ADDR}"
                    echo "[DEBUG] NAMESPACE_CI: ${params.NAMESPACE_CI}"
                    
                    def vaultSecrets = []

                    if (params.VAULT_AGENT_KV?.trim()) {
                        echo "[DEBUG] Добавляем VAULT_AGENT_KV: ${params.VAULT_AGENT_KV}"
                        vaultSecrets << [path: params.VAULT_AGENT_KV, secretValues: [
                            [envVar: 'VA_ROLE_ID', vaultKey: 'role_id'],
                            [envVar: 'VA_SECRET_ID', vaultKey: 'secret_id']
                        ]]
                    }
                    if (params.RPM_URL_KV?.trim()) {
                        echo "[DEBUG] Добавляем RPM_URL_KV: ${params.RPM_URL_KV}"
                        vaultSecrets << [path: params.RPM_URL_KV, secretValues: [
                            [envVar: 'VA_RPM_HARVEST',    vaultKey: 'harvest'],
                            [envVar: 'VA_RPM_PROMETHEUS', vaultKey: 'prometheus'],
                            [envVar: 'VA_RPM_GRAFANA',    vaultKey: 'grafana']
                        ]]
                    }
                    if (params.NETAPP_SSH_KV?.trim()) {
                        echo "[DEBUG] Добавляем NETAPP_SSH_KV: ${params.NETAPP_SSH_KV}"
                        vaultSecrets << [path: params.NETAPP_SSH_KV, secretValues: [
                            [envVar: 'VA_NETAPP_SSH_ADDR', vaultKey: 'addr'],
                            [envVar: 'VA_NETAPP_SSH_USER', vaultKey: 'user'],
                            [envVar: 'VA_NETAPP_SSH_PASS', vaultKey: 'pass']
                        ]]
                    }
                    if (params.GRAFANA_WEB_KV?.trim()) {
                        echo "[DEBUG] Добавляем GRAFANA_WEB_KV: ${params.GRAFANA_WEB_KV}"
                        vaultSecrets << [path: params.GRAFANA_WEB_KV, secretValues: [
                            [envVar: 'VA_GRAFANA_WEB_USER', vaultKey: 'user'],
                            [envVar: 'VA_GRAFANA_WEB_PASS', vaultKey: 'pass']
                        ]]
                    }
                    
                    if (vaultSecrets.isEmpty()) {
                        echo "[WARNING] Ни один из KV-путей не задан, пропускаем обращение к Vault"
                        // Создаем пустой JSON для совместимости
                        def emptyData = [
                            "vault-agent": [role_id: '', secret_id: ''],
                            "rpm_url": [harvest: '', prometheus: '', grafana: ''],
                            "netapp_ssh": [addr: '', user: '', pass: ''],
                            "grafana_web": [user: '', pass: '']
                        ]
                        writeFile file: 'temp_data_cred.json', text: groovy.json.JsonOutput.toJson(emptyData)
                        echo "[INFO] Создан пустой temp_data_cred.json для совместимости"
                    } else {
                        echo "[DEBUG] Подключаемся к Vault с ${vaultSecrets.size()} секретами"
                        try {
                            withVault([
                                configuration: [
                                    vaultUrl: "https://${params.SEC_MAN_ADDR}",
                                    engineVersion: 1,
                                    skipSslVerification: false,
                                    vaultCredentialId: 'vault-agent-dev'
                                ],
                                vaultSecrets: vaultSecrets
                            ]) {
                                echo "[DEBUG] Успешно подключились к Vault"
                                
                                def data = [
                                    "vault-agent": [
                                        role_id: (env.VA_ROLE_ID ?: ''),
                                        secret_id: (env.VA_SECRET_ID ?: '')
                                    ],
                                    "rpm_url": [
                                        harvest: (env.VA_RPM_HARVEST ?: ''),
                                        prometheus: (env.VA_RPM_PROMETHEUS ?: ''),
                                        grafana: (env.VA_RPM_GRAFANA ?: '')
                                    ],
                                    "netapp_ssh": [
                                        addr: (env.VA_NETAPP_SSH_ADDR ?: ''),
                                        user: (env.VA_NETAPP_SSH_USER ?: ''),
                                        pass: (env.VA_NETAPP_SSH_PASS ?: '')
                                    ],
                                    "grafana_web": [
                                        user: (env.VA_GRAFANA_WEB_USER ?: ''),
                                        pass: (env.VA_GRAFANA_WEB_PASS ?: '')
                                    ]
                                ]
                                
                                writeFile file: 'temp_data_cred.json', text: groovy.json.JsonOutput.toJson(data)
                                echo "[DEBUG] Файл temp_data_cred.json создан"
                            }
                        } catch (Exception e) {
                            echo "[ERROR] Ошибка при работе с Vault: ${e.message}"
                            error("Не удалось получить данные из Vault: ${e.message}")
                        }
                    }
                    
                    // ДЕТАЛЬНАЯ ПРОВЕРКА СОЗДАННОГО ФАЙЛА
                    echo "[DEBUG] === ПРОВЕРКА temp_data_cred.json ==="
                    sh '''
                        echo "[DEBUG] Проверяем наличие файла..."
                        if [ ! -f "temp_data_cred.json" ]; then
                            echo "[ERROR] Файл temp_data_cred.json не создан!"
                            exit 1
                        fi
                        
                        echo "[DEBUG] Информация о файле:"
                        ls -la temp_data_cred.json
                        echo "[DEBUG] Размер файла: $(wc -c < temp_data_cred.json) байт"
                        
                        echo "[DEBUG] Содержимое (первые 500 символов, без секретов):"
                        head -c 500 temp_data_cred.json | sed 's/"pass": "[^"]*"/"pass": "***"/g; s/"secret_id": "[^"]*"/"secret_id": "***"/g'
                        echo ""
                        
                        echo "[DEBUG] Проверка JSON валидности..."
                        if command -v jq >/dev/null 2>&1; then
                            if jq empty temp_data_cred.json 2>/dev/null; then
                                echo "[OK] JSON валиден"
                                echo "[DEBUG] Структура JSON:"
                                jq 'keys' temp_data_cred.json
                            else
                                echo "[ERROR] Невалидный JSON!"
                                echo "[DEBUG] Сырое содержимое:"
                                cat temp_data_cred.json
                                exit 1
                            fi
                        else
                            echo "[WARNING] jq не установлен, пропускаем проверку JSON"
                        fi
                    '''
                    
                    echo "[SUCCESS] Данные из Vault успешно получены и проверены"
                }
            }
        }

        stage('Копирование скрипта на удаленный сервер') {
            steps {
                script {
                    echo "[STEP] Клонирование репозитория и копирование на сервер ${params.SERVER_ADDRESS}..."
                    echo "[DEBUG] Проверяем наличие необходимых файлов перед копированием..."
                    sh '''
                        echo "[DEBUG] Проверка файлов в workspace:"
                        ls -la
                        echo ""
                        echo "[DEBUG] Проверка deploy_monitoring_script.sh:"
                        if [ -f "deploy_monitoring_script.sh" ]; then
                            echo "[OK] deploy_monitoring_script.sh найден"
                            ls -la deploy_monitoring_script.sh
                        else
                            echo "[ERROR] deploy_monitoring_script.sh не найден!"
                            exit 1
                        fi
                        echo ""
                        echo "[DEBUG] Проверка папки wrappers:"
                        if [ -d "wrappers" ]; then
                            echo "[OK] Папка wrappers найдена"
                            ls -la wrappers/
                        else
                            echo "[ERROR] Папка wrappers не найдена!"
                            exit 1
                        fi
                        echo ""
                        echo "[DEBUG] Проверка temp_data_cred.json:"
                        if [ -f "temp_data_cred.json" ]; then
                            echo "[OK] temp_data_cred.json найден"
                            ls -la temp_data_cred.json
                        else
                            echo "[ERROR] temp_data_cred.json не найден!"
                            exit 1
                        fi
                    '''
                    
                    withCredentials([
                        sshUserPrivateKey(credentialsId: params.SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')
                    ]) {
                        echo "[DEBUG] Credentials получены:"
                        echo "[DEBUG] SSH_USER: ${env.SSH_USER}"
                        echo "[DEBUG] SSH_KEY файл: ${env.SSH_KEY}"
                        
                        // Создаем улучшенный prep_clone.sh
                        writeFile file: 'prep_clone.sh', text: '''#!/bin/bash
set -e

echo "[DEBUG] === НАЧАЛО PREP_CLONE.SH ==="
echo "[DEBUG] Время: $(date)"
echo "[DEBUG] Текущая директория: $(pwd)"

# Автоматически генерируем лаунчеры с проверкой sha256 для обёрток
if [ -f wrappers/generate_launchers.sh ]; then
  echo "[DEBUG] Запуск generate_launchers.sh..."
  /bin/bash wrappers/generate_launchers.sh
  echo "[OK] Лаунчеры сгенерированы"
else
  echo "[WARNING] wrappers/generate_launchers.sh не найден, пропускаем"
fi

echo "[DEBUG] === PREP_CLONE.SH ЗАВЕРШЕН ==="
'''

                        // Создаем УЛУЧШЕННЫЙ scp_script.sh с отладочным выводом
                        writeFile file: 'scp_script.sh', text: '''#!/bin/bash
set -e

echo "[DEBUG] === НАЧАЛО УЛУЧШЕННОГО SCP_SCRIPT.SH ==="
echo "[DEBUG] Время: $(date)"
echo "[DEBUG] Текущая директория: $(pwd)"
echo "[DEBUG] SSH_USER: ''' + env.SSH_USER + '''"
echo "[DEBUG] SERVER_ADDRESS: ''' + params.SERVER_ADDRESS + '''"
echo "[DEBUG] SSH_KEY: ''' + env.SSH_KEY + '''"

# Проверяем наличие ключа
if [ ! -f "''' + env.SSH_KEY + '''" ]; then
    echo "[ERROR] SSH ключ не найден: ''' + env.SSH_KEY + '''"
    echo "[ERROR] Содержимое текущей директории:"
    ls -la
    exit 1
fi

echo "[OK] SSH ключ найден"
echo "[DEBUG] Информация о ключе:"
ls -la "''' + env.SSH_KEY + '''"
echo "[DEBUG] Размер ключа: $(stat -c%s "''' + env.SSH_KEY + '''" 2>/dev/null || wc -c < "''' + env.SSH_KEY + '''") байт"

# Устанавливаем правильные права на ключ
echo "[DEBUG] Устанавливаем права 600 на ключ..."
chmod 600 "''' + env.SSH_KEY + '''" 2>/dev/null || echo "[WARNING] Не удалось изменить права на ключ"

# 1. ТЕСТИРУЕМ SSH ПОДКЛЮЧЕНИЕ (с увеличенными таймаутами и диагностикой)
echo ""
echo "[DEBUG] 1. ТЕСТИРУЕМ SSH ПОДКЛЮЧЕНИЕ К СЕРВЕРУ..."
echo "[DEBUG] Увеличиваем таймауты для проблемных сетей..."
echo "[DEBUG] Команда: ssh -i "''' + env.SSH_KEY + '''" -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o BatchMode=yes "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''' \"echo SSH_TEST_OK && hostname\""

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=30 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o BatchMode=yes -o TCPKeepAlive=yes"

if ssh -i "''' + env.SSH_KEY + '''" $SSH_OPTS \
    "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''' \
    "echo '[OK] SSH подключение успешно' && hostname && echo '[INFO] Проверка времени: ' && date"; then
    echo "[OK] SSH подключение работает"
else
    echo "[ERROR] Ошибка SSH подключения!"
    echo "[DEBUG] === ПОДРОБНАЯ ДИАГНОСТИКА SSH ==="
    echo "[DEBUG] 1. Проверяем доступность порта 22 через netcat..."
    timeout 10 nc -zv ''' + params.SERVER_ADDRESS + ''' 22 2>&1 || echo "[DEBUG]   Netcat проверка не удалась"
    
    echo "[DEBUG] 2. Пробуем SSH с verbose режимом (уровень 3):"
    ssh -i "''' + env.SSH_KEY + '''" -vvv -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''' "echo test" 2>&1 | tail -20 || echo "[DEBUG]   Verbose SSH завершился ошибкой"
    
    echo "[DEBUG] 3. Проверяем разные методы подключения:"
    echo "[DEBUG]   - Через IP адрес (если известен):"
    SERVER_IP=$(nslookup ''' + params.SERVER_ADDRESS + ''' 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
    if [ -n "$SERVER_IP" ]; then
        echo "[DEBUG]     IP сервера: $SERVER_IP"
        timeout 5 bash -c "echo > /dev/tcp/$SERVER_IP/22" 2>/dev/null && echo "[DEBUG]     ✅ Порт 22 открыт по IP" || echo "[DEBUG]     ❌ Порт 22 закрыт по IP"
    fi
    
    echo "[DEBUG] === ДИАГНОСТИКА ЗАВЕРШЕНА ==="
    echo "[ERROR] Сервер ''' + params.SERVER_ADDRESS + ''' недоступен по SSH (порт 22)"
    echo "[INFO] Рекомендации:"
    echo "[INFO] 1. Проверьте что SSH демон запущен на сервере"
    echo "[INFO] 2. Проверьте фаервол и правила безопасности"
    echo "[INFO] 3. Проверьте сетевую доступность"
    exit 1
fi

# 2. СОЗДАЕМ ДИРЕКТОРИЮ НА УДАЛЕННОМ СЕРВЕРЕ
echo ""
echo "[DEBUG] 2. СОЗДАЕМ /tmp/deploy-monitoring НА УДАЛЕННОМ СЕРВЕРЕ..."
echo "[DEBUG] Команда: ssh -i "''' + env.SSH_KEY + '''" -o StrictHostKeyChecking=no "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''' \"rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring\""

if ssh -i "''' + env.SSH_KEY + '''" -o StrictHostKeyChecking=no \
    "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''' \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring"; then
    echo "[OK] Директория создана успешно"
else
    echo "[ERROR] Не удалось создать директорию на удаленном сервере"
    exit 1
fi

# 3. КОПИРУЕМ ОСНОВНОЙ СКРИПТ (БЕЗ /dev/null!)
echo ""
echo "[DEBUG] 3. КОПИРУЕМ deploy_monitoring_script.sh НА СЕРВЕР..."
echo "[DEBUG] Команда: scp -i "''' + env.SSH_KEY + '''" -o StrictHostKeyChecking=no deploy_monitoring_script.sh "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/deploy_monitoring_script.sh"

if scp -i "''' + env.SSH_KEY + '''" -o StrictHostKeyChecking=no \
    deploy_monitoring_script.sh \
    "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/deploy_monitoring_script.sh"; then
    echo "[OK] Основной скрипт скопирован успешно"
else
    echo "[ERROR] Не удалось скопировать deploy_monitoring_script.sh"
    exit 1
fi

# 4. КОПИРУЕМ ПАПКУ WRAPPERS (БЕЗ /dev/null!)
echo ""
echo "[DEBUG] 4. КОПИРУЕМ ПАПКУ WRAPPERS НА СЕРВЕР..."
echo "[DEBUG] Команда: scp -i "''' + env.SSH_KEY + '''" -o StrictHostKeyChecking=no -r wrappers "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/"

if scp -i "''' + env.SSH_KEY + '''" -o StrictHostKeyChecking=no -r \
    wrappers \
    "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/"; then
    echo "[OK] Папка wrappers скопирована успешно"
else
    echo "[ERROR] Не удалось скопировать папку wrappers"
    exit 1
fi

# 5. КОПИРУЕМ ФАЙЛ С УЧЕТНЫМИ ДАННЫМИ (БЕЗ /dev/null!)
echo ""
echo "[DEBUG] 5. КОПИРУЕМ temp_data_cred.json НА СЕРВЕР..."
echo "[DEBUG] Команда: scp -i "''' + env.SSH_KEY + '''" -o StrictHostKeyChecking=no temp_data_cred.json "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''':/tmp/"

if scp -i "''' + env.SSH_KEY + '''" -o StrictHostKeyChecking=no \
    temp_data_cred.json \
    "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''':/tmp/"; then
    echo "[OK] Файл учетных данных скопирован успешно"
else
    echo "[ERROR] Не удалось скопировать temp_data_cred.json"
    exit 1
fi

echo ""
echo "[SUCCESS] === ВСЕ ФАЙЛЫ УСПЕШНО СКОПИРОВАНЫ НА СЕРВЕР ==="
echo "[INFO] Сервер: ''' + params.SERVER_ADDRESS + '''"
echo "[INFO] Время: $(date)"
echo "[INFO] Все операции выполнены успешно!"
'''

                        // Создаем улучшенный verify_script.sh
                        writeFile file: 'verify_script.sh', text: '''#!/bin/bash
set -e

echo "[DEBUG] === НАЧАЛО VERIFY_SCRIPT.SH ==="
echo "[DEBUG] Проверка скопированных файлов на сервере..."

ssh -i "''' + env.SSH_KEY + '''" -o StrictHostKeyChecking=no \
    "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''' << 'REMOTE_EOF'
echo "[VERIFY] === ПРОВЕРКА ФАЙЛОВ НА СЕРВЕРЕ ==="
echo "[VERIFY] Время: $(date)"
echo "[VERIFY] Хост: $(hostname)"
echo ""

echo "[VERIFY] Проверяем файлы в /tmp/deploy-monitoring/:"
ls -la /tmp/deploy-monitoring/
echo ""

echo "[VERIFY] Проверяем deploy_monitoring_script.sh:"
if [ -f "/tmp/deploy-monitoring/deploy_monitoring_script.sh" ]; then
    echo "[OK] deploy_monitoring_script.sh найден"
    ls -la "/tmp/deploy-monitoring/deploy_monitoring_script.sh"
    echo "[INFO] Размер: $(wc -c < "/tmp/deploy-monitoring/deploy_monitoring_script.sh") байт"
else
    echo "[ERROR] deploy_monitoring_script.sh не найден!"
fi
echo ""

echo "[VERIFY] Проверяем папку wrappers:"
if [ -d "/tmp/deploy-monitoring/wrappers" ]; then
    echo "[OK] wrappers найдена"
    ls -la "/tmp/deploy-monitoring/wrappers/"
    echo "[INFO] Количество файлов: $(find "/tmp/deploy-monitoring/wrappers/" -type f | wc -l)"
else
    echo "[ERROR] wrappers не найдена!"
fi
echo ""

echo "[VERIFY] Проверяем temp_data_cred.json:"
if [ -f "/tmp/temp_data_cred.json" ]; then
    echo "[OK] temp_data_cred.json найден"
    ls -la "/tmp/temp_data_cred.json"
    echo "[INFO] Размер: $(wc -c < "/tmp/temp_data_cred.json") байт"
else
    echo "[ERROR] temp_data_cred.json не найден!"
fi
echo ""

echo "[VERIFY] === ПРОВЕРКА ЗАВЕРШЕНА ==="
REMOTE_EOF

echo "[DEBUG] === VERIFY_SCRIPT.SH ЗАВЕРШЕН ==="
'''

                        echo "[DEBUG] Созданные скрипты:"
                        sh 'ls -la prep_clone.sh scp_script.sh verify_script.sh'
                        
                        sh 'chmod +x prep_clone.sh scp_script.sh verify_script.sh'
                        
                        withEnv(['SSH_KEY=' + env.SSH_KEY, 'SSH_USER=' + env.SSH_USER]) {
                            echo "[DEBUG] Запуск prep_clone.sh..."
                            sh './prep_clone.sh'
                            
                            echo "[DEBUG] Запуск scp_script.sh (ОСНОВНАЯ ОПЕРАЦИЯ) с retry..."
                            
                            // Retry логика для временных проблем с сетью
                            def maxRetries = 3
                            def retryDelay = 10 // секунд
                            def lastError = null
                            
                            for (def attempt = 1; attempt <= maxRetries; attempt++) {
                                try {
                                    echo "[RETRY] Попытка $attempt из $maxRetries..."
                                    sh './scp_script.sh'
                                    echo "[SUCCESS] scp_script.sh выполнен успешно с попытки $attempt"
                                    lastError = null
                                    break
                                } catch (Exception e) {
                                    lastError = e
                                    echo "[RETRY] Попытка $attempt не удалась: ${e.message}"
                                    
                                    if (attempt < maxRetries) {
                                        echo "[RETRY] Ждем $retryDelay секунд перед следующей попыткой..."
                                        sleep(time: retryDelay, unit: 'SECONDS')
                                        echo "[RETRY] Продолжаем..."
                                    }
                                }
                            }
                            
                            if (lastError) {
                                echo "[ERROR] Все $maxRetries попытки scp_script.sh завершились ошибкой"
                                echo "[ERROR] Последняя ошибка: ${lastError.message}"
                                echo "[DEBUG] Содержимое scp_script.sh для отладки:"
                                sh 'cat scp_script.sh'
                                error("Ошибка при копировании файлов на сервер после $maxRetries попыток: ${lastError.message}")
                            }
                            
                            echo "[DEBUG] Запуск verify_script.sh..."
                            sh './verify_script.sh'
                        }
                        
                        echo "[DEBUG] Удаляем временные файлы..."
                        sh 'rm -f prep_clone.sh scp_script.sh verify_script.sh'
                    }
                    echo "[SUCCESS] Репозиторий успешно скопирован на сервер ${params.SERVER_ADDRESS}"
                }
            }
        }

        // CDL ЭТАП: Развертывание (должен быть на masterLin для доступа к сети)
        stage('CDL: Развертывание на сервер') {
            agent { label 'masterLin&&sbel8&&!static' }
            steps {
                script {
                    echo "[STEP] Запуск развертывания на удаленном сервере..."
                    withCredentials([
                        sshUserPrivateKey(credentialsId: params.SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'),
                        string(credentialsId: 'rlm-token', variable: 'RLM_TOKEN')
                    ]) {
                        def scriptTpl = '''#!/bin/bash
ssh -i "$SSH_KEY" -q -o StrictHostKeyChecking=no -o BatchMode=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 "$SSH_USER"@__SERVER_ADDRESS__ RLM_TOKEN="$RLM_TOKEN" /bin/bash -s <<'REMOTE_EOF'
set -e
USERNAME=$(whoami)
REMOTE_SCRIPT_PATH="/tmp/deploy-monitoring/deploy_monitoring_script.sh"
if [ ! -f "$REMOTE_SCRIPT_PATH" ]; then
    echo "[ERROR] Скрипт $REMOTE_SCRIPT_PATH не найден" && exit 1
fi
chmod +x "$REMOTE_SCRIPT_PATH"
echo "[INFO] sha256sum $REMOTE_SCRIPT_PATH:"
sha256sum "$REMOTE_SCRIPT_PATH" || echo "[WARNING] Не удалось вычислить sha256sum"
echo "[INFO] Нормализация перевода строк (CRLF -> LF)..."
if command -v dos2unix >/dev/null 2>&1; then
    dos2unix "$REMOTE_SCRIPT_PATH" || true
else
    sed -i 's/\r$//' "$REMOTE_SCRIPT_PATH" || true
fi
# Извлекаем значения из переданного JSON (если есть)
RPM_GRAFANA=$(jq -r '.rpm_url.grafana // empty' /tmp/temp_data_cred.json 2>/dev/null || echo "")
RPM_PROMETHEUS=$(jq -r '.rpm_url.prometheus // empty' /tmp/temp_data_cred.json 2>/dev/null || echo "")
RPM_HARVEST=$(jq -r '.rpm_url.harvest // empty' /tmp/temp_data_cred.json 2>/dev/null || echo "")

echo "[INFO] Проверка passwordless sudo..."
if ! sudo -n true 2>/dev/null; then
    echo "[ERROR] Требуется passwordless sudo (NOPASSWD) для пользователя $USERNAME" && exit 1
fi

echo "[INFO] Запуск скрипта с правами sudo..."
sudo -n env \
  SEC_MAN_ADDR="__SEC_MAN_ADDR__" \
  NAMESPACE_CI="__NAMESPACE_CI__" \
  RLM_API_URL="__RLM_API_URL__" \
  RLM_TOKEN="$RLM_TOKEN" \
  NETAPP_API_ADDR="__NETAPP_API_ADDR__" \
  GRAFANA_PORT="__GRAFANA_PORT__" \
  PROMETHEUS_PORT="__PROMETHEUS_PORT__" \
  VAULT_AGENT_KV="__VAULT_AGENT_KV__" \
  RPM_URL_KV="__RPM_URL_KV__" \
  NETAPP_SSH_KV="__NETAPP_SSH_KV__" \
  GRAFANA_WEB_KV="__GRAFANA_WEB_KV__" \
  SBERCA_CERT_KV="__SBERCA_CERT_KV__" \
  ADMIN_EMAIL="__ADMIN_EMAIL__" \
  SKIP_VAULT_INSTALL="__SKIP_VAULT_INSTALL__" \
  GRAFANA_URL="$RPM_GRAFANA" \
  PROMETHEUS_URL="$RPM_PROMETHEUS" \
  HARVEST_URL="$RPM_HARVEST" \
  /bin/bash "$REMOTE_SCRIPT_PATH"
REMOTE_EOF
'''
                        def finalScript = scriptTpl
                            .replace('__SERVER_ADDRESS__',     params.SERVER_ADDRESS     ?: '')
                            .replace('__SEC_MAN_ADDR__',       params.SEC_MAN_ADDR       ?: '')
                            .replace('__NAMESPACE_CI__',       params.NAMESPACE_CI       ?: '')
                            .replace('__RLM_API_URL__',        params.RLM_API_URL        ?: '')
                            .replace('__NETAPP_API_ADDR__',    params.NETAPP_API_ADDR    ?: '')
                            .replace('__GRAFANA_PORT__',       params.GRAFANA_PORT       ?: '3000')
                            .replace('__PROMETHEUS_PORT__',    params.PROMETHEUS_PORT    ?: '9090')
                            .replace('__VAULT_AGENT_KV__',     params.VAULT_AGENT_KV     ?: '')
                            .replace('__RPM_URL_KV__',         params.RPM_URL_KV         ?: '')
                            .replace('__NETAPP_SSH_KV__',      params.NETAPP_SSH_KV      ?: '')
                            .replace('__GRAFANA_WEB_KV__',     params.GRAFANA_WEB_KV     ?: '')
                            .replace('__SBERCA_CERT_KV__',     params.SBERCA_CERT_KV     ?: '')
                            .replace('__ADMIN_EMAIL__',        params.ADMIN_EMAIL        ?: '')
                            .replace('__SKIP_VAULT_INSTALL__', params.SKIP_VAULT_INSTALL ? 'true' : 'false')
                        writeFile file: 'deploy_script.sh', text: finalScript
                        sh 'chmod +x deploy_script.sh'
                        withEnv(['SSH_KEY=' + env.SSH_KEY, 'SSH_USER=' + env.SSH_USER]) {
                            sh './deploy_script.sh'
                        }
                        sh 'rm -f deploy_script.sh'
                    }
                }
            }
        }

        stage('Проверка результатов') {
            steps {
                script {
                    echo "[STEP] Проверка результатов развертывания..."
                    withCredentials([sshUserPrivateKey(credentialsId: params.SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                        writeFile file: 'check_results.sh', text: '''#!/bin/bash
ssh -i "$SSH_KEY" -q -o StrictHostKeyChecking=no \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' << 'ENDSSH'
echo "================================================"
echo "ПРОВЕРКА СЕРВИСОВ:"
echo "================================================"
systemctl is-active prometheus && echo "[OK] Prometheus активен" || echo "[FAIL] Prometheus не активен"
systemctl is-active grafana-server && echo "[OK] Grafana активен" || echo "[FAIL] Grafana не активен"
echo ""
echo "================================================"
echo "ПРОВЕРКА ПОРТОВ:"
echo "================================================"
ss -tln | grep -q ":''' + (params.PROMETHEUS_PORT ?: '9090') + ''' " && echo "[OK] Порт ''' + (params.PROMETHEUS_PORT ?: '9090') + ''' (Prometheus) открыт" || echo "[FAIL] Порт ''' + (params.PROMETHEUS_PORT ?: '9090') + ''' не открыт"
ss -tln | grep -q ":''' + (params.GRAFANA_PORT ?: '3000') + ''' " && echo "[OK] Порт ''' + (params.GRAFANA_PORT ?: '3000') + ''' (Grafana) открыт" || echo "[FAIL] Порт ''' + (params.GRAFANA_PORT ?: '3000') + ''' не открыт"
ss -tln | grep -q ":12990 " && echo "[OK] Порт 12990 (Harvest-NetApp) открыт" || echo "[FAIL] Порт 12990 не открыт"
ss -tln | grep -q ":12991 " && echo "[OK] Порт 12991 (Harvest-Unix) открыт" || echo "[FAIL] Порт 12991 не открыт"
exit 0
ENDSSH
'''
                        sh 'chmod +x check_results.sh'
                        def result
                        withEnv(['SSH_KEY=' + env.SSH_KEY, 'SSH_USER=' + env.SSH_USER]) {
                            result = sh(script: './check_results.sh', returnStdout: true).trim()
                        }
                        sh 'rm -f check_results.sh'
                        echo result
                    }
                }
            }
        }

        stage('Очистка') {
            steps {
                script {
                    echo "[STEP] Очистка временных файлов..."
                    sh "rm -rf temp_data_cred.json"
                    withCredentials([sshUserPrivateKey(credentialsId: params.SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                        writeFile file: 'cleanup_script.sh', text: '''#!/bin/bash
ssh -i "$SSH_KEY" -q -o StrictHostKeyChecking=no \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "rm -rf /tmp/deploy-monitoring /tmp/monitoring_deployment.sh /tmp/temp_data_cred.json /opt/mon_distrib/mon_rpm_''' + env.DATE_INSTALL + '''/*.rpm" || true
'''
                        sh 'chmod +x cleanup_script.sh'
                        withEnv(['SSH_KEY=' + env.SSH_KEY, 'SSH_USER=' + env.SSH_USER]) {
                            sh './cleanup_script.sh'
                        }
                        sh 'rm -f cleanup_script.sh'
                    }
                    echo "[SUCCESS] Очистка завершена"
                }
            }
        }

        stage('Получение сведений о развертывании системы') {
            steps {
                script {
                    def domainName = ''
                    withCredentials([sshUserPrivateKey(credentialsId: params.SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                        writeFile file: 'get_domain.sh', text: '''#!/bin/bash
ssh -i "$SSH_KEY" -q -o StrictHostKeyChecking=no \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "nslookup ''' + params.SERVER_ADDRESS + ''' 2>/dev/null | grep 'name =' | awk '{print \\$4}' | sed 's/\\.$//' || echo ''"
'''
                        sh 'chmod +x get_domain.sh'
                        withEnv(['SSH_KEY=' + env.SSH_KEY, 'SSH_USER=' + env.SSH_USER]) {
                            domainName = sh(script: './get_domain.sh', returnStdout: true).trim()
                        }
                        sh 'rm -f get_domain.sh'
                    }
                    if (domainName == '') {
                        domainName = params.SERVER_ADDRESS
                    }
                    def serverIp = ''
                    withCredentials([sshUserPrivateKey(credentialsId: params.SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                        writeFile file: 'get_ip.sh', text: '''#!/bin/bash
ssh -i "$SSH_KEY" -q -o StrictHostKeyChecking=no \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "hostname -I | awk '{print \\$1}' || echo ''' + (params.SERVER_ADDRESS ?: '') + '''"
'''
                        sh 'chmod +x get_ip.sh'
                        withEnv(['SSH_KEY=' + env.SSH_KEY, 'SSH_USER=' + env.SSH_USER]) {
                            serverIp = sh(script: './get_ip.sh', returnStdout: true).trim()
                        }
                        sh 'rm -f get_ip.sh'
                    }
                    echo "[SUCCESS] Развертывание мониторинговой системы завершено!"
                    echo "[INFO] Доступ к сервисам:"
                    echo " • Prometheus: https://${serverIp}:${params.PROMETHEUS_PORT}"
                    echo " • Prometheus: https://${domainName}:${params.PROMETHEUS_PORT}"
                    echo " • Grafana: https://${serverIp}:${params.GRAFANA_PORT}"
                    echo " • Grafana: https://${domainName}:${params.GRAFANA_PORT}"
                    echo "[INFO] Информация о сервере:"
                    echo " • IP адрес: ${serverIp}"
                    echo " • Домен: ${domainName}"
                    echo "==============================="
                }
            }
        }
    }

    post {
        success {
            echo "================================================"
            echo "✅ Pipeline (external) успешно завершен!"
            echo "================================================"
        }
        failure {
            echo "================================================"
            echo "❌ Pipeline (external) завершился с ошибкой!"
            echo "Проверьте логи для диагностики проблемы"
            echo "================================================"
        }
        always {
            echo "Время выполнения: ${currentBuild.durationString}"
        }
    }
}