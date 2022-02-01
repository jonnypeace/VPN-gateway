#!/bin/bash

# The Much simpler openvpn method, lets see how stable this is. 
touch /root/vpn.log

# Check connectivity. If ping fails, the script will restart nordvpn.
nc -zw1 google.com 443

# if nc fails...
if [ $? != 0 ]; then
 echo "Ping failed, trying to reconnect..."
 systemctl restart openvpn@xyz123.service
 if [ $? != 0 ]; then
	 echo "openvpn@nl914.service unable to restart" >> /root/vpn.log;
 fi
 date >> /root/vpn.log && echo -e "\tConnection re-established" >> /root/vpn.log; else
 echo "Connection already established"
fi
