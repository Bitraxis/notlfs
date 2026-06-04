#!/bin/bash
set -e
echo "NotLFS Desktop (KDE Plasma) \r (\n)" > ${LFS}/etc/issue
echo "Kernel \r on an \m" >> ${LFS}/etc/issue
echo "notlfs-desktop" > ${LFS}/etc/hostname

cat > ${LFS}/etc/profile << 'PROFILE'
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
export PS1='\u@\h:\w\$ '
export EDITOR=kate
export DISPLAY=:0
export XAUTHORITY=/home/$(whoami)/.Xauthority
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
auto wlan0
iface wlan0 inet dhcp
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

mkdir -p ${LFS}/etc/X11/xorg.conf.d
cat > ${LFS}/etc/X11/xorg.conf.d/00-keyboard.conf << 'XORG'
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "us"
    Option "XkbModel" "pc105"
EndSection
XORG

mkdir -p ${LFS}/etc/sddm.conf.d
cat > ${LFS}/etc/sddm.conf.d/autologin.conf << 'SDDM'
[Autologin]
User=root
Session=plasma.desktop
SDDM

mkdir -p ${LFS}/etc/xdg
cat > ${LFS}/etc/xdg/kdeglobals << 'KDE'
[General]
Name=NotLFS
[KDE]
SingleClick=false
[General]
ColorSchemePath=breeze
IconThemePath=breeze
CursorTheme=breeze_cursors
FontPath=DejaVu Sans,10,-1,5,50,0,0,0,0,0
KDE

mkdir -p ${LFS}/etc/pulse
cat > ${LFS}/etc/pulse/daemon.conf << 'PULSE'
high-priority = yes
nice-level = -11
realtime-scheduling = yes
PULSE

mkdir -p ${LFS}/etc/asound.conf
cat > ${LFS}/etc/asound.conf << 'ALSA'
defaults.pcm.card 0
defaults.ctl.card 0
ALSA

cat > ${LFS}/etc/environment << 'ENV'
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
DISPLAY=:0
ENV

USERNAME="${USER_NAME:-user}"
USER_GROUPS="${USER_GROUPS:-wheel,audio,video,storage,kvm,input,render}"
if ! grep -q "^${USERNAME}:" ${LFS}/etc/passwd 2>/dev/null; then
    echo "${USERNAME}:x:1000:1000::/home/${USERNAME}:/bin/bash" >> ${LFS}/etc/passwd
    echo "${USERNAME}:x:1000:" >> ${LFS}/etc/shadow
    echo "${USERNAME}::1000:" >> ${LFS}/etc/group
    for group in $(echo "$USER_GROUPS" | tr ',' '\n'); do
        grep -q "^${group}:" ${LFS}/etc/group 2>/dev/null || echo "${group}:::" >> ${LFS}/etc/group
        echo "${USERNAME}::1000:${group}" >> ${LFS}/etc/group
    done
    mkdir -p ${LFS}/home/${USERNAME}
    chown 1000:1000 ${LFS}/home/${USERNAME}
    chmod 700 ${LFS}/home/${USERNAME}
    mkdir -p ${LFS}/home/${USERNAME}/.config ${LFS}/home/${USERNAME}/.local
    mkdir -p ${LFS}/home/${USERNAME}/Desktop ${LFS}/home/${USERNAME}/Documents
    mkdir -p ${LFS}/home/${USERNAME}/Downloads
    chown -R 1000:1000 ${LFS}/home/${USERNAME}
    echo "${USER_NAME}:${USER_PASSWORD:-changeme}" | chpasswd -R ${LFS}
fi

cat > ${LFS}/etc/sudoers << 'SUDO'
root ALL=(ALL:ALL) ALL
%wheel ALL=(ALL:ALL) ALL
SUDO
chmod 440 ${LFS}/etc/sudoers
