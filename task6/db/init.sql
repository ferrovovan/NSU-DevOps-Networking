-- Создаем базу данных, если её нет
CREATE DATABASE IF NOT EXISTS hackernews;

-- Создаем пользователя (если не существует)
CREATE USER IF NOT EXISTS 'user'@'%' IDENTIFIED BY 'password';

-- Даем права
GRANT ALL PRIVILEGES ON hackernews.* TO 'user'@'%';

-- Применяем изменения
FLUSH PRIVILEGES;
