# Анализ проблемы с SCP в Jenkins пайплайне

## Проблема

Пайплайн Jenkins останавливается на этапе `./scp_script.sh`:
```
+ ./scp_script.sh
Stage "Выполнение развертывания" skipped due to earlier failure(s)
Stage "Проверка результатов" skipped due to earlier failure(s)
```

## Причина

Скрипт `scp_script.sh` создается динамически в Jenkinsfile и содержит несколько проблем:

### 1. **Скрытые ошибки**
Все ошибки перенаправляются в `/dev/null`:
```bash
> /dev/null 2>&1
```
Это скрывает реальные ошибки от пользователя.

### 2. **Отсутствие проверок**
Нет проверки успешности выполнения каждой команды.

### 3. **Нет отладочного вывода**
Невозможно понять, на каком этапе происходит ошибка.

## Анализ кода

### Оригинальный код (Jenkinsfile строки 131-139):
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

### Проблемы:
1. `> /dev/null 2>&1` скрывает все ошибки
2. Нет проверки наличия SSH ключа
3. Нет проверки доступности сервера
4. Нет детального логирования

## Решения

### Решение 1: Исправленный scp_script.sh

#### Исправленная версия:
```groovy
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
echo "[DEBUG] Время: $(date)'''
```

### Решение 2: Использование rsync вместо scp

```groovy
writeFile file: 'scp_script.sh', text: '''#!/bin/bash
set -e

# Используем rsync вместо scp (более надежный)
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
```

### Решение 3: Добавить проверки и логирование

```groovy
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

# Проверяем права на ключ
chmod 600 "$SSH_KEY" 2>/dev/null || echo "[WARNING] Не удалось изменить права на ключ"

# Проверяем подключение
echo "[DEBUG] Проверка SSH подключения..."
if ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    "$SSH_USER"@''' + params.SERVER_ADDRESS + ''' "echo 'SSH OK'"; then
    echo "[ERROR] Не удалось подключиться по SSH"
    exit 1
fi

# Выполняем операции с проверками
commands=(
    "ssh -i \"$SSH_KEY\" -o StrictHostKeyChecking=no \"$SSH_USER\"@''' + params.SERVER_ADDRESS + ''' \"rm -rf /tmp/deploy-monitoring && mkdir -p /tmp/deploy-monitoring\""
    "scp -i \"$SSH_KEY\" -o StrictHostKeyChecking=no deploy_monitoring_script.sh \"$SSH_USER\"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/deploy_monitoring_script.sh"
    "scp -i \"$SSH_KEY\" -o StrictHostKeyChecking=no -r wrappers \"$SSH_USER\"@''' + params.SERVER_ADDRESS + ''':/tmp/deploy-monitoring/"
    "scp -i \"$SSH_KEY\" -o StrictHostKeyChecking=no temp_data_cred.json \"$SSH_USER\"@''' + params.SERVER_ADDRESS + ''':/tmp/"
)

for i in "${!commands[@]}"; do
    echo "[DEBUG] Выполняем команду $((i+1)): ${commands[i]}"
    if eval "${commands[i]}"; then
        echo "[DEBUG] ✅ Команда $((i+1)) выполнена успешно"
    else
        echo "[ERROR] ❌ Ошибка выполнения команды $((i+1))"
        exit 1
    fi
done

echo "[SUCCESS] Все файлы скопированы успешно"
'''
```

## Созданные инструменты

### 1. `test_ssh_connection.sh`
Тестирование SSH подключения и SCP операций.

### 2. `diagnose_scp_problem.sh`
Диагностика проблемы с scp_script.sh.

### 3. `patch_jenkins_scp.sh`
Патч для исправления Jenkinsfile.

### 4. `test_ssh_manual.sh`
Ручное тестирование SSH подключения.

### 5. `scp_script_fixed.sh`
Исправленная версия scp_script.sh.

## Возможные причины ошибки

### 1. **Проблемы с SSH ключом**
- Ключ не найден
- Неправильные права на ключ (должны быть 600)
- Ключ не добавлен в authorized_keys на сервере

### 2. **Проблемы с доступом**
- Пользователь не существует на сервере
- Нет прав на запись в /tmp
- Сервер недоступен

### 3. **Проблемы с сетью**
- Фаервол блокирует порт 22
- Проблемы с DNS
- Сервер выключен

### 4. **Проблемы в Jenkins**
- Переменные окружения не установлены
- Jenkins агент не имеет доступа к ключу
- Проблемы с правами Jenkins пользователя

## Диагностика

### Шаг 1: Проверка SSH вручную
```bash
# Проверка подключения
ssh -i /path/to/key -v CI10742292-lnx-mon_sys@tvlds-mvp001939.cloud.delta.sbrf.ru 'echo test'

# Проверка SCP
scp -i /path/to/key -v test.txt CI10742292-lnx-mon_sys@tvlds-mvp001939.cloud.delta.sbrf.ru:/tmp/
```

### Шаг 2: Проверка из Jenkins
Добавить отладочный вывод в scp_script.sh чтобы увидеть реальные ошибки.

### Шаг 3: Проверка переменных
Убедиться что `SSH_KEY`, `SSH_USER` установлены правильно.

## Рекомендации

### 1. **Сначала примените патч**
Используйте исправленную версию scp_script.sh с отладочным выводом.

### 2. **Проверьте SSH ключ**
Убедитесь что ключ существует и имеет правильные права.

### 3. **Проверьте доступность сервера**
Убедитесь что сервер доступен и принимает SSH подключения.

### 4. **Проверьте права пользователя**
Убедитесь что пользователь имеет права на запись в /tmp.

## Быстрое решение

### Вариант A: Применить патч к Jenkinsfile
```bash
./patch_jenkins_scp.sh
git add Jenkinsfile
git commit -m "Fix scp_script.sh with debug output"
git push
```

### Вариант B: Использовать готовый скрипт
Заменить динамическое создание scp_script.sh на использование `scp_script_fixed.sh`.

### Вариант C: Ручная проверка
Запустить `test_ssh_manual.sh` для диагностики проблемы.

## Заключение

**Основная проблема:** Скрытые ошибки в scp_script.sh из-за перенаправления в /dev/null.

**Решение:** Убрать `> /dev/null 2>&1`, добавить отладочный вывод и проверки.

**Рекомендуемое действие:** Применить патч к Jenkinsfile и перезапустить пайплайн. Теперь ошибки будут видны в логах, что позволит точно определить причину проблемы.



