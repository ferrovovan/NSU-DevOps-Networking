# Показ миру

```
Цитата старого ментора:  
Не важно какой ты крутой программист,
  если не можешь показать это миру.



Показываем итоги "Гери Картману".
Нужно подружить VPN (запретное слово) со своим ПК.
Гери -> VPN сервер -> VPN клиент -> наш Nginx
```
Что будет?
1. Вам дадут арендованный сервак (Ubuntu)
2. Которым будут пользоваться все. Поэтому будьте терпимыми.

Рекомендую установить `fish`, чтоб не париться:
```
apt install -y fish

fish  # зайти в крутой терминал
```

И здесь показан проброс через reverse-ssh, 
  но по хорошему нужно настроить WireGuard.

## Выполнение задания
Чтобы не заморачиться, проще всем использовать блокировку по адресам

### 1. Устанавливаем nginx
```
sudo apt update && sudo apt install nginx   # для Debian/Ubuntu
sudo systemctl enable --now nginx
```

### 2. Создаём _свою_ точку проксирования
`nano /etc/nginx/conf.d/hacker-news.conf`

```
server {
        location /hacker-news/ {  # обязательно в конце с чертой [/]!
                if ($is_ru = 1) {
                        return 302 http://google.com;
                }

                proxy_pass http://127.0.0.1:8007/;  # <-- Своя точка!

                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Prefix /hacker-news;
        }
}
```

### 3. Главный конфиг
`/etc/nginx/nginx.conf`
```
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
        worker_connections 768;
}

# УМОЛЯЮ, НЕ МЕНЯЙТЕ ЗДЕСЬ НИЧЕГО
# ВСЕ ИЗМЕНЕНИЯ ДЕЛАТЬ В ЛИЧНЫХ ФАЙЛАХ /etc/nginx/conf.d/

http {
	# Общие настройки сервера
        server {
                listen 80;  server_name _;
                root /etc/nginx/;
                error_page 403 /html/placeholder.html;
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
 Не забудьте прописать `ru_ips.txt` и `placeholder.html`.

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

### 6. Настройка SSH‑сервера (проброс порта)
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
Не забудьте запустить 7-е задание и включить ssh-туннель!
Теперь  можно спокойно переходить на
`http://{ip}/hacker-news/docs`
