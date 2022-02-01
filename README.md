# VPN-gateway

The purpose of these scripts is to connect devices on my LAN to a VPN gateway using wireguard.

Originally my plan was to set up a raspberry pi with open-wrt and connect the devices over wifi
with a stronger wifi dongle, but I couldn't resist exploring this option first.
I'm aware that I could use static ip gateway for something like this, but to keep things easier
to switch on and off (the wireguard client), I feel this is more user friendly than switching gateways.

The benefit of doing it this way, if we have a server running at home anyway, you don't need
additional hardware, just the wireguard client/server application. I've also got this running in an 
Ubuntu VM dedicated to serve only this function. I will be exploring the use of LXC containers
as well.

WARNING : 
This runs strictly iptables only, and doesn't take into account nftables or UFW.

So, a quick flow diagram....

Phone/pc device with wireguard client >> VPN Gateway, with wireguard server traffic coming in >> VPN gateway with NORD VPN traffic going out.

Why wireguard? I find the application fast and think it's brilliant. I regularly use this in cloud servers as well.

I've taken a collection of firewall rules gathered from sources on github, and would welcome any critique / additional rules. Since i'm a learning
Linux System Administrator, and Linux user since 2014, i don't have exposure to Enterprise firewall rules, but all in good time. The rules collected are all DROP/REJECT and i'll be honest, if you use my iptables rules, they never get touched. I suppose they might be more useful in a cloud VPS where there's
no hardware firewall between the server and internet.

############################################################################

So how it works.....

I am going to assume you have followed one of the many ways to set up your wireguard server and client. If you run into any difficulty, contact me
via github.

Log into your server and Switch user to root.
~~~
sudo su -
~~~
Install openvpn and unzip and change directories
~~~
apt-get install openvpn unzip
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
edit uk2161.nordvpn.com.udp.ovpn file
~~~
nano uk2161.nordvpn.com.udp.ovpn
~~~
We're looking for text containing "auth-user-pass" and replacing it with "auth-user-pass /etc/openvpn/auto-auth.txt" in this file uk2161.nordvpn.com.udp.ovpn
~~~
sed -i 's|auth-user-pass|auth-user-pass /etc/openvpn/auto-auth.txt|' uk2161.nordvpn.com.udp.ovpn
~~~
Enter your credentials into /etc/openvpn/auto-auth.txt i.e.
user
pass
and change the permissions so only root can read it.
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
~~~
ip a

2: ens18: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether b6:c5:18:78:ea:40 brd ff:ff:ff:ff:ff:ff
    **inet 192.168.2.10/24** brd 192.168.2.255 scope global ens18
       valid_lft forever preferred_lft forever
    inet6 fe80::b4c5:18ff:fe78:ea40/64 scope link 
       valid_lft forever preferred_lft forever
~~~
replace the second instance of 192.168.0.0/16 (in this sed command) with your lan address subnet.
<pre>
sed -i 's|-A INPUT -s 192.168.0.0/16 -i ens18 -j ACCEPT|-A INPUT -s <b>192.168.0.0/16</b> -i <b>ens18</b> -j ACCEPT|' etc.iptables.rules.v4
</pre>

Copy the rules to directory
~~~
cp etc.iptables.rules.v4 /etc/iptables/rules.v4
~~~

~~~

~~~
run the script provided and choose the default N (or just press enter without typing anything). This will restore IP tables
~~~
./ipRes.sh
~~~
