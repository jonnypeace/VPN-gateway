#!/bin/bash

read -p "save firewall rules? [y/N] " ans

if [ $ans = "y" ]; then
iptables-save > /etc/iptables/rules.v4 ; else
iptables-restore < /etc/iptables/rules.v4
fi
# To add the new rules & without flushing current ones
# sudo iptables-restore -n < /etc/iptables/rules.v4
