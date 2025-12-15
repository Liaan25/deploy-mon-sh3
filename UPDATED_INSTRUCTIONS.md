# Обновленный скрипт деплоя - все в одном файле

## Все исправления интегрированы в `deploy_monitoring_script.sh`

Я согласен с вами - создание отдельного скрипта было лишним усложнением. Теперь **вся функциональность находится в одном файле**:

### Что было исправлено и добавлено:

1. **✅ Исправлены права доступа** к `/etc/grafana/provisioning/` в функции `adjust_grafana_permissions_for_mon_sys()`
2. **✅ Исправлена проверка сервисов** в `verify_installation()` - теперь проверяет user-юниты, а не системные
3. **✅ Упрощена проверка доступности Grafana** в `check_grafana_availability()` - проверяется только порт
4. **✅ Добавлена новая функция** `setup_grafana_datasource_and_dashboards()` - настраивает всё автоматически

## Новая функция `setup_grafana_datasource_and_dashboards()`

Эта функция заменяет три старые функции:
- `ensure_grafana_token()`
- `configure_grafana_datasource()`
- `import_grafana_dashboards()`

И делает всё в одном месте:
1. Проверяет доступность Grafana через API
2. Получает учетные данные из Vault
3. Создает сервисный аккаунт и API токен
4. Настраивает Prometheus datasource с mTLS
5. Импортирует дашборды Harvest

## Как использовать обновленный скрипт

### Вариант 1: Полный перезапуск (рекомендуется)
```bash
# Сохраните существующие данные Grafana
export SKIP_GRAFANA_DATA_CLEANUP=true

# Запустите обновленный скрипт
sudo ./deploy_monitoring_script.sh
```

### Вариант 2: Только настройка Grafana (если сервисы уже работают)
```bash
# Запустите только настройку Grafana
sudo bash -c '
    source deploy_monitoring_script.sh
    setup_grafana_datasource_and_dashboards
'
```

## Что изменилось в основном скрипте

### Было:
```bash
if ! check_grafana_availability; then
    # Пропуск настройки
else
    ensure_grafana_token
    configure_grafana_datasource
    import_grafana_dashboards
fi
```

### Стало:
```bash
if ! check_grafana_availability; then
    print_error "Grafana не доступна. Пропускаем настройку datasource и дашбордов."
else
    setup_grafana_datasource_and_dashboards
fi
```

## Преимущества нового подхода

1. **Проще поддерживать** - одна функция вместо трех
2. **Надежнее** - вся логика в одном месте
3. **Лучшая обработка ошибок** - если что-то не работает, понятно где
4. **Меньше зависимостей** - не нужны отдельные скрипты
5. **Автоматическая настройка** - всё делается за один проход

## Проверка после запуска

### 1. Все сервисы должны работать:
```bash
# User-юниты
sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user status monitoring-prometheus.service monitoring-grafana.service

# Системный сервис
sudo systemctl status harvest
```

### 2. Все порты должны быть открыты:
```bash
sudo ss -tlnp | grep -E ':3000|:9090|:12990|:12991'
```

### 3. Веб-интерфейсы должны отвечать:
```bash
# Grafana
curl -k https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/health

# Prometheus
curl -k https://tvlds-mvp001939.cloud.delta.sbrf.ru:9090/-/healthy
```

### 4. Datasource должен быть настроен:
```bash
# Получите токен (из логов скрипта или создайте новый)
TOKEN="ваш_токен"
curl -k -H "Authorization: Bearer $TOKEN" https://tvlds-mvp001939.cloud.delta.sbrf.ru:3000/api/datasources | jq .
```

## Удаленные файлы

Я удалил лишние файлы, так как их функциональность теперь в основном скрипте:
- `setup_grafana_manually.sh` - функциональность в `setup_grafana_datasource_and_dashboards()`
- `FIX_NOW.md` - информация в инструкциях
- `QUICK_FIX.md` - информация в инструкциях

## Итог

Теперь у вас есть **один скрипт**, который:
1. Устанавливает все компоненты
2. Настраивает права и конфигурации
3. Запускает сервисы как user-юниты
4. Автоматически настраивает Grafana (datasource + дашборды)
5. Правильно проверяет статус для Jenkins

Просто запустите `sudo ./deploy_monitoring_script.sh` с опцией `SKIP_GRAFANA_DATA_CLEANUP=true`, и всё настроится автоматически.
