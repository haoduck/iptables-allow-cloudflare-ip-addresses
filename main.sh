#!/bin/bash

if [[ -z "$(command -v iptables)" ]] || [[ -z "$(command -v ip6tables)" ]];then
    echo "error: iptables/ip6tables not found!
    please install it.
    example: apt install -y iptables    yum install -y iptables"
    exit 1
fi

if [[ -z "$(iptables -L |grep 'Chain CLOUDFLARE')" ]];then
    iptables -N CLOUDFLARE
    iptables -A INPUT -j CLOUDFLARE
fi
if [[ -z "$(ip6tables -L |grep 'Chain CLOUDFLARE')" ]];then
    ip6tables -N CLOUDFLARE
    ip6tables -A INPUT -j CLOUDFLARE
fi

run(){
    iptables=$1
    ips=$2
    rule_file=$3

    #先删掉"不允许其他"，避免在下面命令执行期间GG
    $iptables -D INPUT -p tcp -m multiport --dport http,https -j DROP

    #清除规则(旧的CF IP)
    $iptables -F CLOUDFLARE

    for ip in  `echo -e "$ips"`;do
        $iptables -A CLOUDFLARE -s $ip -j ACCEPT
    done

    #禁用其他IP
    $iptables -A INPUT -p tcp -m multiport --dport http,https -j DROP

    #保存规则
    mkdir -p /etc/iptables/
    $iptables-save > $rule_file
}

#这里对curl的结果做一次判断，避免网络出问题时可能导致的问题。如果curl的结果中没找到xxx.xxx.xxx.xxx/xx或者xxxx:xxxx::/xx的内容就不执行
ips_v4=$(curl -s https://www.cloudflare.com/ips-v4|grep -Eo "([0-9]{1,3}.){3}[0-9]{1,3}/[0-9]{1,3}")
ips_v6=$(curl -s https://www.cloudflare.com/ips-v6|grep -Eo "([a-z0-9]{1,4}:){1,7}:?/[0-9]{1,3}")

if [[ "$ips_v4" ]];then
    run "iptables" "$ips_v4" "/etc/iptables/rules.v4"
fi

if [[ "$ips_v6" ]];then
    run "ip6tables" "$ips_v6" "/etc/iptables/rules.v6"
fi
