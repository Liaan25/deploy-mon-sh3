#!/bin/bash

# Диагностика и исправление проблемы с SCP в Jenkins пайплайне
# Проблема: scp_script.sh возвращает код 255, ошибки скрыты

echo "=== ДИАГНОСТИКА ПРОБЛЕМЫ SCP В JENKINS ПАЙПЛАЙНЕ ==="
echo "Проблема: Пайплайн раньше работал, теперь возвращает код 255"
echo "Сервер: tvlds-mvp001939.cloud.delta.sbrf.ru"
echo "Пользователь: CI10742292-lnx-mon_sys"
echo "Ключ: mon-ssh-key-2"
echo

echo "=== АНАЛИЗ ПРИЧИН ==="
echo "1. ✅ Другой пайплайн работает с тем же ключом"
echo "   → Значит ключ и доступ в порядке"
echo
echo "2. ❌ Этот пайплайн перестал работать без изменений"
echo "   → Возможные причины:"
echo "   a) Изменилась конфигурация Jenkins агента"
echo "   b) Проблемы с временными файлами/директориями"
echo "   c) Изменились переменные окружения"
echo "   d) Проблемы с Vault (temp_data_cred.json)"
echo "   e) Проблемы с правами на файлы в workspace"
echo

echo "=== ПРОВЕРКА ТЕКУЩЕЙ РЕАЛИЗАЦИИ ==="
echo "Из Jenkinsfile (строки 131-139):"
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
echo "ПРОБЛЕМЫ:"
echo "1. Все ошибки скрыты (> /dev/null 2>&1)"
echo "2. Нет проверки успешности каждой команды"
echo "3. Нет отладочного вывода"
echo

echo "=== СОЗДАНИЕ ИСПРАВЛЕННОЙ ВЕРСИИ ==="
echo "Создаем исправленный scp_script.sh с подробным логированием:"

cat > fixed_scp_script.sh << 'EOF'
#!/bin/bash
set -e

echo "=== НАЧАЛО SCP_SCRIPT.SH ==="
echo "[DEBUG] Время: $(date)"
echo "[DEBUG] Пользователь: $SSH_USER"
echo "[DEBUG] Сервер: $SERVER_ADDRESS"
echo "[DEBUG] Ключ: $SSH_KEY"
echo "[DEBUG] Рабочая директория: $(pwd)"
echo

# Проверяем наличие ключа
if [[ ! -f "$SSH_KEY" ]]; then
    echo "[ERROR] SSH ключ не найден: $SSH_KEY"
    echo "[ERROR] Содержимое текущей директории:"
    ls -la
    exit 1
fi

echo "[DEBUG] SSH ключ найден, размер: $(stat -c%s "$SSH_KEY" 2>/dev/null || wc -c < "$SSH_KEY") байт"
echo "[DEBUG] Права на ключ: $(stat -c "%a" "$SSH_KEY" 2>/dev/null || echo "unknown")"
chmod 600 "$SSH_KEY" 2>/dev/null || echo "[WARNING] Не удалось изменить права на ключ"

# Проверяем наличие файлов для копирования
echo
echo "[DEBUG] Проверка файлов для копирования:"
if [[ ! -f "deploy_monitoring_script.sh" ]]; then
    echo "[ERROR] Файл deploy_monitoring_script.sh не найден"
    exit 1
fi
echo "[OK] deploy_monitoring_script.sh найден"

if [[ ! -d "wrappers" ]]; then
    echo "[ERROR] Папка wrappers не найдена"
    exit 1
fi
echo "[OK] Папка wrappers найдена"

if [[ ! -f "temp_data_cred.json" ]]; then
    echo "[ERROR] Файл temp_data_cred.json не найден"
    exit 1
fi
echo "[OK] temp_data_cred.json найден, размер: $(stat -c%s "temp_data_cred.json" 2>/dev/null || wc -c < "temp_data_cred.json") байт"

# 1. Тестируем SSH подключение
echo
echo "[DEBUG] 1. Тестируем SSH подключение..."
if ssh -i "$SSH_KEY" -v -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    "$SSH_USER@$SERVER_ADDRESS" "echo '[OK] SSH подключение успешно'; hostname"; then
    echo "[OK] SSH подключение работает"
else
    echo "[ERROR] Ошибка SSH подключения"
    exit 1
fi

# 2. Создаем директорию на удаленном сервере
echo
echo "[DEBUG] 2. Создаем /tmp/deploy-monitoring на удаленном сервере..."
if ssh -i "$SSH_KEY" -v -o StrictHostKeyChecking=no \
    "$SSH_USER@$SERVER_ADDRESS" \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring"; then
    echo "[OK] Директория создана успешно"
else
    echo "[ERROR] Не удалось создать директорию"
    exit 1
fi

# 3. Копируем основной скрипт
echo
echo "[DEBUG] 3. Копируем deploy_monitoring_script.sh..."
if scp -i "$SSH_KEY" -v -o StrictHostKeyChecking=no \
    deploy_monitoring_script.sh \
    "$SSH_USER@$SERVER_ADDRESS:/tmp/deploy-monitoring/deploy_monitoring_script.sh"; then
    echo "[OK] Скрипт скопирован успешно"
else
    echo "[ERROR] Не удалось скопировать скрипт"
    exit 1
fi

# 4. Копируем папку wrappers
echo
echo "[DEBUG] 4. Копируем папку wrappers..."
if scp -i "$SSH_KEY" -v -o StrictHostKeyChecking=no -r \
    wrappers \
    "$SSH_USER@$SERVER_ADDRESS:/tmp/deploy-monitoring/"; then
    echo "[OK] Папка wrappers скопирована успешно"
else
    echo "[ERROR] Не удалось скопировать папку wrappers"
    exit 1
fi

# 5. Копируем файл с учетными данными
echo
echo "[DEBUG] 5. Копируем temp_data_cred.json..."
if scp -i "$SSH_KEY" -v -o StrictHostKeyChecking=no \
    temp_data_cred.json \
    "$SSH_USER@$SERVER_ADDRESS:/tmp/"; then
    echo "[OK] Файл учетных данных скопирован успешно"
else
    echo "[ERROR] Не удалось скопировать файл учетных данных"
    exit 1
fi

echo
echo "=== ВСЕ ОПЕРАЦИИ ВЫПОЛНЕНЫ УСПЕШНО ==="
echo "[SUCCESS] Все файлы скопированы на сервер $SERVER_ADDRESS"
echo "[INFO] Время: $(date)"
EOF

chmod +x fixed_scp_script.sh
echo "✅ fixed_scp_script.sh создан"
echo

echo "=== ИСПРАВЛЕНИЕ JENKINSFILE ==="
echo "Замените в Jenkinsfile строки 131-139 на:"

cat << 'EOF'
writeFile file: 'scp_script.sh', text: '''#!/bin/bash
set -e

echo "[DEBUG] === НАЧАЛО SCP_SCRIPT.SH ==="
echo "[DEBUG] Время: $(date)"
echo "[DEBUG] Пользователь: $SSH_USER"
echo "[DEBUG] Сервер: ''' + params.SERVER_ADDRESS + '''"
echo "[DEBUG] Ключ: $SSH_KEY"

# Проверяем наличие ключа
if [ ! -f "$SSH_KEY" ]; then
    echo "[ERROR] SSH ключ не найден: $SSH_KEY"
    exit 1
fi

# Устанавливаем правильные права на ключ
chmod 600 "$SSH_KEY" 2>/dev/null || true

# 1. Тестируем SSH подключение
echo "[DEBUG] Тестируем SSH подключение..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "echo '[OK] SSH подключение успешно'" || {
    echo "[ERROR] Ошибка SSH подключения"
    exit 1
}

# 2. Создаем директорию на удаленном сервере
echo "[DEBUG] Создаем /tmp/deploy-monitoring на удаленном сервере..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring" || {
    echo "[ERROR] Не удалось создать директорию"
    exit 1
}

# 3. Копируем основной скрипт
echo "[DEBUG] Копируем deploy_monitoring_script.sh..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    deploy_monitoring_script.sh \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/deploy_monitoring_script.sh || {
    echo "[ERROR] Не удалось скопировать скрипт"
    exit 1
}

# 4. Копируем wrappers
echo "[DEBUG] Копируем wrappers..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r \
    wrappers \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/ || {
    echo "[ERROR] Не удалось скопировать wrappers"
    exit 1
}

# 5. Копируем учетные данные
echo "[DEBUG] Копируем temp_data_cred.json..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    temp_data_cred.json \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/ || {
    echo "[ERROR] Не удалось скопировать temp_data_cred.json"
    exit 1
}

echo "[SUCCESS] Все файлы скопированы успешно"
'''
EOF
echo

echo "=== АЛЬТЕРНАТИВНОЕ РЕШЕНИЕ ==="
echo "Если проблема не в скрипте, возможные причины:"
echo
echo "1. Проблема с temp_data_cred.json:"
echo "   - Проверьте что файл создается корректно на этапе Vault"
echo "   - Добавьте проверку: test -s temp_data_cred.json"
echo
echo "2. Проблема с переменными окружения в Jenkins:"
echo "   - Проверьте что SSH_KEY и SSH_USER устанавливаются корректно"
echo "   - Добавьте отладочный вывод переменных"
echo
echo "3. Проблема с правами Jenkins агента:"
echo "   - Проверьте что агент имеет доступ к SSH ключу"
echo "   - Проверьте права на workspace директорию"
echo
echo "4. Временная проблема с сетью/сервером:"
echo "   - Увеличьте таймауты SSH"
echo "   - Добавьте retry логику"
echo

echo "=== КОМАНДЫ ДЛЯ БЫСТРОЙ ПРОВЕРКИ ==="
echo "1. Проверка SSH ключа в Jenkins:"
echo "   ssh -i \"\$SSH_KEY\" -v \"\$SSH_USER@tvlds-mvp001939.cloud.delta.sbrf.ru\" 'echo test'"
echo
echo "2. Проверка SCP вручную:"
echo "   scp -i \"\$SSH_KEY\" -v deploy_monitoring_script.sh \"\$SSH_USER@tvlds-mvp001939.cloud.delta.sbrf.ru:/tmp/test.txt\""
echo
echo "3. Проверка файла temp_data_cred.json:"
echo "   ls -la temp_data_cred.json && head -c 100 temp_data_cred.json"
echo

echo "=== ВЫВОД ==="
echo "Основная проблема: ошибки скрыты в /dev/null"
echo "Решение: Используйте исправленную версию scp_script.sh с отладочным выводом"
echo "Это покажет реальную причину ошибки (SSH, SCP, права, файлы и т.д.)"
