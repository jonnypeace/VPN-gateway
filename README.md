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

- WIREGUARD

Log into your server and Switch user to root. install wireguard and change directory
~~~
sudo su -
apt install wireguard
cd /etc/wireguard/
~~~
Create keys
~~~
umask 077; wg genkey | tee privatekey | wg pubkey > publickey
~~~
Create new file..
~~~
nano /etc/wireguard/wg0.conf
~~~
Paste this into it
~~~
[Interface]
Address = 10.6.0.1/24
ListenPort = 51820
~~~
Below command will include the private key in the wgo.conf.
~~~
echo "PrivateKey = $(cat privatekey)" >> wg0.conf
~~~
We need to uncomment (#) this line in /etc/sysctl.conf and update systctl. No edit necessary
~~~
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p
~~~
By now, we can enable& start wireguard service.
~~~
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
systemctl status wg-quick@wg0
~~~
This is a script from my bashscripts repository, which will help us add new users. 
Also change permissions so the script can run.
~~~
wget https://raw.githubusercontent.com/jonnypeace/bashscripts/main/wireguardadduser.sh
chmod 700 wireguardadduser.sh 
~~~
In this script we can update our DNS to use NordVPN - this is client side only. No edit necessary
~~~
sed -i 's|DNS = 9.9.9.9|DNS = 103.86.96.100, 103.86.99.100|g' wireguardadduser.sh
~~~
To update the NordVPN dns on the server, i use netplan yaml to configure.
~~~
nano /etc/netplan/00-installer-config.yaml # (your yaml might be named differently)

Spacing is quite important in yaml, and it should look something like this. Update your gateway & addresses. Nameservers included here are of NordVPN.

# This is the network config written by 'subiquity'
network:
  ethernets:
    ens3:
      dhcp4: no
      addresses:
        - 192.168.1.111/24
      gateway4: 192.168.1.1
      nameservers:
          addresses: [103.86.96.100, 103.86.99.100]
  version: 2
~~~
apply the netplan config
~~~
netplan apply
~~~
Check the DNS has been applied
~~~
systemd-resolve --status | grep 'DNS Servers' -A1
~~~
Below should provide the ip address for wireguard client config.
~~~
ip route list default | cut -d " " -f9
~~~
if this doesn't work, try 
~~~
ip a
~~~
Replace "HOSTNAMEorIPofGATEWAY" with the IP above (the above ip is for home use, if you're using a VPS, it will be the hostname or public ip you use to SSH into the server)
~~~
sed -i "s|Endpoint = MYDNS.ORMY.IP|Endpoint = HOSTNAMEorIPofGATEWAY|g" wireguardadduser.sh 
~~~
This will add your public key to the client config, no edit necessary
~~~
sed -i "s|PublicKey = MYPUBKEY|PublicKey = $(cat publickey)|g" wireguardadduser.sh 
~~~

Ok, the script should be ready to run, just folllow the prompts.
~~~
./wireguardadduser.sh 
~~~
Now that the script has finished, we should see an entry in wg0.conf
~~~
cat /etc/wireguard/wg0.conf
~~~
And we should have a config for the client/desktop/mobile device.
~~~
cat /etc/wireguard/configs/NAMEofYOUR.conf
~~~
This .conf needs copied to the desktop or mobile device. You can copy/paste the contents if you have no other means of getting
the file off the server.

- OPENVPN

Install openvpn, unzip, net-tools and curl and change directories
~~~
apt install openvpn unzip net-tools git curl
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
<pre>
nano /etc/openvpn/auto-auth.txt

jonny
password123
</pre>
and change the permissions so only root can read it:
~~~
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
on boot, lets check our ip and country and see if our vpn has connected. If this hasn't worked, try again with another server (some of the sed commands will need modified, as the files will have changed from default, i.e. /etc/default/openvpn)
~~~
curl ifconfig.co ; curl ifconfig.co/city ; curl ifconfig.co/country
~~~

- FIREWALL RULES AND KILLSWITCH

Make sure your root
~~~
sudo su -
~~~
Lets clone this repo on the gateway, change directory, and provide necessary permissions for the scripts.
~~~
mkdir -p $HOME/git && cd $HOME/git
git clone https://github.com/jonnypeace/VPN-gateway.git && cd VPN-gateway
chmod 700 ipRes.sh openvpn.sh
~~~

I've put in some firewall rules that can be copied to /etc/iptables
This might not work well with UFW, i find it better to keep things simple and choose one over the other.
If you are using ufw, you might want to disable it, and flush the iptable rules, but for the purpose of this tutorial,
i'll assume fresh install of Ubuntu with ufw disabled (and never been run).

We'll need to edit the rules to match your system and not lock you out, so...
replace ens18 with your network interface, which can be found using...

<pre>
run this command:
    ip route list table main default

snippet of the output:
default via 192.168.1.1 dev <b>ens7</b> proto dhcp src <b>192.168.1.111</b> metric 100

if this doesn't work, use..
  ip a

snippet of ip a
2: <b>ens7</b>: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:12:34:56 brd ff:ff:ff:ff:ff:ff
    inet <b>192.168.1.111/24</b> brd 192.168.2.255 scope global ens7
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fe12:3456/64 scope link 
       valid_lft forever preferred_lft forever
</pre>

replace "EDITME" with the correct interface on your system.. i.e. the output from above command was ens7
<pre>
sed -i 's|ens18|<b>EDITME</b>|g' etc.iptables.rules.v4

If my interface is ens7
sed -i 's|ens18|<b>ens7|g' etc.iptables.rules.v4
</pre>

replace "EDITME" (in this sed command below) with your lan address subnet.
WARNING: This is important to get right, as this rule whitelists you from the firewall, and will allow SSH/wireguard access
SUBNET HELP: A subnet from the ip address identified from the command above (in bold), would equate to...
~~~
192.168.2.10/24 = 192.168.2.0/24 or 192.168.0.0/16 (/16 will provide more addresses than /24)

For a better understanding, maybe have a look here. https://www.cloudflare.com/en-gb/learning/network-layer/what-is-a-subnet/

Home lans usually fall somewhere in the 192.168.0.0/16 range.
~~~
Now lets replace the "EDITME" (in this sed command) with your lan address subnet. If you're happy with 192.168.0.0/16, then skip this part, as no sed edit will be necessary
<pre>
sed -i 's|192.168.0.0/16|<b>EDITME</b>|g' etc.iptables.rules.v4
</pre>

We need the nordvpn IP address we're connecting to in our uk config file, so...
~~~
grep "^remote" /etc/openvpn/uk2161.conf | awk 'NR==1{print $2}'
~~~

Now use this ip to replace "EDITME" 
<pre>
sed -i 's|123.123.123.123/32|<b>EDITME</b>|g' etc.iptables.rules.v4
</pre>

rules should be good now, so copy them to the correct directory, and correctly labelled.
~~~
mkdir -p /etc/iptables
cp etc.iptables.rules.v4 /etc/iptables/rules.v4
~~~

If we make these rules live, we can make them persistent afterwards, so, lets run the script provided and choose the
default N (or just press enter without typing anything).
WARNING - If your LAN address is wrong, this will lock you out of SSH
~~~
./ipRes.sh
~~~
Check rules are in place
~~~
iptables -vL --line-numbers
~~~

Try pinging google & checking our IP
~~~
ping -c1 google.com
curl ifconfig.co ; curl ifconfig.co/city ; curl ifconfig.co/country
~~~

If the ping was successful install iptables-persistent & follow the screen prompt. It will ask to save your current iptables, and it should be fine to do so.
~~~
apt install iptables-persistent
~~~

If you are having difficulty connecting to the outside with your vpn, check your systemctl service. Replace uk2161 with the
server config you chose above.
Some commands to try below
~~~
systemctl status openvpn@uk2161.service
systemctl enable openvpn@uk2161.service
systemctl start openvpn@uk2161.service
systemctl restart openvpn@uk2161.service
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
