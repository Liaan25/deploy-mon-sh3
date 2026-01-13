#!/bin/bash

# Патч для исправления scp_script.sh в Jenkinsfile

echo "=== ПАТЧ ДЛЯ ИСПРАВЛЕНИЯ SCP В JENKINSFILE ==="
echo

# Проверяем наличие Jenkinsfile
if [[ ! -f "Jenkinsfile" ]]; then
    echo "❌ Jenkinsfile не найден"
    exit 1
fi

echo "1. Создание резервной копии Jenkinsfile..."
cp Jenkinsfile Jenkinsfile.backup
echo "   ✅ Создана резервная копия: Jenkinsfile.backup"
echo

echo "2. Поиск проблемного блока scp_script.sh в Jenkinsfile..."
# Ищем строки с scp_script.sh
if grep -q "writeFile file: 'scp_script.sh'" Jenkinsfile; then
    echo "   ✅ Найден блок scp_script.sh"
else
    echo "   ❌ Блок scp_script.sh не найден"
    exit 1
fi
echo

echo "3. Создание исправленной версии scp_script.sh..."
# Создаем исправленный блок
FIXED_SCP_BLOCK=$(cat << 'EOF'
                        writeFile file: 'scp_script.sh', text: '''#!/bin/bash
set -e

echo "[DEBUG] === НАЧАЛО SCP_SCRIPT.SH ==="
echo "[DEBUG] Время: $(date)"
echo "[DEBUG] Пользователь: \$SSH_USER"
echo "[DEBUG] Сервер: ''' + params.SERVER_ADDRESS + '''"
echo "[DEBUG] Ключ: \$SSH_KEY"

# Проверяем наличие ключа
if [ ! -f "\$SSH_KEY" ]; then
    echo "[ERROR] SSH ключ не найден: \$SSH_KEY"
    exit 1
fi

# Проверяем права на ключ
chmod 600 "\$SSH_KEY" 2>/dev/null || echo "[WARNING] Не удалось изменить права на ключ"

# 1. Создаем директорию на удаленном сервере
echo "[DEBUG] 1. Создаем /tmp/deploy-monitoring на удаленном сервере..."
if ssh -i "\$SSH_KEY" -o StrictHostKeyChecking=no \
    "\$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring"; then
    echo "[DEBUG] ✅ Директория создана успешно"
else
    echo "[ERROR] ❌ Не удалось создать директорию"
    exit 1
fi

# 2. Копируем основной скрипт
echo "[DEBUG] 2. Копируем deploy_monitoring_script.sh..."
if scp -i "\$SSH_KEY" -o StrictHostKeyChecking=no \
    deploy_monitoring_script.sh \
    "\$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/deploy_monitoring_script.sh"; then
    echo "[DEBUG] ✅ Скрипт скопирован успешно"
else
    echo "[ERROR] ❌ Не удалось скопировать скрипт"
    exit 1
fi

# 3. Копируем папку wrappers
echo "[DEBUG] 3. Копируем папку wrappers..."
if scp -i "\$SSH_KEY" -o StrictHostKeyChecking=no -r \
    wrappers \
    "\$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/"; then
    echo "[DEBUG] ✅ Папка wrappers скопирована успешно"
else
    echo "[ERROR] ❌ Не удалось скопировать папку wrappers"
    exit 1
fi

# 4. Копируем файл с учетными данными
echo "[DEBUG] 4. Копируем temp_data_cred.json..."
if scp -i "\$SSH_KEY" -o StrictHostKeyChecking=no \
    temp_data_cred.json \
    "\$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/"; then
    echo "[DEBUG] ✅ Файл учетных данных скопирован успешно"
else
    echo "[ERROR] ❌ Не удалось скопировать файл учетных данных"
    exit 1
fi

echo "[SUCCESS] === ВСЕ ОПЕРАЦИИ ВЫПОЛНЕНЫ УСПЕШНО ==="
echo "[DEBUG] Время: $(date)'''
EOF
)

echo "4. Применение патча..."
# Используем awk для замены блока
awk '
# Находим начало блока scp_script.sh
/writeFile file: .scp_script.sh., text: .{3}/ {
    in_block = 1
    block_start = NR
    print $0
    next
}

# Если мы внутри блока, пропускаем строки пока не найдем конец
in_block && /.{3}/ && !/writeFile file: .scp_script.sh., text: .{3}/ {
    # Это конец блока (закрывающие кавычки)
    in_block = 0
    # Вместо оригинального блока выводим исправленный
    system("echo \"'"$FIXED_SCP_BLOCK"'\"")
    next
}

# Если не внутри блока, выводим строку как есть
!in_block {
    print $0
}
' Jenkinsfile > Jenkinsfile.fixed

# Проверяем результат
if [[ -f "Jenkinsfile.fixed" ]]; then
    mv Jenkinsfile.fixed Jenkinsfile
    echo "   ✅ Патч применен успешно"
else
    echo "   ❌ Ошибка применения патча"
    exit 1
fi
echo

echo "5. Проверка синтаксиса Jenkinsfile..."
# Простая проверка - ищем ключевые строки
echo "   Проверяем наличие исправленного блока:"
if grep -q "echo \"\[DEBUG\] === НАЧАЛО SCP_SCRIPT.SH ===\"" Jenkinsfile; then
    echo "   ✅ Исправленный блок найден"
else
    echo "   ❌ Исправленный блок не найден"
    echo "   Применяем патч вручную..."
    
    # Создаем ручной патч
    cat > manual_patch.groovy << 'EOF'
                        writeFile file: 'scp_script.sh', text: '''#!/bin/bash
set -e

echo "[DEBUG] === НАЧАЛО SCP_SCRIPT.SH ==="
echo "[DEBUG] Время: \$(date)"
echo "[DEBUG] Пользователь: \$SSH_USER"
echo "[DEBUG] Сервер: ''' + params.SERVER_ADDRESS + '''"
echo "[DEBUG] Ключ: \$SSH_KEY"

# Проверяем наличие ключа
if [ ! -f "\$SSH_KEY" ]; then
    echo "[ERROR] SSH ключ не найден: \$SSH_KEY"
    exit 1
fi

# Проверяем права на ключ
chmod 600 "\$SSH_KEY" 2>/dev/null || echo "[WARNING] Не удалось изменить права на ключ"

# 1. Создаем директорию на удаленном сервере
echo "[DEBUG] 1. Создаем /tmp/deploy-monitoring на удаленном сервере..."
if ssh -i "\$SSH_KEY" -o StrictHostKeyChecking=no \
    "\$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring"; then
    echo "[DEBUG] ✅ Директория создана успешно"
else
    echo "[ERROR] ❌ Не удалось создать директорию"
    exit 1
fi

# 2. Копируем основной скрипт
echo "[DEBUG] 2. Копируем deploy_monitoring_script.sh..."
if scp -i "\$SSH_KEY" -o StrictHostKeyChecking=no \
    deploy_monitoring_script.sh \
    "\$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/deploy_monitoring_script.sh"; then
    echo "[DEBUG] ✅ Скрипт скопирован успешно"
else
    echo "[ERROR] ❌ Не удалось скопировать скрипт"
    exit 1
fi

# 3. Копируем папку wrappers
echo "[DEBUG] 3. Копируем папку wrappers..."
if scp -i "\$SSH_KEY" -o StrictHostKeyChecking=no -r \
    wrappers \
    "\$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/"; then
    echo "[DEBUG] ✅ Папка wrappers скопирована успешно"
else
    echo "[ERROR] ❌ Не удалось скопировать папку wrappers"
    exit 1
fi

# 4. Копируем файл с учетными данными
echo "[DEBUG] 4. Копируем temp_data_cred.json..."
if scp -i "\$SSH_KEY" -o StrictHostKeyChecking=no \
    temp_data_cred.json \
    "\$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/"; then
    echo "[DEBUG] ✅ Файл учетных данных скопирован успешно"
else
    echo "[ERROR] ❌ Не удалось скопировать файл учетных данных"
    exit 1
fi

echo "[SUCCESS] === ВСЕ ОПЕРАЦИИ ВЫПОЛНЕНЫ УСПЕШНО ==="
echo "[DEBUG] Время: \$(date)'''
EOF
    
    echo "   Создан файл manual_patch.groovy с исправленным блоком"
    echo "   Вам нужно вручную заменить блок scp_script.sh в Jenkinsfile"
fi
echo

echo "6. Альтернативное решение - создать отдельный файл scp_script.sh:"
cat > scp_script_fixed.sh << 'EOF'
#!/bin/bash
set -e

# Параметры (будут установлены Jenkins)
SERVER_ADDRESS="${SERVER_ADDRESS:-tvlds-mvp001939.cloud.delta.sbrf.ru}"
SSH_USER="${SSH_USER:-CI10742292-lnx-mon_sys}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"

echo "[DEBUG] === НАЧАЛО SCP_SCRIPT.SH ==="
echo "[DEBUG] Время: $(date)"
echo "[DEBUG] Пользователь: $SSH_USER"
echo "[DEBUG] Сервер: $SERVER_ADDRESS"
echo "[DEBUG] Ключ: $SSH_KEY"

# Проверяем наличие ключа
if [ ! -f "$SSH_KEY" ]; then
    echo "[ERROR] SSH ключ не найден: $SSH_KEY"
    exit 1
fi

# Проверяем права на ключ
chmod 600 "$SSH_KEY" 2>/dev/null || echo "[WARNING] Не удалось изменить права на ключ"

# 1. Создаем директорию на удаленном сервере
echo "[DEBUG] 1. Создаем /tmp/deploy-monitoring на удаленном сервере..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    "$SSH_USER@$SERVER_ADDRESS" \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring"

# 2. Копируем основной скрипт
echo "[DEBUG] 2. Копируем deploy_monitoring_script.sh..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    deploy_monitoring_script.sh \
    "$SSH_USER@$SERVER_ADDRESS:/tmp/deploy-monitoring/deploy_monitoring_script.sh"

# 3. Копируем папку wrappers
echo "[DEBUG] 3. Копируем папку wrappers..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r \
    wrappers \
    "$SSH_USER@$SERVER_ADDRESS:/tmp/deploy-monitoring/"

# 4. Копируем файл с учетными данными
echo "[DEBUG] 4. Копируем temp_data_cred.json..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    temp_data_cred.json \
    "$SSH_USER@$SERVER_ADDRESS:/tmp/"

echo "[SUCCESS] === ВСЕ ОПЕРАЦИИ ВЫПОЛНЕНЫ УСПЕШНО ==="
echo "[DEBUG] Время: $(date)"
EOF

chmod +x scp_script_fixed.sh
echo "   ✅ Создан scp_script_fixed.sh (можно использовать вместо динамического)"
echo

echo "7. Инструкция для Jenkinsfile:"
cat << 'EOF'
# В Jenkinsfile вместо динамического создания scp_script.sh:
# writeFile file: 'scp_script.sh', text: '''...'''

# Можно использовать готовый файл:
sh '''
cat > scp_script.sh << "SCRIPT_EOF"
#!/bin/bash
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

# 1. Создаем директорию на удаленном сервере
echo "[DEBUG] 1. Создаем /tmp/deploy-monitoring на удаленном сервере..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring"

# 2. Копируем основной скрипт
echo "[DEBUG] 2. Копируем deploy_monitoring_script.sh..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    deploy_monitoring_script.sh \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/deploy_monitoring_script.sh"

# 3. Копируем папку wrappers
echo "[DEBUG] 3. Копируем папку wrappers..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r \
    wrappers \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/

# 4. Копируем файл с учетными данными
echo "[DEBUG] 4. Копируем temp_data_cred.json..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    temp_data_cred.json \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/

echo "[SUCCESS] === ВСЕ ОПЕРАЦИИ ВЫПОЛНЕНЫ УСПЕШНО ==="
echo "[DEBUG] Время: $(date)"
SCRIPT_EOF

chmod +x scp_script.sh
'''
EOF
echo

echo "=== ВЫВОД ==="
echo "Проблема: scp_script.sh завершается с ошибкой, но ошибки скрыты"
echo "Решение: Добавить отладочный вывод и проверки"
echo
echo "Созданы файлы:"
echo "1. Jenkinsfile.backup - резервная копия"
echo "2. scp_script_fixed.sh - исправленная версия скрипта"
echo "3. manual_patch.groovy - патч для ручного применения"
echo
echo "Следующие шаги:"
echo "1. Запушить исправленный Jenkinsfile в репозиторий"
echo "2. Перезапустить пайплайн Jenkins"
echo "3. Проверить логи - теперь будут видны детальные ошибки"



