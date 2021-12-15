#!/bin/bash
IPT="/sbin/iptables"

IN_FACE="ens18"
WG_FACE="wg0"
NORD_FACE="tun0"
WG_NET="10.6.0.0/24"
WG_PORT="51820"
NORD_NET="10.8.1.0/24"
SSH="22"
LOC_NET="192.168.0.0/16"

## IPv4 ##
$IPT -t nat -I POSTROUTING 1 -o $NORD_FACE -j MASQUERADE
$IPT -I INPUT 1 -i lo -j ACCEPT
$IPT -I INPUT 2 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
$IPT -I INPUT 4 -i $IN_FACE -p udp --dport $WG_PORT -s $LOC_NET -j ACCEPT
$IPT -I INPUT 5 -i $IN_FACE -p tcp --dport $SSH -s $LOC_NET -j ACCEPT
$IPT -I INPUT 7 -m limit --limit 5/min -j LOG --log-prefix "iptables IN denied: " --log-level 7

$IPT -A FORWARD -o $NORD_FACE -i $WG_FACE -j ACCEPT
$IPT -A FORWARD -o $WG_FACE -i $NORD_FACE -m state --state RELATED,ESTABLISHED -j ACCEPT
$IPT -A FORWARD -m limit --limit 5/min -j LOG --log-prefix "iptables FW denied: " --log-level 7
$IPT -A FORWARD -j DROP


# Found these rules on github to drop bad traffic. Using insert 7 to keep the rules above
# the nordvpn rule to block all.
# reject new non-syn TCP packets
$IPT -I INPUT 7 -m conntrack --ctstate NEW -p tcp ! --syn -m comment --comment "TCP: new non-syn packets" -j REJECT --reject-with tcp-reset
# drop all other invalid packets
$IPT -I INPUT 7 -p all -m conntrack --ctstate INVALID -j DROP -m comment --comment "ALL: other invalid packets"
# drop all fragmented packets
$IPT -I INPUT 7 -p all --fragment -j DROP -m comment --comment "ALL: fragmented packets"
# known ICMP attacks
$IPT -I INPUT 7 -p icmp -m length --length 1492:65535 -j DROP -m comment --comment "ICMP: oversized unfragmented packets"
$IPT -I INPUT 7 -p icmp -m u32 ! --u32 "0x4&0x3fff=0x0" -j DROP -m comment --comment "ICMP: fragmented packets"
# known TCP attacks
$IPT -I INPUT 7 -p tcp --tcp-flags ALL URG,PSH,SYN,FIN -j DROP -m comment --comment "TCP: nmap ID scan"
$IPT -I INPUT 7 -p tcp --tcp-flags ALL FIN -j DROP -m comment --comment "TCP: FIN scan"
$IPT -I INPUT 7 -p tcp --tcp-flags ALL URG,PSH,FIN -j DROP -m comment --comment "TCP: nmap Xmas scan"
$IPT -I INPUT 7 -p tcp --tcp-flags ALL SYN,FIN -j DROP -m comment --comment "TCP: SYN-FIN scan"
$IPT -I INPUT 7 -p tcp --tcp-flags ACK,URG URG -j DROP -m comment --comment "TCP: URG scan"
$IPT -I INPUT 7 -p tcp --tcp-flags SYN,RST SYN,RST -j DROP -m comment --comment "TCP: SYN-RST scan"
$IPT -I INPUT 7 -p tcp --tcp-flags FIN,RST FIN,RST -j DROP -m comment --comment "TCP: port scan 3"
$IPT -I INPUT 7 -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP -m comment --comment "TCP: port scan 2"
$IPT -I INPUT 7 -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP -m comment --comment "TCP: port scan 1"
$IPT -I INPUT 7 -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP -m comment --comment "TCP: stealth scan"
$IPT -I INPUT 7 -p tcp --tcp-flags ALL ALL -j DROP -m comment --comment "TCP: Xmas scan"
$IPT -I INPUT 7 -p tcp --tcp-flags ALL NONE -j DROP -m comment --comment "TCP: NULL scan"
