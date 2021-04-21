yum update

yum install git make gcc net-tools bsdtar

grep 97816 /etc/security/limits.conf || echo -e "* hard nofile 97816\n* soft nofile 97816" >> /etc/security/limits.conf
