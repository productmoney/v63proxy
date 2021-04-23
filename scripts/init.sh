echo ""
echo "Updating system and installing requirements"

yum update -y

yum install git make gcc net-tools bsdtar -y

echo "----------------"
echo "Adding * hard nofile 97816 and * soft nofile 97816 to /etc/security/limits.conf"

grep 97816 /etc/security/limits.conf || echo -e "* hard nofile 97816\n* soft nofile 97816" >> /etc/security/limits.conf

echo "----------------"
echo "Init script done"

echo "----------------"
echo "***IMPORTANT***"
echo "Please log out and log back in before continuing"
