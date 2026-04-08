#!/usr/bin/env bash

# Скрипт для сбора статистики по полям IPv4 и IPv6 из pcap-файлов.
# Требуется установленный tshark (из пакета wireshark).
# Файлы захвата: ipv4.pcap и ipv6.pcap должны находиться в текущей директории.

set -euo pipefail

# Проверка наличия tshark
if ! command -v tshark &> /dev/null; then
    echo "Ошибка: tshark не найден. Установите Wireshark." >&2
    exit 1
fi

# Проверка существования файлов
check_files() {
    local type="$1"
    if [[ "$type" == "ipv4" && ! -f "ipv4.pcap" ]]; then
        echo "Ошибка: файл ipv4.pcap не найден." >&2
        exit 1
    elif [[ "$type" == "ipv6" && ! -f "ipv6.pcap" ]]; then
        echo "Ошибка: файл ipv6.pcap не найден." >&2
        exit 1
    fi
}


# Общая функция для получения среднего числового значения из поля tshark
# Параметры: тип, поле для ipv4, поле для ipv6, (опционально) признак "не число"
# Возвращает: среднее (с плавающей точкой) или переданный fallback
get_average() {
    local type="$1"
    local field4="$2"
    local field6="$3"
    local fallback="${4:-}"

    local field=""
    local pcap=""

    case "$type" in
        ipv4)
            field="$field4"
            pcap="ipv4.pcap"
            ;;
        ipv6)
            field="$field6"
            pcap="ipv6.pcap"
            ;;
        *)
            echo "Неверный тип: $type" >&2
            return 1
    esac

    if [[ -z "$field" ]]; then
        echo "$fallback"
        return
    fi

    local values
    values=$(tshark -r "$pcap" -T fields -e "$field" 2>/dev/null | grep -v '^$')
    if [[ -z "$values" ]]; then
        echo "0"
        return
    fi

    echo "$values" | awk '{sum+=$1; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}'
}

# Функция для подсчёта уникальных адресов (источник или назначение)
get_unique_count() {
    local type="$1"
    local field4="$2"
    local field6="$3"

    local field=""
    local pcap=""

    case "$type" in
        ipv4)
            field="$field4"
            pcap="ipv4.pcap"
            ;;
        ipv6)
            field="$field6"
            pcap="ipv6.pcap"
            ;;
        *)
            echo "0"
            return
    esac

    tshark -r "$pcap" -T fields -e "$field" 2>/dev/null | grep -v '^$' | sort -u | wc -l
}

# --- Функции для каждого поля (согласно таблице) ---

src_addr_stats() {
    get_unique_count "$1" "ip.src" "ipv6.src"
}

dst_addr_stats() {
    get_unique_count "$1" "ip.dst" "ipv6.dst"
}

packet_length_stats() {
    get_average "$1" "ip.len" "ipv6.plen" "0"
}

traffic_type_stats() {
    get_average "$1" "ip.dsfield" "ipv6.tclass" "0"
}

flow_label_stats() {
    if [[ "$1" == "ipv4" ]]; then
        echo "нет поля"
    else
        get_average "ipv6" "" "ipv6.flow" "0"
    fi
}

ttl_stats() {
    get_average "$1" "ip.ttl" "ipv6.hlim" "0"
}

protocol_stats() {
    get_average "$1" "ip.proto" "ipv6.nxt" "0"
}

checksum_stats() {
    if [[ "$1" == "ipv4" ]]; then
        # Проверяем, есть ли хотя бы одна контрольная сумма (всегда есть, но для строгости)
        local pcap="ipv4.pcap"
        local checksums
        checksums=$(tshark -r "$pcap" -T fields -e "ip.checksum" 2>/dev/null | grep -v '^$' | head -1)
        if [[ -n "$checksums" ]]; then
            echo "присутствует"
        else
            echo "отсутствует"
        fi
    else
        echo "отсутствует"
    fi
}

# --- Формирование CSV ---

# Заголовок
echo "Field,IPv4,IPv6"

# Строка для адреса источника
src4=$(src_addr_stats "ipv4")
src6=$(src_addr_stats "ipv6")
echo "Адрес источника,$src4,$src6"

# Адрес назначения
dst4=$(dst_addr_stats "ipv4")
dst6=$(dst_addr_stats "ipv6")
echo "Адрес назначения,$dst4,$dst6"

# Длина пакета
len4=$(packet_length_stats "ipv4")
len6=$(packet_length_stats "ipv6")
echo "Длина пакета,$len4,$len6"

# Тип трафика
tclass4=$(traffic_type_stats "ipv4")
tclass6=$(traffic_type_stats "ipv6")
echo "Тип трафика,$tclass4,$tclass6"

# Метка потока
flow4=$(flow_label_stats "ipv4")
flow6=$(flow_label_stats "ipv6")
echo "Метка потока,$flow4,$flow6"

# Время жизни (TTL/Hop Limit)
ttl4=$(ttl_stats "ipv4")
ttl6=$(ttl_stats "ipv6")
echo "Время жизни,$ttl4,$ttl6"

# Протокол выше
proto4=$(protocol_stats "ipv4")
proto6=$(protocol_stats "ipv6")
echo "Протокол выше,$proto4,$proto6"

# Контрольная сумма
chk4=$(checksum_stats "ipv4")
chk6=$(checksum_stats "ipv6")
echo "Контрольная сумма,$chk4,$chk6"


