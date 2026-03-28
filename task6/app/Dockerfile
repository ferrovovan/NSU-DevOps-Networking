FROM python:3.11-slim

# 1. Устанавливаем playwright через pip заранее
RUN pip install --no-cache-dir playwright


# 2. Устанавливаем системные зависимости для Playwright
RUN apt-get update && \
    apt-get install -y iputils-ping  # Для проверки
RUN playwright install-deps chromium && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 3. Устанавливаем сам браузер
RUN playwright install chromium

# 4. Устанавливаем зависимости приложения
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5. Копируем код приложения
COPY api-point.py .
COPY database.py .
COPY parser.py .
COPY json_to_csv.py .

# Открываем порт (не 80)
EXPOSE 8007

# Запускаем приложение
CMD ["uvicorn", "api-point:app", "--host", "0.0.0.0", "--port", "8007"]
