#!/bin/bash
# Проверка синтаксиса основных функций

echo "=== Проверка синтаксиса deploy_monitoring_script.sh ==="
echo

# Проверяем основные функции на очевидные ошибки
echo "1. Проверка функции setup_grafana_datasource_and_dashboards..."
if grep -q "setup_grafana_datasource_and_dashboards()" deploy_monitoring_script.sh; then
    echo "   ✅ Функция найдена"
    
    # Проверяем наличие незакрытых кавычек
    function_start=$(grep -n "setup_grafana_datasource_and_dashboards()" deploy_monitoring_script.sh | head -1 | cut -d: -f1)
    function_end=$(grep -n "^}" deploy_monitoring_script.sh | awk -v start="$function_start" '$1 > start {print $1; exit}')
    
    if [[ -n "$function_end" ]]; then
        echo "   ✅ Функция имеет закрывающую скобку на строке $function_end"
        
        # Проверяем баланс кавычек в функции
        lines=$(sed -n "${function_start},${function_end}p" deploy_monitoring_script.sh)
        double_quotes=$(echo "$lines" | grep -o '"' | wc -l)
        single_quotes=$(echo "$lines" | grep -o "'" | wc -l)
        
        if (( double_quotes % 2 == 0 )); then
            echo "   ✅ Двойные кавычки сбалансированы ($double_quotes)"
        else
            echo "   ❌ Двойные кавычки не сбалансированы ($double_quotes)"
        fi
        
        if (( single_quotes % 2 == 0 )); then
            echo "   ✅ Одинарные кавычки сбалансированы ($single_quotes)"
        else
            echo "   ❌ Одинарные кавычки не сбалансированы ($single_quotes)"
        fi
    else
        echo "   ❌ Не найдена закрывающая скобка функции"
    fi
else
    echo "   ❌ Функция не найдена"
fi

echo
echo "2. Проверка функции ensure_grafana_token..."
if grep -q "ensure_grafana_token()" deploy_monitoring_script.sh; then
    echo "   ✅ Функция найдена"
else
    echo "   ❌ Функция не найдена"
fi

echo
echo "3. Проверка основных переменных..."
echo "   GRAFANA_PORT: $(grep -c "GRAFANA_PORT" deploy_monitoring_script.sh) упоминаний"
echo "   SERVER_DOMAIN: $(grep -c "SERVER_DOMAIN" deploy_monitoring_script.sh) упоминаний"
echo "   GRAFANA_BEARER_TOKEN: $(grep -c "GRAFANA_BEARER_TOKEN" deploy_monitoring_script.sh) упоминаний"

echo
echo "4. Проверка наличия критических ошибок..."
echo "   Незакрытые here-docs: $(grep -c "<<[[:space:]]*[A-Z]" deploy_monitoring_script.sh)"
echo "   Незакрытые кавычки в строках с curl:"
grep -n "curl.*\"" deploy_monitoring_script.sh | while read line; do
    line_num=$(echo "$line" | cut -d: -f1)
    content=$(echo "$line" | cut -d: -f2-)
    quotes=$(echo "$content" | grep -o '"' | wc -l)
    if (( quotes % 2 != 0 )); then
        echo "   ❌ Строка $line_num: нечетное количество кавычек ($quotes)"
    fi
done

echo
echo "=== РЕЗУЛЬТАТЫ ПРОВЕРКИ ==="
echo "Если нет ошибок '❌', то синтаксис в порядке."
echo "Для полной проверки запустите на Linux сервере:"
echo "  bash -n deploy_monitoring_script.sh"
