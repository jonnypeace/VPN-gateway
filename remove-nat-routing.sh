#!/bin/bash
IPT="/sbin/iptables"

IN_FACE="ens18"
WG_FACE="wg0"
NORD_FACE="tun0"
WG_NET="10.6.0.0/24"
WG_PORT="51820"
SSH="22"
NORD_NET="10.8.1.0/24"
LOC_NET="192.168.0.0/16"

# IPv4 rules
$IPT -t nat -D POSTROUTING -o $NORD_FACE -j MASQUERADE
$IPT -D INPUT -i lo -j ACCEPT
$IPT -D INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
$IPT -D INPUT -i $IN_FACE -p udp --dport $WG_PORT -s $LOC_NET -j ACCEPT
$IPT -D INPUT -i $IN_FACE -p tcp --dport $SSH -s $LOC_NET -j ACCEPT
$IPT -D INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables IN denied: " --log-level 7

$IPT -D FORWARD -i $WG_FACE -o $NORD_FACE -j ACCEPT
$IPT -D FORWARD -i $NORD_FACE -o $WG_FACE -m state --state RELATED,ESTABLISHED -j ACCEPT
$IPT -D FORWARD -m limit --limit 5/min -j LOG --log-prefix "iptables FW denied: " --log-level 7
$IPT -D FORWARD -j DROP

# known TCP attacks
$IPT -D INPUT -p tcp --tcp-flags ALL NONE -j DROP -m comment --comment "TCP: NULL scan"
$IPT -D INPUT -p tcp --tcp-flags ALL ALL -j DROP -m comment --comment "TCP: Xmas scan"
$IPT -D INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP -m comment --comment "TCP: stealth scan"
$IPT -D INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP -m comment --comment "TCP: port scan 1"
$IPT -D INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP -m comment --comment "TCP: port scan 2"
$IPT -D INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP -m comment --comment "TCP: port scan 3"
$IPT -D INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP -m comment --comment "TCP: SYN-RST scan"
$IPT -D INPUT -p tcp --tcp-flags ACK,URG URG -j DROP -m comment --comment "TCP: URG scan"
$IPT -D INPUT -p tcp --tcp-flags ALL SYN,FIN -j DROP -m comment --comment "TCP: SYN-FIN scan"
$IPT -D INPUT -p tcp --tcp-flags ALL URG,PSH,FIN -j DROP -m comment --comment "TCP: nmap Xmas scan"
$IPT -D INPUT -p tcp --tcp-flags ALL FIN -j DROP -m comment --comment "TCP: FIN scan"
$IPT -D INPUT -p tcp --tcp-flags ALL URG,PSH,SYN,FIN -j DROP -m comment --comment "TCP: nmap ID scan"

# known ICMP attacks
$IPT -D INPUT -p icmp -m u32 ! --u32 "0x4&0x3fff=0x0" -j DROP -m comment --comment "ICMP: fragmented packets"
$IPT -D INPUT -p icmp -m length --length 1492:65535 -j DROP -m comment --comment "ICMP: oversized unfragmented packets"

# drop all fragmented packets
$IPT -D INPUT -p all --fragment -j DROP -m comment --comment "ALL: fragmented packets"

# drop all other invalid packets
$IPT -D INPUT -p all -m conntrack --ctstate INVALID -j DROP -m comment --comment "ALL: other invalid packets"

# reject new non-syn TCP packets
$IPT -D INPUT -m conntrack --ctstate NEW -p tcp ! --syn -m comment --comment "TCP: new non-syn packets" -j REJECT --reject-with tcp-reset

$IPT -D OUTPUT -o lo -j ACCEPT
