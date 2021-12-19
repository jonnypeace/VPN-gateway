# VPN-gateway

The purpose of these scripts is to connect devices on my LAN to a VPN gateway using wireguard.

Originally my plan was to set up a raspberry pi with open-wrt and connect the devices over wifi
with a stronger wifi dongle, but thought about exploring this option first.

The benefit of doing it this way, if we have a server running at home anyway, you don't need
additional hardware, just the wireguard client/server application. I've also got this running in an 
Ubuntu VM dedicated to serve only this function. I will be exploring the use of LXC containers
as well.

WARNING : 
This runs strictly iptables only, and doesn't take into account nftables or UFW.

So, a quick flow diagram....

Phone/pc device with wireguard client >> VPN Gateway, with wireguard server traffic coming in >> VPN gateway with NORD VPN traffic going out.

Why wireguard? I find the application fast and think it's brilliant. I regularly use this in cloud servers as well.

The idea for the POSTUP and POSTDOWN wireguard scripts was taken from https://www.cyberciti.biz/faq/how-to-set-up-wireguard-firewall-rules-in-linux/

However, I've adapated it for forwarding traffic over VPN interfaces wg0 (wireguard) and tun0 (openvpn).

I've also taken a collection of firewall rules gathered from sources on github, and would welcome any critique / additional rules. Since i'm a learning
Linux System Administrator, and Linux user since 2014, i don't have exposure to Enterprise firewall rules, but all in good time. I have an idea how the TCP
handshakes work, and the rules collected are all DROP/REJECT, so should work well.

############################################################################

So how it works.....

I have the nord.sh script running in crontab as root. It checks for internet connectivity (ping), and if no connection is made to the outside world
then the script will run a set-up process. If you look in the script, it uses the exit code from the ping. If the ping fails the exit code will be 1
and if the exit code succeeds, the exit code will be 0. Look inside the script for an if statement for $?. You can switch this round, and may well
want to on initial set up, but before you do, we would want to have our POSTUP and POSTDOWN scripts ready.

I am going to assume you have followed one of the many ways to set up your wireguard server and client. If you run into any difficulty, contact me
via github.

Switch user to root.

sudo su -

Make a helper directory to store POSTUP and POSTDOWN scripts.

mkdir -p /etc/wireguard/helper

Open your wg0.conf

nano -il /etc/wireguard/wg0.conf

[Interface]

PostUp = /etc/wireguard/helper/add-nat-routing.sh

PreDown = /etc/wireguard/helper/remove-nat-routing.sh

Include these two lines under the interface section, no need to remove anything, just include those lines.

Copy the two scripts (add-nat-routing.sh & remove-nat-routing.sh) into the /etc/wireguard/helper directory.

Make the scripts executable..

chmod 700 /etc/wireguard/helper/add-nat-routing.sh /etc/wireguard/helper/remove-nat-routing.sh

Edit the scripts to suit your needs (ip ranges & interfaces) you are using in your wireguard client. 

....................................................................................................................................................

The nord.sh script.

I have this script located in the root home directory /root 
It will create a file called nord.log in /root which I set up to help troubleshooting. It's very basic, and i wanted to see how often
the connection would drop, but i find the ping keeps the connection alive, which leads me to believe that nordvpn must drop the connection
during a period of inactivity.

Create a crontab is optional, but helps keep the connection alive and reliable.

Switch to root user...
sudo su -

Move the nord.sh script to /root (or directory of choice)

Make nord.sh executable..
chmod 700 /root/nord.sh

Crontab (optional).
Create cron job...
crontab -e

add this to the bottom of the crontab     * * * * * /root/nord.sh

This will run every minute, but you could change it to every 5 mins etc    */5 * * * * /root/nord.sh

Ok, finally the nord.sh script and idea behind how all this works.

I am using the nordvpn application, which you can download from nordvpn if you use them. They have very good instructions. Follow everything
they do ensuring you also enable the service as well.

I have mine set up with killswitch on, and whitelisting my local network. There's a little bit of duplication in iptables with this, but necessary
so you don't lock yourself out by mistake. You could run this on openvpn, but this seems to work well.

The first time you run the script, nothing will happen if the script see's an internet connection. If you set the killswitch on....

nordvpn set killswitch on

The script will now work, once the ping fails.

To enable cybersec...
Run the script...  /root/nord.sh on

The script layout has a specific order it must follow to ensure the firwall rules work as intended. Once nordvpn connects, the wireguard service
is restarted to allow the firewall rules in the POSTUP & POSTDOWN scripts. If the wireguard service is not restarted, then nordvpn firewall rules will sit on top, and cancel out the wireguard rules (to an extent), but do not fear... the killswitch still works, as i've not modified the OUTPUT rules.

Happy VPN-Gatewaying :-)
