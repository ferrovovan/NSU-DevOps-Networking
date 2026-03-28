#!/bin/bash

# Останавливаем и удаляем старые контейнеры, если есть
echo "🧹 Очистка старых контейнеров..."
sudo docker stop app-container db-container 2>/dev/null || true
sudo docker rm app-container db-container 2>/dev/null || true

# Создаем сеть
echo "🌐 Создание сети..."
sudo docker network create app-network 2>/dev/null || true

# Собираем образы
echo "🔨 Сборка образа базы данных..."
sudo docker build -t my-mariadb ./db

echo "🔨 Сборка образа приложения..."
sudo docker build -t my-app ./app

# Запускаем контейнер с базой данных
echo "🗄️ Запуск контейнера базы данных..."
sudo docker run -d \
    --name db-container \
    --network app-network \
    -e MYSQL_ROOT_PASSWORD=rootpassword \
    -e MYSQL_DATABASE=hackernews \
    -e MYSQL_USER=user \
    -e MYSQL_PASSWORD=password \
    -v mariadb-data:/var/lib/mysql \
    my-mariadb

# Ждем инициализации базы данных
echo "⏳ Ожидание готовности базы данных (5 секунды)..."
sleep 5

# Запускаем контейнер с приложением
echo "🚀 Запуск контейнера приложения..."
sudo docker run -d \
    --name app-container \
    --network app-network \
    -p 8007:8007 \
    -e DATABASE_URL="mysql+aiomysql://user:password@db-container:3306/hackernews" \
    my-app

echo ""
echo "✅ Контейнеры запущены!"
echo "🌐 Приложение доступно на http://localhost:8007"
echo "📚 Документация API: http://localhost:8007/docs"
echo ""
echo "Проверка статуса контейнеров:"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
