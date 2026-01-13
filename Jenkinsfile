pipeline {
    agent none

    parameters {
        string(name: "SERVER_ADDRESS", defaultValue: "", description: "Адрес сервера для подключения по SSH")
        string(name: "SSH_CREDENTIALS_ID", defaultValue: "", description: "ID Jenkins Credentials (SSH Username with private key)")
        string(name: "SEC_MAN_ADDR", defaultValue: "", description: "Адрес Vault для SecMan")
        string(name: "NAMESPACE_CI", defaultValue: "", description: "Namespace для CI в Vault")
        string(name: "NETAPP_API_ADDR", defaultValue: "", description: "FQDN/IP NetApp API")
        string(name: "VAULT_AGENT_KV", defaultValue: "", description: "Путь KV в Vault для AppRole")
        string(name: "RPM_URL_KV", defaultValue: "", description: "Путь KV в Vault для RPM URL")
        string(name: "NETAPP_SSH_KV", defaultValue: "", description: "Путь KV в Vault для NetApp SSH")
        string(name: "GRAFANA_WEB_KV", defaultValue: "", description: "Путь KV в Vault для Grafana Web")
        string(name: "SBERCA_CERT_KV", defaultValue: "", description: "Путь KV в Vault для SberCA Cert")
        string(name: "ADMIN_EMAIL", defaultValue: "", description: "Email администратора для сертификатов")
        string(name: "GRAFANA_PORT", defaultValue: "3000", description: "Порт Grafana")
        string(name: "PROMETHEUS_PORT", defaultValue: "9090", description: "Порт Prometheus")
        string(name: "RLM_API_URL", defaultValue: "", description: "Базовый URL RLM API")
        booleanParam(name: "SKIP_VAULT_INSTALL", defaultValue: false, description: "Пропустить установку Vault через RLM")
    }
    

    stages {
        // CI ЭТАП: Подготовка и диагностика (можно на clearAgent)
        stage("CI: Подготовка и диагностика") {
            agent { label "clearAgent&&sbel8&&!static" }
            steps {
                script {
                    // Вычисляем DATE_INSTALL здесь, где есть контекст агента
                    env.DATE_INSTALL = sh(script: "date '+%Y%m%d_%H%M%S'", returnStdout: true).trim()
                    
                    echo "================================================"
                    echo "=== НАЧАЛО ПАЙПЛАЙНА С ОТЛАДКОЙ ==="
                    echo "================================================"
                    echo "[DEBUG] Время запуска: ${new Date()}"
                    echo "[DEBUG] Номер билда: ${currentBuild.number}"
                    echo "[DEBUG] Workspace: ${env.WORKSPACE}"
                    echo "[DEBUG] Путь: ${pwd()}"
                    echo "[DEBUG] DATE_INSTALL: ${env.DATE_INSTALL}"
                    
                    // Очистка workspace
                    echo "[DEBUG] Очистка workspace..."
                    sh '''
                        echo "Текущая директория: $(pwd)"
                        ls -la
                    '''
                    
                    // Проверка параметров
                    echo "[DEBUG] === ПРОВЕРКА ПАРАМЕТРОВ ==="
                    echo "[DEBUG] SERVER_ADDRESS: ${params.SERVER_ADDRESS}"
                    echo "[DEBUG] SSH_CREDENTIALS_ID: ${params.SSH_CREDENTIALS_ID}"
                    
                    if (!params.SERVER_ADDRESS?.trim()) {
                        error(" ОШИБКА: Не указан SERVER_ADDRESS")
                    }
                    if (!params.SSH_CREDENTIALS_ID?.trim()) {
                        error(" ОШИБКА: Не указан SSH_CREDENTIALS_ID")
                    }
                    
                    // Диагностика сети
                    echo "[DEBUG] === ДИАГНОСТИКА СЕТИ ==="
                    sh '''
                        echo "[DIAG] Jenkins агент: $(hostname)"
                        echo "[DIAG] Проверка DNS..."
                        nslookup ''' + params.SERVER_ADDRESS + ''' 2>/dev/null || echo "[WARNING] DNS проверка не удалась"
                        echo "[DIAG] Проверка ping..."
                        ping -c 2 -W 1 ''' + params.SERVER_ADDRESS + ''' 2>/dev/null || echo "[WARNING] Ping не работает"
                    '''
                    
                    echo "[SUCCESS] CI этап завершен"
                }
            }
        }
        
        // CDL ЭТАП: Развертывание (должен быть на masterLin для доступа к сети)
        stage("CDL: Развертывание на сервер") {
            agent { label "masterLin&&sbel8&&!static" }
            steps {
                script {
                    echo "================================================"
                    echo "=== CDL ЭТАП: РАЗВЕРТЫВАНИЕ ==="
                    echo "================================================"
                    echo "[DEBUG] Агент: ${env.NODE_NAME}"
                    echo "[DEBUG] DATE_INSTALL: ${env.DATE_INSTALL}"
                    
                    // SSH тест
                    withCredentials([
                        sshUserPrivateKey(
                            credentialsId: params.SSH_CREDENTIALS_ID, 
                            keyFileVariable: "SSH_KEY", 
                            usernameVariable: "SSH_USER"
                        )
                    ]) {
                        echo "[DEBUG] SSH_USER: ${env.SSH_USER}"
                        echo "[DEBUG] Тестируем SSH подключение..."
                        
                        sh '''
                            echo "[SSH_TEST] Проверяем SSH ключ..."
                            ls -la "$SSH_KEY" || echo "[ERROR] SSH ключ не найден"
                            
                            echo "[SSH_TEST] Пробуем подключиться к серверу..."
                            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
                                "${SSH_USER}@''' + params.SERVER_ADDRESS + '''" \
                                "echo \'[OK] SSH подключение успешно\' && hostname" || {
                                echo "[ERROR] SSH подключение не удалось"
                                echo "[INFO] Проверьте:"
                                echo "[INFO] 1. Запущен ли SSH на сервере"
                                echo "[INFO] 2. Доступен ли порт 22"
                                echo "[INFO] 3. Правильные ли credentials"
                                exit 1
                            }
                        '''
                        
                        echo "[SUCCESS] SSH подключение работает!"
                    }
                    
                    echo "[SUCCESS] CDL этап завершен"
                }
            }
        }
    }

    post {
        success {
            echo "================================================"
            echo " Pipeline успешно завершен!"
            echo "================================================"
        }
        failure {
            echo "================================================"
            echo " Pipeline завершился с ошибкой!"
            echo "Проверьте логи для диагностики проблемы"
            echo "================================================"
        }
        always {
            echo "Время выполнения: ${currentBuild.durationString}"
        }
    }
}
