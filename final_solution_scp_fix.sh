#!/bin/bash

# ФИНАЛЬНОЕ РЕШЕНИЕ ПРОБЛЕМЫ SCP В JENKINS ПАЙПЛАЙНЕ
# Проблема: Пайплайн возвращает код 255, хотя раньше работал
# Другой пайплайн с тем же ключом работает

echo "=== ФИНАЛЬНОЕ РЕШЕНИЕ ПРОБЛЕМЫ ==="
echo "Проблема: Jenkins пайплайн перестал работать без изменений в коде"
echo "Код ошибки: 255 (SSH/SCP ошибка)"
echo "Важный факт: Другой пайплайн работает с тем же ключом"
echo

echo "=== КОРЕНЬ ПРОБЛЕМЫ ==="
echo "В текущем scp_script.sh ВСЕ ошибки скрыты:"
echo "  >/dev/null 2>&1"
echo
echo "Это значит:"
echo "1. Мы не видим реальную ошибку"
echo "2. Скрыты детали SSH/SCP failures"
echo "3. Невозможно диагностировать проблему"
echo

echo "=== ПОЧЕМУ ПРОБЛЕМА ВОЗНИКЛА БЕЗ ИЗМЕНЕНИЙ ==="
echo "Возможные сценарии:"
echo
echo "1. 🕒 Временные проблемы сети/сервера"
echo "   - Временная недоступность сервера"
echo "   - Проблемы с DNS"
echo "   - Фаервол блокировал подключение"
echo "   - Таймауты SSH"
echo
echo "2. 📁 Проблемы с workspace Jenkins"
echo "   - Конфликты временных файлов"
echo "   - Недостаточно места на диске"
echo "   - Проблемы с правами доступа"
echo "   - Старые файлы не удаляются"
echo
echo "3. 🔑 Проблемы с переменными окружения"
echo "   - Переменные перезаписываются"
echo "   - Разные значения между пайплайнами"
echo   "   - Проблемы с маскированием Jenkins"
echo
echo "4. ⚙️  Изменения в инфраструктуре"
echo "   - Обновление SSH на целевом сервере"
echo "   - Изменение политик безопасности"
echo "   - Обновление Jenkins/плагинов"
echo

echo "=== ПОЛНОЕ ИСПРАВЛЕНИЕ JENKINSFILE ==="
echo "Замените ВЕСЬ блок stage('Копирование скрипта на удаленный сервер'):"

cat << 'EOF'
stage('Копирование скрипта на удаленный сервер') {
    steps {
        script {
            echo "[STEP] Клонирование репозитория и копирование на сервер ${params.SERVER_ADDRESS}..."
            withCredentials([
                sshUserPrivateKey(credentialsId: params.SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')
            ]) {
                // Создаем улучшенную версию scp_script.sh с отладочным выводом
                writeFile file: 'scp_script.sh', text: '''#!/bin/bash
set -e

echo "[DEBUG] === НАЧАЛО SCP_SCRIPT.SH ==="
echo "[DEBUG] Время: $(date)"
echo "[DEBUG] Рабочая директория: $(pwd)"
echo "[DEBUG] Пользователь: ''' + env.SSH_USER + '''"
echo "[DEBUG] Сервер: ''' + params.SERVER_ADDRESS + '''"
echo "[DEBUG] Ключ: ''' + env.SSH_KEY + '''"

# Проверяем наличие ключа
if [ ! -f "''' + env.SSH_KEY + '''" ]; then
    echo "[ERROR] SSH ключ не найден: ''' + env.SSH_KEY + '''"
    echo "[ERROR] Содержимое текущей директории:"
    ls -la
    exit 1
fi

echo "[DEBUG] SSH ключ найден"
echo "[DEBUG] Размер ключа: $(stat -c%s "''' + env.SSH_KEY + '''" 2>/dev/null || wc -c < "''' + env.SSH_KEY + '''") байт"

# Устанавливаем правильные права на ключ
chmod 600 "''' + env.SSH_KEY + '''" 2>/dev/null || echo "[WARNING] Не удалось изменить права на ключ"

# Проверяем наличие файлов для копирования
echo "[DEBUG] Проверка файлов для копирования..."
if [ ! -f "deploy_monitoring_script.sh" ]; then
    echo "[ERROR] Файл deploy_monitoring_script.sh не найден"
    exit 1
fi
echo "[OK] deploy_monitoring_script.sh найден"

if [ ! -d "wrappers" ]; then
    echo "[ERROR] Папка wrappers не найдена"
    exit 1
fi
echo "[OK] Папка wrappers найдена"

if [ ! -f "temp_data_cred.json" ]; then
    echo "[ERROR] Файл temp_data_cred.json не найден"
    exit 1
fi
echo "[OK] temp_data_cred.json найден"

# 1. Тестируем SSH подключение (без скрытия ошибок)
echo "[DEBUG] 1. Тестируем SSH подключение..."
if ssh -i "''' + env.SSH_KEY + '''" -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes \
    "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''' \
    "echo \'[OK] SSH подключение успешно\' && hostname"; then
    echo "[OK] SSH подключение работает"
else
    echo "[ERROR] Ошибка SSH подключения"
    echo "[DEBUG] Попробуем с verbose режимом для диагностики:"
    ssh -i "''' + env.SSH_KEY + '''" -v -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''' "echo test" || true
    exit 1
fi

# 2. Создаем директорию на удаленном сервере
echo "[DEBUG] 2. Создаем /tmp/deploy-monitoring на удаленном сервере..."
if ssh -i "''' + env.SSH_KEY + '''" -o StrictHostKeyChecking=no \
    "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''' \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring"; then
    echo "[OK] Директория создана успешно"
else
    echo "[ERROR] Не удалось создать директорию"
    exit 1
fi

# 3. Копируем основной скрипт
echo "[DEBUG] 3. Копируем deploy_monitoring_script.sh..."
if scp -i "''' + env.SSH_KEY + '''" -o StrictHostKeyChecking=no \
    deploy_monitoring_script.sh \
    "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/deploy_monitoring_script.sh"; then
    echo "[OK] Скрипт скопирован успешно"
else
    echo "[ERROR] Не удалось скопировать скрипт"
    exit 1
fi

# 4. Копируем папку wrappers
echo "[DEBUG] 4. Копируем папку wrappers..."
if scp -i "''' + env.SSH_KEY + '''" -o StrictHostKeyChecking=no -r \
    wrappers \
    "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/"; then
    echo "[OK] Папка wrappers скопирована успешно"
else
    echo "[ERROR] Не удалось скопировать папку wrappers"
    exit 1
fi

# 5. Копируем файл с учетными данными
echo "[DEBUG] 5. Копируем temp_data_cred.json..."
if scp -i "''' + env.SSH_KEY + '''" -o StrictHostKeyChecking=no \
    temp_data_cred.json \
    "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''':/tmp/"; then
    echo "[OK] Файл учетных данных скопирован успешно"
else
    echo "[ERROR] Не удалось скопировать файл учетных данных"
    exit 1
fi

echo "[SUCCESS] === ВСЕ ФАЙЛЫ УСПЕШНО СКОПИРОВАНЫ ==="
echo "[INFO] Сервер: ''' + params.SERVER_ADDRESS + '''"
echo "[INFO] Время: $(date)"
'''

                // Также создаем prep_clone.sh с отладочным выводом
                writeFile file: 'prep_clone.sh', text: '''#!/bin/bash
set -e
echo "[DEBUG] Запуск prep_clone.sh"
echo "[DEBUG] Время: $(date)"

# Автоматически генерируем лаунчеры с проверкой sha256 для обёрток
if [ -f wrappers/generate_launchers.sh ]; then
  echo "[DEBUG] Запуск generate_launchers.sh..."
  /bin/bash wrappers/generate_launchers.sh
  echo "[OK] Лаунчеры сгенерированы"
else
  echo "[WARNING] wrappers/generate_launchers.sh не найден, пропускаем"
fi

echo "[DEBUG] prep_clone.sh завершен"
'''

                writeFile file: 'verify_script.sh', text: '''#!/bin/bash
set -e
echo "[DEBUG] Запуск verify_script.sh"

ssh -i "''' + env.SSH_KEY + '''" -q -o StrictHostKeyChecking=no \
    "''' + env.SSH_USER + '''"@''' + params.SERVER_ADDRESS + ''' \
    "echo \'[VERIFY] Проверка файлов на сервере:\'; \
     ls -l /tmp/deploy-monitoring/deploy_monitoring_script.sh && echo \'[OK] Скрипт найден\' || echo \'[ERROR] Скрипт не найден\'; \
     ls -ld /tmp/deploy-monitoring/wrappers && echo \'[OK] Папка wrappers найдена\' || echo \'[ERROR] Папка wrappers не найдена\'; \
     ls -l /tmp/temp_data_cred.json && echo \'[OK] Файл учетных данных найден\' || echo \'[ERROR] Файл учетных данных не найден\'" \
    2>/dev/null

echo "[DEBUG] verify_script.sh завершен"
'''

                sh 'chmod +x prep_clone.sh scp_script.sh verify_script.sh'
                
                // Запускаем с отладочным выводом
                echo "[DEBUG] Запуск prep_clone.sh..."
                sh './prep_clone.sh'
                
                echo "[DEBUG] Запуск scp_script.sh..."
                sh './scp_script.sh'
                
                echo "[DEBUG] Запуск verify_script.sh..."
                sh './verify_script.sh'
                
                // Очищаем временные файлы
                sh 'rm -f prep_clone.sh scp_script.sh verify_script.sh'
            }
            echo "[SUCCESS] Репозиторий скопирован на сервер"
        }
    }
}
EOF
echo

echo "=== АЛЬТЕРНАТИВНОЕ РЕШЕНИЕ (если выше не помогает) ==="
echo "1. Использовать rsync вместо scp:"

cat << 'EOF'
writeFile file: 'scp_script.sh', text: '''#!/bin/bash
set -e

echo "[INFO] Используем rsync вместо scp"

# Проверяем наличие rsync
if ! command -v rsync >/dev/null 2>&1; then
    echo "[ERROR] rsync не установлен"
    exit 1
fi

# Создаем директорию
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring"

# Копируем файлы через rsync (более надежно)
rsync -avz -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
    deploy_monitoring_script.sh \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/

rsync -avz -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
    wrappers/ \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/wrappers/

rsync -avz -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
    temp_data_cred.json \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/

echo "[SUCCESS] Файлы скопированы через rsync"
'''
EOF
echo

echo "2. Добавить retry логику:"

cat << 'EOF'
// В Jenkinsfile добавьте retry
def retryCommand(cmd, maxAttempts = 3) {
    def attempts = 0
    while (attempts < maxAttempts) {
        try {
            sh cmd
            break
        } catch (Exception e) {
            attempts++
            echo "[WARNING] Попытка $attempts/$maxAttempts не удалась: ${e.message}"
            if (attempts >= maxAttempts) {
                throw e
            }
            sleep(time: 5, unit: 'SECONDS')
        }
    }
}

// Используйте так:
retryCommand('./scp_script.sh')
EOF
echo

echo "3. Увеличить таймауты SSH:"

cat << 'EOF'
# В scp_script.sh добавьте:
SSH_OPTS="-o StrictHostKeyChecking=no \
          -o ConnectTimeout=30 \
          -o ServerAliveInterval=15 \
          -o ServerAliveCountMax=3 \
          -o BatchMode=yes"

ssh -i "$SSH_KEY" $SSH_OPTS ...
EOF
echo

echo "=== ЧТО ДЕЛАТЬ СЕЙЧАС ==="
echo "1. НЕМЕДЛЕННО: Примените исправленный scp_script.sh в Jenkinsfile"
echo "2. Запустите пайплайн - теперь вы увидите РЕАЛЬНУЮ ошибку"
echo "3. По ошибке определите конкретную проблему:"
echo "   - Если 'SSH ключ не найден' → проблема с Jenkins credentials"
echo "   - Если 'Connection timeout' → проблема с сетью/сервером"
echo "   - Если 'Permission denied' → проблема с правами"
echo "   - Если 'No such file' → проблема с temp_data_cred.json"
echo "4. Исправьте конкретную проблему"
echo

echo "=== ЧАСТЫЕ ОШИБКИ И РЕШЕНИЯ ==="
echo "1. Ошибка: 'SSH ключ не найден'"
echo "   Решение: Проверьте Jenkins credentials 'mon-ssh-key-2'"
echo
echo "2. Ошибка: 'Connection timed out'"
echo "   Решение: Увеличьте таймауты, проверьте доступность сервера"
echo
echo "3. Ошибка: 'Permission denied (publickey)'"
echo "   Решение: Ключ не добавлен в authorized_keys на сервере"
echo
echo "4. Ошибка: 'temp_data_cred.json not found'"
echo "   Решение: Проверьте этап Vault в Jenkinsfile"
echo
echo "5. Ошибка: 'scp: not found'"
echo "   Решение: На целевом сервере нет scp, используйте rsync"
echo

echo "=== ВЫВОД ==="
echo "Проблема в 99% случаев: скрытые ошибки в scp_script.sh"
echo "Решение: Убрать >/dev/null 2>&1 и добавить отладочный вывод"
echo "После этого станет ясна реальная причина ошибки"
echo
echo "Так как другой пайплайн работает, проблема НЕ в:"
echo "✓ SSH ключе"
echo "✓ Доступности сервера"
echo "✓ Пользователе"
echo
echo "Проблема скорее всего в:"
echo "● Временных файлах/конфликтах"
echo "● Переменных окружения"
echo "● Таймаутах/временных проблемах сети"
echo
echo "Исправленный scp_script.sh покажет точную причину!"
