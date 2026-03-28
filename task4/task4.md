## Подготовка
### Создание окружения
```
python -m venv venv
. ./venv/bin/activate.fish  # активация окружения
```

### Установка пакетов
```
pip install fastapi uvicorn sqlalchemy aiomysql playwright
```

### Запуск API точки
```
clear && python api-point.py
```

## Применение
### Зайти на GUI
`http://localhost/docs`

### Заполнение из БД
```
curl -X POST "http://127.0.0.1:8000/parse?use_more_button=False&max_page=10&start_page=2"
```

### Взятие из БД
```
curl -X GET "http://127.0.0.1:8000/get-catalog" -o catalog.json
```

- Красиво посмотреть: paru -S csview

```
python json_to_csv.py catalog.json output.csv
csview output.csv
```
