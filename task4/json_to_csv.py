#!/usr/bin/env python3
"""
Скрипт для конвертации JSON вывода API в CSV формат.
Использование:
    python json_to_csv.py input.json output.csv
    или
    curl "http://127.0.0.1:8000/get-catalog" | python json_to_csv.py - output.csv
"""

import json
import sys
import csv
from pathlib import Path


def json_to_csv(json_input, csv_output):
    """
    Конвертирует JSON с каталогом в CSV.
    
    Args:
        json_input: Путь к JSON файлу или '-' для stdin
        csv_output: Путь к выходному CSV файлу
    """
    # Читаем JSON
    if json_input == '-':
        data = json.load(sys.stdin)
    else:
        with open(json_input, 'r', encoding='utf-8') as f:
            data = json.load(f)
    
    # Извлекаем список каталога
    catalog = data.get('catalog', [])
    
    if not catalog:
        print("Нет данных в каталоге", file=sys.stderr)
        return
    
    # Записываем CSV
    with open(csv_output, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=catalog[0].keys())
        writer.writeheader()
        writer.writerows(catalog)
    
    print(f"✅ Конвертировано {len(catalog)} записей в {csv_output}", file=sys.stderr)


def main():
    if len(sys.argv) != 3:
        print("Использование:", file=sys.stderr)
        print("  python json_to_csv.py input.json output.csv", file=sys.stderr)
        print("  curl ... | python json_to_csv.py - output.csv", file=sys.stderr)
        sys.exit(1)
    
    json_input = sys.argv[1]
    csv_output = sys.argv[2]
    
    try:
        json_to_csv(json_input, csv_output)
    except Exception as e:
        print(f"Ошибка: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
