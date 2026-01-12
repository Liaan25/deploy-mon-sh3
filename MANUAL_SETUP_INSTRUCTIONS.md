# Инструкция по ручной настройке Grafana

## Текущая ситуация
✅ **Сервисы работают:**
- Prometheus: `monitoring-prometheus.service` (user-юнит)
- Grafana: `monitoring-grafana.service` (user-юнит) 
- Harvest: `harvest.service` (системный сервис)

❌ **Не настроено автоматически:**
- Prometheus datasource в Grafana
- Дашборды Harvest в Grafana
- API токен Grafana

## Быстрое решение

### Вариант 1: Запустить скрипт ручной настройки
```bash
# На сервере выполните:
sudo bash setup_grafana_manually.sh
```

Скрипт автоматически:
1. Проверит доступность Grafana
2. Получит учетные данные из Vault
3. Создаст сервисный аккаунт и токен
4. Настроит Prometheus datasource с mTLS
5. Импортирует дашборды Harvest

### Вариант 2: Команды вручную

#### 1. Проверьте доступность Grafana
```bash
curl -k https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/health
```

#### 2. Получите учетные данные
```bash
sudo cat /opt/vault/conf/data_sec.json | jq '.grafana_web'
```

#### 3. Настройте datasource через веб-интерфейс
1. Откройте в браузере: `https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000`
2. Войдите с учетными данными из шага 2
3. Перейдите: Configuration → Data sources → Add data source
4. Выберите Prometheus
5. Настройки:
   - URL: `https://tvlds-mvp001939.cloud.delta.sbrf.ru:9090`
   - Access: `Server (default)`
   - Auth: Включить TLS Client Auth и TLS CA Cert
   - Client cert: `/opt/vault/certs/grafana-client.crt`
   - Client key: `/opt/vault/certs/grafana-client.key`
   - CA cert: `/etc/prometheus/cert/ca_chain.crt`

#### 4. Импортируйте дашборды Harvest
```bash
cd /opt/harvest
# Получите токен API (см. скрипт setup_grafana_manually.sh)
# Затем:
echo "Y" | ./bin/harvest --config ./harvest.yml grafana import \
  --addr "https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000" \
  --token "ВАШ_ТОКЕН" \
  --insecure
```

## Почему автоматическая настройка не сработала?

### 1. Проблема с проверкой доступности Grafana
Обертка `grafana_launcher.sh` не может обработать доменное имя с точками. Исправлено в обновленном скрипте - теперь проверяется только активность юнита и порт.

### 2. Jenkins показывает ложные ошибки
Функция `verify_installation()` проверяла системные юниты (`prometheus`, `grafana-server`), а не user-юниты. Исправлено - теперь проверяются правильные юниты.

### 3. Проблема с правами на provisioning директорию
Исправлено в функции `adjust_grafana_permissions_for_mon_sys()`.

## Что делать дальше?

### 1. Запустите обновленный скрипт деплоя
```bash
export SKIP_GRAFANA_DATA_CLEANUP=true
sudo ./deploy_monitoring_script.sh
```

### 2. Или настройте вручную
```bash
sudo bash setup_grafana_manually.sh
```

### 3. Проверьте результат
```bash
# Все сервисы
sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user status monitoring-prometheus.service monitoring-grafana.service

# Порты
sudo ss -tlnp | grep -E ':3000|:9090|:12990|:12991'

# Веб-интерфейсы
curl -k https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000
curl -k https://tvlds-mvp001939.cloud.delta.sbrf.ru:9090
```

## Доступ к сервисам
- **Grafana**: https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000
- **Prometheus**: https://tvlds-mvp001939.cloud.delta.sbrf.ru:9090
- **Harvest Unix**: http://localhost:12991/metrics
- **Harvest NetApp**: https://localhost:12990/metrics

## Учетные данные Grafana
Находятся в: `/opt/vault/conf/data_sec.json`
```bash
sudo jq '.grafana_web' /opt/vault/conf/data_sec.json
```





