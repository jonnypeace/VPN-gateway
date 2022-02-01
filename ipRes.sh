#!/bin/bash

read -p "save firewall rules? [y/N] " ans

if [[ $ans = "y" ]]; then
 iptables-save > /etc/iptables/rules.v4
 echo "iptables saved"; else
 iptables-restore < /etc/iptables/rules.v4
 echo "iptables restored"
fi
# To add the new rules & without flushing current ones
# sudo iptables-restore -n < /etc/iptables/rules.v4
