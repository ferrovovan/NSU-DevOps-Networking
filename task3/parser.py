import csv
import asyncio

from playwright.async_api import async_playwright


# ---------- Функции для пагинации ----------
async def next_page(page):
	"""
	Нажимает на кнопку "More" для перехода на следующую страницу.
	Возвращает True, если переход выполнен, иначе False.
	"""
	try:
		# Ищем ссылку "More" (обычно находится в самом низу)
		more_link = page.locator(".morelink")
		if await more_link.count() > 0:
			await more_link.first.click()
			# Ждём появления новых элементов (изменение URL или загрузка контейнера)
			await page.wait_for_selector("#bigbox", timeout=10000)
			return True
		else:
			return False
	except Exception as e:
		print(f"Ошибка при переходе на следующую страницу: {e}")
		return False


async def go_to_max_page(page, max_page=22):
	"""
	Переходит напрямую на страницу со всеми загруженными страницами.
	(закреплённое значение)
	"""
	url = f"https://news.ycombinator.com/?p={max_page}"
	await page.goto(url)
	await page.wait_for_selector("#bigbox", timeout=10000)


# =========== Парсинг внутренних элементов =============
async def parse_athing_row(row):
    """
    Извлекает данные из строки с классом 'athing submission'.
    Возвращает словарь с полями: rank, title, url.
    """
    # Ранг
    rank_elem = await row.query_selector("span.rank")
    rank = await rank_elem.text_content() if rank_elem else None
    if rank:
        rank = rank.replace(".", "").strip()  # убираем точку в конце

    # Заголовок и ссылка
    title_elem = await row.query_selector("span.titleline > a")
    title = await title_elem.text_content() if title_elem else None
    url = await title_elem.get_attribute("href") if title_elem else None

    return {
        "rank": rank,
        "title": title,
        "url": url
    }


async def parse_subtext_row(row):
    """
    Извлекает данные из строки с подстрочным текстом (subtext).
    Возвращает словарь с полями: score, author.
    """
    # Очки (score)
    score_elem = await row.query_selector("span.score")
    score_text = await score_elem.text_content() if score_elem else None
    score = None
    if score_text:
        # Ожидается формат "X points"
        parts = score_text.split()
        if parts:
            try:
                score = int(parts[0])
            except ValueError:
                pass

    # Автор
    author_elem = await row.query_selector("a.hnuser")
    author = await author_elem.text_content() if author_elem else None

    return {
        "score": score,
        "author": author
    }


# ---------- Функция парсинга одной страницы ----------
async def parse_page(page):
    """
    Собирает данные со страницы, используя контейнер.
    Возвращает список словарей с полями: rank, title, url, score, author.
    """
    container_selector = "#bigbox > td:nth-child(1) > table:nth-child(1) > tbody:nth-child(1)"
    # Ожидание загрузки контейнера
    await page.wait_for_selector(container_selector, timeout=2500)

    # Получаем все строки внутри tbody
    rows = await page.query_selector_all(f"{container_selector} > tr")
    results = []

    i = 0
    while i <= len(rows) - 3:  # для полной группы нужно минимум 3 строки
        athing_row = rows[i]
        subtext_row = rows[i + 1]
        spacer_row = rows[i + 2]

        # Проверяем, что первая строка — это элемент с классом "athing submission"
        athing_class = await athing_row.get_attribute("class")
        if not athing_class or "athing" not in athing_class or "submission" not in athing_class:
            i += 1
            continue

        # Проверяем, что третья строка — разделитель (класс "spacer")
        spacer_class = await spacer_row.get_attribute("class")
        if not spacer_class or "spacer" not in spacer_class:
            i += 1
            continue

        # Извлекаем данные из двух первых строк
        athing_data = await parse_athing_row(athing_row)
        subtext_data = await parse_subtext_row(subtext_row)

        # Объединяем словари в один элемент
        item = {**athing_data, **subtext_data}
        results.append(item)

        i += 3  # переходим к следующей группе

    return results



# ---------- Функция записи в CSV ----------
def write_to_csv(data, filename="hacker_news.csv"):
	"""
	Записывает список словарей в CSV-файл.
	"""
	if not data:
		print("Нет данных для записи.")
		return
	
	fieldnames = ['rank', 'title', 'url', 'score', 'author', 'age']
	with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
		writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
		writer.writeheader()
		writer.writerows(data)
	print(f"Данные сохранены в {filename}")


# ---------- Основная функция ----------
async def main(start_page=1, max_page=22, use_more_button=True):
	"""
	Парсит Hacker News со start_page до max_page.
	Если use_more_button=True, использует нажатие "More" для перехода между страницами.
	Иначе переходит напрямую по URL с номером страницы.
	"""
	all_items = []
	
	async with async_playwright() as p:
		# Запуск браузера (headless=False для отладки)
		browser = await p.chromium.launch(headless=False)
		page = await browser.new_page()
		
		# Переход на первую страницу
		if start_page > 1:
			await go_to_max_page(page, start_page)
		else:
			await page.goto("https://news.ycombinator.com/")
			await page.wait_for_selector("#bigbox", timeout=10000)
		
		current_page = start_page
		while current_page <= max_page:
			print(f"Парсинг страницы {current_page}...")
			items = await parse_page(page)
			print(f"Найдено {len(items)} новостей")
			all_items.extend(items)
			
			# Переход на следующую страницу
			if use_more_button:
				# Нажимаем "More" и проверяем успешность
				success = await next_page(page)
				if not success:
					print("Кнопка 'More' не найдена. Завершаем.")
					break
			else:
				# Переходим по прямой ссылке
				current_page += 1
				if current_page > max_page:
					break
				await go_to_max_page(page, current_page)
		
		await browser.close()
	
	# Запись всех данных в CSV
	write_to_csv(all_items)

if __name__ == "__main__":
	# Пример: парсим все страницы с 3 по 6, используя прямой переход (быстрее)
	asyncio.run(main(start_page=3, max_page=6, use_more_button=False))
	
	# Альтернатива: парсим с 5-й страницы и далее через кнопку "More"
	# asyncio.run(main(start_page=5, max_page=22, use_more_button=True))
