#!/bin/sh

S5P=192.168.0.100:1888
TIMEZONE=HKT-8
uci set system.@system[0].zonename="Asia/Hong Kong"

#https://github.com/openwrt/luci/blob/master/modules/luci-base/luasrc/sys/zoneinfo/tzdata.lua
uci set system.@system[0].timezone="$TIMEZONE"
uci commit
echo "$TIMEZONE">/etc/TZ
/etc/init.d/sysntpd restart
opkg update
LU=`opkg find libustream-openssl* | awk '{print $1}'`
opkg install tor ca-bundle ca-certificates bash python kmod-tcp-bbr $LU
mkdir /opt>/dev/null 2>&1
cd /opt
wget https://raw.githubusercontent.com/torproject/tor/master/src/config/mmdb-convert.py
wget https://raw.githubusercontent.com/xr09/cron-last-sunday/master/run-if-today
chmod +x run-if-today

cat >updateip.sh<<EOF
#!/bin/bash

source /etc/profile
cd /opt
wget https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.mmdb.gz && \
gunzip GeoLite2-Country.mmdb.gz && \
python mmdb-convert.py GeoLite2-Country.mmdb && \
/etc/init.d/tor restart
rm GeoLite2-Country.mmdb>/dev/null 2>&1
EOF
chmod +x updateip.sh

cat >cron<<EOF
5 6 * * 4 /opt/run-if-today 3 && /opt/updateip.sh
EOF
crontab cron
rm cron>/dev/null 2>&1

cat<<EOF>>/etc/tor/torrc
SocksPort `ip a |grep br-lan | grep '\binet\b.*\/[[:digit:]]\{1,2\}.*\bscope[[:space:]]global\b.*' | awk '{print $2}' | cut -d "/" -f 1`:9050
Socks5Proxy $S5P
GeoIPFile /opt/geoip
GeoIPv6File /opt/geoip6
GeoIPExcludeUnknown 1
StrictNodes 1
ExcludeNodes {cn},{hk},{mo},{sg},{th},{pk},{by},{ru},{ir},{vn},{ph},{my},{cu},{br},{kz},{kw},{lk},{ci},{tk},{tw},{sy},{mn},{fr},{de},{??}
ExcludeExitNodes {cn},{hk},{mo},{sg},{th},{pk},{by},{ru},{ir},{vn},{ph},{my},{cu},{br},{kz},{kw},{lk},{ci},{tk},{tw},{sy},{mn},{fr},{de},{??}
#https://en.wikipedia.org/wiki/ISO_3166-1
#EntryNodes {us}
#ExitNodes {us}
EOF
./updateip.sh