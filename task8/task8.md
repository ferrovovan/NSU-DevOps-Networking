# Показ миру

```
Цитата старого ментора:  
Не важно какой ты крутой программист,
  если не можешь показать это миру.



Показываем итоги "Гери Картману".
Нужно подружить VPN (запретное слово) со своим ПК.
Гери -> VPN сервер -> VPN клиент -> наш Nginx
```

### 1. Устанавливаем nginx
```
sudo apt update && sudo apt install nginx   # для Debian/Ubuntu
sudo systemctl enable --now nginx
```

### 2. Создаём точку проксирования
`nano /etc/nginx/conf.d/hacker-news.conf`

```
server {

        location /hacker-news/ {  # обязательно в конце с чертой [/]!
                if ($forbidden_country) {
                        # return 403 "Доступ из вашего региона ограничен.";
                        return 302 http://google.com;
                }

                #rewrite ^/hacker-news(.*)$ $1 break;  # Другой способ
                proxy_pass http://127.0.0.1:8007/;

                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Prefix /hacker-news;

        }
}
```

### 3.
http {
        server {
                listen 80;  server_name _;
                root /etc/nginx/html;
                error_page 403 /placeholder.html;
                location = /placeholder.html {
                        internal;
                }
        }
        geo $is_ru {
                default 0;
                include /etc/nginx/conf.d/ru_ips.txt;
        }

        include /etc/nginx/conf.d/*.conf;  # <-- Прошлое задание
}
```

### 4. API-точка
Проверяем, чтобы в API-точке была запись
```
app = FastAPI(
        root_path="/hacker-news",  <-- НЕОБХОДИМО ДОБАВИТЬ!
)
```

### 5. Применяем
```
sudo nginx -t && sudo systemctl reload nginx
```

### 6. Настройка SSH‑сервера
#### 1. GatewayPorts
В файле /etc/ssh/sshd_config убедитесь, что присутствует (или добавьте) строка:
```
GatewayPorts yes
```

#### 2.  Организация reverse tunnel с локальной машины
На вашем локальном компьютере (где уже запущены Docker‑контейнеры и nginx)
 выполните команду, которая пробросит порт 80 вашего локального nginx на порт 8007 VPS:

```
ssh -R 8007:localhost:80 user@<vps_ip> -N -f
```

### 7. Применение
Теперь  можно спокойно переходить на
`http://{ip}/hacker-news/docs`
