# VPN-gateway

The purpose of these scripts is to connect devices on my LAN to a VPN gateway using wireguard.

Originally my plan was to set up a raspberry pi with open-wrt and connect the devices over wifi
with a stronger wifi dongle, but I couldn't resist exploring this option first.
I'm aware that I could use static ip gateway for something like this, but to keep things easier
to switch on and off (the wireguard client), I feel this is more user friendly than switching gateways.

The benefit of doing it this way, if we have a server running at home anyway, you don't need
additional hardware (wifi access points for the server), just the wireguard client/server application. I've also got this running in an 
Ubuntu VM dedicated to serve only this function. I will be exploring the use of LXC containers
as well.

WARNING : 
This runs strictly iptables only, and doesn't take into account nftables or UFW or firewalld.

So, a quick flow diagram....

Phone/pc device with wireguard client >> VPN Gateway, with wireguard server traffic coming in >> VPN gateway with NORD VPN traffic going out.

I've taken a collection of firewall rules gathered from sources on github, and would welcome any critique / additional rules. Since i'm a learning
Linux System Administrator, and Linux user since 2014, i don't have exposure to Enterprise firewall rules, but all in good time. The rules collected are all DROP/REJECT and i'll be honest, if you use my iptables rules, they never get touched so some of them could probably be removed. I suppose they might be more useful in a cloud VPS where there's no hardware firewall between the server and internet.

############################################################################

So how it works.....

I am going to assume you have followed one of the many ways to set up your wireguard server and client. If you run into any difficulty, contact me
via github. I might include a section here for wireguard in the future. I do have a script to set up new users in my bashscripts repo which might help, but i'm looking at improving this script in the future as well.

Log into your server and Switch user to root.
~~~
sudo su -
~~~
Install openvpn and unzip and change directories
~~~
apt install openvpn unzip
cd /etc/openvpn
~~~
Grab the server list from nordvpn. Check NordVPN website incase this link changes.
~~~
wget https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip
~~~
unzip the server list and remove the zip file
~~~
unzip ovpn.zip
rm ovpn.zip
~~~
move into the udp server directory and list all uk servers, lots to choose from, and uk is just an example.
for the purposes of this readme, i'll select uk2161.nordvpn.com.udp.ovpn
~~~
cd /etc/openvpn/ovpn_udp
ls uk*
~~~

In this tutorial, we could use nano/vi/vim to edit files, but for a change, i figured lets do it the sed way for most of it. Feel free to edit with the editor of your choice.

We're looking for text containing "auth-user-pass" and replacing it with "auth-user-pass /etc/openvpn/auto-auth.txt" in this file uk2161.nordvpn.com.udp.ovpn
~~~
sed -i 's|auth-user-pass|auth-user-pass /etc/openvpn/auto-auth.txt|' uk2161.nordvpn.com.udp.ovpn
~~~
Enter your credentials into /etc/openvpn/auto-auth.txt i.e. These credentials will be found in your nordvpn account dashboard.
jonny
password123
and change the permissions so only root can read it:
~~~
nano /etc/openvpn/auto-auth.txt
chmod 400 /etc/openvpn/auto-auth.txt
~~~
we need to move uk2161.nordvpn.com.udp.ovpn into a config in the etc/openvpn directory
~~~
mv /etc/openvpn/ovpn_udp/uk2161.nordvpn.com.udp.ovpn /etc/openvpn/uk2161.conf
~~~
edit the default openvpn config to autostart with uk2161 (or which ever server you chose) /etc/default/openvpn
~~~
sed -i '/AUTOSTART="all"/a AUTOSTART="uk2161"' /etc/default/openvpn
~~~
Lastly, reboot
~~~
reboot
~~~

Firewall rules for killswitch

I've put in some firewall rules that can be copied to /etc/iptables
This might not work well with UFW, i find it better to keep things simple and choose one over the other.
If you are using ufw, you might want to disable it, and flush the iptable rules, but for the purpose of this tutorial,
i'll assume fresh install of Ubuntu with ufw disabled (and never been run).

We'll need to edit the rules to match your system and not lock you out, so...
replace ens18 with your network interface, which can be found using...

<pre>
run this command:
    ip a

snipper of the output:

2: <b>ens18</b>: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether b6:c5:18:78:ea:40 brd ff:ff:ff:ff:ff:ff
    inet <b>192.168.2.10/24</b> brd 192.168.2.255 scope global ens18
       valid_lft forever preferred_lft forever
    inet6 fe80::b4c5:18ff:fe78:ea40/64 scope link 
       valid_lft forever preferred_lft forever
</pre>

replace the interface ens30 for one that is on your system
<pre>
sed -i 's|ens18|<b>ens30</b>|g' etc.iptables.rules.v4
</pre>

replace the 10.10.0.0/24 (in this sed command) with your lan address subnet.
WARNING: This is important to get right, as this rule whitelists you from the firewall, and will allow SSH/wireguard access
SUBNET HELP: A subnet from the ip address identified from the command above (in bold), would equate to...
~~~
192.168.2.10/24 = 192.168.2.0/24 or 192.168.0.0/16 (/16 will provide more addresses than /24)

For a better understanding, maybe have a look here. https://www.cloudflare.com/en-gb/learning/network-layer/what-is-a-subnet/

Home lans usually fall somewhere in the 192.168.0.0/16 range.
~~~
Now lets replace the 10.10.0.0/24 (in this sed command) with your lan address subnet.
<pre>
sed -i 's|192.168.0.0/16|<b>10.10.0.0/24</b>|g' etc.iptables.rules.v4
</pre>

We need the nordvpn IP address we're connecting to in our uk config file, so...
~~~
grep "^remote" /etc/openvpn/uk2161.conf | awk 'NR==1{print $2}'
~~~

Now use this ip to replace (10.10.0.0/32) with the ip address in the from the output above
<pre>
sed -i 's|123.123.123.123/32|<b>10.10.0.0/32</b>|g' etc.iptables.rules.v4
</pre>

rules should be good now, so copy them to the correct directory, correctly labelled.
~~~
cp etc.iptables.rules.v4 /etc/iptables/rules.v4
~~~

If we make these rules live, we can make them persistent afterwards, so, lets run the script provided and choose the
default N (or just press enter without typing anything).
WARNING - If your LAN address is wrong, this will lock you out of SSH
~~~
./ipRes.sh
~~~

Try pinging google
~~~
ping -c1 google.com
~~~

If the ping was successful install iptables-persistent & follow the screen prompt. It will ask to save your current iptables, and it should be fine to do so.
~~~
apt install iptables-persistent
~~~

If you are having difficulty connecting to the outside with your vpn, check your service. Replace uk2161 with the
server config you chose above.
Some commands to try below
~~~
systemctl status openvpn@uk2161.service
systemctl enable openvpn@uk2161.service
systemctl start openvpn@uk2161.service
~~~
If the service is active & enabled it's probably your firewall rules.
~~~
This will flush your rules.
iptables -F
~~~
Try ping now
~~~
ping -c1 google.com
~~~
If there are still issues after iptables flushed, then there's maybe a problem with the openvpn config/credentials, or nordvpn server, and the best i can offer at this point is to go through the start of this readme and try again, with another nordvpn server.
