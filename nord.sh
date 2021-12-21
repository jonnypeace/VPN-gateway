#!/bin/bash

# Author : Jonny Peace
# Date : 21/12/2021
# Manual use...
# Run with sudo, or root.
# Run in location, so if in home directory, ~/nord.sh
# can be run with an on option for cybersec.
# So ~/nord.sh on command will run the command with cybersec on.
# I've whitelisted my home network, so i can still ssh into the server. 192.168.0.0/16

# You'll have to follow NORDVPN login details, and start the service.
touch /root/nord.log

# Check connectivity. If ping fails, the script will restart nordvpn.
ping -c 1 google.com

# if ping fails...
if [ $? = 1 ]; then
 echo "Ping failed, trying to reconnect..."
 nordvpn whitelist add subnet 192.168.0.0/16
 nordvpn disconnect
 nordvpn connect
 nordvpn set killswitch on
	if [[ $1 = "on" ]]
	then
	nordvpn set cybersec on
	echo "cybersec is on"
	else
	echo "Cybersec is off"
	#this additional DNS may not be necessary, but left here
	#for info - these are NORDVPN DNS servers.
	#nordvpn set dns 103.86.96.100 103.86.99.100
	fi
 nordvpn settings
 nordvpn status
 echo "NordVPN set up completed"
 # restart wireguard to ensure firewall rules are reset
 systemctl restart wg-quick@wg0
 date >> /root/nord.log && echo -e "\tConnection re-established" >> /root/nord.log; else
 echo "Connection already established"
fi
