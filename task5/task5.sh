# В нашем случае:
# 22 страницы * 30 новостей = 660 новостей
# То есть в таблица БД редко заполнится на 1000+ строк.

# app-container запущен на 8007

# """
# FastAPI приложение с двумя эндпоинтами:
# - POST /parse – запускает парсер Hacker News и сохраняет результат в БД.
# - GET /get-catalog – возвращает все сохранённые записи в формате JSON.
# - GET /get-catalog-csv - отсылает в потоке клиенту csv таблицу.
# """

# --- Применение ---
# Заполнение из БД
curl -X POST "http://127.0.0.1:8007/parse?use_more_button=False&max_page=10&start_page=2"
# Взятие из БД
curl -X GET "http://127.0.0.1:8007/get-catalog-csv" -o output.csv
# Красиво посмотреть: paru -S csview
csview output.csv
