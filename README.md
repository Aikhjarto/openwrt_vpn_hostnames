# Hostnames for VPN clients on OpenWrt

On OpenWrt, dnsmasq learns the names of LAN clients from DHCP, so `laptop.lan` works while the
laptop is at home. Over a VPN there is no DHCP, so the name is unknown (or still points to the
old LAN address). This project puts the names of connected VPN clients into dnsmasq:

* **WireGuard** (`wg-hosts`): a small procd service.
* **OpenVPN** (`openvpn_client_*.sh`): client-connect / client-disconnect scripts.

Both write `IP name` lines to a file in `/tmp/hosts/` and send dnsmasq a SIGHUP through procd.

## How it works

dnsmasq on OpenWrt reads every file in `/tmp/hosts/` (`addn-hosts=/tmp/hosts`), and that
directory is mounted into its ujail. A name in such a file takes precedence over a DHCP lease
with the same name. dnsmasq logs `not giving name … to the DHCP lease of … because the name
exists in /tmp/hosts/…`. So while a client is connected over the VPN, its usual hostname resolves
to the tunnel address. Once the client disconnects, the line is removed and the name falls back
to the LAN lease.

Why not a file on a USB stick via `list addnhosts`: the jail bind-mounts such a single file only
if it exists when dnsmasq starts, and a file replaced by `sed -i` (new inode) is not seen inside
the jail. Why not `kill -HUP` with the pid file: inside the jail the pid file says `1`.
`ubus call service signal '{"name":"dnsmasq","signal":1}'` reaches the right process.

### WireGuard

WireGuard has no connect or disconnect events. A peer only has the time of its latest handshake
(the netlink notification patches for peer changes were never merged). `wg-hosts.sh` therefore
checks `wg show <iface> latest-handshakes` every 30 s. Peers with a handshake in the last 180 s
are listed in `/tmp/hosts/wireguard-<iface>`. The file is rewritten, and dnsmasq reloaded, only
when the set of peers changes.

The clients need `PersistentKeepalive` (e.g. `25`). An active tunnel rekeys every 120 s, but an
idle tunnel without keepalive stops handshaking and would be dropped from DNS after 3 minutes.

The names come from an extra option `hostname` on the peer sections in `/etc/config/network`.
netifd ignores options it doesn't know. Only `/32` and `/128` entries of `allowed_ips` are used.

### OpenVPN

`client-connect` / `client-disconnect` call `openvpn_client_script.sh up|down`. It adds or
removes `$ifconfig_pool_remote_ip $common_name` (the certificate CN) in `/tmp/hosts/openvpn`.
The script always exits 0, because a failing client-connect script makes OpenVPN reject the
client. OpenVPN only runs external scripts with `script-security 2`. The OpenWrt init script
sets that by default.

## Install

Copy `etc/` and `usr/` to the router, keeping the executable flags:

```sh
scp -O -r etc usr root@router:/
```

WireGuard: give each peer a hostname, then enable the service. The interface name is `IFACE` in
`/etc/init.d/wg-hosts` (default `Wireguard`).

```sh
uci show network | grep wireguard_          # find the peer sections
uci set network.@wireguard_Wireguard[0].hostname='laptop'
uci commit network
/etc/init.d/wg-hosts enable
/etc/init.d/wg-hosts start
```

The service restarts on `reload_config` after network changes.

OpenVPN: in the server section of `/etc/config/openvpn`

```
	option client_connect '/usr/local/bin/openvpn_client_connect.sh'
	option client_disconnect '/usr/local/bin/openvpn_client_disconnect.sh'
```

Keep everything across `sysupgrade` by adding these lines to `/etc/sysupgrade.conf`:

```
/usr/local/
/etc/init.d/wg-hosts
/etc/rc.d/S99wg-hosts
```

### As apk packages

The `Makefile` builds two architecture-independent packages with the OpenWrt SDK (any target):
`wg-hosts` (depends on `wireguard-tools`) and `openvpn-hosts`. They install to the same paths
as above.

```sh
ln -s /path/to/openwrt_vpn_hostnames <sdk>/package/vpn-hostnames
make defconfig
make package/vpn-hostnames/compile
# -> bin/packages/<arch>/base/wg-hosts-1.0-r1.apk, openvpn-hosts-1.0-r1.apk
apk add --allow-untrusted ./wg-hosts-1.0-r1.apk     # on the router; enables and starts the service
```

Packages installed this way are not part of the firmware, so after a `sysupgrade` (or an `owut`
upgrade) they have to be installed again unless the files are listed in `/etc/sysupgrade.conf`.

## Check

```sh
cat /tmp/hosts/wireguard-Wireguard /tmp/hosts/openvpn
logread -e wg-hosts
nslookup laptop 127.0.0.1
```

Tested on OpenWrt 25.12 (dnsmasq 2.93, apk).
