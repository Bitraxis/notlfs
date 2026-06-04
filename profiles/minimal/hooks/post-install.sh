#!/bin/bash
set -e
echo "NotLFS Minimal" > ${LFS}/etc/issue
echo "Kernel \r on an \m" >> ${LFS}/etc/issue
echo "notlfs-minimal" > ${LFS}/etc/hostname

cat > ${LFS}/etc/profile << 'PROFILE'
export PATH=/bin:/usr/bin:/sbin:/usr/sbin
export PS1='\u@\h:\w\$ '
PROFILE

cat > ${LFS}/etc/fstab << 'FSTAB'
proc /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
devpts /dev/pts devpts gid=5,mode=620 0 0
tmpfs /dev/shm tmpfs defaults 0 0
FSTAB

mkdir -p ${LFS}/etc/s6/current
mkdir -p ${LFS}/etc/s6/s6-svscan
cat > ${LFS}/etc/s6/s6-svscan/run << 'RUN'
#!/bin/sh
exec s6-svscan /etc/s6/current
RUN
chmod +x ${LFS}/etc/s6/s6-svscan/run
ln -sf /etc/s6/s6-svscan ${LFS}/etc/s6/current/s6-svscan
mkdir -p ${LFS}/run
ln -sf /bin/s6-svscan ${LFS}/sbin/init
