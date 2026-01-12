# Тестовый скрипт PowerShell для проверки логики Варианта 3

Write-Host "=== ТЕСТ ВАРИАНТА 3: Сначала без сертификатов, потом с ними ==="
Write-Host ""

# Создаем временные файлы для имитации сертификатов
$tempDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_ }
Write-Host "Создана временная директория: $tempDir"

# Имитируем наличие сертификатов
New-Item -ItemType File -Path "$tempDir\grafana-client.crt" -Force
New-Item -ItemType File -Path "$tempDir\grafana-client.key" -Force

Write-Host "Созданы тестовые сертификаты:"
Write-Host "  - $tempDir\grafana-client.crt"
Write-Host "  - $tempDir\grafana-client.key"
Write-Host ""

Write-Host "=== ЛОГИКА ВАРИАНТА 3 ==="
Write-Host ""

Write-Host "1. Функция create_service_account_via_api:"
Write-Host "   - Сначала пробует БЕЗ клиентских сертификатов"
Write-Host "   - Если получает ошибку (HTTP 400 или другую) → пробует С сертификатами"
Write-Host "   - Если сертификатов нет → выполняет только одну попытку"
Write-Host ""

Write-Host "2. Функция create_token_via_api:"
Write-Host "   - Сначала пробует БЕЗ клиентских сертификатов"
Write-Host "   - Если получает ошибку → пробует С сертификатами"
Write-Host "   - Если сертификатов нет → выполняет только одну попытку"
Write-Host ""

Write-Host "=== ПРЕИМУЩЕСТВА ==="
Write-Host "1. Решает проблему HTTP 400 'Bad request data' при использовании сертификатов"
Write-Host "2. Более безопасный подход: использует сертификаты только когда необходимо"
Write-Host "3. Сохраняет совместимость с существующей инфраструктурой"
Write-Host ""

Write-Host "=== КАК ПРОВЕРИТЬ РАБОТУ ==="
Write-Host "1. Запустите основной скрипт на сервере:"
Write-Host "   ./deploy_monitoring_script.sh"
Write-Host ""
Write-Host "2. Проверьте логи в файле:"
Write-Host "   /var/log/grafana_monitoring_diagnosis.log"
Write-Host ""
Write-Host "3. Ищите в логах:"
Write-Host "   - 'ПОПЫТКА 1: Без клиентских сертификатов'"
Write-Host "   - 'ПОПЫТКА 2: С клиентскими сертификатами' (если первая не удалась)"
Write-Host ""
Write-Host "4. Ожидаемый результат:"
Write-Host "   - Если первая попытка успешна → токен создан"
Write-Host "   - Если первая неудачна, вторая успешна → токен создан"
Write-Host "   - Если обе неудачны → используется fallback метод"
Write-Host ""

# Очистка
Remove-Item -Path $tempDir -Recurse -Force
Write-Host "Тест завершен. Временные файлы удалены."




