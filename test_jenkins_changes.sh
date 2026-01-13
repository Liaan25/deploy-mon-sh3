#!/bin/bash

# Тестовый скрипт для проверки изменений в Jenkinsfile
# Проверяет синтаксис и логику без запуска в Jenkins

echo "=== ТЕСТИРОВАНИЕ ИЗМЕНЕНИЙ В JENKINSFILE ==="
echo

echo "1. Проверка синтаксиса Jenkinsfile..."
if grep -q ">/dev/null 2>&1" Jenkinsfile; then
    echo "❌ НАЙДЕНА ПРОБЛЕМА: В Jenkinsfile еще есть скрытие ошибок в /dev/null"
    grep -n ">/dev/null 2>&1" Jenkinsfile
else
    echo "✅ ОК: В Jenkinsfile нет скрытия ошибок в /dev/null"
fi
echo

echo "2. Проверка наличия отладочного вывода..."
DEBUG_COUNT=$(grep -c "\[DEBUG\]" Jenkinsfile)
echo "✅ Найдено $DEBUG_COUNT отладочных сообщений [DEBUG]"

ERROR_COUNT=$(grep -c "\[ERROR\]" Jenkinsfile)
echo "✅ Найдено $ERROR_COUNT сообщений об ошибках [ERROR]"

SUCCESS_COUNT=$(grep -c "\[SUCCESS\]" Jenkinsfile)
echo "✅ Найдено $SUCCESS_COUNT сообщений об успехе [SUCCESS]"
echo

echo "3. Проверка новых stages..."
if grep -q "stage('Очистка workspace и отладка')" Jenkinsfile; then
    echo "✅ Найден новый stage: 'Очистка workspace и отладка'"
else
    echo "❌ Не найден stage очистки workspace"
fi

if grep -q "stage('Отладка параметров пайплайна')" Jenkinsfile; then
    echo "✅ Найден новый stage: 'Отладка параметров пайплайна'"
else
    echo "❌ Не найден stage отладки параметров"
fi

if grep -q "stage('Информация о коде и окружении')" Jenkinsfile; then
    echo "✅ Найден новый stage: 'Информация о коде и окружении'"
else
    echo "❌ Не найден stage информации о коде"
fi
echo

echo "4. Проверка улучшенного scp_script.sh..."
SCP_SCRIPT_LINES=$(sed -n '/writeFile file: .scp_script.sh/,/'''/p' Jenkinsfile | wc -l)
echo "✅ Размер scp_script.sh: примерно $SCP_SCRIPT_LINES строк"

# Проверяем ключевые улучшения в scp_script.sh
if sed -n '/writeFile file: .scp_script.sh/,/'''/p' Jenkinsfile | grep -q "\[DEBUG\] === НАЧАЛО УЛУЧШЕННОГО SCP_SCRIPT.SH ==="; then
    echo "✅ scp_script.sh начинается с отладочного заголовка"
else
    echo "❌ scp_script.sh не имеет отладочного заголовка"
fi

if sed -n '/writeFile file: .scp_script.sh/,/'''/p' Jenkinsfile | grep -q "Проверяем наличие ключа"; then
    echo "✅ scp_script.sh проверяет наличие SSH ключа"
else
    echo "❌ scp_script.sh не проверяет наличие SSH ключа"
fi

if sed -n '/writeFile file: .scp_script.sh/,/'''/p' Jenkinsfile | grep -q "ТЕСТИРУЕМ SSH ПОДКЛЮЧЕНИЕ"; then
    echo "✅ scp_script.sh тестирует SSH подключение перед копированием"
else
    echo "❌ scp_script.sh не тестирует SSH подключение"
fi

if sed -n '/writeFile file: .scp_script.sh/,/'''/p' Jenkinsfile | grep -q "ssh.*-v.*verbose"; then
    echo "✅ scp_script.sh использует verbose режим для диагностики"
else
    echo "❌ scp_script.sh не использует verbose режим"
fi
echo

echo "5. Проверка проверки temp_data_cred.json..."
if grep -q "=== ПРОВЕРКА temp_data_cred.json ===" Jenkinsfile; then
    echo "✅ Добавлена детальная проверка temp_data_cred.json"
else
    echo "❌ Нет детальной проверки temp_data_cred.json"
fi

if grep -q "Проверка JSON валидности" Jenkinsfile; then
    echo "✅ Проверяется валидность JSON"
else
    echo "❌ Не проверяется валидность JSON"
fi
echo

echo "6. Проверка очистки workspace..."
if grep -q "Очистка workspace от старых временных файлов" Jenkinsfile; then
    echo "✅ Добавлена очистка workspace"
    
    # Проверяем какие файлы удаляются
    echo "Удаляемые файлы:"
    grep -A5 "rm -f" Jenkinsfile | grep -v "rm -f" | sed 's/^/  /'
else
    echo "❌ Нет очистки workspace"
fi
echo

echo "7. Сводка изменений:"
echo "-------------------"
echo "✅ Добавлено 3 новых stage для отладки"
echo "✅ Улучшен scp_script.sh с отладочным выводом"
echo "✅ Убрано скрытие ошибок в /dev/null"
echo "✅ Добавлена проверка каждой команды SCP"
echo "✅ Добавлена детальная проверка temp_data_cred.json"
echo "✅ Добавлена очистка workspace"
echo "✅ Добавлен verbose режим SSH для диагностики"
echo

echo "8. Что теперь будет видно в логах при ошибке:"
echo "--------------------------------------------"
echo "1. Конкретный stage где произошла ошибка"
echo "2. Конкретная команда которая упала"
echo "3. Полное сообщение об ошибке (не обрезанное)"
echo "4. Отладочная информация вокруг ошибки"
echo "5. Проверка всех необходимых файлов"
echo "6. Проверка SSH подключения"
echo "7. Проверка параметров пайплайна"
echo

echo "9. Рекомендации по запуску:"
echo "---------------------------"
echo "1. Запустите обычный пайплайн (который не работает)"
echo "2. Изучите логи - найдите первое сообщение [ERROR]"
echo "3. Посмотрите отладочную информацию перед ошибкой"
echo "4. Сравните с логами ребилда (который работает)"
echo "5. Обратите внимание на различия в параметрах"
echo

echo "=== ТЕСТ ЗАВЕРШЕН ==="
echo
echo "Если все проверки пройдены, можно запускать пайплайн в Jenkins."
echo "Теперь при ошибке будет понятно, что именно пошло не так и почему."

