#!/bin/bash
set -e
echo "NotLFS Base \r (\n)" > ${LFS}/etc/issue
echo "Kernel \r on an \m" >> ${LFS}/etc/issue
echo "notlfs-base" > ${LFS}/etc/hostname

cat > ${LFS}/etc/profile << 'PROFILE'
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
export PS1='\u@\h:\w\$ '
export EDITOR=vim
export PAGER=less
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
