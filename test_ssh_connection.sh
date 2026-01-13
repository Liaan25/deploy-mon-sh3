#!/bin/bash

# Тестирование SSH подключения к серверу

echo "=== ТЕСТИРОВАНИЕ SSH ПОДКЛЮЧЕНИЯ ==="
echo

# Проверяем наличие необходимых файлов
echo "1. Проверка файлов:"
if [[ -f "deploy_monitoring_script.sh" ]]; then
    echo "   ✅ deploy_monitoring_script.sh найден"
else
    echo "   ❌ deploy_monitoring_script.sh не найден"
    exit 1
fi

if [[ -d "wrappers" ]]; then
    echo "   ✅ Папка wrappers найдена"
else
    echo "   ❌ Папка wrappers не найдена"
    exit 1
fi

if [[ -f "temp_data_cred.json" ]]; then
    echo "   ✅ temp_data_cred.json найден"
else
    echo "   ❌ temp_data_cred.json не найден"
    exit 1
fi

echo

# Создаем тестовый скрипт для проверки SSH
echo "2. Создание тестового SSH скрипта:"
cat > test_ssh_simple.sh << 'EOF'
#!/bin/bash
set -e

SERVER_ADDRESS="tvlds-mvp001939.cloud.delta.sbrf.ru"
SSH_USER="CI10742292-lnx-mon_sys"
SSH_KEY="$HOME/.ssh/id_rsa"

echo "Проверка SSH подключения к $SERVER_ADDRESS..."
echo "Пользователь: $SSH_USER"
echo "Ключ: $SSH_KEY"

# Проверяем наличие ключа
if [[ ! -f "$SSH_KEY" ]]; then
    echo "❌ SSH ключ не найден: $SSH_KEY"
    exit 1
fi

# Проверяем права на ключ
chmod 600 "$SSH_KEY" 2>/dev/null || true

# Тестируем подключение
echo "Тестируем SSH подключение..."
if ssh -i "$SSH_KEY" -q -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 \
    "$SSH_USER@$SERVER_ADDRESS" "echo '✅ SSH подключение успешно'; hostname"; then
    echo "✅ SSH подключение работает"
else
    echo "❌ Ошибка SSH подключения"
    exit 1
fi

echo "✅ Все проверки пройдены"
EOF

chmod +x test_ssh_simple.sh
echo "   ✅ test_ssh_simple.sh создан"

echo

# Создаем упрощенную версию scp_script.sh
echo "3. Создание упрощенного scp_script.sh:"
cat > scp_simple.sh << 'EOF'
#!/bin/bash
set -e

SERVER_ADDRESS="tvlds-mvp001939.cloud.delta.sbrf.ru"
SSH_USER="CI10742292-lnx-mon_sys"
SSH_KEY="$HOME/.ssh/id_rsa"

echo "Копирование файлов на сервер $SERVER_ADDRESS..."

# Создаем временную директорию на удаленном сервере
echo "Создаем /tmp/deploy-monitoring на удаленном сервере..."
ssh -i "$SSH_KEY" -q -o StrictHostKeyChecking=no \
    "$SSH_USER@$SERVER_ADDRESS" \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring" || {
    echo "❌ Ошибка создания директории на удаленном сервере"
    exit 1
}

# Копируем основной скрипт
echo "Копируем deploy_monitoring_script.sh..."
scp -i "$SSH_KEY" -q -o StrictHostKeyChecking=no \
    deploy_monitoring_script.sh \
    "$SSH_USER@$SERVER_ADDRESS:/tmp/deploy-monitoring/deploy_monitoring_script.sh" || {
    echo "❌ Ошибка копирования deploy_monitoring_script.sh"
    exit 1
}

# Копируем папку wrappers
echo "Копируем папку wrappers..."
scp -i "$SSH_KEY" -q -o StrictHostKeyChecking=no -r \
    wrappers \
    "$SSH_USER@$SERVER_ADDRESS:/tmp/deploy-monitoring/" || {
    echo "❌ Ошибка копирования wrappers"
    exit 1
}

# Копируем файл с учетными данными
echo "Копируем temp_data_cred.json..."
scp -i "$SSH_KEY" -q -o StrictHostKeyChecking=no \
    temp_data_cred.json \
    "$SSH_USER@$SERVER_ADDRESS:/tmp/" || {
    echo "❌ Ошибка копирования temp_data_cred.json"
    exit 1
}

echo "✅ Все файлы успешно скопированы"
EOF

chmod +x scp_simple.sh
echo "   ✅ scp_simple.sh создан"

echo

# Создаем скрипт для проверки
echo "4. Создание скрипта проверки:"
cat > verify_simple.sh << 'EOF'
#!/bin/bash
set -e

SERVER_ADDRESS="tvlds-mvp001939.cloud.delta.sbrf.ru"
SSH_USER="CI10742292-lnx-mon_sys"
SSH_KEY="$HOME/.ssh/id_rsa"

echo "Проверка скопированных файлов на сервере $SERVER_ADDRESS..."

# Проверяем наличие файлов
ssh -i "$SSH_KEY" -q -o StrictHostKeyChecking=no \
    "$SSH_USER@$SERVER_ADDRESS" << 'REMOTE_EOF'
echo "Проверяем файлы в /tmp/deploy-monitoring/:"
ls -la /tmp/deploy-monitoring/
echo
echo "Проверяем deploy_monitoring_script.sh:"
if [[ -f "/tmp/deploy-monitoring/deploy_monitoring_script.sh" ]]; then
    echo "✅ deploy_monitoring_script.sh найден"
    ls -la "/tmp/deploy-monitoring/deploy_monitoring_script.sh"
else
    echo "❌ deploy_monitoring_script.sh не найден"
fi
echo
echo "Проверяем папку wrappers:"
if [[ -d "/tmp/deploy-monitoring/wrappers" ]]; then
    echo "✅ wrappers найдена"
    ls -la "/tmp/deploy-monitoring/wrappers/"
else
    echo "❌ wrappers не найдена"
fi
echo
echo "Проверяем temp_data_cred.json:"
if [[ -f "/tmp/temp_data_cred.json" ]]; then
    echo "✅ temp_data_cred.json найден"
    ls -la "/tmp/temp_data_cred.json"
else
    echo "❌ temp_data_cred.json не найден"
fi
REMOTE_EOF
EOF

chmod +x verify_simple.sh
echo "   ✅ verify_simple.sh создан"

echo

# Инструкции
echo "=== ИНСТРУКЦИИ ==="
echo "1. Сначала проверьте SSH подключение:"
echo "   ./test_ssh_simple.sh"
echo
echo "2. Если SSH работает, попробуйте скопировать файлы:"
echo "   ./scp_simple.sh"
echo
echo "3. Проверьте скопированные файлы:"
echo "   ./verify_simple.sh"
echo
echo "=== РЕШЕНИЕ ПРОБЛЕМ ==="
echo "Если возникают ошибки:"
echo "1. Проверьте наличие SSH ключа: ~/.ssh/id_rsa"
echo "2. Проверьте права на ключ: chmod 600 ~/.ssh/id_rsa"
echo "3. Проверьте доступность сервера: ping tvlds-mvp001939.cloud.delta.sbrf.ru"
echo "4. Проверьте учетные данные пользователя CI10742292-lnx-mon_sys"
echo
echo "=== АЛЬТЕРНАТИВНЫЙ ПУТЬ ==="
echo "Если scp не работает, можно использовать rsync:"
echo "rsync -avz -e \"ssh -i ~/.ssh/id_rsa\" deploy_monitoring_script.sh CI10742292-lnx-mon_sys@tvlds-mvp001939.cloud.delta.sbrf.ru:/tmp/deploy-monitoring/"



