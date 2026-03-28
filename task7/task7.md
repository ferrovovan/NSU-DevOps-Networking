# Блокировка по IP

Есть 2 способа:
1. Статическая блокировка по подсетям
2. База данных GeoLite2-Country.mmdb

## Способ 1
Сработает для 99% устройств.
_(Кроме питерских ip)_

### 1. Запись списка
`/etc/nginx/conf.d/ru_ips.txt`
```
2.27.32.176 1;
5.18.0.0/16 1;
5.34.0.0/16 1;
5.53.192.0/19 1;

...  # И так далее
```
Берётся из нейронки

### 2. Изменение основного конфига
`/etc/nginx/nginx.conf`
```

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

### 3. Cвой конфиг:
`/etc/nginx/conf.d/hacker-news.conf`
```
server {
	location /hacker-news/ {
                if ($is_ru = 1) {
                        # return 403 "Доступ из вашего региона ограничен.";
                        return 404 /blocked;
                }

                proxy_pass http://127.0.0.1:8007/;

		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Prefix /hacker-news;
	}
}
```

## Способ 2: GEOIP2
Он странный - запустится, но не сработает.

### 1. Установка модуля
*На Arch Linux всё просто*
`paru -S nginx-mod-geoip2`

Модуль - это `.so`  
`file /usr/lib/nginx/modules/ngx_http_geoip2_module.so`

### 2. Скачать базу данных
```
sudo mkdir -p /etc/nginx/geoip
sudo curl -L -o /etc/nginx/geoip/GeoLite2-Country.mmdb \
    "https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb"
```

### 3. Добавляем заглушку
В самом верху `/etc/nginx/nginx.conf` (вне блоков) должен быть подключен модуль,
 а внутри блока http прописан путь к базе и логика проверки.

```
#  В начале файла
load_module /etc/nginx/modules-enabled/*.conf;
# load_module modules/ngx_http_geoip2_module.so;  # Или напрямую

http {
    # Указываем путь к базе данных
    geoip2 /etc/nginx/geoip/GeoLite2-Country.mmdb {
        auto_reload 5m;
        $geoip2_data_country_code country iso_code;
    }

    # Создаем переменную-флаг: 1 — запретить, 0 — разрешить
    map $geoip2_data_country_code $forbidden_country {
        default 0;
        RU      1; # Блокируем Россию
        # BY    1; # Можно добавить и другие
    }
    
    include /etc/nginx/conf.d/*.conf;
}
```

### 4. Дополняем редирект на наше приложение
```
server {
	...
	location / {
                if ($forbidden_country) {
                        # return 403 "Доступ из вашего региона ограничен.";
                        return 302 http://google.com;
                }
                proxy_pass http://127.0.0.1:8007/;
		...
	}
}
```

### 5. Проверка
Для проверки GEOIP2 можно _временно_ поставить `default 1`.

## Итог
Переходим на `http://localhost/docs` !
