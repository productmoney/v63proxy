Redirect connections from different ports at one ipv4 address to unique random ipv6 address from \64 subnetwork. Based on 3proxy

![cover](cover.svg)

## Installation

1. Create a Centos 8 vps with Ipv6 \64 on, VPS from [Vultr *100$ free*](https://www.vultr.com/?ref=8815005-6G) used as Centos setup. ssh into it

2. `yum update;yum install git;grep 97816 /etc/security/limits.conf || echo -e "* hard nofile 97816\n* soft nofile 97816" >> /etc/security/limits.conf`

3. log out, log back in

4. `bash <(curl -s "https://raw.githubusercontent.com/productmoney/v63proxy/main/scripts/install.sh")`

5. After installation dowload the file `proxy.zip`
   * File structure: `IP4:PORT:LOGIN:PASS`
   * You can use this online [util](http://buyproxies.org/panel/format.php
) to change proxy format as you like

## Test your proxy

Install [FoxyProxy](https://addons.mozilla.org/en-US/firefox/addon/foxyproxy-standard/) in Firefox
![Foxy](foxyproxy.png)

Open [ipv6-test.com](http://ipv6-test.com/) and check your connection
![check ip](check_ip.png)
