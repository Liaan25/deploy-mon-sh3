#!/bin/bash

# Скрипт для применения всех исправлений

echo "=== ПРИМЕНЕНИЕ ВСЕХ ИСПРАВЛЕНИЙ ==="
echo

# 1. Делаем файлы исполняемыми
echo "1. Делаем скрипты исполняемыми..."
chmod +x *.sh 2>/dev/null || true
echo "   ✅ Скрипты сделаны исполняемыми"
echo

# 2. Создаем резервную копию Jenkinsfile
echo "2. Создаем резервную копию Jenkinsfile..."
if [[ -f "Jenkinsfile" ]]; then
    cp Jenkinsfile Jenkinsfile.backup.$(date +%Y%m%d_%H%M%S)
    echo "   ✅ Создана резервная копия: Jenkinsfile.backup.*"
else
    echo "   ⚠️  Jenkinsfile не найден"
fi
echo

# 3. Применяем патч для Jenkinsfile
echo "3. Применяем патч для Jenkinsfile..."
if [[ -f "patch_jenkins_scp.sh" ]]; then
    ./patch_jenkins_scp.sh
    echo "   ✅ Патч применен"
else
    echo "   ⚠️  patch_jenkins_scp.sh не найден"
fi
echo

# 4. Создаем README с инструкциями
echo "4. Создаем README с инструкциями..."
cat > QUICK_START.md << 'EOF'
# Быстрый старт - исправление проблем Jenkins пайплайна

## Проблемы и решения

### 1. Проблема: SCP ошибка в Jenkins пайплайне
**Симптомы:** Пайплайн останавливается на `./scp_script.sh`
**Решение:** Исправленный Jenkinsfile с отладочным выводом

### 2. Проблема: HTTP 400 при создании сервисного аккаунта
**Симптомы:** `DEBUG_SA_RESPONSE: Ответ получен, HTTP код: 400`
**Решение:** Использовать `USE_GRAFANA_LOCALHOST=true` или изменить формат payload

## Созданные инструменты

### Для диагностики SCP:
- `test_ssh_connection.sh` - тестирование SSH подключения
- `diagnose_scp_problem.sh` - диагностика проблемы SCP
- `test_ssh_manual.sh` - ручное тестирование SSH

### Для исправления SCP:
- `patch_jenkins_scp.sh` - патч для Jenkinsfile
- `scp_script_fixed.sh` - исправленная версия скрипта

### Для HTTP 400 ошибки:
- `test_payload_formats.sh` - тестирование форматов payload
- `quick_fix_400_error.sh` - быстрые исправления
- `fixed_create_service_account.sh` - исправленная функция

## Быстрые команды

### 1. Проверить SSH подключение:
```bash
./test_ssh_manual.sh
```

### 2. Протестировать форматы payload:
```bash
./test_payload_formats.sh
```

### 3. Применить все исправления:
```bash
./apply_all_fixes.sh
```

### 4. Запустить пайплайн с исправлениями:
```bash
# Сначала закоммитьте изменения
git add .
git commit -m "Apply fixes for SCP and HTTP 400 issues"
git push

# Затем перезапустите пайплайн в Jenkins
```

## Рекомендуемый порядок действий

1. **Сначала исправьте SCP проблему:**
   - Примените патч к Jenkinsfile
   - Запушите изменения
   - Перезапустите пайплайн

2. **Если возникает HTTP 400:**
   - Используйте `USE_GRAFANA_LOCALHOST=true`
   - Или запустите `./test_payload_formats.sh` для диагностики

3. **Для быстрого решения:**
   ```bash
   export USE_GRAFANA_LOCALHOST=true
   # Перезапустите пайплайн
   ```

## Контакты для помощи

Если проблемы persist:
1. Проверьте логи Jenkins (теперь с отладочным выводом)
2. Запустите диагностические скрипты
3. Проверьте SSH ключ и доступность сервера

## Важные файлы

- `Jenkinsfile` - основной пайплайн (исправлен)
- `deploy_monitoring_script.sh` - скрипт развертывания
- `SCP_PROBLEM_ANALYSIS.md` - анализ проблемы SCP
- `FINAL_400_ERROR_ANALYSIS.md` - анализ HTTP 400
EOF

echo "   ✅ Создан QUICK_START.md"
echo

# 5. Показываем итоговую информацию
echo "5. Итоговая информация:"
echo "   Созданы следующие файлы:"
echo "   - Jenkinsfile.backup.* - резервная копия"
echo "   - Jenkinsfile - исправленная версия"
echo "   - QUICK_START.md - инструкции"
echo "   - Много диагностических скриптов"
echo
echo "   Следующие шаги:"
echo "   1. Проверьте изменения в Jenkinsfile:"
echo "      git diff Jenkinsfile"
echo
echo "   2. Закоммитьте изменения:"
echo "      git add ."
echo "      git commit -m 'Fix SCP script with debug output and error handling'"
echo "      git push"
echo
echo "   3. Перезапустите пайплайн в Jenkins"
echo
echo "   4. Если возникнет HTTP 400 ошибка:"
echo "      Используйте USE_GRAFANA_LOCALHOST=true"
echo "      Или запустите ./test_payload_formats.sh"
echo

echo "=== ВСЕ ИСПРАВЛЕНИЯ ПРИМЕНЕНЫ ==="
echo "Теперь ошибки в scp_script.sh будут видны в логах Jenkins!"
echo "Это позволит точно определить причину проблемы."
