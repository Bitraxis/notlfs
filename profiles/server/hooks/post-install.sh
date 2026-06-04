#!/bin/bash
set -e
echo "NotLFS Server \r (\n)" > ${LFS}/etc/issue
echo "Kernel \r on an \m" >> ${LFS}/etc/issue
echo "notlfs-server" > ${LFS}/etc/hostname

cat > ${LFS}/etc/profile << 'PROFILE'
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
export PS1='\u@\h:\w\$ '
export EDITOR=vim
PROFILE

cat > ${LFS}/etc/fstab << 'FSTAB'
proc /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
devpts /dev/pts devpts gid=5,mode=620 0 0
tmpfs /dev/shm tmpfs defaults 0 0
FSTAB

mkdir -p ${LFS}/etc/network
cat > ${LFS}/etc/network/interfaces << 'INTERFACES'
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp
INTERFACES

cat > ${LFS}/etc/resolv.conf << 'RESOLV'
nameserver 8.8.8.8
nameserver 8.8.4.4
RESOLV

mkdir -p ${LFS}/etc/service
mkdir -p ${LFS}/var/log ${LFS}/var/cache ${LFS}/var/lib ${LFS}/var/run ${LFS}/tmp ${LFS}/home ${LFS}/root
chmod 1777 ${LFS}/tmp
chmod 700 ${LFS}/root

if [ -f ${LFS}/usr/share/zoneinfo/UTC ]; then
    ln -sf /usr/share/zoneinfo/UTC ${LFS}/etc/localtime
    echo "UTC" > ${LFS}/etc/timezone
fi

mkdir -p ${LFS}/etc/default
cat > ${LFS}/etc/default/locale << 'LOCALE'
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
LOCALE

mkdir -p ${LFS}/etc/ssh
cat > ${LFS}/etc/ssh/sshd_config << 'SSHD'
ListenAddress 0.0.0.0
Port 22
Protocol 2
PubkeyAuthentication yes
PasswordAuthentication yes
PermitRootLogin yes
PermitEmptyPasswords no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
LogLevel INFO
Subsystem sftp /usr/lib/ssh/sftp-server
UsePAM yes
SSHD
chmod 700 ${LFS}/etc/ssh

mkdir -p ${LFS}/etc/nginx
cat > ${LFS}/etc/nginx/nginx.conf << 'NGINX'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /var/run/nginx.pid;
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" \$status \$body_bytes_sent "\$http_referer" "\$http_user_agent" "\$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;
    sendfile on;
    keepalive_timeout 65;
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
    server {
        listen 80;
        server_name localhost;
        location / { root /usr/share/nginx/html; index index.html index.htm; }
        error_page 500 502 503 504 /50x.html;
        location = /50x.html { root /usr/share/nginx/html; }
    }
}
NGINX

mkdir -p ${LFS}/etc/nginx/conf.d ${LFS}/etc/nginx/sites-available ${LFS}/etc/nginx/sites-enabled
mkdir -p ${LFS}/usr/share/nginx/html
cat > ${LFS}/usr/share/nginx/html/index.html << 'HTML'
<!DOCTYPE html>
<html><head><title>NotLFS Server</title></head>
<body><h1>Welcome to NotLFS Server</h1><p>Your server is running successfully!</p></body>
</html>
HTML

mkdir -p ${LFS}/var/lib/postgresql ${LFS}/etc/postgresql
cat > ${LFS}/etc/postgresql/postgresql.conf << 'PGSQL'
data_directory = '/var/lib/postgresql/data'
listen_addresses = '*'
port = 5432
max_connections = 100
shared_buffers = 128MB
work_mem = 16MB
PGSQL
mkdir -p ${LFS}/var/lib/postgresql/data

mkdir -p ${LFS}/etc/samba
cat > ${LFS}/etc/samba/smb.conf << 'SAMBA'
[global]
    workgroup = WORKGROUP
    server string = NotLFS Server
    security = user
    map to guest = Bad User
[homes]
    browseable = no
    read only = no
    create mask = 0700
    directory mask = 0700
[public]
    path = /srv/samba/public
    browseable = yes
    read only = no
    guest ok = yes
SAMBA
mkdir -p ${LFS}/srv/samba/public
chmod 777 ${LFS}/srv/samba/public

mkdir -p ${LFS}/etc/postfix
cat > ${LFS}/etc/postfix/main.cf << 'POSTFIX'
myhostname = notlfs-server
mydomain = local
myorigin = \$myhostname
inet_interfaces = all
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
unknown_local_recipient_reject_code = 550
mynetworks = 127.0.0.0/8
mail_name = NotLFS Server
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
home_mailbox = Maildir/
POSTFIX

cat > ${LFS}/etc/aliases << 'ALIASES'
root: admin@localhost
postmaster: root
ALIASES

mkdir -p ${LFS}/etc/dnsmasq
cat > ${LFS}/etc/dnsmasq.conf << 'DNSMASQ'
listen-address=0.0.0.0
listen-address=127.0.0.1
server=8.8.8.8
server=8.8.4.4
log-queries
log-dhcp
DNSMASQ

mkdir -p ${LFS}/etc/chrony
cat > ${LFS}/etc/chrony.conf << 'CHRONY'
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst
server 3.pool.ntp.org iburst
driftfile /var/lib/chrony/chrony.drift
rtcsync
CHRONY
mkdir -p ${LFS}/var/lib/chrony

mkdir -p ${LFS}/etc/rsyslog.d
cat > ${LFS}/etc/rsyslog.conf << 'RSYSLOG'
module(load="imuxsock")
module(load="imklog")
*.* /var/log/syslog
kern.* /var/log/kern.log
auth,authpriv.* /var/log/auth.log
cron.* /var/log/cron.log
mail.* /var/log/mail.log
*.emerg :omusrmsg:*
*.* stop
RSYSLOG

mkdir -p ${LFS}/etc/fail2ban
cat > ${LFS}/etc/fail2ban/jail.local << 'FAIL2BAN'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
FAIL2BAN

mkdir -p ${LFS}/etc/logrotate.d
cat > ${LFS}/etc/logrotate.conf << 'LOGROTATE'
weekly
rotate 4
create
dateext
compress
delaycompress
notifempty
missingok
include /etc/logrotate.d
LOGROTATE

mkdir -p ${LFS}/etc/iptables
cat > ${LFS}/etc/iptables/rules.v4 << 'IPTABLES'
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p tcp --dport 22 -j ACCEPT
-A INPUT -p tcp --dport 80 -j ACCEPT
-A INPUT -p tcp --dport 443 -j ACCEPT
-A INPUT -p icmp --icmp-type echo-request -j ACCEPT
-A INPUT -j LOG --log-prefix "IPTables-Dropped: " --log-level 4
-A INPUT -j DROP
COMMIT
IPTABLES

cat > ${LFS}/usr/local/bin/iptables-restore.sh << 'RESTORE'
#!/bin/sh
iptables-restore < /etc/iptables/rules.v4
RESTORE
chmod +x ${LFS}/usr/local/bin/iptables-restore.sh
