# Быстрое исправление проблемы SCP в Jenkins пайплайне

## Проблема
- Пайплайн возвращает код 255 на этапе `scp_script.sh`
- Раньше работал, теперь не работает без изменений в коде
- Другой пайплайн с тем же ключом работает

## Корень проблемы
В `scp_script.sh` все ошибки скрыты: `>/dev/null 2>&1`

## Немедленное решение

### Шаг 1: Замените scp_script.sh в Jenkinsfile

Замените блок в Jenkinsfile (строки 131-139):

```groovy
writeFile file: 'scp_script.sh', text: '''#!/bin/bash
set -e
ssh -i "$SSH_KEY" -q -o StrictHostKeyChecking=no \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring" >/dev/null 2>&1
scp -i "$SSH_KEY" -q -o StrictHostKeyChecking=no deploy_monitoring_script.sh "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/deploy_monitoring_script.sh >/dev/null 2>&1
scp -i "$SSH_KEY" -q -o StrictHostKeyChecking=no -r wrappers "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/ >/dev/null 2>&1
scp -i "$SSH_KEY" -q -o StrictHostKeyChecking=no temp_data_cred.json "$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/ >/dev/null 2>&1
'''
```

На исправленную версию:

```groovy
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

# 1. Тестируем SSH подключение
echo "[DEBUG] Тестируем SSH подключение..."
ssh -i "\$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    "\$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "echo '[OK] SSH подключение успешно'" || {
    echo "[ERROR] Ошибка SSH подключения"
    exit 1
}

# 2. Создаем директорию
echo "[DEBUG] Создаем /tmp/deploy-monitoring на удаленном сервере..."
ssh -i "\$SSH_KEY" -o StrictHostKeyChecking=no \
    "\$SSH_USER"@''' + params.SERVER_ADDRESS + ''' \
    "rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring" || {
    echo "[ERROR] Не удалось создать директорию"
    exit 1
}

# 3. Копируем основной скрипт
echo "[DEBUG] Копируем deploy_monitoring_script.sh..."
scp -i "\$SSH_KEY" -o StrictHostKeyChecking=no \
    deploy_monitoring_script.sh \
    "\$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/deploy_monitoring_script.sh || {
    echo "[ERROR] Не удалось скопировать скрипт"
    exit 1
}

# 4. Копируем wrappers
echo "[DEBUG] Копируем wrappers..."
scp -i "\$SSH_KEY" -o StrictHostKeyChecking=no -r \
    wrappers \
    "\$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/ || {
    echo "[ERROR] Не удалось скопировать wrappers"
    exit 1
}

# 5. Копируем учетные данные
echo "[DEBUG] Копируем temp_data_cred.json..."
scp -i "\$SSH_KEY" -o StrictHostKeyChecking=no \
    temp_data_cred.json \
    "\$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/ || {
    echo "[ERROR] Не удалось скопировать temp_data_cred.json"
    exit 1
}

echo "[SUCCESS] Все файлы скопированы успешно"
'''
```

### Шаг 2: Запустите пайплайн

После применения исправления запустите пайплайн. Теперь вы увидите реальную ошибку в логах.

### Шаг 3: Определите конкретную проблему

По сообщению об ошибке определите проблему:

| Ошибка | Причина | Решение |
|--------|---------|---------|
| `SSH ключ не найден` | Проблема с Jenkins credentials | Проверьте credentials 'mon-ssh-key-2' |
| `Connection timed out` | Проблема с сетью/сервером | Увеличьте таймауты, проверьте доступность |
| `Permission denied` | Проблема с правами доступа | Проверьте authorized_keys на сервере |
| `temp_data_cred.json not found` | Проблема с Vault | Проверьте этап получения данных из Vault |
| `scp: not found` | На сервере нет scp | Используйте rsync вместо scp |

## Почему проблема возникла без изменений?

Так как другой пайплайн работает, проблема НЕ в:
- SSH ключе (он действителен)
- Доступности сервера (сервер доступен)
- Пользователе (пользователь существует)

Проблема скорее всего в:
1. **Временных файлах/конфликтах** - старые файлы не удаляются
2. **Переменных окружения** - переменные перезаписываются
3. **Таймаутах** - временные проблемы сети
4. **Workspace Jenkins** - проблемы с правами/дисковым пространством

## Дополнительные улучшения

### 1. Использовать rsync вместо scp (более надежно)
```bash
rsync -avz -e "ssh -i \$SSH_KEY -o StrictHostKeyChecking=no" \
    deploy_monitoring_script.sh \
    "\$SSH_USER"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/
```

### 2. Добавить retry логику
```groovy
def retryCommand(cmd, maxAttempts = 3) {
    def attempts = 0
    while (attempts < maxAttempts) {
        try {
            sh cmd
            break
        } catch (Exception e) {
            attempts++
            echo "[WARNING] Попытка \$attempts/\$maxAttempts не удалась"
            if (attempts >= maxAttempts) {
                throw e
            }
            sleep(time: 5, unit: 'SECONDS')
        }
    }
}

// Использовать:
retryCommand('./scp_script.sh')
```

### 3. Увеличить таймауты SSH
```bash
SSH_OPTS="-o StrictHostKeyChecking=no \
          -o ConnectTimeout=30 \
          -o ServerAliveInterval=15 \
          -o ServerAliveCountMax=3"

ssh -i "\$SSH_KEY" \$SSH_OPTS ...
```

## Файлы для диагностики

В проекте созданы следующие файлы для помощи:
1. `diagnose_jenkins_scp_fix.sh` - полная диагностика проблемы
2. `check_time_based_issues.sh` - проверка временных проблем
3. `final_solution_scp_fix.sh` - полное решение с кодом

## Важно!
После исправления ошибки можно вернуть `>/dev/null 2>&1` для чистоты логов, но оставить проверки команд (`|| exit 1`).

---

**Итог**: Проблема в скрытых ошибках. Исправленный `scp_script.sh` покажет реальную причину, которую можно будет устранить.
