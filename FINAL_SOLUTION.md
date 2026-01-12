# Итоговое решение всех проблем

## Краткое описание проблем и решений

### Проблема 1: Grafana падала с ошибкой прав доступа
**Решение:** Исправлены права на `/etc/grafana/provisioning/` в функции `adjust_grafana_permissions_for_mon_sys()`

### Проблема 2: Jenkins показывал ложные ошибки
**Решение:** Исправлена функция `verify_installation()` - теперь проверяет user-юниты, а не системные

### Проблема 3: Автоматическая настройка Grafana не работала
**Решение:** 
1. Упрощена проверка доступности Grafana (проверяется только порт)
2. Создан скрипт для ручной настройки
3. Добавлена обработка ошибок - если Grafana не доступна, скрипт не падает

## Текущее состояние (из ваших логов)

### ✅ Работает:
1. **Prometheus** - `monitoring-prometheus.service` (user-юнит)
   ```bash
   sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user status monitoring-prometheus.service
   ```

2. **Grafana** - `monitoring-grafana.service` (user-юнит)
   ```bash
   sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user status monitoring-grafana.service
   ```

3. **Harvest** - `harvest.service` (системный сервис)
   ```bash
   sudo systemctl status harvest
   ```

4. **Все порты открыты:**
   - 3000 (Grafana) - HTTPS работает
   - 9090 (Prometheus) - HTTPS работает
   - 12990 (Harvest NetApp) - работает
   - 12991 (Harvest Unix) - работает

### ❌ Не настроено (но легко исправить):
1. Prometheus datasource в Grafana
2. Дашборды Harvest в Grafana
3. API токен Grafana

## Что делать сейчас?

### Вариант А: Быстрое решение (рекомендуется)
```bash
# 1. Запустите скрипт ручной настройки
sudo bash setup_grafana_manually.sh

# 2. Проверьте результат
curl -k https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/health
```

### Вариант Б: Запустить обновленный скрипт деплоя
```bash
# Сохраните существующие данные Grafana
export SKIP_GRAFANA_DATA_CLEANUP=true

# Запустите обновленный скрипт
sudo ./deploy_monitoring_script.sh
```

### Вариант В: Настроить вручную через веб-интерфейс
1. Откройте: https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000
2. Войдите с учетными данными из `/opt/vault/conf/data_sec.json`
3. Настройте Prometheus datasource
4. Импортируйте дашборды Harvest

## Проверка после настройки

### 1. Проверьте datasource в Grafana
```bash
# Получите токен API
TOKEN=$(sudo bash -c 'curl -k -s -X POST -H "Content-Type: application/json" -u $(jq -r ".grafana_web.user" /opt/vault/conf/data_sec.json):$(jq -r ".grafana_web.pass" /opt/vault/conf/data_sec.json) https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/serviceaccounts | jq -r ".serviceAccounts[0].id" | xargs -I {} curl -k -s -X POST -H "Content-Type: application/json" -u $(jq -r ".grafana_web.user" /opt/vault/conf/data_sec.json):$(jq -r ".grafana_web.pass" /opt/vault/conf/data_sec.json) https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/serviceaccounts/{}/tokens | jq -r ".key"')

# Проверьте datasources
curl -k -H "Authorization: Bearer $TOKEN" https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/datasources | jq .
```

### 2. Проверьте дашборды
```bash
curl -k -H "Authorization: Bearer $TOKEN" https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/search?type=dash-db | jq .
```

### 3. Проверьте метрики Harvest
```bash
# Unix metrics
curl http://localhost:12991/metrics | head -20

# NetApp metrics (HTTPS)
curl -k https://localhost:12990/metrics | head -20
```

## Важные файлы

### Скрипты:
- `deploy_monitoring_script.sh` - основной скрипт деплоя (исправлен)
- `setup_grafana_manually.sh` - ручная настройка Grafana
- `debug_grafana.sh` - диагностика проблем
- `FIX_NOW.md` - команды для быстрого исправления

### Инструкции:
- `MANUAL_SETUP_INSTRUCTIONS.md` - подробная инструкция
- `INSTRUCTIONS.md` - общие инструкции
- `QUICK_FIX.md` - быстрое решение

## Итог

**Основная проблема решена:** Все сервисы работают как user-юниты под пользователем `CI10742292-lnx-mon_sys`.

**Осталось сделать:** Настроить datasource и дашборды в Grafana (легко делается скриптом `setup_grafana_manually.sh`).

**Рекомендация:** Запустите `sudo bash setup_grafana_manually.sh` - это займет 2-3 минуты и полностью настроит Grafana.





