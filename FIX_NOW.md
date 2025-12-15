# Немедленное исправление проблемы с Grafana

## Проблема
Grafana падает с ошибкой:
```
Error: ✗ Failed to create provisioner: Failed to read dashboards config: could not parse provisioning config file: sample.yaml error: open /etc/grafana/provisioning/dashboards/sample.yaml: permission denied
```

## Быстрое решение

### Шаг 1: Исправьте права на директорию provisioning
```bash
# Установите правильные права
sudo chown -R CI10742292-lnx-mon_sys:grafana /etc/grafana/provisioning
sudo chmod 750 /etc/grafana/provisioning
sudo find /etc/grafana/provisioning -type f -exec chmod 640 {} \;
sudo find /etc/grafana/provisioning -type d -exec chmod 750 {} \;

# Проверьте права
ls -la /etc/grafana/provisioning/
ls -la /etc/grafana/provisioning/dashboards/
```

### Шаг 2: Перезапустите Grafana
```bash
# Остановите Grafana
sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user stop monitoring-grafana.service

# Сбросьте failed состояние
sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user reset-failed monitoring-grafana.service

# Запустите Grafana
sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user start monitoring-grafana.service

# Проверьте статус
sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user status monitoring-grafana.service
```

### Шаг 3: Проверьте логи
```bash
# Посмотрите логи Grafana
sudo cat /tmp/grafana-debug.log | tail -50

# Если файл пустой, проверьте journald
sudo journalctl -u monitoring-grafana.service --user -n 50 --no-pager
```

### Шаг 4: Проверьте работу всех сервисов
```bash
# Prometheus
sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user status monitoring-prometheus.service

# Harvest (системный сервис)
sudo systemctl status harvest

# Порты
sudo ss -tlnp | grep -E ':3000|:9090|:12990|:12991'
```

## Альтернативное решение: Используйте системный юнит Grafana
Если user-юнит не работает, можно временно использовать системный:

```bash
# Остановите user-юнит
sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user stop monitoring-grafana.service
sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user disable monitoring-grafana.service

# Запустите системный юнит
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

# Проверьте
sudo systemctl status grafana-server
```

## Проверка после исправления

### 1. Проверьте, что Grafana создала базу данных
```bash
ls -la /var/lib/grafana/grafana.db
```

### 2. Проверьте доступность веб-интерфейса
```bash
# HTTPS
curl -k https://localhost:3000/api/health

# HTTP (если HTTPS не работает)
curl http://localhost:3000/api/health
```

### 3. Проверьте членство пользователя в группе grafana
```bash
id CI10742292-lnx-mon_sys | grep grafana
```

### 4. Запустите скрипт отладки
```bash
sudo ./debug_grafana.sh
```

## Если проблема не решена

### Вариант A: Удалите проблемный файл sample.yaml
```bash
# Создайте резервную копию
sudo cp /etc/grafana/provisioning/dashboards/sample.yaml /etc/grafana/provisioning/dashboards/sample.yaml.backup

# Удалите или переименуйте
sudo mv /etc/grafana/provisioning/dashboards/sample.yaml /etc/grafana/provisioning/dashboards/sample.yaml.disabled

# Перезапустите Grafana
sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user restart monitoring-grafana.service
```

### Вариант B: Проверьте содержимое sample.yaml
```bash
sudo cat /etc/grafana/provisioning/dashboards/sample.yaml
```

### Вариант C: Полный сброс прав Grafana
```bash
# Остановите все сервисы
sudo systemctl stop grafana-server
sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user stop monitoring-grafana.service

# Восстановите стандартные права
sudo chown -R root:grafana /etc/grafana
sudo chmod 750 /etc/grafana
sudo chmod 640 /etc/grafana/*

# Права на данные
sudo chown -R CI10742292-lnx-mon_sys:grafana /var/lib/grafana
sudo chmod 775 /var/lib/grafana
sudo chmod g+s /var/lib/grafana

# Права на логи
sudo chown -R CI10742292-lnx-mon_sys:grafana /var/log/grafana
sudo chmod 775 /var/log/grafana
sudo chmod g+s /var/log/grafana

# Запустите Grafana
sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user start monitoring-grafana.service
```

## Важное замечание
После исправления прав перезапустите скрипт деплоя с опцией пропуска очистки данных:
```bash
export SKIP_GRAFANA_DATA_CLEANUP=true
sudo ./deploy_monitoring_script.sh
```
