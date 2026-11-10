#!/bin/sh
# wg-hosts: DNS names for WireGuard peers of this router (dnsmasq).
#
# WireGuard has no connect/disconnect events, only the time of each peer's latest handshake.
# Every INTERVAL seconds, each peer with a handshake in the last MAXAGE seconds is written as
# "IP hostname" to /tmp/hosts/wireguard-<iface>. dnsmasq reads /tmp/hosts (addn-hosts); a name
# there wins over a stale LAN DHCP lease of the same name. dnsmasq is reloaded (SIGHUP via procd)
# only when the file changes.
#
# Names: "option hostname" in the peer sections (config wireguard_<iface>) of /etc/config/network;
# only /32 and /128 allowed_ips are used. Peers need PersistentKeepalive (e.g. 25) so an idle
# tunnel keeps handshaking (rekey every 120 s while packets flow).
#
# Started by /etc/init.d/wg-hosts (restarted on "uci commit network"). Set up 2026-11-09.

. /lib/functions.sh

IFACE=${1:-Wireguard}
MAXAGE=${2:-180}
INTERVAL=${3:-30}
OUT=/tmp/hosts/wireguard-$IFACE
MAP=/var/run/wg-hosts-$IFACE.map

peer() {
	local key name ips ip
	config_get key "$1" public_key
	config_get name "$1" hostname
	config_get ips "$1" allowed_ips
	[ -n "$key" ] && [ -n "$name" ] || return 0
	for ip in $ips; do
		case "$ip" in
			*/32|*/128) echo "$key ${ip%/*} $name" ;;
			*/*) ;;
			*) echo "$key $ip $name" ;;
		esac
	done
}

reload_dnsmasq() {
	# the pid file inside the dnsmasq jail says 1, so let procd send the signal
	ubus call service signal '{"name":"dnsmasq","signal":1}' >/dev/null 2>&1
}

config_load network
config_foreach peer "wireguard_$IFACE" > "$MAP"

while :; do
	now=$(date +%s)
	wg show "$IFACE" latest-handshakes 2>/dev/null |
		awk -v now="$now" -v max="$MAXAGE" '
			NR == FNR { if ($2 > 0 && now - $2 <= max) up[$1] = 1; next }
			($1 in up) { print $2, $3 }' - "$MAP" > "$OUT.new"
	if cmp -s "$OUT.new" "$OUT"; then
		rm -f "$OUT.new"
	else
		mv "$OUT.new" "$OUT"
		logger -t wg-hosts "$IFACE peers online: $(awk '{printf "%s%s=%s", sep, $2, $1; sep=", "}' "$OUT")"
		reload_dnsmasq
	fi
	sleep "$INTERVAL"
done
