# Диагностика проблем с Grafana

Созданы следующие скрипты для диагностики проблем с Grafana:

## 1. Комплексная диагностика - `diagnose_grafana.sh`
**Запуск:** `sudo ./diagnose_grafana.sh`

**Что проверяет:**
- Базовую систему (ОС, память, диски)
- Сетевые настройки
- Процесс Grafana и порты
- Сервисы systemd
- Файлы и директории
- Конфигурацию
- Логи
- Учетные данные Vault
- Сертификаты
- Доступность API
- Скрипты и обертки
- Переменные окружения
- Зависимости

**Вывод:** Цветной вывод с результатами проверок и рекомендациями.

## 2. Быстрый тест API - `quick_grafana_api_test.sh`
**Запуск:** `sudo ./quick_grafana_api_test.sh`

**Что проверяет:**
- Извлечение учетных данных из Vault
- Проверку порта и процесса
- Тестирование основных API endpoints:
  - `/api/health`
  - `/api/serviceaccounts` 
  - `/api/datasources`
  - `/api/folders`
- Попытку создания сервисного аккаунта и токена
- Проверку клиентских сертификатов

**Вывод:** Детальные результаты каждого API запроса.

## 3. Отладка функции - `debug_grafana_function.sh`
**Запуск:** `sudo ./debug_grafana_function.sh`

**Что делает:**
- Анализирует функцию `setup_grafana_datasource_and_dashboards()`
- Показывает структуру функции
- Ищет потенциальные проблемы
- Создает тестовые скрипты
- Дает рекомендации по отладке

**Вывод:** Анализ функции и создание тестовых сред.

## 4. Упрощенный тест - `/tmp/simple_grafana_test.sh`
**Запуск:** `sudo /tmp/simple_grafana_test.sh`

**Что проверяет:**
- Базовые проверки (порт, процесс)
- Файл с учетными данными
- Быстрый тест API

## Порядок диагностики:

### Шаг 1: Быстрая проверка
```bash
sudo /tmp/simple_grafana_test.sh
```

### Шаг 2: Комплексная диагностика  
```bash
sudo ./diagnose_grafana.sh
```

### Шаг 3: Детальный тест API
```bash
sudo ./quick_grafana_api_test.sh
```

### Шаг 4: Анализ функции
```bash
sudo ./debug_grafana_function.sh
```

## Частые проблемы и решения:

### 1. Порт 3000 не слушается
```bash
# Проверьте статус сервиса
sudo systemctl status grafana-server

# Запустите сервис
sudo systemctl start grafana-server

# Проверьте конфигурацию
sudo grep -n "http_port\|domain" /etc/grafana/grafana.ini
```

### 2. Проблемы с учетными данными
```bash
# Проверьте файл
sudo cat /opt/vault/conf/data_sec.json

# Проверьте структуру
sudo jq '.' /opt/vault/conf/data_sec.json

# Извлеките учетные данные
sudo jq '.grafana_web' /opt/vault/conf/data_sec.json
```

### 3. Ошибки API
```bash
# Проверьте вручную
USER=$(sudo jq -r '.grafana_web.user' /opt/vault/conf/data_sec.json)
PASS=$(sudo jq -r '.grafana_web.pass' /opt/vault/conf/data_sec.json)
sudo curl -k -v -u "${USER}:${PASS}" https://localhost:3000/api/health

# Проверьте логи
sudo journalctl -u grafana-server -n 50 --no-pager
```

### 4. Проблемы с клиентскими сертификатами
```bash
# Проверьте наличие
sudo ls -la /opt/vault/certs/

# Проверьте содержимое
sudo head -c 100 /opt/vault/certs/grafana-client.crt
sudo head -c 100 /opt/vault/certs/grafana-client.key
```

## Создание отчета:
Все скрипты создают подробные логи. Для создания отчета:

```bash
# Запустите диагностику и сохраните в файл
sudo ./diagnose_grafana.sh 2>&1 | tee /tmp/grafana_diagnosis_$(date +%Y%m%d_%H%M%S).log

# Добавьте тест API
sudo ./quick_grafana_api_test.sh 2>&1 | tee -a /tmp/grafana_diagnosis_$(date +%Y%m%d_%H%M%S).log
```

## Автоматическое исправление:
Если диагностика выявила проблемы с форматом JSON файла, скрипты могут автоматически исправить:

1. Windows line endings (`\r\n` → `\n`)
2. Лишние запятые в JSON
3. Проблемы с кодировкой

**Внимание:** Перед исправлением создается backup файла.

## Контакты для помощи:
Если диагностика не помогла решить проблему, предоставьте:
1. Вывод `sudo ./diagnose_grafana.sh`
2. Вывод `sudo ./quick_grafana_api_test.sh`
3. Логи Grafana: `sudo journalctl -u grafana-server -n 100`
4. Содержимое `/opt/vault/conf/data_sec.json` (без паролей)



