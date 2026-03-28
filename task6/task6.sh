# 1) Установка nginx 
sudo pacman -S nginx
# Для работы с nginx требуются root права.

# 2. Создание конфигурации для вашего домена
sudo mkdir /etc/nginx/conf.d/
sudo nano /etc/nginx/conf.d/app.conf
: << EOF
server {
    listen 80;
    server_name localhost;

    # Проксирование запросов в приложение
    location / {
        proxy_pass http://127.0.0.1:8007;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
>> EOF

# 3. Добавление в сервер
: << EOF
http {
	...
	include /etc/nginx/conf.d/*.conf;
	...
}
>> EOF

# 4. Проверка конфигурации nginx
sudo nginx -t
# `syntax is ok`

# 4. Перезагрузка nginx
sudo systemctl reload nginx
# Или, если nginx запущен вручную:
sudo nginx -s reload

# Теперь можно переходить на `http://localhost/docs` !
