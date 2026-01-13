#!/bin/bash

# Диагностика проблемы с scp_script.sh в Jenkins пайплайне

echo "=== ДИАГНОСТИКА ПРОБЛЕМЫ SCP В JENKINS ==="
echo

echo "1. Анализ логов Jenkins:"
echo "   Из логов видно, что пайплайн останавливается на:"
echo "   + ./scp_script.sh"
echo "   Stage 'Выполнение развертывания' skipped due to earlier failure(s)"
echo
echo "   Это означает, что scp_script.sh завершился с ошибкой."
echo

echo "2. Возможные причины:"
echo "   a) ❌ SSH ключ не настроен или неверный"
echo "   b) ❌ Пользователь не имеет доступа к серверу"
echo "   c) ❌ Сервер недоступен (network/firewall)"
echo "   d) ❌ Команда scp не работает из-за настроек SSH"
echo "   e) ❌ Недостаточно прав на запись в /tmp/"
echo

echo "3. Проверка из Jenkinsfile:"
echo "   Из Jenkinsfile видно, что scp_script.sh создается динамически:"
cat << 'EOF'
writeFile file: 'scp_script.sh', text: '''#!/bin/bash
set -e
ssh -i "$SSH_KEY" -q -o StrictHostKeyChecking=no \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring" >/dev/null 2>&1
scp -i "$SSH_KEY" -q -o StrictHostKeyChecking=no deploy_monitoring_script.sh "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/deploy_monitoring_script.sh >/dev/null 2>&1
scp -i "$SSH_KEY" -q -o StrictHostKeyChecking=no -r wrappers "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/ >/dev/null 2>&1
scp -i "$SSH_KEY" -q -o StrictHostKeyChecking=no temp_data_cred.json "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/ >/dev/null 2>&1
'''
EOF
echo

echo "4. Проблемы с этой реализацией:"
echo "   a) Все ошибки перенаправляются в /dev/null (> /dev/null 2>&1)"
echo "   b) Нет детального логирования ошибок"
echo "   c) Нет проверки успешности каждой команды"
echo

echo "5. Улучшенная версия scp_script.sh:"
cat > scp_improved.sh << 'EOF'
#!/bin/bash
set -e

echo "=== НАЧАЛО SCP_SCRIPT.SH ==="
echo "Время: $(date)"
echo "Пользователь: $SSH_USER"
echo "Сервер: $SERVER_ADDRESS"
echo "Ключ: $SSH_KEY"
echo

# Проверяем наличие ключа
if [[ ! -f "$SSH_KEY" ]]; then
    echo "❌ ОШИБКА: SSH ключ не найден: $SSH_KEY"
    exit 1
fi

# Проверяем права на ключ
chmod 600 "$SSH_KEY" 2>/dev/null || echo "⚠️  Не удалось изменить права на ключ"

# 1. Создаем директорию на удаленном сервере
echo "1. Создаем /tmp/deploy-monitoring на удаленном сервере..."
if ssh -i "$SSH_KEY" -v -o StrictHostKeyChecking=no \
    "$SSH_USER@$SERVER_ADDRESS" \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring"; then
    echo "✅ Директория создана успешно"
else
    echo "❌ ОШИБКА: Не удалось создать директорию"
    exit 1
fi

# 2. Копируем основной скрипт
echo "2. Копируем deploy_monitoring_script.sh..."
if scp -i "$SSH_KEY" -v -o StrictHostKeyChecking=no \
    deploy_monitoring_script.sh \
    "$SSH_USER@$SERVER_ADDRESS:/tmp/deploy-monitoring/deploy_monitoring_script.sh"; then
    echo "✅ Скрипт скопирован успешно"
else
    echo "❌ ОШИБКА: Не удалось скопировать скрипт"
    exit 1
fi

# 3. Копируем папку wrappers
echo "3. Копируем папку wrappers..."
if scp -i "$SSH_KEY" -v -o StrictHostKeyChecking=no -r \
    wrappers \
    "$SSH_USER@$SERVER_ADDRESS:/tmp/deploy-monitoring/"; then
    echo "✅ Папка wrappers скопирована успешно"
else
    echo "❌ ОШИБКА: Не удалось скопировать папку wrappers"
    exit 1
fi

# 4. Копируем файл с учетными данными
echo "4. Копируем temp_data_cred.json..."
if scp -i "$SSH_KEY" -v -o StrictHostKeyChecking=no \
    temp_data_cred.json \
    "$SSH_USER@$SERVER_ADDRESS:/tmp/"; then
    echo "✅ Файл учетных данных скопирован успешно"
else
    echo "❌ ОШИБКА: Не удалось скопировать файл учетных данных"
    exit 1
fi

echo "=== ВСЕ ОПЕРАЦИИ ВЫПОЛНЕНЫ УСПЕШНО ==="
echo "Время: $(date)"
EOF

chmod +x scp_improved.sh
echo "   ✅ scp_improved.sh создан (с подробным логированием)"
echo

echo "6. Как исправить проблему в Jenkins:"
echo "   Вариант A: Использовать улучшенную версию scp_script.sh"
echo "   Вариант B: Добавить отладочный вывод в текущий скрипт"
echo "   Вариант C: Проверить SSH ключ и доступность сервера"
echo

echo "7. Команды для проверки вручную:"
echo "   # Проверка SSH подключения"
echo "   ssh -i /path/to/key -v CI10742292-lnx-mon_sys@tvlds-mvp001939.cloud.delta.sbrf.ru 'echo test'"
echo
echo "   # Проверка SCP"
echo "   scp -i /path/to/key -v deploy_monitoring_script.sh CI10742292-lnx-mon_sys@tvlds-mvp001939.cloud.delta.sbrf.ru:/tmp/test.txt"
echo

echo "8. Быстрое решение для Jenkinsfile:"
cat << 'EOF'
# ЗАМЕНИТЕ в Jenkinsfile строки 131-139 на:

writeFile file: 'scp_script.sh', text: '''#!/bin/bash
set -e

echo "[DEBUG] Начало scp_script.sh"
echo "[DEBUG] Пользователь: $SSH_USER"
echo "[DEBUG] Сервер: ''' + params.SERVER_ADDRESS + '''"
echo "[DEBUG] Ключ: $SSH_KEY"

# Проверяем наличие ключа
if [ ! -f "$SSH_KEY" ]; then
    echo "[ERROR] SSH ключ не найден: $SSH_KEY"
    exit 1
fi

# 1. Создаем директорию
echo "[DEBUG] Создаем директорию на удаленном сервере..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring"

# 2. Копируем основной скрипт
echo "[DEBUG] Копируем deploy_monitoring_script.sh..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    deploy_monitoring_script.sh \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/deploy_monitoring_script.sh

# 3. Копируем wrappers
echo "[DEBUG] Копируем wrappers..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r \
    wrappers \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/

# 4. Копируем учетные данные
echo "[DEBUG] Копируем temp_data_cred.json..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    temp_data_cred.json \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/

echo "[SUCCESS] Все файлы скопированы успешно"
'''
EOF
echo

echo "9. Альтернативное решение - использовать rsync:"
cat << 'EOF'
# Вместо scp использовать rsync (более надежный)

writeFile file: 'scp_script.sh', text: '''#!/bin/bash
set -e

# Используем rsync вместо scp
rsync -avz -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
    deploy_monitoring_script.sh \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/

rsync -avz -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
    wrappers/ \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/wrappers/

rsync -avz -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
    temp_data_cred.json \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/
'''
EOF
echo

echo "=== ВЫВОД ==="
echo "Проблема: scp_script.sh завершается с ошибкой, но ошибки скрыты (> /dev/null 2>&1)"
echo
echo "Решение:"
echo "1. Убрать перенаправление ошибок в /dev/null"
echo "2. Добавить подробное логирование"
echo "3. Проверить SSH ключ и доступность сервера"
echo "4. Рассмотреть использование rsync вместо scp"
echo
echo "Самый быстрый способ: заменить scp_script.sh в Jenkinsfile на улучшенную версию"



