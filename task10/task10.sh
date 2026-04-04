#!/usr/bin/env bash

: << EOF
Скрипт работает долго. Минуты 2, может больше. Напишите в issues.
Сократите число доменов для ускорения.
>> EOF


INPUT="domains.txt"
OUT="traceroute.csv"
TRACE_OPTS="-n"          # numeric output, no hostname resolution

# CSV header: domain, resolved_ip, hop_number, hop_ip, rtt1, rtt2, rtt3
echo "domain,resolved_ip,hop,hop_ip,rtt1_ms,rtt2_ms,rtt3_ms" > "$OUT"

while IFS= read -r domain; do
    [[ -z "$domain" ]] && continue

    # 1. DNS lookup using 'host'
    # Extract only IPv4 addresses (ignore CNAME, mail, etc.)
    ip_list=$(LC_ALL=C host -t A "$domain" 2>/dev/null | grep -E 'has address' | awk '{print $4}')
    if [[ -z "$ip_list" ]]; then
        # No A record found – write a single error row
        echo "$domain,ERROR_DNS_RESOLUTION,-,-,-,-,-" >> "$OUT"
        echo "Warning: Could not resolve $domain" >&2
        continue
    fi

    # Take the first IPv4 address (you can modify to iterate over all)
    resolved_ip=$(echo "$ip_list" | head -n1)
	echo "$domain resolve:  $resolved_ip"

    # 2. Run traceroute to the resolved IP
    # Example output line (with -n):
    #  1  192.168.1.1  0.123 ms  0.145 ms  0.134 ms
    trace_output=$(traceroute $TRACE_OPTS "$resolved_ip" 2>/dev/null)

    if [[ $? -ne 0 ]] || [[ -z "$trace_output" ]]; then
        echo "$domain,$resolved_ip,TRACEROUTE_FAILED,-,-,-,-" >> "$OUT"
        continue
    fi

    # 3. Parse traceroute lines (skip the first line which is "traceroute to ...")
    echo "$trace_output" | tail -n +2 | while read -r line; do
        # Extract hop number, IP, and three RTT values (if present)
        # Format: hop_nr  IP  rtt1  rtt2  rtt3
        hop=$(echo "$line" | awk '{print $1}')
        hop_ip=$(echo "$line" | awk '{print $2}')
        rtt1=$(echo "$line" | awk '{print $3}')
        rtt2=$(echo "$line" | awk '{print $5}')
        rtt3=$(echo "$line" | awk '{print $7}')

        # Remove trailing 'ms' and handle asterisks (*) or missing values
        rtt1=${rtt1%ms}
        rtt2=${rtt2%ms}
        rtt3=${rtt3%ms}

        # Write one CSV row per hop
        echo "$domain,$resolved_ip,$hop,$hop_ip,$rtt1,$rtt2,$rtt3"
    done >> "$OUT"

done < "$INPUT"

echo "Done. Results saved to $OUT"
