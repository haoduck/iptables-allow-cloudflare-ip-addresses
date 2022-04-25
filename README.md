# iptables-allow-cloudflare-ip-addresses
使用iptables实现只允许CloudFlare的回源IP访问

### iptables创建一个链
```
iptables -N CLOUDFLARE
ip6tables -N CLOUDFLARE
```

### 让INPUT引用
```
iptables -A INPUT -j CLOUDFLARE
ip6tables -A INPUT -j CLOUDFLARE
```

### 把CF的IP加进链里
```
for ip in `curl -s https://www.cloudflare.com/ips-v4`;do
iptables  -A CLOUDFLARE -p tcp -m multiport --dports http,https -s $ip -j ACCEPT
done
for ip in `curl -s https://www.cloudflare.com/ips-v6`;do
ip6tables  -A CLOUDFLARE -p tcp -m multiport --dports http,https -s $ip -j ACCEPT
done
```

### 不允许其他
```
iptables -A INPUT -p tcp -m multiport --dport http,https -j DROP
ip6tables -A INPUT -p tcp -m multiport --dport http,https -j DROP
```


### iptables规则持久化的设置
```
#保存规则
mkdir -p /etc/iptables/
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
```


```
#应用规则
iptables-restore < /etc/iptables/rules.v4
ip6tables-restore < /etc/iptables/rules.v6
```

应用规则的命令配置开机执行


上面的内容全放一起，方便复制
```
iptables -N CLOUDFLARE
ip6tables -N CLOUDFLARE
iptables -A INPUT -j CLOUDFLARE
ip6tables -A INPUT -j CLOUDFLARE
for ip in `curl -s https://www.cloudflare.com/ips-v4`;do
iptables  -A CLOUDFLARE -p tcp -m multiport --dports http,https -s $ip -j ACCEPT
done
for ip in `curl -s https://www.cloudflare.com/ips-v6`;do
ip6tables  -A CLOUDFLARE -p tcp -m multiport --dports http,https -s $ip -j ACCEPT
done
iptables -A INPUT -p tcp -m multiport --dport http,https -j DROP
ip6tables -A INPUT -p tcp -m multiport --dport http,https -j DROP
mkdir -p /etc/iptables/
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
```


以上配置完毕后
以下内容保存为脚本，定时执行即可(更新CloudFlare的IP)

```
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
```


### 管杀管埋
不玩了，清空上面设置过的规则
```
iptables -F CLOUDFLARE
ip6tables -F CLOUDFLARE
iptables -D INPUT -j CLOUDFLARE
ip6tables -D INPUT -j CLOUDFLARE
iptables -X CLOUDFLARE
ip6tables -X CLOUDFLARE
iptables -D INPUT -p tcp --dport http,https -j DROP
ip6tables -D INPUT -p tcp --dport http,https -j DROP
> /etc/iptables/rules.v4
> /etc/iptables/rules.v6
```

