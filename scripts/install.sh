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
daemon
maxconn 1000
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
flush
auth strong

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
  cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

upload_proxy() {
  local PASS=$(random)
  zip --password $PASS proxy.zip proxy.txt
  URL=$(curl -s --upload-file proxy.zip https://transfer.sh/proxy.zip)

  echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
  echo "Download zip archive from: ${URL}"
  echo "Password: ${PASS}"

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

gen_data() {
  seq $FIRST_PORT $LAST_PORT | while read port; do
    echo "usr$(random)/pass$(random)/$IP4/$port/$(gen64 $IP6)"
  done
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

PRFILE=/usr/bin/3proxy
if test -f "$PRFILE"; then
  echo "3proxy already installed."
else
  echo "3proxy not installed."
  install_3proxy
fi

echo "working folder = /root/proxy-installer"
WORKDIR="/root/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"

echo "How many proxy do you want to create? Example 500"
read COUNT

FIRST_PORT=10000
LAST_PORT=$(($FIRST_PORT + $COUNT))

gen_data >$WORKDIR/data.txt

FIRST_IPV6=$(awk -F "/" 'NR==1{print $5}' "/root/proxy-installer/data.txt")
if ifconfig | grep -q "$FIRST_IPV6"; then
  echo "Addresses already added"
else
  echo "Adding addresses"
  gen_iptables >$WORKDIR/boot_iptables.sh
  gen_ifconfig >$WORKDIR/boot_ifconfig.sh
fi

chmod +x boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/3proxy/conf/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
systemctl stop 3proxy.service
sleep 5
systemctl start 3proxy.service
EOF

bash /etc/rc.local

gen_proxy_file_for_user

# upload_proxy

# Make sure jq properly installed
JQFILE=/usr/bin/jq
if test -f "$JQFILE"; then
  echo "jq is already installed."
else
  echo "jq is not installed."
  install_jq
fi

upload_2file

echo "to start proxy: systemctl start 3proxy.service"
echo "to stop proxy: systemctl stop 3proxy.service"
echo "config at: /usr/local/3proxy/conf/add3proxyuser.sh"
echo "Log files are created in /usr/local/3proxy/logs symlinked from /var/log/3proxy."
