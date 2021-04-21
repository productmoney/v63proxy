#!/bin/sh

random() {
	tr </dev/urandom -dc A-Za-z0-9 | head -c5
	echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
	ip64() {
		echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
	}
	echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

install_3proxy() {
  echo "installing 3proxy"

  URL="https://github.com/z3apa3a/3proxy"
  git clone $URL
  cd 3proxy

  ln -s Makefile.Linux Makefile
  make
  make install

  cd $WORKDIR
}

gen_3proxy() {
  cat <<EOF
#daemon
maxconn 1000
nscache 65536
nscache6 65536
timeouts 1 5 30 60 180 1800 15 60
stacksize 262144
log /var/log/3proxy.log

flush

$(awk -F "/" '{print "proxy -6 -n -a -p" $3 " -i" $2 " -e"$4"\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $2 ":" $3 }' ${WORKDATA})
EOF
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$IP_AUTHORIZATION/$IP4/$port/$(gen64 $IP6)"
    done
}

install_jq() {
  wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
  chmod +x ./jq
  cp jq /usr/bin
}

upload_2file() {
  local PASS=$(random)
  zip --password $PASS proxy.zip proxy.txt
  JSON=$(curl -F "file=@proxy.zip" https://file.io)
  URL=$(echo "$JSON" | jq --raw-output '.link')

  echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
  echo "Download zip archive from: ${URL}"
  echo "Password: ${PASS}"
}

gen_iptables() {
  cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' "/root/proxy-installer/data.txt")
EOF
}

gen_ifconfig() {
  cat <<EOF
$(awk -v pcmd=`ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//"` -F "/" '{print "ifconfig " pcmd " inet6 add " $5 "/64"}' "/root/proxy-installer/data.txt")
EOF
}

touch /var/log/3proxy.log

PRFILE=/usr/bin/3proxy
if test -f "$PRFILE"; then
  echo "3proxy already installed."
else
  echo "3proxy not installed."
  install_3proxy
fi
sleep 2

echo "working folder = /root/proxy-installer"
WORKDIR="/root/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "-----------------"
echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"
sleep 3

echo "-----------------"
echo "How many proxy do you want to create? Example 500"
read -r COUNT

echo "Which IP do you want to authorize the proxies for?"
read -r IP_AUTHORIZATION

FIRST_PORT=10000
LAST_PORT=$((FIRST_PORT + COUNT))

gen_data >$WORKDIR/data.txt

echo "-----------------"
echo "Generating iptables script"
gen_iptables >$WORKDIR/boot_iptables.sh
echo "Generating ifconfig script"
gen_ifconfig >$WORKDIR/boot_ifconfig.sh

chmod +x boot_*.sh /etc/rc.local

gen_3proxy >/etc/3proxy/3proxy.cfg
cp /etc/3proxy/3proxy.cfg "$WORKDIR"

echo "-----------------"
systemctl stop 3proxy.service
sleep 2
killall 3proxy
sleep 2

wget https://raw.githubusercontent.com/productmoney/v63proxy/main/scripts/fix_ips.sh -P "$WORKDIR"
chmod +x "$WORKDIR/fix_ips.sh"

cat >/etc/rc.local <<EOF
#!/bin/bash
# THIS FILE IS ADDED FOR COMPATIBILITY PURPOSES
#
# It is highly advisable to create own systemd services or udev rules
# to run scripts during boot instead of using this file.
#
# In contrast to previous versions due to parallel execution during boot
# this script will NOT be run after all other services.
#
# Please note that you must run 'chmod +x /etc/rc.d/rc.local' to ensure
# that this script will be executed during boot.

touch /var/lock/subsys/local

bash /root/proxy-installer/fix_ips.sh

cp /root/proxy-installer/3proxy.cfg /etc/3proxy/3proxy.cfg

service 3proxy start
EOF

echo "-----------------"
echo "/root/proxy-installer"
bash /etc/rc.local
sleep 2

echo "-----------------"
gen_proxy_file_for_user

echo "-----------------"
# Make sure jq properly installed
JQFILE=/usr/bin/jq
if test -f "$JQFILE"; then
  echo "jq is already installed."
else
  echo "jq is not installed."
  install_jq
fi

echo "-----------------"
echo "ps aux | grep 3proxy"
ps aux | grep 3proxy | grep -v grep
sleep 2

echo "-----------------"
echo "ulimit -Hn (should return 97816)"
ulimit -Hn

echo "-----------------"
upload_2file
sleep 2

# iptables -I INPUT -p tcp --dport $IP6::/64 -m state --state NEW -j ACCEPT

echo "-----------------"
echo "to start proxy: systemctl start 3proxy.service"
echo "to stop proxy: killall 3proxy"
echo "config at: /etc/3proxy/3proxy.cfg"
echo "Log at: /var/log/3proxy.log"
