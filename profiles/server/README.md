# NotLFS Server Profile
The Server profile provides a server-oriented Linux system with web, database, and file services.

## Features
- Web Server: Nginx
- Database: PostgreSQL
- File Server: Samba and NFS
- Mail Server: Postfix
- DNS: dnsmasq
- Security: fail2ban, iptables
- Monitoring: sysstat
- Logging: rsyslog, logrotate
- Time Sync: chrony
- Cron: cronie
- SSH Server: OpenSSH
- Headless: No GUI by default

## Use Cases
- Web servers
- Database servers
- File servers
- Mail servers
- DNS servers
- Cloud instances
- Production servers

## Default Init System
runit - Lightweight, reliable, and simple
Alternative: s6-rc, dinit, sysv, systemd, openrc

## Build Configuration
./notlfs.sh -p server
./notlfs.sh -p server -i runit
./notlfs.sh -p server -i s6-rc
