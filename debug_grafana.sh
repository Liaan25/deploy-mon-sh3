#!/bin/bash
# Скрипт для отладки проблемы с Grafana user-юнитом

set -euo pipefail

echo "=== Отладка Grafana user-юнита ==="
echo

# 1. Проверка пользователя
echo "1. Проверка пользователя CI10742292-lnx-mon_sys:"
if id "CI10742292-lnx-mon_sys" &>/dev/null; then
    echo "   ✓ Пользователь существует"
    echo "   Группы пользователя:"
    id -Gn "CI10742292-lnx-mon_sys" | tr ' ' '\n' | sed 's/^/     - /'
    
    if id -Gn "CI10742292-lnx-mon_sys" | grep -q '\bgrafana\b'; then
        echo "   ✓ Пользователь входит в группу grafana"
    else
        echo "   ✗ Пользователь НЕ входит в группу grafana"
        echo "   Добавление пользователя в группу grafana..."
        usermod -a -G grafana "CI10742292-lnx-mon_sys" 2>/dev/null && echo "   ✓ Пользователь добавлен в группу grafana" || echo "   ✗ Не удалось добавить пользователя в группу grafana"
    fi
else
    echo "   ✗ Пользователь CI10742292-lnx-mon_sys не существует"
fi
echo

# 2. Проверка директории /var/lib/grafana
echo "2. Проверка директории /var/lib/grafana:"
if [[ -d "/var/lib/grafana" ]]; then
    echo "   ✓ Директория существует"
    echo "   Права и владелец:"
    ls -ld "/var/lib/grafana" | awk '{print "     " $0}'
    echo "   Содержимое:"
    ls -la "/var/lib/grafana/" 2>/dev/null | while read line; do echo "     $line"; done || echo "     Не удалось прочитать содержимое"
    
    # Проверка прав на запись
    if sudo -u "CI10742292-lnx-mon_sys" test -w "/var/lib/grafana"; then
        echo "   ✓ Пользователь имеет права на запись"
    else
        echo "   ✗ Пользователь НЕ имеет прав на запись"
        echo "   Исправление прав..."
        chown -R "CI10742292-lnx-mon_sys:grafana" "/var/lib/grafana" 2>/dev/null && chmod 775 "/var/lib/grafana" 2>/dev/null && chmod g+s "/var/lib/grafana" 2>/dev/null && echo "   ✓ Права исправлены" || echo "   ✗ Не удалось исправить права"
    fi
else
    echo "   ✗ Директория не существует"
    echo "   Создание директории..."
    mkdir -p "/var/lib/grafana"
    chown "CI10742292-lnx-mon_sys:grafana" "/var/lib/grafana"
    chmod 775 "/var/lib/grafana"
    chmod g+s "/var/lib/grafana"
    echo "   ✓ Директория создана с правильными правами"
fi
echo

# 3. Проверка user-юнита
echo "3. Проверка user-юнита monitoring-grafana.service:"
USER_HOME=$(getent passwd "CI10742292-lnx-mon_sys" | awk -F: '{print $6}')
UNIT_FILE="${USER_HOME}/.config/systemd/user/monitoring-grafana.service"

if [[ -f "$UNIT_FILE" ]]; then
    echo "   ✓ Файл юнита существует: $UNIT_FILE"
    echo "   Содержимое юнита:"
    cat "$UNIT_FILE" | sed 's/^/     /'
else
    echo "   ✗ Файл юнита не существует"
fi
echo

# 4. Проверка логов
echo "4. Проверка логов Grafana:"
LOG_FILE="/tmp/grafana-debug.log"
if [[ -f "$LOG_FILE" ]]; then
    echo "   ✓ Лог-файл существует: $LOG_FILE"
    echo "   Последние 20 строк лога:"
    tail -20 "$LOG_FILE" | sed 's/^/     /'
else
    echo "   ✗ Лог-файл не существует"
    echo "   Создание тестового лог-файла..."
    echo "$(date): Тестовое сообщение" > "$LOG_FILE"
    chmod 666 "$LOG_FILE" 2>/dev/null || true
    echo "   ✓ Лог-файл создан"
fi
echo

# 5. Проверка статуса юнита
echo "5. Проверка статуса monitoring-grafana.service:"
if sudo -u "CI10742292-lnx-mon_sys" XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user is-active monitoring-grafana.service &>/dev/null; then
    echo "   ✓ Юнит активен"
elif sudo -u "CI10742292-lnx-mon_sys" XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user is-failed monitoring-grafana.service &>/dev/null; then
    echo "   ✗ Юнит в состоянии failed"
    echo "   Статус юнита:"
    sudo -u "CI10742292-lnx-mon_sys" XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user status monitoring-grafana.service --no-pager | sed 's/^/     /'
else
    echo "   ? Юнит не активен и не в состоянии failed"
fi
echo

# 6. Ручной запуск Grafana для проверки
echo "6. Тестовый запуск Grafana вручную:"
echo "   Остановка текущего юнита..."
sudo -u "CI10742292-lnx-mon_sys" XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user stop monitoring-grafana.service 2>/dev/null || true
sleep 2

echo "   Запуск Grafana вручную на 5 секунд..."
sudo -u "CI10742292-lnx-mon_sys" bash -c 'cd ~ && /usr/sbin/grafana-server --config=/etc/grafana/grafana.ini --homepath=/usr/share/grafana 2>&1 & PID=$!; sleep 5; kill $PID; wait $PID 2>/dev/null' | tee /tmp/grafana-manual-test.log

echo "   Проверка создания grafana.db..."
if [[ -f "/var/lib/grafana/grafana.db" ]]; then
    echo "   ✓ Файл grafana.db создан"
    ls -la "/var/lib/grafana/grafana.db" | awk '{print "     " $0}'
else
    echo "   ✗ Файл grafana.db НЕ создан"
    echo "   Лог ручного запуска:"
    tail -20 /tmp/grafana-manual-test.log | sed 's/^/     /'
fi
echo

echo "=== Отладка завершена ==="
echo
echo "Рекомендации:"
echo "1. Проверьте файл /tmp/grafana-debug.log после перезапуска юнита"
echo "2. Используйте export SKIP_GRAFANA_DATA_CLEANUP=true перед запуском deploy_monitoring_script.sh"
echo "3. Убедитесь, что порт 3000 не занят другим процессом"







