
PRFILE=/usr/bin/3proxy
if test -f "$PRFILE"; then
  echo "3proxy is already installed."
else
  echo "3proxy is not installed."
  install_3proxy
fi

echo "working folder = /root/proxy-installer"
WORKDIR="/root/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $_

IP4=$(curl -4 -s ifconfig.co)
IP6=$(curl -6 -s ifconfig.co | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"

echo "How many proxy do you want to create? Example 500"
read COUNT

FIRST_PORT=10000
LAST_PORT=$(($FIRST_PORT + $COUNT))

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x boot_*.sh /etc/rc.local

gen_3proxy >/conf/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
service 3proxy start
EOF

bash /etc/rc.local

gen_proxy_file_for_user

upload_proxy
