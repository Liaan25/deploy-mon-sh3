# Быстрое решение проблемы с Grafana и Prometheus

## Проблема
1. Grafana user-юнит падает с `status=1`
2. Prometheus перестал работать после обновления скрипта

## Решение

### Шаг 1: Используйте исправленный скрипт с опциями отладки
```bash
# Скачайте обновленный скрипт на сервер
# (замените путь на актуальный)

# Запустите с отключением проблемных функций
export SKIP_PROMETHEUS_PERMISSIONS_ADJUST=true
export SKIP_GRAFANA_DATA_CLEANUP=true
sudo ./deploy_monitoring_script.sh
```

### Шаг 2: Проверьте логи Grafana
```bash
# После запуска проверьте логи
sudo cat /tmp/grafana-debug.log

# Если файл пустой, попробуйте запустить Grafana вручную
sudo -u CI10742292-lnx-mon_sys bash -c 'cd ~ && /usr/sbin/grafana-server --config=/etc/grafana/grafana.ini --homepath=/usr/share/grafana 2>&1 | head -20'
```

### Шаг 3: Восстановите Prometheus если нужно
```bash
# Проверьте статус
sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user status monitoring-prometheus.service

# Если не работает, восстановите права
sudo chown -R prometheus:prometheus /etc/prometheus/cert /var/lib/prometheus
sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml /etc/prometheus/web-config.yml /etc/prometheus/prometheus.env

# Перезапустите
sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user restart monitoring-prometheus.service
```

### Шаг 4: Запустите скрипт отладки
```bash
sudo ./debug_grafana.sh
```

## Альтернативное решение (быстрое)
Если нужно срочно запустить сервисы:

1. **Для Grafana** - используйте системный юнит:
```bash
sudo systemctl start grafana-server
sudo systemctl enable grafana-server
```

2. **Для Prometheus** - используйте системный юнит:
```bash
sudo systemctl start prometheus
sudo systemctl enable prometheus
```

3. **Для Harvest** - оставьте как есть (он использует системный юнит)

## Что исправлено в скрипте

1. **Функция `adjust_grafana_permissions_for_mon_sys`** - теперь определена перед вызовом
2. **Логирование Grafana** - вывод записывается в `/tmp/grafana-debug.log`
3. **Опция `SKIP_PROMETHEUS_PERMISSIONS_ADJUST`** - можно отключить настройку прав Prometheus
4. **Опция `SKIP_GRAFANA_DATA_CLEANUP`** - можно сохранить базу данных Grafana

## Следующие шаги
1. Запустите скрипт с опциями отладки
2. Предоставьте вывод `/tmp/grafana-debug.log`
3. Запустите `sudo ./debug_grafana.sh` и предоставьте вывод
4. Проверьте, входит ли пользователь `CI10742292-lnx-mon_sys` в группу `grafana`:
   ```bash
   id CI10742292-lnx-mon_sys | grep grafana
   ```

