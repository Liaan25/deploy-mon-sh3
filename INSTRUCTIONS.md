# Инструкция по решению проблемы с Grafana user-юнитом

## Проблема
Grafana user-юнит падает с status=1 за 97 мс, не оставляя логов в journald.

## Решения

### Решение 1: Использовать обновленный скрипт деплоя (рекомендуется)
Скрипт `deploy_monitoring_script.sh` уже обновлен с учетом проблемы:

1. **Автоматическое логирование**: Вывод Grafana теперь записывается в `/tmp/grafana-debug.log`
2. **Автоматическая настройка прав**: Права на директории Grafana настраиваются для пользователя `CI10742292-lnx-mon_sys`
3. **Опция пропуска очистки**: Можно использовать `export SKIP_GRAFANA_DATA_CLEANUP=true`

### Решение 2: Запустить скрипт отладки
Выполните на сервере:
```bash
sudo ./debug_grafana.sh
```

Скрипт проверит:
- Существование пользователя и его членство в группе `grafana`
- Права на директорию `/var/lib/grafana`
- Наличие и содержимое user-юнита
- Логи Grafana
- Статус юнита
- Возможность создания `grafana.db` при ручном запуске

### Решение 3: Временные команды для диагностики

#### Вариант 1 - Добавить логирование (временная правка юнита)
```bash
sudo -u CI10742292-lnx-mon_sys \
  XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" \
  bash -c 'cd ~ && cat > .config/systemd/user/monitoring-grafana.service <<"EOF"
[Unit]
Description=Monitoring Grafana (user service)
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/sbin/grafana-server --config=/etc/grafana/grafana.ini --homepath=/usr/share/grafana
StandardOutput=append:/tmp/grafana-debug.log
StandardError=append:/tmp/grafana-debug.log
Restart=on-failure

[Install]
WantedBy=default.target
EOF'

sudo -u CI10742292-lnx-mon_sys \
  XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" \
  systemctl --user daemon-reload

sudo -u CI10742292-lnx-mon_sys \
  XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" \
  systemctl --user restart monitoring-grafana.service

sleep 2
sudo cat /tmp/grafana-debug.log 2>/dev/null || echo "Файл ещё не создан"
```

#### Вариант 2 - Проверить создание grafana.db
```bash
# Перед запуском
sudo ls -la /var/lib/grafana/

# Запуск Grafana вручную
sudo -u CI10742292-lnx-mon_sys bash -c 'cd ~ && /usr/sbin/grafana-server --config=/etc/grafana/grafana.ini --homepath=/usr/share/grafana & sleep 5 ; kill $!'

# После запуска
sudo ls -la /var/lib/grafana/
```

#### Вариант 3 - Проверить права и группу
```bash
# Проверить группы пользователя
id CI10742292-lnx-mon_sys

# Добавить в группу grafana (если не входит)
sudo usermod -a -G grafana CI10742292-lnx-mon_sys

# Проверить права на директорию
ls -ld /var/lib/grafana

# Исправить права
sudo chown -R CI10742292-lnx-mon_sys:grafana /var/lib/grafana
sudo chmod 775 /var/lib/grafana
sudo chmod g+s /var/lib/grafana
```

## Что делать после получения логов
1. Проверьте `/tmp/grafana-debug.log` на наличие ошибок
2. Распространенные ошибки:
   - `permission denied` - проблема с правами
   - `address already in use` - порт 3000 занят
   - `cannot open database file` - проблема с созданием grafana.db
   - `no such file or directory` - отсутствует конфиг или сертификаты

3. Если проблема не ясна, предоставьте:
   - Вывод `sudo ./debug_grafana.sh`
   - Содержимое `/tmp/grafana-debug.log`
   - Вывод `ls -la /var/lib/grafana/`

## Быстрое решение
Если нужно быстро запустить Grafana, можно временно использовать системный юнит:
```bash
# Остановить user-юнит
sudo -u CI10742292-lnx-mon_sys XDG_RUNTIME_DIR="/run/user/$(id -u CI10742292-lnx-mon_sys)" systemctl --user stop monitoring-grafana.service

# Запустить системный юнит
sudo systemctl start grafana-server
sudo systemctl enable grafana-server
```
