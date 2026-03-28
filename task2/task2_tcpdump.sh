#!/usr/bin/env bash
set -euo pipefail

# ==========================
# ФУНКЦИОНАЛЬНЫЙ ИНСТРУМЕНТАРИЙ
# ==========================

# проверка наличия обязательных утилит в начале выполнения
check_prereqs() {
	local -a missing=()
	local cmd

	for cmd in ssh tcpdump grep sudo; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			missing+=("$cmd")
		fi
	done

	if (( ${#missing[@]} )); then
		# точная фраза, как просили
		echo "не хватает пакетов: ${missing[*]}" >&2
		exit 1
	fi
}

die() { echo "ERROR: $*" >&2; exit 1; }

need_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "command not found: $1"
}

# валидация / разрешение user@host или ssh-профиля
# вход: аргумент (например "user@host" или "myprofile")
# выход: устанавливает переменные RESOLVED_USER и RESOLVED_HOST и SSH_PROFILE (если профиль)
# возврат: 0 — успешно, 1 — не удалось разрешить
validate_userhost() {
	local input="$1"
	RESOLVED_USER=""
	RESOLVED_HOST=""

	# случай user@host
	if [[ "$input" == *@* ]]; then
		RESOLVED_USER="${input%%@*}"
		RESOLVED_HOST="${input##*@}"
		return 0
	fi

	# иначе считаем, что это профиль из ~/.ssh/config или алиас
	local SSH_PROFILE="$input"

	# пробуем безопасно использовать ssh -G (выведет окончательные параметры конфига)
	if ssh_output=$(ssh -G "$SSH_PROFILE" 2>/dev/null); then
		#echo "[DEBUG]  CASE ssh -G"
		# hostname и user могут отсутствовать — берём первые попавшиеся
		RESOLVED_HOST=$(awk '/^hostname /{print $2; exit}' <<<"$ssh_output")
		RESOLVED_USER=$(awk '/^user /{print $2; exit}'     <<<"$ssh_output")
		[[ -n "$RESOLVED_HOST" ]] && return 0
	fi

	# если ssh -G недоступен или не помог — парсим ~/.ssh/config вручную
	local cfg="$HOME/.ssh/config"
	if [[ -f "$cfg" ]]; then
		#echo "[DEBUG]  CASE config"
		# awk: найти блок Host, в котором перечислен профиль, затем из этого блока взять HostName и User
		# учитываем, что Host может быть строкой с несколькими алиасами
		read -r RESOLVED_HOST RESOLVED_USER < <(
			awk -v prof="$SSH_PROFILE" '
				BEGIN { inblock=0; hn=""; u="" }
				# новая секция Host
				/^[[:space:]]*Host[[:space:]]+/ {
					inblock=0
					for(i=2;i<=NF;i++) {
						if($i==prof) { inblock=1; break }
					}
					next
				}
				inblock && /^[[:space:]]*HostName[[:space:]]+/ {
					hn=$2
					next
				}
				inblock && /^[[:space:]]*User[[:space:]]+/ {
					u=$2
					next
				}
				END { print hn, u }
			' "$cfg"
		)
		[[ -n "$RESOLVED_HOST" ]] && return 0
	fi

	# ничего не найдено
	return 1
}

now_ts() {
	date +"%Y-%m-%d_%H-%M-%S"
}


run_tcpdump_bg() {
	local iface="$1"
	local host="$2"
	local outfile="$3"

	# -U  = packet-buffer flush быстрее
	# -w  = писать в pcap
	# filter: только трафик к host:22
	sudo tcpdump -i "$iface" -U -w "$outfile" "host $host and port 22" >/dev/null 2>&1 &
	echo $!
}

stop_capture() {
	local pid="$1"
	sudo kill -INT "$pid" >/dev/null 2>&1 || true
	wait "$pid" 2>/dev/null || true
}

run_ssh_session() {
	local userhost="$1"

	# BatchMode=yes запрещает спрашивать пароль (полезно для проверки ключа)
	# ConnectTimeout=5 чтобы не висеть вечно
	ssh -o BatchMode=yes -o ConnectTimeout=5 "$userhost" "echo '[REMOTE] SSH OK'; exit" || true
}

tcpdump_read_text() {
	local file="$1"
	sudo tcpdump -nn -tt -r "$file"
}

filter_handshake() {
	# SYN, SYN-ACK, ACK (первые пакеты TCP)
	grep -E "Flags \[S\]|Flags \[S\.\]|Flags \[\.\]" || true
}

filter_ssh_banner() {
	# В начале SSH-сессии часто видно ASCII "SSH-2.0-OpenSSH_..."
	# tcpdump может вывести это как "SSH-2.0"
	grep -E "SSH-2\.0|OpenSSH" || true
}

filter_encrypted_data() {
	# Основной поток: PSH, ACK (данные)
	grep -E "Flags \[P\.\]" || true
}

filter_session_end() {
	# FIN завершение соединения
	grep -E "Flags \[F\.\]|Flags \[R\]" || true
}

print_section() {
	local title="$1"
	echo
	echo "========================================"
	echo "$title"
	echo "========================================"
}

# логирование для секций [INFO] с опцией анонимизации адресов
# использование: log_info "сообщение с $RESOLVED_HOST и 1.2.3.4"
# переключатель анонимизации: если переменная ANON установлена в непустое значение — включено
log_info() {
	local msg="$*"
	local esc_host ip_masked host_regex

	# если разрешён конкретный хост — заменяем его точные вхождения
	if [[ -n "${ANON:-}" && -n "${RESOLVED_HOST:-}" ]]; then
		# экранируем специальные символы для sed-совместимого регулярного выражения
		esc_host="$(printf '%s' "$RESOLVED_HOST" | sed -e 's/[]\/$*.^[]/\\&/g')"
		# заменяем точные вхождения имени хоста (границы слова), учитывая возможные символы ':' и '/' после имени
		msg="$(printf '%s' "$msg" | sed -E "s/\\b${esc_host}\\b/<REDACTED>/g")"
	fi

	# анонимизируем IPv4-адреса (например 192.168.0.1 -> <IP_REDACTED>)
	if [[ -n "${ANON:-}" ]]; then
		msg="$(printf '%s' "$msg" | sed -E 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/<IP_REDACTED>/g')"
		# дополнительно маскируем явные доменные имена вида something.example.com (чтобы не оставлять информацию)
		msg="$(printf '%s' "$msg" | sed -E 's/\b([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}\b/<HOSTNAME_REDACTED>/g')"
	fi

	# выводим в том же формате, что и раньше
printf '[INFO] %s\n' "$msg"
}



# ==========================
# MAIN
# ==========================
main() {
	# ранняя проверка зависимостей
	check_prereqs

	# --- USAGE ---
	if [[ $# -lt 2 ]]; then
		echo "Usage: $0 <interface> {<user@host>|<ssh-profile>}"
		echo "Example: $0 eth0 root@192.168.1.10"
		echo "Example: $0 wlo1 dummy_server"
		exit 1
	fi

	# --- UNPUT ---
	local iface="$1"
	local userhost="$2"

	# разрешение профиля / user@host
	validate_userhost "$userhost" || die "bad ssh input"

	# RESOLVED_HOST и RESOLVED_USER выставлены в validate_userhost
	local host="$RESOLVED_HOST"
	local resolved_user="${RESOLVED_USER:-}"

	[[ -n "$host" ]] || die "не удалось определить хост для захвата трафика"
	
	local pcap
	pcap="ssh_capture_${host}_$(now_ts).pcap"

	# --- INFO ---
	log_info "capture interface: $iface"
	log_info "target: $userhost"
	log_info "resolved host: ${host:-<unknown>}"
	log_info "output pcap: $pcap"

	# --- SSH CAPTURE ---
	# подготовка — обеспечим корректную остановку tcpdump при выходе
	local cap_pid=""
	trap '[[ -n "${cap_pid:-}" ]] && stop_capture "$cap_pid" || true' EXIT

	log_info "starting tcpdump..."
	cap_pid="$(run_tcpdump_bg "$iface" "$host" "$pcap")" || die "не удалось запустить tcpdump (проверьте права sudo)"

	# дать немного времени на стартер tcpdump
	sleep 1

	# --- SSH RUN ---
	log_info "running ssh session..."
	# захватим вывод ssh чтобы определить тип ошибки (например Host key verification failed)
	local ssh_out
	ssh_out="$(run_ssh_session "$userhost" 2>&1 || true)"

	# анализ вывода ssh
	if printf '%s' "$ssh_out" | grep -q -i "Host key verification failed"; then
		log_info "SSH: Host key verification failed. Добавьте ключ сервера в known_hosts или используйте ssh-keyscan."
		printf '%s\n' "$ssh_out" >&2
	elif printf '%s' "$ssh_out" | grep -q -i "Permission denied"; then
		log_info "SSH: Permission denied — проверьте публичный ключ и права доступа (ssh-agent, ssh-add)."
		printf '%s\n' "$ssh_out" >&2
	else
		# короткий вывод результата сессии (первые 20 строк)
		log_info "SSH session finished, вывод (первые 20 строк):"
		printf '%s\n' "$ssh_out" | sed -n '1,20p'
	fi

	# --- ANALYSIS ---
	log_info "stopping tcpdump..."
	stop_capture "$cap_pid"
	cap_pid=""

	[[ -f "$pcap" ]] || die "pcap not created"

	print_section "1) TCP HANDSHAKE (SYN / SYN-ACK / ACK)"
	tcpdump_read_text "$pcap" | filter_handshake | head -n 30

	print_section "2) SSH BANNER / INITIAL NEGOTIATION"
	tcpdump_read_text "$pcap" | filter_ssh_banner | head -n 30

	print_section "3) ENCRYPTED DATA (PSH, ACK packets)"
	tcpdump_read_text "$pcap" | filter_encrypted_data | head -n 30

	print_section "4) SESSION TERMINATION (FIN/RST)"
	tcpdump_read_text "$pcap" | filter_session_end | head -n 30

	print_section "DONE"
	log_info "pcap saved: $pcap"
	log_info "open in Wireshark: wireshark $pcap"
}

main "$@"
