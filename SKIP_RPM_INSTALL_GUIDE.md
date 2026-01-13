# Руководство по использованию SKIP_RPM_INSTALL

## Назначение
Переменная окружения `SKIP_RPM_INSTALL` позволяет пропустить установку RPM пакетов через RLM для ускорения отладки и тестирования других частей системы мониторинга.

## Как использовать

### Вариант 1: Запуск пайплайна Jenkins
```bash
# В настройках пайплайна Jenkins добавьте переменную:
SKIP_RPM_INSTALL=true
```

### Вариант 2: Прямой запуск скрипта
```bash
# Экспортируйте переменную перед запуском
export SKIP_RPM_INSTALL=true
sudo ./deploy_monitoring_script.sh
```

### Вариант 3: Однострочный запуск
```bash
SKIP_RPM_INSTALL=true sudo ./deploy_monitoring_script.sh
```

## Что происходит при SKIP_RPM_INSTALL=true

### Пропускается:
1. **Установка RPM пакетов через RLM** - функция `create_rlm_install_tasks()` не выполняется
2. **Создание задач RLM** для установки:
   - Grafana
   - Prometheus  
   - Harvest

### Выполняется (если пакеты уже установлены):
1. **Настройка сертификатов** - `setup_certificates_after_install()`
2. **Конфигурация Harvest** - `configure_harvest()` (пропускается если `/opt/harvest` не существует)
3. **Конфигурация Prometheus** - `configure_prometheus()` (пропускается если `/etc/prometheus` не существует)
4. **Настройка iptables** - `configure_iptables()`
5. **Настройка user-юнитов** - `setup_monitoring_user_units()`
6. **Конфигурация сервисов** - `configure_services()`
7. **Настройка Grafana** - `setup_grafana_datasource_and_dashboards()` (пропускается если Grafana не установлена)

## Проверки добавленные для безопасной работы

### 1. Функция `configure_harvest()`
```bash
if [[ ! -d "/opt/harvest" ]]; then
    print_warning "Директория /opt/harvest еще не существует, пропускаем настройку"
    return 0
fi
```

### 2. Функция `configure_prometheus()`
```bash
if [[ ! -d "/etc/prometheus" ]]; then
    print_warning "Директория /etc/prometheus не существует (Prometheus не установлен)"
    print_info "Если используется SKIP_RPM_INSTALL=true, это ожидаемо"
    return 0
fi
```

### 3. Функция `configure_grafana_ini()`
```bash
if [[ ! -d "/etc/grafana" ]]; then
    print_warning "Директория /etc/grafana не существует (Grafana не установлена)"
    print_info "Если используется SKIP_RPM_INSTALL=true, это ожидаемо"
    return 0
fi
```

### 4. Функция `configure_prometheus_files()`
```bash
if [[ ! -d "/etc/prometheus" ]]; then
    print_warning "Директория /etc/prometheus не существует (Prometheus не установлен)"
    print_info "Если используется SKIP_RPM_INSTALL=true, это ожидаемо"
    return 0
fi
```

### 5. Функция `setup_grafana_datasource_and_dashboards()`
```bash
if [[ ! -d "/usr/share/grafana" && ! -d "/etc/grafana" ]]; then
    print_warning "Grafana не установлена (отсутствуют /usr/share/grafana и /etc/grafana)"
    print_info "Если используется SKIP_RPM_INSTALL=true, пропускаем настройку datasource и дашбордов"
    return 0
fi
```

## Сочетание с другими флагами пропуска

### SKIP_VAULT_INSTALL
```bash
# Можно использовать оба флага одновременно
SKIP_VAULT_INSTALL=true
SKIP_RPM_INSTALL=true
```

### USE_GRAFANA_LOCALHOST
```bash
# Для отладки Grafana API можно использовать localhost
USE_GRAFANA_LOCALHOST=true
SKIP_RPM_INSTALL=true
```

## Примеры использования

### Пример 1: Отладка проблем с Grafana API
```bash
# Пропускаем установку пакетов, используем уже установленную Grafana
SKIP_RPM_INSTALL=true ./deploy_monitoring_script.sh
```

### Пример 2: Тестирование конфигурации без установки
```bash
# Проверяем только конфигурационные файлы
SKIP_RPM_INSTALL=true SKIP_VAULT_INSTALL=true ./deploy_monitoring_script.sh
```

### Пример 3: Отладка конкретной функции
```bash
# Пропускаем установку, тестируем только настройку Grafana
SKIP_RPM_INSTALL=true
# Скрипт пропустит установку пакетов, но попробует настроить Grafana если она установлена
```

## Важные замечания

### 1. **Требуются установленные пакеты**
Для работы функций конфигурации соответствующие пакеты должны быть уже установлены в системе.

### 2. **Диагностические сообщения**
При пропуске настройки из-за отсутствия пакетов выводятся предупреждения с пояснением:
```
⚠️  Директория /etc/grafana не существует (Grafana не установлена)
ℹ️  Если используется SKIP_RPM_INSTALL=true, это ожидаемо
```

### 3. **Безопасность**
- Функции возвращают код 0 (успех) при пропуске
- Не возникает ошибок или падений скрипта
- Логика работы не нарушается

### 4. **Обратная совместимость**
- Без флага `SKIP_RPM_INSTALL` скрипт работает как обычно
- Все проверки добавлены с условиями, не влияющими на нормальную работу

## Диагностика

### Проверка состояния пакетов
```bash
# Проверьте, установлены ли пакеты
ls -la /opt/harvest 2>/dev/null || echo "Harvest не установлен"
ls -la /etc/prometheus 2>/dev/null || echo "Prometheus не установлен"
ls -la /etc/grafana 2>/dev/null || echo "Grafana не установлена"
```

### Проверка логов
При использовании `SKIP_RPM_INSTALL=true` в логах будут сообщения:
```
[INFO] SKIP_RPM_INSTALL=true: пропускаем create_rlm_install_tasks, предполагаем что пакеты уже установлены
[WARNING] Директория /etc/grafana не существует (Grafana не установлена)
[INFO] Если используется SKIP_RPM_INSTALL=true, это ожидаемо
```

## Заключение
Флаг `SKIP_RPM_INSTALL` позволяет значительно ускорить процесс отладки, пропуская длительную установку RPM пакетов и сосредотачиваясь на тестировании конфигурации и интеграции компонентов системы мониторинга.





