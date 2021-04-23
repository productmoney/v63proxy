WORKDIR="/root/proxy-installer"
FIRST_IPV6=$(awk -F "/" 'NR==1{print $5}' "/root/proxy-installer/data.txt")
GIPV=$(ifconfig | grep "$FIRST_IPV6")
if [ -z "$GIPV" ]; then
  echo "Adding addresses"
#  bash "$WORKDIR/boot_iptables.sh"
  bash "$WORKDIR/boot_ifconfig.sh"

  iptables -I INPUT -j ACCEPT

  systemctl mask firewalld
  systemctl stop firewalld

else
  echo "Addresses already added"
fi
