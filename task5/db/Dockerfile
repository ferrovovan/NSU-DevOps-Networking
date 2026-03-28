FROM mariadb:11.2

# Копируем скрипт инициализации
COPY init.sql /docker-entrypoint-initdb.d/

# Устанавливаем переменные окружения для MariaDB
ENV MYSQL_ROOT_PASSWORD=rootpassword
ENV MYSQL_DATABASE=hackernews
ENV MYSQL_USER=user
ENV MYSQL_PASSWORD=password
