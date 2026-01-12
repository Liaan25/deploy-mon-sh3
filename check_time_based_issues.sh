#!/bin/bash

# Проверка проблем, которые могли возникнуть со временем без изменений в коде
# Пайплайн раньше работал, теперь возвращает код 255

echo "=== ПРОВЕРКА ВРЕМЕННЫХ ПРОБЛЕМ В JENKINS ПАЙПЛАЙНЕ ==="
echo "Симптом: Пайплайн работал, перестал работать без изменений в коде"
echo "Другой пайплайн с тем же ключом работает"
echo

echo "=== ВОЗМОЖНЫЕ ПРИЧИНЫ ==="
echo "1. ✅ Другой пайплайн работает"
echo "   → Ключ SSH действителен"
echo "   → Сервер доступен"
echo "   → Пользователь существует"
echo

echo "2. ❌ Различия между пайплайнами:"
echo "   a) Разные Jenkins агенты"
echo "   b) Разные workspace директории"
echo "   c) Разные версии файлов"
echo "   d) Разное время выполнения"
echo "   e) Разные переменные окружения"
echo

echo "=== ДЕТАЛЬНАЯ ДИАГНОСТИКА ==="

echo "1. Проблемы с временными файлами:"
cat << 'EOF'
# В Jenkinsfile создаются временные файлы:
# - prep_clone.sh
# - scp_script.sh  
# - verify_script.sh
# - temp_data_cred.json

# Возможные проблемы:
# 1. Файлы создаются с неправильными правами
# 2. Файлы создаются в разных директориях
# 3. Конфликты имен файлов между запусками
# 4. Не удаляются старые файлы
EOF
echo

echo "2. Проблемы с переменными окружения:"
cat << 'EOF'
# В Jenkins используются:
# - SSH_KEY (из withCredentials)
# - SSH_USER (из withCredentials)
# - Параметры пайплайна

# Возможные проблемы:
# 1. Переменные перезаписываются между этапами
# 2. Разные значения в разных пайплайнах
# 3. Проблемы с маскированием переменных
EOF
echo

echo "3. Проблемы с Jenkins агентом:"
cat << 'EOF'
# Возможные проблемы:
# 1. Агент перезагружался
# 2. Изменились настройки агента
# 3. Проблемы с дисковым пространством
# 4. Проблемы с памятью
# 5. Конфликты с другими job
EOF
echo

echo "4. Проблемы с сетью/таймаутами:"
cat << 'EOF'
# Возможные проблемы:
# 1. Временные проблемы с сетью
# 2. Увеличение времени ответа сервера
# 3. Таймауты SSH/SCP
# 4. Проблемы с DNS кэшированием
EOF
echo

echo "=== СПЕЦИФИЧЕСКИЕ ПРОВЕРКИ ==="

echo "1. Проверка temp_data_cred.json:"
cat > check_temp_file.sh << 'EOF'
#!/bin/bash
echo "Проверка temp_data_cred.json:"
if [[ -f "temp_data_cred.json" ]]; then
    echo "✅ Файл существует"
    echo "Размер: $(stat -c%s "temp_data_cred.json" 2>/dev/null || wc -c < "temp_data_cred.json") байт"
    echo "Права: $(stat -c "%a" "temp_data_cred.json" 2>/dev/null || echo "unknown")"
    echo "Владелец: $(stat -c "%U:%G" "temp_data_cred.json" 2>/dev/null || echo "unknown")"
    
    # Проверяем JSON
    if command -v jq >/dev/null 2>&1; then
        if jq empty "temp_data_cred.json" 2>/dev/null; then
            echo "✅ Валидный JSON"
        else
            echo "❌ Невалидный JSON"
            echo "Первые 200 символов:"
            head -c 200 "temp_data_cred.json"
            echo
        fi
    fi
else
    echo "❌ Файл не существует"
fi
EOF
chmod +x check_temp_file.sh
echo "✅ check_temp_file.sh создан"
echo

echo "2. Проверка SSH ключа в Jenkins:"
cat > check_ssh_in_jenkins.sh << 'EOF'
#!/bin/bash
echo "Проверка SSH в Jenkins контексте:"
echo "1. Проверяем переменные:"
echo "   SSH_KEY: $SSH_KEY"
echo "   SSH_USER: $SSH_USER"
echo "   SERVER_ADDRESS: $SERVER_ADDRESS"
echo
echo "2. Проверяем наличие ключа:"
if [[ -f "$SSH_KEY" ]]; then
    echo "   ✅ Ключ найден: $SSH_KEY"
    echo "   Размер: $(stat -c%s "$SSH_KEY" 2>/dev/null || wc -c < "$SSH_KEY") байт"
    echo "   Права: $(stat -c "%a" "$SSH_KEY" 2>/dev/null || echo "unknown")"
    
    # Проверяем формат ключа
    echo "   Проверка формата ключа:"
    if head -1 "$SSH_KEY" | grep -q "BEGIN.*PRIVATE KEY"; then
        echo "   ✅ Правильный формат приватного ключа"
    else
        echo "   ❌ Неправильный формат ключа"
    fi
else
    echo "   ❌ Ключ не найден"
    echo "   Текущая директория: $(pwd)"
    echo "   Содержимое:"
    ls -la
fi
EOF
chmod +x check_ssh_in_jenkins.sh
echo "✅ check_ssh_in_jenkins.sh создан"
echo

echo "3. Проверка конфликтов файлов:"
cat > check_file_conflicts.sh << 'EOF'
#!/bin/bash
echo "Проверка конфликтов файлов в workspace:"
echo "Текущая директория: $(pwd)"
echo
echo "Поиск временных файлов:"
find . -name "*.sh" -type f | grep -E "(prep_clone|scp_script|verify_script|deploy_script|check_results|cleanup_script|get_domain|get_ip)" | while read file; do
    echo "   Найден: $file"
    echo "   Размер: $(stat -c%s "$file" 2>/dev/null || wc -c < "$file") байт"
    echo "   Модификация: $(stat -c "%y" "$file" 2>/dev/null || echo "unknown")"
done
echo
echo "Проверка temp_data_cred.json:"
find . -name "temp_data_cred.json" -type f | while read file; do
    echo "   Найден: $file"
    echo "   Размер: $(stat -c%s "$file" 2>/dev/null || wc -c < "$file") байт"
    echo "   Модификация: $(stat -c "%y" "$file" 2>/dev/null || echo "unknown")"
done
EOF
chmod +x check_file_conflicts.sh
echo "✅ check_file_conflicts.sh создан"
echo

echo "=== РЕШЕНИЯ ДЛЯ КАЖДОЙ ПРОБЛЕМЫ ==="

echo "1. Проблема: Временные файлы"
cat << 'EOF'
Решение в Jenkinsfile:
# Добавить уникальные имена файлов
def timestamp = sh(script: "date '+%Y%m%d_%H%M%S'", returnStdout: true).trim()
def scpScript = "scp_script_${timestamp}.sh"
def prepScript = "prep_clone_${timestamp}.sh"

writeFile file: scpScript, text: '''...'''
sh "./${scpScript}"
sh "rm -f ${scpScript} ${prepScript}"
EOF
echo

echo "2. Проблема: Конфликты переменных"
cat << 'EOF'
Решение в Jenkinsfile:
# Использовать локальные переменные в withEnv
withCredentials([
    sshUserPrivateKey(credentialsId: params.SSH_CREDENTIALS_ID, 
                     keyFileVariable: 'LOCAL_SSH_KEY', 
                     usernameVariable: 'LOCAL_SSH_USER')
]) {
    withEnv(["SSH_KEY=${env.LOCAL_SSH_KEY}", "SSH_USER=${env.LOCAL_SSH_USER}"]) {
        sh './scp_script.sh'
    }
}
EOF
echo

echo "3. Проблема: Таймауты сети"
cat << 'EOF'
Решение в Jenkinsfile:
# Увеличить таймауты SSH
writeFile file: 'scp_script.sh', text: '''#!/bin/bash
set -e

# Увеличиваем таймауты
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=30 -o ServerAliveInterval=15 -o ServerAliveCountMax=3"

ssh -i "$SSH_KEY" $SSH_OPTS \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring"

# Остальные команды...
'''
EOF
echo

echo "4. Проблема: Retry логика"
cat << 'EOF'
Решение в Jenkinsfile:
# Добавить retry для ненадежных операций
def retryScp() {
    retry(3) {
        sh './scp_script.sh'
    }
}

stage('Копирование скрипта на удаленный сервер') {
    steps {
        script {
            echo "[STEP] Клонирование репозитория и копирование на сервер..."
            withCredentials([
                sshUserPrivateKey(credentialsId: params.SSH_CREDENTIALS_ID, 
                                 keyFileVariable: 'SSH_KEY', 
                                 usernameVariable: 'SSH_USER')
            ]) {
                writeFile file: 'scp_script.sh', text: '''...'''
                sh 'chmod +x scp_script.sh'
                retryScp()
            }
        }
    }
}
EOF
echo

echo "=== БЫСТРОЕ ИСПРАВЛЕНИЕ ==="
echo "Самый простой способ диагностики:"
echo "1. Добавить отладочный вывод в scp_script.sh"
echo "2. Убрать перенаправление ошибок в /dev/null"
echo "3. Добавить проверку каждой команды"
echo
echo "Пример быстрого исправления для Jenkinsfile:"

cat << 'EOF'
# ЗАМЕНИТЕ ЭТО:
writeFile file: 'scp_script.sh', text: '''#!/bin/bash
set -e
ssh -i "$SSH_KEY" -q -o StrictHostKeyChecking=no \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring" >/dev/null 2>&1
scp -i "$SSH_KEY" -q -o StrictHostKeyChecking=no deploy_monitoring_script.sh "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/deploy_monitoring_script.sh >/dev/null 2>&1
scp -i "$SSH_KEY" -q -o StrictHostKeyChecking=no -r wrappers "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/ >/dev/null 2>&1
scp -i "$SSH_KEY" -q -o StrictHostKeyChecking=no temp_data_cred.json "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/ >/dev/null 2>&1
'''

# НА ЭТО:
writeFile file: 'scp_script.sh', text: '''#!/bin/bash
set -e

echo "[DEBUG] Начало scp_script.sh"
echo "[DEBUG] SSH_KEY: $SSH_KEY"
echo "[DEBUG] SSH_USER: $SSH_USER"
echo "[DEBUG] SERVER: ''' + params.SERVER_ADDRESS + '''"

# Проверяем ключ
if [ ! -f "$SSH_KEY" ]; then
    echo "[ERROR] Ключ не найден: $SSH_KEY"
    exit 1
fi

# Тестируем SSH
echo "[DEBUG] Тестируем SSH..."
ssh -i "$SSH_KEY" -v -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' "echo SSH_OK" || {
    echo "[ERROR] SSH failed"
    exit 1
}

# Копируем файлы (БЕЗ /dev/null)
echo "[DEBUG] Копируем файлы..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring"

scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    deploy_monitoring_script.sh \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/deploy_monitoring_script.sh

scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r \
    wrappers \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/

scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    temp_data_cred.json \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/

echo "[SUCCESS] Все файлы скопированы"
'''
EOF
echo

echo "=== ВЫВОД ==="
echo "Так как другой пайплайн работает, проблема скорее всего в:"
echo "1. Временных файлах/директориях (конфликты)"
echo "2. Переменных окружения (перезапись)"
echo "3. Таймаутах (временные проблемы сети)"
echo
echo "Рекомендация: Используйте исправленный scp_script.sh с отладочным выводом"
echo "Это сразу покажет конкретную ошибку"
