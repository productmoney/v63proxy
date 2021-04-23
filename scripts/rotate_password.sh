
ip -6 addr | grep inet6 | grep -v dynamic | grep -v link | grep -v host | awk '{print $2}' > /root/extra-addresses.txt

DFNWINTERFACE=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")

while read addrx; do
  echo "ip addr del $addrx dev $DFNWINTERFACE"
done </root/extra-addresses.txt

rm /root/extra-addresses.txt

systemctl restart NetworkManager

bash <(curl -s "https://raw.githubusercontent.com/productmoney/v63proxy/main/scripts/install_password.sh")
