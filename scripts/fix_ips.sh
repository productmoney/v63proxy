# Try for password format first
FIRST_IPV6=$(awk -F "/" 'NR==1{print $5}' "/root/proxy-installer/data.txt")
if [ -z "${FIRST_IPV6// }" ]; then
  echo "IP auth is being used"
  FIRST_IPV6=$(awk -F "/" 'NR==1{print $4}' "/root/proxy-installer/data.txt")
else
  echo "Password auth is being used"
fi

GIPV=$(ifconfig | grep "$FIRST_IPV6")
if [ -z "$GIPV" ]; then
  echo "Adding addresses"
#  bash "$WORKDIR/boot_iptables.sh"
  bash "/root/proxy-installer/boot_ifconfig.sh"

  echo "Turning off the firewall"
  iptables -I INPUT -j ACCEPT
  systemctl mask firewalld
  systemctl stop firewalld

else
  echo "Addresses already added"
fi
