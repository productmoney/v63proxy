#!/bin/bash

ip -6 addr | grep inet6 | grep -v dynamic | grep -v link | grep -v host | awk '{print $2}' > /root/extra-addresses.txt

DFNWINTERFACE=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")

ifconfig

echo "Deleting extra leftover ipv6 addresses"

while read -r addrx; do
  ip addr del "$addrx" dev "$DFNWINTERFACE"
done </root/extra-addresses.txt

ifconfig

rm -f /root/extra-addresses.txt

systemctl restart NetworkManager

echo "------------"
echo "Deleting previous proxies files"
rm -r /root/proxy-installer

echo "------------"
echo "killing 3proxy"
killall 3proxy
