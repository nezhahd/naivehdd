#!/bin/bash
naygV="22.10.30 V 1.0"
remoteV=`wget -qO- https://gitlab.com/rwkgyg/naiveproxy-yg/raw/main/naiveproxy.sh | sed  -n 2p | cut -d '"' -f 2`
chmod +x /root/naiveproxy.sh
red='\033[0;31m'
bblue='\033[0;34m'
plain='\033[0m'
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "请以root模式运行脚本" && exit
yellow " 请稍等3秒……正在扫描vps类型及参数中……"
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -q -E -i "debian"; then
release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
else 
red "不支持你当前系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
fi
vsid=`grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1`
sys(){
[ -f /etc/os-release ] && grep -i pretty_name /etc/os-release | cut -d \" -f2 && return
[ -f /etc/lsb-release ] && grep -i description /etc/lsb-release | cut -d \" -f2 && return
[ -f /etc/redhat-release ] && awk '{print $0}' /etc/redhat-release && return;}
op=`sys`
version=`uname -r | awk -F "-" '{print $1}'`
main=`uname  -r | awk -F . '{print $1}'`
minor=`uname -r | awk -F . '{print $2}'`

bit=`uname -m`
if [[ $bit = x86_64 ]]; then
cpu=amd64
elif [[ $bit = aarch64 ]]; then
cpu=arm64
else
red "VPS的CPU架构为$bit 脚本不支持当前CPU架构，请使用amd64或arm64架构的CPU运行脚本" && exit
fi

vi=`systemd-detect-virt`
rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
if [[ -n $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk -F ' ' '{print $3}') ]]; then
bbr=`sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}'`
elif [[ -n $(ping 10.0.0.2 -c 2 | grep ttl) ]]; then
bbr="openvz版bbr-plus"
else
bbr="暂不支持显示"
fi

start(){
if [[ $vi = openvz ]]; then
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
red "检测到未开启TUN，现尝试添加TUN支持" && sleep 2
cd /dev
mkdir net
mknod net/tun c 10 200
chmod 0666 net/tun
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
green "添加TUN支持失败，建议与VPS厂商沟通或后台设置开启" && exit
else
green "恭喜，添加TUN支持成功，现添加TUN守护功能" && sleep 4
cat>/root/tun.sh<<-\EOF
#!/bin/bash
cd /dev
mkdir net
mknod net/tun c 10 200
chmod 0666 net/tun
EOF
chmod +x /root/tun.sh
grep -qE "^ *@reboot root bash /root/tun.sh >/dev/null 2>&1" /etc/crontab || echo "@reboot root bash /root/tun.sh >/dev/null 2>&1" >> /etc/crontab
green "TUN守护功能已启动"
fi
fi
fi
[[ $(type -P yum) ]] && yumapt='yum -y' || yumapt='apt -y'
[[ $(type -P curl) ]] || (yellow "检测到curl未安装，升级安装中" && $yumapt update;$yumapt install curl)
[[ $(type -P lsof) ]] || (yellow "检测到lsof未安装，升级安装中" && $yumapt update;$yumapt install lsof)
[[ ! $(type -P qrencode) ]] && ($yumapt update;$yumapt install qrencode)
if [[ -z $(grep 'DiG 9' /etc/hosts) ]]; then
v4=$(curl -s4m5 https://ip.gs -k)
if [ -z $v4 ]; then
echo -e nameserver 2a01:4f8:c2c:123f::1 > /etc/resolv.conf
fi
fi
systemctl stop firewalld.service >/dev/null 2>&1
systemctl disable firewalld.service >/dev/null 2>&1
setenforce 0 >/dev/null 2>&1
ufw disable >/dev/null 2>&1
iptables -P INPUT ACCEPT >/dev/null 2>&1
iptables -P FORWARD ACCEPT >/dev/null 2>&1
iptables -P OUTPUT ACCEPT >/dev/null 2>&1
iptables -t nat -F >/dev/null 2>&1
iptables -t mangle -F >/dev/null 2>&1
iptables -F >/dev/null 2>&1
iptables -X >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
if [[ -n $(apachectl -v 2>/dev/null) ]]; then
systemctl stop httpd.service >/dev/null 2>&1
systemctl disable httpd.service >/dev/null 2>&1
service apache2 stop >/dev/null 2>&1
systemctl disable apache2 >/dev/null 2>&1
fi
}

insupdate(){
if [[ $release = Centos ]]; then
if [[ ${vsid} =~ 8 ]]; then
cd /etc/yum.repos.d/ && mkdir backup && mv *repo backup/ 
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-8.repo
sed -i -e "s|mirrors.cloud.aliyuncs.com|mirrors.aliyun.com|g " /etc/yum.repos.d/CentOS-*
sed -i -e "s|releasever|releasever-stream|g" /etc/yum.repos.d/CentOS-*
yum clean all && yum makecache
fi
yum install epel-release -y
else
apt update
fi
}
forwardproxy(){
go env -w GO111MODULE=on
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive
}
rest(){
if [[ ! -f /root/caddy ]]; then
red "caddy2-naiveproxy构建失败，脚本退出" && exit
fi
chmod +x caddy
mv caddy /usr/bin/
mkdir /etc/caddy
}

inscaddynaive(){
green "请选项安装naiveproxy方式:"
readp "1. 直接使用已编译好的caddy2-naiveproxy版本（回车默认）\n2. 自动编译最新caddy2-naiveproxy版本\n请选择：" chcaddynaive
if [ -z "$chcaddynaive" ] || [ $chcaddynaive == "1" ]; then
insupdate
wget -N https://github.com/rkygogo/na/raw/main/caddy2-naive-linux-${cpu}.tar.gz
tar zxvf caddy2-naive-linux-${cpu}.tar.gz
rm caddy2-naive-linux-${cpu}.tar.gz -f
rest
elif [ $chcaddynaive == "2" ]; then
insupdate
if [[ $release = Centos ]]; then 
rpm --import https://mirror.go-repo.io/centos/RPM-GPG-KEY-GO-REPO
curl -s https://mirror.go-repo.io/centos/go-repo.repo | tee /etc/yum.repos.d/go-repo.repo
yum install golang && forwardproxy
else
apt install software-properties-common
add-apt-repository ppa:longsleep/golang-backports 
apt update 
apt install golang-go && forwardproxy
fi
rest
else 
red "输入错误，请重新选择" && inscaddynaive
fi
}

inscertificate(){
green "naiveproxy协议证书申请方式选择如下:"
readp "1. acme一键申请证书脚本（支持常规80端口模式与dns api模式），已用此脚本申请的证书则自动识别（回车默认）\n2. 自定义证书路径\n请选择：" certificate
if [ -z "${certificate}" ] || [ $certificate == "1" ]; then
if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key ]] && [[ -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]] && [[ -f /root/ygkkkca/ca.log ]]; then
blue "经检测，之前已使用此acme脚本申请过证书"
readp "1. 直接使用原来的证书（回车默认）\n2. 删除原来的证书，重新申请证书\n请选择：" certacme
if [ -z "${certacme}" ] || [ $certacme == "1" ]; then
ym=$(cat /root/ygkkkca/ca.log)
blue "检测到的域名：$ym ，已直接引用\n"
elif [ $certacme == "2" ]; then
rm -rf /root/ygkkkca
wget -N https://gitlab.com/rwkgyg/acme-script/raw/main/acme.sh && bash acme.sh
ym=$(cat /root/ygkkkca/ca.log)
if [[ ! -f /root/ygkkkca/cert.crt && ! -f /root/ygkkkca/private.key ]] && [[ ! -s /root/ygkkkca/cert.crt && ! -s /root/ygkkkca/private.key ]]; then
red "证书申请失败，脚本退出" && exit
fi
fi
else
wget -N https://gitlab.com/rwkgyg/acme-script/raw/main/acme.sh && bash acme.sh
ym=$(cat /root/ygkkkca/ca.log)
if [[ ! -f /root/ygkkkca/cert.crt && ! -f /root/ygkkkca/private.key ]] && [[ ! -s /root/ygkkkca/cert.crt && ! -s /root/ygkkkca/private.key ]]; then
red "证书申请失败，脚本退出" && exit
fi
fi
certificatec='/root/ygkkkca/cert.crt'
certificatep='/root/ygkkkca/private.key'
elif [ $certificate == "2" ]; then
readp "请输入已放置好的公钥文件crt的路径（/a/b/……/cert.crt）：" cerroad
blue "公钥文件crt的路径：$cerroad "
readp "请输入已放置好的密钥文件key的路径（/a/b/……/private.key）：" keyroad
blue "密钥文件key的路径：$keyroad "
certificatec=$cerroad
certificatep=$keyroad
readp "请输入已解析好的域名:" ym
blue "已解析好的域名：$ym "
else 
red "输入错误，请重新选择" && inscertificate
fi
}

insport(){
readp "\n设置naiveproxy端口[1-65535]（回车跳过为2000-65535之间的随机端口）：" port
if [[ -z $port ]]; then
port=$(shuf -i 2000-65535 -n 1)
until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]
do
[[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义naiveproxy端口:" port
done
else
until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]
do
[[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义naiveproxy端口:" port
done
fi
blue "已确认端口：$port\n"
}

insuser(){
readp "设置naiveproxy用户名（回车跳过为随机6位字符）：" user
if [[ -z ${user} ]]; then
user=`date +%s%N |md5sum | cut -c 1-6`
fi
blue "已确认用户名：${user}\n"
}

inspswd(){
readp "设置naiveproxy密码（回车跳过为随机10位字符）：" pswd
if [[ -z ${pswd} ]]; then
pswd=`date +%s%N |md5sum | cut -c 1-10`
fi
blue "已确认密码：${pswd}\n"
}

insconfig(){
green "设置naiveproxy的配置文件、服务进程……\n"
mkdir -p /root/naive
cat << EOF >/etc/caddy/Caddyfile
:$port, $ym:$port {
tls ${certificatec} ${certificatep} 
route {
 forward_proxy {
   basic_auth ${user} ${pswd}
   hide_ip
   hide_via
   probe_resistance
  }
 reverse_proxy  https://ygkkk.blogspot.com  {
   header_up  Host  {upstream_hostport}
   header_up  X-Forwarded-Host  {host}
  }
}
}
EOF

cat <<EOF > /root/naive/v2rayn.json
{
  "listen": "socks://127.0.0.1:1080",
  "proxy": "https://${user}:${pswd}@${ym}:$port"
}
EOF

cat << EOF >/etc/systemd/system/caddy.service
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target
[Service]
User=root
Group=root
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
PrivateTmp=true
ProtectSystem=full
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable caddy
systemctl start caddy
}

stclre(){
if [[ ! -f '/etc/caddy/Caddyfile' ]]; then
green "未正常安装naiveproxy" && exit
fi
green "naiveproxy服务执行以下操作"
readp "1. 重启\n2. 关闭\n3. 启动\n请选择：" action
if [[ $action == "1" ]]; then
systemctl restart caddy
green "naiveproxy服务重启\n"
elif [[ $action == "2" ]]; then
systemctl stop caddy
systemctl disable caddy
green "naiveproxy服务关闭\n"
elif [[ $action == "3" ]]; then
systemctl enable caddy
systemctl start caddy
green "naiveproxy服务开启\n"
else
red "输入错误,请重新选择" && stclre
fi
}

changeserv(){
if [[ -z $(systemctl status caddy 2>/dev/null | grep -w active) && ! -f '/etc/caddy/Caddyfile' ]]; then
red "未正常安装naiveproxy" && exit
fi
green "naiveproxy配置变更选择如下:"
readp "1. 添加或删除多端口复用(每执行一次添加一个端口)\n2. 变更证书\n3. 变更用户名\n4. 变更密码\n5. 变更主端口\n6. 返回上层\n请选择：" choose
if [ $choose == "1" ];then
duoport
elif [ $choose == "2" ];then
inscertificate
oldcer=`cat /etc/caddy/Caddyfile 2>/dev/null | sed -n 2p | awk '{print $2}'`
oldkey=`cat /etc/caddy/Caddyfile 2>/dev/null | sed -n 2p | awk '{print $3}'`
sed -i "s#$oldcer#${certificatec}#g" /etc/caddy/Caddyfile
sed -i "s#$oldkey#${certificatep}#g" /etc/caddy/Caddyfile
sed -i "s#$oldcer#${certificatec}#g" /etc/caddy/reCaddyfile
sed -i "s#$oldkey#${certificatep}#g" /etc/caddy/reCaddyfile
oldym=`cat /etc/caddy/Caddyfile 2>/dev/null | sed -n 1p | awk '{print $2}'| awk -F":" '{print $1}'`
sed -i "s/$oldym/${ym}/g" /etc/caddy/Caddyfile /etc/caddy/reCaddyfile /root/naive/URL.txt /root/naive/v2rayn.json
sussnaiveproxy
elif [ $choose == "3" ];then
changeuser
elif [ $choose == "4" ];then
changepswd
elif [ $choose == "5" ];then
changeport
elif [ $choose == "6" ];then
na
else 
red "请重新选择" && changeserv
fi
}

duoport(){
naiveports=`cat /etc/caddy/Caddyfile 2>/dev/null | awk '{print $1}' | grep : | tr -d ',:'`
green "\n当前naiveproxy代理正在使用的端口："
blue "$naiveports"
readp "\n1. 添加多端口复用\n2. 恢复仅一个主端口\n3. 返回上层\n请选择：" choose
if [ $choose == "1" ]; then
oldport1=`cat /etc/caddy/reCaddyfile 2>/dev/null | sed -n 1p | awk '{print $1}'| tr -d ',:'`
insport
sed -i "s/$oldport1/$port/g" /etc/caddy/reCaddyfile
cat /etc/caddy/reCaddyfile >> /etc/caddy/Caddyfile
sussnaiveproxy
elif [ $choose == "2" ]; then
sed -i '16,$d' /etc/caddy/Caddyfile 2>/dev/null
sussnaiveproxy
elif [ $choose == "3" ]; then
changeserv
else 
red "请重新选择" && duoport
fi
}

changeuser(){
olduserc=`cat /etc/caddy/Caddyfile 2>/dev/null | sed -n 5p | awk '{print $2}'`
echo
blue "当前正在使用的用户名：$olduserc"
echo
insuser
sed -i "s/$olduserc/${user}/g" /etc/caddy/Caddyfile /etc/caddy/reCaddyfile /root/naive/URL.txt /root/naive/v2rayn.json
sussnaiveproxy
}

changepswd(){
oldpswdc=`cat /etc/caddy/Caddyfile 2>/dev/null | sed -n 5p | awk '{print $3}'`
echo
blue "当前正在使用的密码：$oldpswdc"
echo
inspswd
sed -i "s/$oldpswdc/${pswd}/g" /etc/caddy/Caddyfile /etc/caddy/reCaddyfile /root/naive/URL.txt /root/naive/v2rayn.json
sussnaiveproxy
}

changeport(){
oldport1=`cat /etc/caddy/Caddyfile 2>/dev/null | sed -n 1p | awk '{print $1}'| tr -d ',:'`
echo
blue "当前正在使用的主端口：$oldport1"
echo
insport
sed -i "s/$oldport1/$port/g" /etc/caddy/Caddyfile /root/naive/v2rayn.json /root/naive/URL.txt
sussnaiveproxy
}

cfwarp(){
wget -N --no-check-certificate https://gitlab.com/rwkgyg/cfwarp/raw/main/CFwarp.sh && bash CFwarp.sh
}

bbr(){
bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
}

naiveproxystatus(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
[[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]] && wgcf=$(green "未启用") || wgcf=$(green "启用中")
naiveports=`cat /etc/caddy/Caddyfile 2>/dev/null | awk '{print $1}' | grep : | tr -d ',:'`
if [[ -n $(systemctl status caddy 2>/dev/null | grep -w active) && -f '/etc/caddy/Caddyfile' ]]; then
status=$(white "naiveproxy状态：\c";green "运行中";white "naiveproxy代理端口： \c";green "$naiveports";white "WARP状态：    \c";eval echo \$wgcf)
elif [[ -z $(systemctl status caddy 2>/dev/null | grep -w active) && -f '/etc/hysteria/config.json' ]]; then
status=$(white "naiveproxy状态：\c";yellow "未启动,可尝试选择4，开启或者重启naiveproxy";white "WARP状态：    \c";eval echo \$wgcf)
else
status=$(white "naiveproxy状态：\c";red "未安装";white "WARP状态：    \c";eval echo \$wgcf)
fi
}

upnayg(){
if [[ -z $(systemctl status caddy 2>/dev/null | grep -w active) && ! -f '/etc/caddy/Caddyfile' ]]; then
red "未正常安装naiveproxy" && exit
fi
wget -N https://gitlab.com/rwkgyg/naiveproxy-yg/raw/main/naiveproxy.sh
chmod +x /root/naiveproxy.sh 
ln -sf /root/naiveproxy.sh /usr/bin/na
green "naiveproxy-yg安装脚本升级成功"
}

unins(){
systemctl stop caddy >/dev/null 2>&1
systemctl disable caddy >/dev/null 2>&1
rm -f /etc/systemd/system/caddy.service
rm -rf /usr/bin/caddy /etc/caddy /root/naive /root/naiveproxy.sh /usr/bin/na
green "naiveproxy卸载完成！"
}

sussnaiveproxy(){
systemctl restart caddy
if [[ -n $(systemctl status caddy 2>/dev/null | grep -w active) && -f '/etc/caddy/Caddyfile' ]]; then
green "naiveproxy服务启动成功" && naiveproxyshare
else
red "naiveproxy服务启动失败，请运行systemctl status caddy查看服务状态并反馈，脚本退出" && exit
fi
}

naiveproxyshare(){
if [[ -z $(systemctl status caddy 2>/dev/null | grep -w active) && ! -f '/etc/caddy/Caddyfile' ]]; then
red "未正常安装naiveproxy" && exit
fi
naiveports=`cat /etc/caddy/Caddyfile 2>/dev/null | awk '{print $1}' | grep : | tr -d ',:'`
green "\n当前naiveproxy代理正在使用的端口："
blue "$naiveports\n"
green "当前v2rayn客户端配置文件v2rayn.json内容如下，保存到 /root/naive/v2rayn.json\n"
yellow "$(cat /root/naive/v2rayn.json)\n"
green "当前naiveproxy节点分享链接如下，保存到 /root/naive/URL.txt"
yellow "$(cat /root/naive/URL.txt)\n"
green "当前naiveproxy节点二维码分享链接如下(SagerNet / Matsuri)"
qrencode -o - -t ANSIUTF8 "$(cat /root/naive/URL.txt)"
}

insna(){
if [[ -n $(systemctl status caddy 2>/dev/null | grep -w active) && -f '/etc/caddy/Caddyfile' ]]; then
green "已安装naiveproxy，重装请先执行卸载功能" && exit
fi
inscaddynaive ; inscertificate ; insport ; insuser ; inspswd ; insconfig
if [[ -n $(systemctl status caddy 2>/dev/null | grep -w active) && -f '/etc/caddy/Caddyfile' ]]; then
green "naiveproxy服务启动成功"
chmod +x /root/naiveproxy.sh 
ln -sf /root/naiveproxy.sh /usr/bin/na
cp -f /etc/caddy/Caddyfile /etc/caddy/reCaddyfile >/dev/null 2>&1
if [[ ! $vi =~ lxc|openvz ]]; then
sysctl -w net.core.rmem_max=8000000
sysctl -p
fi
else
red "naiveproxy服务启动失败，请运行systemctl status caddy查看服务状态并反馈，脚本退出" && exit
fi
url="naive+https://${user}:${pswd}@${ym}:$port?padding=true#Naive-ygkkk"
echo ${url} > /root/naive/URL.txt
green "\nnaiveproxy代理服务安装完成，生成脚本的快捷方式为 na"
blue "\nv2rayn客户端配置文件v2rayn.json保存到 /root/naive/v2rayn.json\n"
yellow "$(cat /root/naive/v2rayn.json)\n"
blue "分享链接保存到 /root/naive/URL.txt"
yellow "${url}\n"
green "二维码分享链接如下(SagerNet / Matsuri)"
qrencode -o - -t ANSIUTF8 "$(cat /root/naive/URL.txt)"
}

start_menu(){
naiveproxystatus
clear
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"           
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
echo -e "${bblue}   ░██ ░██      ░██ ${plain}                ░██ ██        ░██ █${red}█        ░██ ██  ${plain}   "
echo -e "${bblue}     ░██        ░${plain}██    ░██ ██       ░██ ██        ░█${red}█ ██        ░██ ██  ${plain}  "
echo -e "${bblue}     ░██ ${plain}        ░██    ░░██        ░██ ░██       ░${red}██ ░██       ░██ ░██ ${plain}  "
echo -e "${bblue}     ░█${plain}█          ░██ ██ ██         ░██  ░░${red}██     ░██  ░░██     ░██  ░░██ ${plain}  "
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "甬哥Gitlab项目  ：gitlab.com/rwkgyg"
white "甬哥blogger博客 ：ygkkk.blogspot.com"
white "甬哥YouTube频道 ：www.youtube.com/c/甬哥侃侃侃kkkyg"
green "naiveproxy-yg脚本安装成功后，再次进入脚本的快捷方式为 na"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green " 1. 安装naiveproxy（必选）" 
green " 2. 卸载naiveproxy"
white "----------------------------------------------------------------------------------"
green " 3. 配置变更（多端口复用、证书、用户名、密码、主端口）" 
green " 4. 关闭、开启、重启naiveproxy"   
green " 5. 更新naiveproxy-yg安装脚本"  
white "----------------------------------------------------------------------------------"
green " 6. 显示当前naiveproxy分享链接、V2rayN配置文件、二维码"
green " 7. 安装warp（可选）"
green " 8. 安装bbr加速（可选）"
green " 0. 退出脚本"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
if [[ -n $(systemctl status caddy 2>/dev/null | grep -w active) && -f '/etc/caddy/Caddyfile' ]]; then
if [ "${naygV}" = "${remoteV}" ]; then
green "当前naiveproxy-yg安装脚本版本号：${naygV} ，已是最新版本\n"
else
green "当前naiveproxy-yg安装脚本版本号：${naygV}"
yellow "检测到最新naiveproxy-yg安装脚本版本号：${remoteV} ，可选择5进行更新\n"
fi
fi
white "VPS系统信息如下："
white "操作系统:     $(blue "$op")" && white "内核版本:     $(blue "$version")" && white "CPU架构 :     $(blue "$cpu")" && white "虚拟化类型:   $(blue "$vi")" && white "TCP加速算法   : $(blue "$bbr")"
white "$status"
echo
readp "请输入数字:" Input
case "$Input" in     
 1 ) insna;;
 2 ) unins;;
 3 ) changeserv;;
 4 ) stclre;;
 5 ) upnayg;; 
 6 ) naiveproxyshare;;
 7 ) cfwarp;;
 8 ) bbr;;
 * ) exit 
esac
}
if [ $# == 0 ]; then
start
start_menu
fi
