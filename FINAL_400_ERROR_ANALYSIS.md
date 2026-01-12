# Окончательный анализ проблемы HTTP 400 при создании сервисного аккаунта

## Краткое описание проблемы

Пайплайн завершается с ошибкой HTTP 400 (Bad Request) при попытке создания сервисного аккаунта через Grafana API.

## Анализ логов

### Успешные этапы:
```
DEBUG_HEALTH_SUCCESS: Health check прошел успешно, HTTP 200
DEBUG_DOMAIN_CHECK: Текущий URL: https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000
DEBUG_SA_CREATE: Начало создания сервисного аккаунта
DEBUG_SA_ENDPOINT: Endpoint: https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/serviceaccounts
DEBUG_SA_PAYLOAD: Payload: {
  "name": "harvest-service-account_1767082020",
  "role": "Admin"
}
```

### Проблемный этап:
```
DEBUG_SA_RESPONSE: Ответ получен, HTTP код: 400
DEBUG_SA_FULL_RESPONSE: Полный ответ от API:
{"message":"Bad request data"}
400
DEBUG_SA_BODY: Тело ответа: {"message":"Bad request data"}
```

## Причины HTTP 400

### 1. **Проблема с форматом payload**
- Текущий payload: `{"name":"имя","role":"Admin"}`
- Возможные проблемы:
  - Неправильное значение `role` (должно быть `"admin"` вместо `"Admin"`)
  - Неправильный тип данных для `role` (должно быть число или строка в lowercase)
  - Отсутствие обязательных полей

### 2. **Проблема с доменным именем/SSL**
- Health check проходит (HTTP 200), но создание SA не работает
- Возможные проблемы с reverse proxy или load balancer
- Проблемы с проверкой hostname в SSL сертификате

### 3. **Разница в версиях API**
- Разные версии Grafana могут требовать разный формат запроса
- API мог измениться между версиями

### 4. **Проблема с кодировкой или форматом JSON**
- Неправильные кавычки или escape-символы
- Проблемы с передачей данных через curl

## Решения

### Решение 1: Использовать localhost (рекомендуется)
```bash
# Самый простой и быстрый способ
export USE_GRAFANA_LOCALHOST=true
sudo ./deploy_monitoring_script.sh

# Или в одну строку
USE_GRAFANA_LOCALHOST=true sudo ./deploy_monitoring_script.sh
```

**Преимущества:**
- Обходит проблемы с SSL/доменным именем
- Не требует изменения кода
- Работает сразу

### Решение 2: Изменить формат payload

#### Вариант A: Изменить role на lowercase
```bash
# Изменить в основном скрипте
sed -i 's/--arg role "Admin"/--arg role "admin"/' deploy_monitoring_script.sh
```

#### Вариант B: Убрать role полностью
```bash
# Изменить payload на {name:"имя"}
sed -i 's/jq -n --arg name "\$service_account_name" --arg role "Admin" '\''{name:\$name, role:\$role}'\''/jq -n --arg name "\$service_account_name" '\''{name:\$name}'\''/' deploy_monitoring_script.sh
```

#### Вариант C: Использовать role как число
```bash
# Изменить payload на {name:"имя", role:2}
sed -i 's/jq -n --arg name "\$service_account_name" --arg role "Admin" '\''{name:\$name, role:\$role}'\''/jq -n --arg name "\$service_account_name" '\''{name:\$name, role:2}'\''/' deploy_monitoring_script.sh
```

### Решение 3: Диагностика и точное исправление

#### Шаг 1: Запустить диагностику
```bash
# Проверить разные форматы payload
./test_payload_formats.sh

# Детальная диагностика
./debug_400_problem.sh
```

#### Шаг 2: Проверить версию Grafana
```bash
curl -k https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/health | jq .
```

#### Шаг 3: Проверить существующие SA
```bash
USER=$(jq -r '.grafana_web.user' /opt/vault/conf/data_sec.json)
PASS=$(jq -r '.grafana_web.pass' /opt/vault/conf/data_sec.json)
curl -k -u "$USER:$PASS" https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/serviceaccounts | jq .
```

### Решение 4: Временное решение

#### Пропустить создание SA
```bash
export SKIP_SERVICE_ACCOUNT_CREATION=true
sudo ./deploy_monitoring_script.sh
```

#### Создать SA вручную
1. Войдите в Grafana через веб-интерфейс
2. Настройки → Service accounts → Add service account
3. Создайте аккаунт с ролью Admin
4. Создайте токен и сохраните его

## Созданные инструменты

### 1. `test_payload_formats.sh`
Тестирует 6 разных форматов payload для определения правильного.

### 2. `quick_fix_400_error.sh`
Быстрые команды для исправления проблемы.

### 3. `debug_400_problem.sh`
Детальная диагностика проблемы.

### 4. `fixed_create_service_account.sh`
Исправленная версия функции с улучшенным логированием.

## Рекомендации по порядку действий

### 1. **Сначала попробуйте самое простое:**
```bash
USE_GRAFANA_LOCALHOST=true sudo ./deploy_monitoring_script.sh
```

### 2. **Если не помогло, запустите диагностику:**
```bash
./test_payload_formats.sh
```

### 3. **На основе диагностики примените точное исправление:**
- Если работает `role:"admin"` → измените payload
- Если работает без `role` → уберите role из payload
- Если работает с `localhost` → используйте `USE_GRAFANA_LOCALHOST=true`

### 4. **Если ничего не помогает:**
- Пропустите создание SA (`SKIP_SERVICE_ACCOUNT_CREATION=true`)
- Создайте SA вручную через веб-интерфейс

## Технические детали

### Текущая реализация функции:
```bash
sa_payload=$(jq -n --arg name "$service_account_name" --arg role "Admin" '{name:$name, role:$role}')
```

### Возможные исправления:
1. `role:"admin"` вместо `role:"Admin"`
2. `role:2` вместо `role:"Admin"`
3. Убрать `role` полностью
4. Добавить `isDisabled:false`

### Поддержка USE_GRAFANA_LOCALHOST:
Функция `create_service_account_via_api` автоматически использует `localhost` вместо доменного имени при установке переменной:
```bash
USE_GRAFANA_LOCALHOST=true
```

## Заключение

**Основная причина:** Неправильный формат payload для версии Grafana API.

**Рекомендуемое решение:** Использовать `USE_GRAFANA_LOCALHOST=true` для обхода проблем с доменным именем.

**Альтернативное решение:** Изменить формат payload на основе результатов диагностики.

**Быстрая команда для исправления:**
```bash
USE_GRAFANA_LOCALHOST=true sudo ./deploy_monitoring_script.sh
```

Если проблема persists, запустите `./test_payload_formats.sh` для определения точной причины и соответствующего исправления.


