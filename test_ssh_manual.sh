#!/bin/bash

# Ручное тестирование SSH подключения для Jenkins пайплайна

echo "=== РУЧНОЕ ТЕСТИРОВАНИЕ SSH ДЛЯ JENKINS ==="
echo

# Параметры (такие же как в Jenkins)
SERVER_ADDRESS="tvlds-mvp001939.cloud.delta.sbrf.ru"
SSH_USER="CI10742292-lnx-mon_sys"
SSH_KEY="$HOME/.ssh/id_rsa"

echo "Параметры подключения:"
echo "  Сервер: $SERVER_ADDRESS"
echo "  Пользователь: $SSH_USER"
echo "  Ключ: $SSH_KEY"
echo

# Проверка 1: Наличие ключа
echo "1. Проверка SSH ключа:"
if [[ -f "$SSH_KEY" ]]; then
    echo "   ✅ SSH ключ найден: $SSH_KEY"
    ls -la "$SSH_KEY"
else
    echo "   ❌ SSH ключ не найден: $SSH_KEY"
    echo "   Попробуйте другие расположения:"
    ls -la ~/.ssh/ 2>/dev/null || echo "   Папка ~/.ssh/ не существует"
    exit 1
fi
echo

# Проверка 2: Права на ключ
echo "2. Проверка прав на ключ:"
chmod 600 "$SSH_KEY" 2>/dev/null
current_perms=$(stat -c "%a" "$SSH_KEY" 2>/dev/null || echo "unknown")
if [[ "$current_perms" == "600" ]]; then
    echo "   ✅ Правильные права на ключ: 600"
else
    echo "   ⚠️  Неправильные права на ключ: $current_perms (должны быть 600)"
    echo "   Исправляем: chmod 600 $SSH_KEY"
    chmod 600 "$SSH_KEY"
fi
echo

# Проверка 3: Проверка подключения
echo "3. Тестирование SSH подключения:"
echo "   Команда: ssh -i \"$SSH_KEY\" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \"$SSH_USER@$SERVER_ADDRESS\" 'echo \"✅ SSH подключение успешно\"; hostname'"
echo

if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    "$SSH_USER@$SERVER_ADDRESS" 'echo "✅ SSH подключение успешно"; hostname'; then
    echo "   ✅ SSH подключение работает"
else
    echo "   ❌ Ошибка SSH подключения"
    echo
    echo "   Возможные причины:"
    echo "   a) Ключ не добавлен в authorized_keys на сервере"
    echo "   b) Пользователь $SSH_USER не существует на сервере"
    echo "   c) Сервер недоступен (проверьте ping)"
    echo "   d) Фаервол блокирует подключение"
    echo "   e) Проблемы с DNS разрешением имени"
    echo
    echo "   Диагностика:"
    echo "   - Проверьте ping: ping -c 3 $SERVER_ADDRESS"
    echo "   - Проверьте DNS: nslookup $SERVER_ADDRESS"
    echo "   - Проверьте порт: nc -zv $SERVER_ADDRESS 22"
    exit 1
fi
echo

# Проверка 4: Проверка SCP
echo "4. Тестирование SCP:"
TEST_FILE="test_scp_$(date +%s).txt"
echo "test content" > "$TEST_FILE"
echo "   Создан тестовый файл: $TEST_FILE"
echo

echo "   Копируем файл на сервер..."
if scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    "$TEST_FILE" \
    "$SSH_USER@$SERVER_ADDRESS:/tmp/$TEST_FILE"; then
    echo "   ✅ SCP копирование успешно"
    
    # Проверяем файл на сервере
    echo "   Проверяем файл на сервере..."
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no \
        "$SSH_USER@$SERVER_ADDRESS" \
        "ls -la /tmp/$TEST_FILE && cat /tmp/$TEST_FILE && rm -f /tmp/$TEST_FILE"
else
    echo "   ❌ Ошибка SCP копирования"
fi

# Удаляем локальный тестовый файл
rm -f "$TEST_FILE"
echo

# Проверка 5: Проверка прав на запись в /tmp
echo "5. Проверка прав на запись в /tmp:"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    "$SSH_USER@$SERVER_ADDRESS" \
    "echo '✅ Проверка прав на запись в /tmp'; touch /tmp/test_write_$(date +%s) && echo '✅ Файл создан' && rm -f /tmp/test_write_*"
echo

# Проверка 6: Проверка наличия необходимых команд
echo "6. Проверка необходимых команд на сервере:"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no \
    "$SSH_USER@$SERVER_ADDRESS" \
    "echo 'Проверка команд:'; \
     which bash && echo '✅ bash найден'; \
     which scp && echo '✅ scp найден'; \
     which ssh && echo '✅ ssh найден'; \
     which mkdir && echo '✅ mkdir найден'; \
     which rm && echo '✅ rm найден'; \
     which chmod && echo '✅ chmod найден'"
echo

echo "=== ИТОГ ==="
echo "Если все проверки пройдены успешно, то проблема в:"
echo "1. Jenkins пайплайне (скрытые ошибки в scp_script.sh)"
echo "2. Переменных окружения в Jenkins"
echo "3. Правах Jenkins агента"
echo
echo "Рекомендации:"
echo "1. Используйте исправленный scp_script.sh с отладочным выводом"
echo "2. Проверьте переменные SSH_KEY, SSH_USER в Jenkins"
echo "3. Убедитесь что Jenkins агент имеет доступ к SSH ключу"
echo
echo "Быстрая команда для проверки из Jenkins:"
echo "ssh -i \"\$SSH_KEY\" -v \"\$SSH_USER@$SERVER_ADDRESS\" 'echo test'"


