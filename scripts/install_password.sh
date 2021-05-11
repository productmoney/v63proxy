#!/bin/bash
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
  cd 3proxy || exit

  ln -s Makefile.Linux Makefile
  make
  make install

  cd "$WORKDIR" || exit
}

gen_3proxy() {
  cat <<EOF
daemon
maxconn 1000
nscache 65536
nserver 1.1.1.1
timeouts 1 5 30 60 180 1800 15 60
stacksize  65536
log /var/log/3proxy.log
logformat "t:%o %d %H:%M:%S %T err:%E User:%U %N:%p client:%C:%c target:%R:%r ext_ip:%e req_ip:%Q:%q bytes:req:%I/sent:%O %Q"
flush
auth strong

auth iponly

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' "/root/proxy-installer/data.txt")

$(awk -F "/" '{print "auth strong\nallow " $1 "\nproxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\nflush\n"}' "/root/proxy-installer/data.txt")
EOF
}

gen_proxy_file_for_user() {
  cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' "${WORKDATA}")
EOF
}

upload_proxy() {
  local PASS
  PASS=$(random)
  zip --password "$PASS" proxy.zip proxy.txt
  URL=$(curl -s --upload-file proxy.zip https://transfer.sh/proxy.zip)

  echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
  echo "Download zip archive from: ${URL}"
  echo "Password: ${PASS}"
}

install_jq() {
  wget -O -nvq jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
  chmod +x ./jq
  cp jq /usr/bin
}

upload_2file() {
  local PASS
  PASS=$(random)
  zip --password "$PASS" proxy.zip proxy.txt
  local JSON
  JSON=$(curl -F "file=@proxy.zip" https://file.io)
  URL=$(echo "$JSON" | jq --raw-output '.link')

  echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
  echo "Download zip archive from: ${URL}"
  echo "Password: ${PASS}"
}

upload_2api() {
  local token_content
  local access_token
  sed -i '/^$/d' "/root/proxy-installer/data.txt"
  token_content=$(curl -X POST -H "Content-Type: application/json" -d "{\"username\": \"$DJANGO_USERNAME\", \"password\": \"$DJANGO_PASSWORD\"}" https://proxy6way.us/api/token/)
#  local refresh
#  refresh=$( jq -r '.refresh' <<< "${token_content}" )
  access_token=$( jq -r '.access' <<< "${token_content}" )
  if [ -z "${access_token}" ]; then
    echo "\$access_token token is empty!"
  else
    local proxy_json
    proxy_json=$(q -Rs 'split("\n")|map(split("/")|{"username":.[0], "password":.[1], "ipv4_address":.[2], "port":.[3], "ipv6_exit_address":.[4]})' /root/proxy-installer/data.txt | jq 'del(.[][] | nulls)' | jq 'del(.[] | select(. == {}))')
    echo "access_token: $access_token"
    echo "proxy_json: $proxy_json"
    echo "curl -X POST -H 'Authorization: Bearer \$access_token\" -H \"Content-Type: application/json\" -d \"\$proxy_json\"  \"https://proxy6way.us/api/proxies/\""
    curl -X POST -H "Authorization: Bearer $access_token" -H "Content-Type: application/json" -d "$proxy_json"  "https://proxy6way.us/api/proxies/"
  fi
}

gen_data() {
  local port
  local addrsix
  seq "$FIRST_PORT" "$LAST_PORT" | while read -r port; do
    addrsix=$(gen64 "$IP6")
    echo "usr$(random)/pass$(random)/$IP4/$port/$addrsix"
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
mkdir -p $WORKDIR && cd "$_" || exit

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "-----------------"
echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"
sleep 3

echo "-----------------"
echo "What is this instance called?"
read -r INSTANCE_NAME

echo "How many proxy do you want to create? Example 500"
read -r COUNT

echo "What is the username on the proxy warming server?"
read -r DJANGO_USERNAME

echo "What is the password on the proxy warming server?"
read -r DJANGO_PASSWORD

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

killall 3proxy

touch /var/lock/subsys/local

bash /root/proxy-installer/fix_ips.sh

cp /root/proxy-installer/3proxy.cfg /etc/3proxy/3proxy.cfg

service 3proxy start
EOF

echo "-----------------"
echo "bash /etc/rc.local"
bash /etc/rc.local
sleep 2

echo "-----------------"
echo "Generating proxy file for user at $WORKDATA/proxy.txt."
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
upload_2file
sleep 2

echo "-----------------"
upload_2api
sleep 2

echo "-----------------"
echo "ps aux | grep 3proxy"
ps aux | grep 3proxy | grep -v grep
sleep 2

echo "-----------------"
echo "ulimit -Hn (should return 97816)"
ulimit -Hn

# iptables -I INPUT -p tcp --dport $IP6::/64 -m state --state NEW -j ACCEPT

echo "-----------------"
echo "Example proxies"
head -n 10 $WORKDATA/proxy.txt

echo "-----------------"
echo "Proxy list: /root/proxy-installer/proxy.txt"
echo "Active config at: /etc/3proxy/3proxy.cfg"
echo "Config template /etc/rc.local writes: /root/proxy-installer/3proxy.cfg"
echo "To start proxy: bash /etc/rc.local"
echo "To stop proxy: killall 3proxy"
echo "Log at: tail -n 30 /var/log/3proxy.log"
echo "-----------------"
