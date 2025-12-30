#!/bin/bash

# Тест формата ответа curl

echo "=== ТЕСТ ФОРМАТА ОТВЕТА CURL ==="
echo

# Тест 1: Формат как в тестовом скрипте (работает)
echo "ТЕСТ 1: Формат как в тестовом скрипте (HTTP_CODE:)"
test_response1=$(echo -e '{"message":"test"}\nHTTP_CODE:200')
echo "Ответ:"
echo "$test_response1"
echo "HTTP код (grep HTTP_CODE:): $(echo "$test_response1" | grep "HTTP_CODE:" | cut -d: -f2)"
echo

# Тест 2: Формат как в основном скрипте (tail -1)
echo "ТЕСТ 2: Формат как в основном скрипте (tail -1)"
test_response2=$(echo -e '{"message":"test"}\n400')
echo "Ответ:"
echo "$test_response2"
echo "HTTP код (tail -1): $(echo "$test_response2" | tail -1)"
echo "Тело (head -n -1): $(echo "$test_response2" | head -n -1)"
echo

# Тест 3: Реальный пример с пустыми строками
echo "ТЕСТ 3: Реальный пример с возможными пустыми строками"
test_response3=$(echo -e '\n{"message":"Bad request data"}\n\n400\n')
echo "Ответ:"
echo "$test_response3"
echo "HTTP код (tail -1): '$(echo "$test_response3" | tail -1)'"
echo "Тело (head -n -1): '$(echo "$test_response3" | head -n -1)'"
echo

# Тест 4: Более надежный метод извлечения
echo "ТЕСТ 4: Более надежный метод извлечения"
test_response4=$(echo -e '\n{"message":"Bad request data"}\n\n400\n')
echo "Ответ:"
echo "$test_response4"

# Метод 1: Последняя непустая строка
last_line=$(echo "$test_response4" | grep -v '^$' | tail -1)
echo "Последняя непустая строка: '$last_line'"

# Метод 2: Разделение по последней строке с числом
if [[ "$last_line" =~ ^[0-9]+$ ]]; then
    http_code="$last_line"
    body=$(echo "$test_response4" | head -n -$(echo "$test_response4" | wc -l | awk '{print $1 - 1}'))
    echo "HTTP код (число): $http_code"
    echo "Тело: '$body'"
else
    echo "Последняя строка не число: $last_line"
fi

echo
echo "=== ВЫВОД ==="
echo "Проблема: Основной скрипт использует tail -1 и head -n -1"
echo "Если в ответе есть пустые строки, это ломает извлечение HTTP кода"
echo "Решение: Использовать более надежный метод извлечения"


