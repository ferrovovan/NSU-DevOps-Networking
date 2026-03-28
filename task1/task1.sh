#!/usr/bin/env bash

INPUT="domains.txt"
OUT="result.csv"
COUNT=5
TIMEOUT=3

# Запись заголовка в .csv
# 9 полей
echo "domain,status,rtt_min_ms,rtt_avg_ms,rtt_max_ms,rtt_mdev_ms,transmitted,received,loss_percent" > "$OUT"

while IFS= read -r domain; do
	[[ -z "$domain" ]] && continue	# пропуск пустых строк

	echo -e "ping -c $COUNT -W $TIMEOUT $domain  2>&1"
	output=$(ping -c "$COUNT" -W "$TIMEOUT" "$domain"  2>&1)
	exit_code=$?  # код ошибки

	# Значения по умолчанию (на случай ошибки)
	status="Error"
	rtt_min=0
	rtt_avg=0
	rtt_max=0
	rtt_mdev=0
	transmitted=0
	received=0
	loss=100
	
	# Случай 1: домен не резолвится / ping не запустился
	if [[ $exit_code -ne 0 ]] && ! grep -q "ping statistics" <<< "$output"; then
		status="Error"

	# ping statistics есть => ping запускался, значит можно достать transmitted/received/loss
	elif grep -q "ping statistics" <<< "$output"; then

		# Парсим строку:
		# "5 packets transmitted, 0 received, +5 errors, 100% packet loss, time 4130ms"
		stats_line=$(grep -m1 "packets transmitted" <<< "$output")

		transmitted=$(awk '{print $1}' <<< "$stats_line")
		received=$(awk '{print $4}' <<< "$stats_line")
		loss=$(awk -F',' '{print $3}' <<< "$stats_line" | awk '{print $1}' | tr -d '%')

		# Случай 2 и 3: есть ли строка RTT?
		if grep -qE "rtt min/avg/max" <<< "$output"; then
			status="OK"

			# Парсим:
			# "rtt min/avg/max/mdev = 171.206/171.804/172.817/0.719 ms"
			rtt_line=$(grep -m1 "rtt min/avg/max" <<< "$output")

			rtt_values=$(awk -F'=' '{print $2}' <<< "$rtt_line" | awk '{print $1}')
			rtt_min=$(cut -d'/' -f1 <<< "$rtt_values")
			rtt_avg=$(cut -d'/' -f2 <<< "$rtt_values")
			rtt_max=$(cut -d'/' -f3 <<< "$rtt_values")
			rtt_mdev=$(cut -d'/' -f4 <<< "$rtt_values")

		else
			# ping statistics есть, но rtt нет
			status="Unreachable"
		fi
	fi

	echo "$domain,$status,$rtt_min,$rtt_avg,$rtt_max,$rtt_mdev,$transmitted,$received,$loss" >> "$OUT"

done < "$INPUT"


# Красиво посмотреть табличку:
# yay -S csview
