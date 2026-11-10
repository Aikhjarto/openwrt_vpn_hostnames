#!/bin/sh
# OpenVPN tun_server client-connect / client-disconnect (via openvpn_client_{connect,disconnect}.sh):
# keeps "pool-IP common-name" lines in /tmp/hosts/openvpn, which dnsmasq reads (addn-hosts=/tmp/hosts;
# the whole directory is mounted into its ujail), and reloads dnsmasq via procd.
# 2026-11-10: moved from /mnt/sda1/persistent/dhcp_hosts/openvpn (that directory was named
# dhcp-hosts on the stick, and a single-file jail mount doesn't see files replaced by sed -i).
# Always exits 0: a failing client-connect script would reject the client.

F=/tmp/hosts/openvpn
[ -n "$common_name" ] || exit 0
mkdir -p /tmp/hosts
touch "$F"
awk -v n="$common_name" '$2 != n' "$F" > "$F.new"
if [ "$1" = "up" ] && [ -n "$ifconfig_pool_remote_ip" ]; then
	echo "$ifconfig_pool_remote_ip $common_name" >> "$F.new"
fi
mv "$F.new" "$F"
ubus call service signal '{"name":"dnsmasq","signal":1}' >/dev/null 2>&1
exit 0
