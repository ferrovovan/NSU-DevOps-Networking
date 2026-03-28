"""
Этот модуль определяет функции для взаимодействия
с базой данных MySQL, включая создание сессий, таблиц и сохранение данных.
"""
from typing import Type, List, Dict, Union

"""
SQLAlchemy - это «переводчик», с языка Python на язык SQL.

Вместо чистого SQL:
  "SELECT * FROM users WHERE age > 35"
Запрос пишется в коде
  session.query(User).filter(User.age > 35).all()
"""

from sqlalchemy import Column, Integer, String, Text, select
from sqlalchemy.orm import DeclarativeBase, Mapped
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.exc import SQLAlchemyError


class Base(DeclarativeBase):
	pass


class CatalogItem(Base):
	"""Модель для хранения записей каталога (результатов парсинга)."""
	__tablename__ = 'catalog'
	id: Mapped[int]     = Column(Integer, primary_key=True)
	rank: Mapped[str]   = Column(Integer,  nullable=False)
	title: Mapped[str]  = Column(String(500),   nullable=False)
	url: Mapped[str]    = Column(Text,   nullable=True)
	score: Mapped[int]  = Column(Integer,  nullable=True)
	author: Mapped[str] = Column(String(255),   nullable=True)
	age: Mapped[int]    = Column(Integer,  nullable=True)


async def init_db_session(connection_string: str) -> async_sessionmaker:
	"""
	Инициализирует асинхронную сессию базы данных SQLAlchemy и создаёт таблицы.
	Args:
		connection_string: Строка подключения к MySQL в формате
			'mysql+aiomysql://user:pass@host/dbname'
	Returns:
		async_sessionmaker: Фабрика асинхронных сессий.
	Raises:
		SQLAlchemyError: Если не удается установить соединение с базой данных.
	"""
	try:
		engine = create_async_engine(connection_string, echo=False)

		# Создаём таблицы (если их нет)
		async with engine.begin() as conn:
			await conn.run_sync(Base.metadata.create_all)
		
		async_session = async_sessionmaker(bind=engine)
		return async_session
	except SQLAlchemyError as e:
		raise SQLAlchemyError(f"Failed to initialize database session: {e}") from e



async def pack_data_into_db(
	async_session: async_sessionmaker,
	catalog: List[Dict[str, Union[str, int]]]
) -> None:
	"""
	Сохраняет список записей в таблицу catalog.

	Args:
		async_session: Фабрика асинхронных сессий.
		catalog: Список словарей, каждый из которых представляет запись
				 с ключами: rank, title, url, score, author, age.
	"""
	if not catalog:
		return

	async with async_session() as session:
		try:
			# Преобразуем словари в объекты модели
			items = [
				CatalogItem(
					rank=item['rank'],
					title=item['title'],
					url=item.get('url'),
					score=item.get('score'),
					author=item.get('author'),
					age=item.get('age')
				)
				for item in catalog
			]
			session.add_all(items)
			await session.commit()
		except SQLAlchemyError as e:
			await session.rollback()
			raise SQLAlchemyError(f"Ошибка при сохранении данных: {e}") from e


async def get_all_catalog_items(async_session: async_sessionmaker) -> List[Dict]:
	"""
	Возвращает все записи из таблицы catalog в виде списка словарей.

	Args:
		async_session: Фабрика асинхронных сессий.

	Returns:
		List[Dict]: Список записей, каждая – словарь с полями модели.
	"""
	async with async_session() as session:
		result = await session.execute(
			# Используем ORM-запрос: выбираем все объекты CatalogItem
			# Можно и просто session.query(CatalogItem).all(), но execute с select более современно
			select(CatalogItem)
		)
		items = result.scalars().all()
		# Преобразуем объекты в словари для JSON-ответа
		return [
			{
				'id': item.id,
				'rank': item.rank,
				'title': item.title,
				'url': item.url,
				'score': item.score,
				'author': item.author,
				'age': item.age
			}
			for item in items
		]
