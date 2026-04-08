#!/bin/bash

# Останавливаем и удаляем старые контейнеры, если есть
echo "🧹 Очистка старых контейнеров..."
sudo docker stop client server 2>/dev/null || true
sudo docker rm   client server 2>/dev/null || true
echo "🧹 Очистка старой сети..."
sudo docker network rm  dualstack-net 2>/dev/null || true


# Создаем сеть
echo "🌐 Создание сети..."
sudo docker network create \
        --driver bridge \
        --ipv6 \
        --subnet=172.20.0.0/16 \
        --subnet=2001:db8:2::/64 \
        dualstack-net > /dev/null 2>&1


# Запускаем контейнеры
echo "📦 Запуск контейнеров..."
# Client
sudo docker run -d \
  --name client \
  --network dualstack-net \
  --ip 172.20.0.20 \
  --ip6 2001:db8:2::20 \
  alpine \
  sleep infinity > /dev/null 2>&1

# Server
sudo docker run -d \
  --name server \
  --network dualstack-net \
  --ip 172.20.0.10 \
  --ip6 2001:db8:2::10 \
  alpine \
  sh -c "apk update && apk add iperf3 tcpdump && iperf3 -s" \
   > /dev/null 2>&1

echo "⏳ Ожидание готовности контейнеров..."
sleep 10


echo "📡 Запуск tcpdump на сервере..."
sudo docker exec -d server tcpdump -i eth0 -w /tmp/ipv4.pcap ip
sudo docker exec -d server tcpdump -i eth0 -w /tmp/ipv6.pcap ip6
# Ждём пару секунд, чтобы tcpdump инициализировался
sleep 2


num=50
interval=1.0
time=$(echo "$interval * $num" | bc)

echo "🏓 Ping IPv4 & IPv6 ($num пакетов с $interval задержкой)..."
sudo docker exec -d client  \
	ping  -c $num -i $interval 172.20.0.10
sudo docker exec -d client  \
	ping6 -c $num -i $interval 2001:db8:2::10
echo "⏳ Ожидание выполнения пинга ($time секунд)..."
sleep $time

echo "🛑 Остановка tcpdump..."
sudo docker exec server pkill tcpdump || true
sleep 1

echo "📥 Копирование pcap-файлов на хост..."
sudo docker cp server:/tmp/ipv4.pcap ./ipv4.pcap
sudo docker cp server:/tmp/ipv6.pcap ./ipv6.pcap

echo "✅ Готово. Файлы: ipv4.pcap, ipv6.pcap"
