import os
from typing import Optional

import uvicorn
from fastapi import FastAPI, HTTPException, Query
from contextlib import asynccontextmanager
from sqlalchemy.exc import SQLAlchemyError

from database import init_db_session, pack_data_into_db, get_all_catalog_items
from parser import main as parse_hackernews


"""
FastAPI приложение с двумя эндпоинтами:
- POST /parse – запускает парсер Hacker News и сохраняет результат в БД.
- GET /get-catalog – возвращает все сохранённые записи в формате JSON.
"""

# Строка подключения к MySQL (можно через переменную окружения)
# Пример: "mysql+aiomysql://user:password@localhost/hackernews"
DATABASE_URL = os.getenv("DATABASE_URL", "mysql+aiomysql://youruser:yourpassword@localhost/hackernews")

# Глобальная фабрика сессий (будет инициализирована при старте)
db_session_maker = None

@asynccontextmanager
async def lifespan(app: FastAPI):
	"""Lifespan-менеджер для инициализации и закрытия ресурсов."""
	global db_session_maker
	try:
		db_session_maker = await init_db_session(DATABASE_URL)
		print("✅ База данных инициализирована")
	except Exception as e:
		print(f"❌ Ошибка инициализации БД: {e}")
		raise
	yield

app = FastAPI(
	title="Hacker News Parser API",
	description="API для запуска парсинга Hacker News и получения каталога",
	version="1.0.0",
	lifespan=lifespan
)


@app.post(
	"/parse",
	tags=["Парсинг 🕷️"],
	summary="Запуск парсинга Hacker News",
	description="Запускает асинхронный парсер Hacker News и сохраняет результаты в MySQL."
)
async def parse(
	start_page: int = Query(1, description="Стартовая страница", ge=1, le=100),
	max_page: int = Query(22, description="Конечная страница", ge=1, le=100),
	use_more_button: bool = Query(True, description="Использовать кнопку 'More' для перехода"),
):
	"""
	Эндпоинт запускает парсер Hacker News.
	Параметры:
	- start_page: номер начальной страницы (по умолчанию 1)
	- max_page: номер последней страницы (по умолчанию 22)
	- use_more_button: если True, использует кнопку 'More', иначе переход по URL
	"""
	#global db_session_maker
	if db_session_maker is None:
		raise HTTPException(status_code=500, detail="База данных не инициализирована")

	try:
		# Запускаем парсер (асинхронная функция)
		items = await parse_hackernews(
			start_page=start_page,
			max_page=max_page,
			use_more_button=use_more_button
		)
		# Сохраняем в базу
		await pack_data_into_db(db_session_maker, items)
		return {
			"status": "success",
			"message": f"Парсинг завершён, сохранено {len(items)} записей",
			"items_count": len(items)
		}
	except Exception as e:
		raise HTTPException(status_code=500, detail=f"Ошибка при парсинге: {str(e)}")


@app.get(
	"/get-catalog",
	tags=["Каталог 📂"],
	summary="Получение всех записей из каталога",
	description="Возвращает все сохранённые в БД записи в виде JSON."
)
async def get_catalog_json():
	"""Эндпоинт возвращает список всех записей из таблицы catalog."""
	# global db_session_maker
	if db_session_maker is None:
		raise HTTPException(status_code=500, detail="База данных не инициализирована")

	try:
		catalog = await get_all_catalog_items(db_session_maker)
		return {"catalog": catalog}
	except Exception as e:
		raise HTTPException(status_code=500, detail=f"Ошибка при чтении БД: {str(e)}")


if __name__ == '__main__':
	uvicorn.run("api-point:app", host="0.0.0.0", port=8000, reload=True)
