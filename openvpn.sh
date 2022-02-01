#!/bin/bash

# This is optional, you may find your openvpn service stops. This script has been written for a crontab entry
# to monitor connection status.
# If you are like me, where openvpn occasionally drops connection,
# then add this to a crontab and edit your openvpn systemctl service.

# The Much simpler openvpn method, lets see how stable this is. 
touch /root/vpn.log

# Check connectivity. If ping fails, the script will restart nordvpn.
nc -zw1 google.com 443

# if nc fails...
if [ $? != 0 ]; then
 echo "Ping failed, trying to reconnect..."
 systemctl restart openvpn@uk2161.service
 if [ $? != 0 ]; then
	 echo "openvpn@uk2161.service unable to restart" >> /root/vpn.log;
 fi
 date >> /root/vpn.log && echo -e "\tConnection re-established" >> /root/vpn.log; else
 echo "Connection already established"
fi
