#!/bin/bash

# Original name:  comparison.sh
# Лишь примеры применения фильтров полей
# Список всех полей можно посмотреть
#   tshark -G fields | grep "IPv4\|IPv6" | less
# Но там и не всё что надо

{
      echo "=== IPv4 Statistics ==="
      tshark -r ipv4.pcap -q -z io,stat,0
      echo -e "\n=== IPv6 Statistics ==="
      tshark -r ipv6.pcap -q -z io,stat,0
      echo -e "\n=== Packet Size Comparison ===\n"
      echo "Размеры пакетов (min/max/avg)"
      tshark -r ipv4.pcap -T fields -e frame.len | awk '{sum+=$1; min=($1<min)?$1:min; max=($1>max)?$1:max; count++} END {print "Min:", min, "Max:", max, "Avg:", sum/count}'
      tshark -r ipv6.pcap -T fields -e frame.len | awk '{sum+=$1; min=($1<min)?$1:min; max=($1>max)?$1:max; count++} END {print "Min:", min, "Max:", max, "Avg:", sum/count}'

      tshark -r ipv4.pcap -T fields -e ip.ttl | awk '{sum+=$1; count++} END {print sum/count}'
      echo "avg Hop Limit in IPv4"
      tshark -r ipv6.pcap -T fields -e ipv6.hlim | awk '{sum+=$1; count++} END {print sum/count}'

      echo -e "\n=== IPv4 vs IPv6 Header Analysis ===\n"
      tshark -r ipv4.pcap -T fields -e ip.hdr_len 2>/dev/null | awk '{sum+=$1; count++} END {if(count>0) printf "  Average: %.2f\n", sum/count; else print "  No data"}'

      echo "IPv6 Header Length (bytes):"
      tshark -r ipv6.pcap -T fields -e ipv6.hdr_len 2>/dev/null | awk '{sum+=$1; count++} END {if(count>0) printf "  Average: %.2f\n", sum/count; else print "  No data"}'

      echo -e "\n=== Checksum ===\n"
      echo "IPv4 Checksum (example from first packet):"
      tshark -r ipv4.pcap -T fields -e ip.checksum 2>/dev/null | head -n1 | awk '{print "  " $0}'
      echo "IPv6 Checksum: Not present in base header (handled by upper layers: ICMPv6, TCP, UDP)"

      echo -e "\n=== IP Packet Length (bytes) ===\n"
      echo "IPv4 Packet Length (ip.len):"
      tshark -r ipv4.pcap -T fields -e ip.len 2>/dev/null | awk '{sum+=$1; min=($1<min)?$1:min; max=($1>max)?$1:max; count++} END {printf "  Min: %s\n  Max: %s\n  Avg: %.2f\n", min, max, sum/count}'

      echo "IPv6 Packet Length (payload + 40-byte header):"
      tshark -r ipv6.pcap -T fields -e ipv6.plen 2>/dev/null | awk '{total=$1+40; sum+=total; min=(total<min)?total:min; max=(total>max)?total:max; count++} END {printf "  Min: %s\n  Max: %s\n  Avg: %.2f\n", min, max, sum/count}'

} > comparison.txt
