# harden-focalfossa
Hardening and server deployment scripts for Ubuntu 20.04.5 LTS

The install.sh script is intended to harden, automate VMware template creation prep, net-tools install, and hardening for Ubuntu 20.04.5 This is intended for a freshly installed OS.

The harden.sh script is designed to (only) harden a fresh isntall of Ubuntu 20.04.5

> ⚠ Not recommended to execute these scripts on servers with existing firewall configurations.

# Getting Started
These scripts are designed to be executed on a freshly installed **Ubuntu Server 20.04** server. Run these from the working directory you wish to use on the local system.

## Hardening

```bash
sudo wget -O ./harden.sh https://raw.githubusercontent.com/daleatdizzion/harden-focalfossa/main/harden.sh && sudo chmod +x ./harden.sh && sudo ./harden.sh
```

# Hardening Notes
Firewall will only allow SSH access over port 22. All other connections are rejected.

# THE FOLLOWING NEEDS TO BE UPDATED

# What does it do?
The purpose of this script is to optimize and secure your system to run web applications. It does this by disabling unnecessary services, bootstrapping your firewall, secure your system settings and other things. Continue reading if you want to know exactly what's being executed.

#### update dependencies
```bash
apt-get install wget sed git -y
```

#### update system
Keeping the system updated is vital before starting anything on your system. This will prevent people to use known vulnerabilities to enter in your system.
```bash
apt-get update -y && apt-get full-upgrade -y
```

#### update ntp servers
```bash
truncate -s0 /etc/systemd/timesyncd.conf
echo "[Time]" | sudo tee -a /etc/systemd/timesyncd.conf
echo "NTP=pool.ntp.org" | sudo tee -a /etc/systemd/timesyncd.conf
echo "FallbackNTP=ntp.ubuntu.com" | sudo tee -a /etc/systemd/timesyncd.conf
```

#### update sysctl.conf
```bash
wget -q -c https://raw.githubusercontent.com/conduro/ubuntu/main/sysctl.conf -O /etc/sysctl.conf
```
```conf
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0 
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0 
net.ipv6.conf.default.accept_redirects = 0

# Ignore Directed pings
net.ipv4.icmp_echo_ignore_all = 1

# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# Hide kernel pointers
kernel.kptr_restrict = 2

# Enable panic on OOM
vm.panic_on_oom = 1

# Reboot kernel ten seconds after OOM
kernel.panic = 10
```

#### update sshd_config
```bash
wget -q -c https://raw.githubusercontent.com/conduro/ubuntu/main/sshd.conf -O /etc/ssh/sshd_config
```
```conf
# To disable tunneled clear text passwords, change to no here!
PasswordAuthentication yes

# Disable connection multiplexing which can be used to bypass authentication
MaxSessions 1

# Block client 10 minutes after 3 failed login attempts
MaxAuthTries 3
LoginGraceTime 10

# Do not allow empty passwords
PermitEmptyPasswords no

# Enable PAM authentication
UsePAM yes

# Disable Kerberos based authentication
KerberosAuthentication no
KerberosGetAFSToken no
KerberosOrLocalPasswd no
KerberosTicketCleanup yes
GSSAPIAuthentication no
GSSAPICleanupCredentials yes

# Disable user environment forwarding
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitUserRC no
PermitUserEnvironment no

# We want to log all activity
LogLevel INFO
SyslogFacility AUTHPRIV


#### configure firewall
```bash
ufw disable
echo "y" | sudo ufw reset
ufw logging off
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
sed -i "/ipv6=/Id" /etc/default/ufw
echo "IPV6=no" | sudo tee -a /etc/default/ufw

sed -i "/GRUB_CMDLINE_LINUX_DEFAULT=/Id" /etc/default/grub
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"ipv6.disable=1 quiet splash\"" | sudo tee -a /etc/default/grub
```

```

#### reload system
```bash
sysctl -p
update-grub2
systemctl restart systemd-timesyncd
ufw --force enable
service ssh restart
```
