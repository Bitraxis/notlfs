#!/bin/bash
# NotLFS Build Profiles
# This file creates the four build profiles for the NotLFS framework:
#   1. minimal   - Absolute minimal system with only essential packages
#   2. base      - Base system with development tools and networking
#   3. desktop   - Full desktop environment with KDE Plasma
#   4. server    - Server-oriented system with web and database services

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTLFS_ROOT="${NOTLFS_ROOT:-${SCRIPT_DIR}}"
PROFILES_DIR="${NOTLFS_ROOT}/profiles"
PACKAGES_DIR="${NOTLFS_ROOT}/packages"
CONFIG_DIR="${NOTLFS_ROOT}/configs"

mkdir -p "${PROFILES_DIR}" "${PACKAGES_DIR}" "${CONFIG_DIR}"

create_profile_directory() {
    local profile_name="$1"
    local profile_dir="${PROFILES_DIR}/${profile_name}"
    mkdir -p "${profile_dir}/services" "${profile_dir}/config" "${profile_dir}/hooks" "${profile_dir}/scripts"
}

create_minimal_profile() {
    local profile_name="minimal"
    local profile_dir="${PROFILES_DIR}/${profile_name}"
    create_profile_directory "$profile_name"

    cat > "${profile_dir}/profile.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<profile name="minimal">
    <description>Absolute minimal NotLFS system with only essential packages for a bootable Linux</description>
    <author>NotLFS Team</author>
    <version>1.0</version>
    <init_system>s6</init_system>
    <supported_init_systems>
        <init>s6</init>
        <init>s6-rc</init>
        <init>dinit</init>
        <init>runit</init>
        <init>sysv</init>
    </supported_init_systems>
    <packages>
        <include category="core" />
        <include category="init" />
        <package name="util-linux" enabled="true" />
        <package name="e2fsprogs" enabled="true" />
        <package name="iana-etc" enabled="true" />
        <package name="bash" enabled="true" />
        <package name="coreutils" enabled="true" />
        <package name="diffutils" enabled="true" />
        <package name="findutils" enabled="true" />
        <package name="gawk" enabled="true" />
        <package name="grep" enabled="true" />
        <package name="gzip" enabled="true" />
        <package name="sed" enabled="true" />
        <package name="tar" enabled="true" />
        <package name="xz" enabled="true" />
    </packages>
    <features>
        <feature name="minimal">true</feature>
        <feature name="network">false</feature>
        <feature name="development">false</feature>
        <feature name="desktop">false</feature>
        <feature name="server">false</feature>
        <feature name="hardening">true</feature>
        <feature name="strip_debug">true</feature>
    </features>
    <build>
        <optimization>-Os -pipe</optimization>
        <jobs>$(nproc)</jobs>
        <strip_debug>true</strip_debug>
        <keep_sources>false</keep_sources>
    </build>
    <security>
        <stack_protector>true</stack_protector>
        <fortify_source>true</fortify_source>
        <relro>true</relro>
        <aslr>true</aslr>
        <pie>true</pie>
    </security>
    <hooks>
        <hook stage="pre-toolchain">echo "Building minimal profile - optimizing for size"</hook>
        <hook stage="post-system">echo "NotLFS Minimal" > ${LFS}/etc/issue && echo "Kernel \r on an \m" >> ${LFS}/etc/issue</hook>
        <hook stage="post-install">echo "notlfs-minimal" > ${LFS}/etc/hostname</hook>
    </hooks>
</profile>
EOF

    cat > "${profile_dir}/packages.list" << 'EOF'
binutils
gcc
linux-headers
glibc
bash
coreutils
diffutils
file
findutils
gawk
grep
m4
make
patch
sed
tar
xz
util-linux
e2fsprogs
iana-etc
s6
EOF

    cat > "${profile_dir}/README.md" << 'EOF'
# NotLFS Minimal Profile
The Minimal profile provides the absolute bare essentials for a bootable Linux system.

## Features
- Smallest possible NotLFS installation
- Fast build time (30-60 minutes)
- Minimal disk footprint (300-500 MB)
- Security hardening enabled by default

## Use Cases
- Embedded systems
- Container images
- Rescue/recovery systems
- Custom builds with maximum control

## Default Init System
s6 - Minimalist supervision suite
Alternative: s6-rc, dinit, runit, sysv

## Build Configuration
./notlfs.sh -p minimal -i s6
./notlfs.sh -p minimal -i s6-rc
EOF

    mkdir -p "${profile_dir}/services/s6"
    cat > "${profile_dir}/services/s6/README.md" << 'EOF'
# Minimal Profile - s6 Service Definitions
Default services: s6-svscan, s6-rc-init (if using s6-rc)
EOF

    cat > "${profile_dir}/config/minimal.conf" << 'EOF'
BUILD_OPTIMIZATION="-Os -pipe"
STRIP_DEBUG="true"
KEEP_SOURCES="false"
HOSTNAME="notlfs-minimal"
INIT_SYSTEM="s6"
EOF

    cat > "${profile_dir}/hooks/pre-build.sh" << 'HOOK'
#!/bin/bash
set -e
export OPTIMIZATION="-Os -pipe"
export STRIP_DEBUG="true"
export DISABLE_NETWORK="true"
export HOSTNAME="notlfs-minimal"
HOOK
    chmod +x "${profile_dir}/hooks/pre-build.sh"

    cat > "${profile_dir}/hooks/post-install.sh" << 'HOOK'
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
HOOK
    chmod +x "${profile_dir}/hooks/post-install.sh"
}

create_base_profile() {
    local profile_name="base"
    local profile_dir="${PROFILES_DIR}/${profile_name}"
    create_profile_directory "$profile_name"

    cat > "${profile_dir}/profile.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<profile name="base">
    <description>Complete NotLFS system with development tools, networking, and essential utilities</description>
    <author>NotLFS Team</author>
    <version>1.0</version>
    <init_system>s6-rc</init_system>
    <supported_init_systems>
        <init>s6</init>
        <init>s6-rc</init>
        <init>dinit</init>
        <init>runit</init>
        <init>sysv</init>
        <init>systemd</init>
        <init>openrc</init>
    </supported_init_systems>
    <packages>
        <include category="core" />
        <include category="init" />
        <include category="dev" />
        <include category="utils" />
        <include category="network" />
        <include category="languages" />
        <package name="vim" enabled="true" />
        <package name="nano" enabled="true" />
        <package name="less" enabled="true" />
        <package name="man-db" enabled="true" />
        <package name="iproute2" enabled="true" />
        <package name="curl" enabled="true" />
        <package name="wget" enabled="true" />
        <package name="openssh" enabled="true" />
        <package name="procps" enabled="true" />
        <package name="htop" enabled="true" />
    </packages>
    <features>
        <feature name="minimal">false</feature>
        <feature name="network">true</feature>
        <feature name="development">true</feature>
        <feature name="desktop">false</feature>
        <feature name="server">false</feature>
        <feature name="hardening">true</feature>
        <feature name="strip_debug">false</feature>
        <feature name="documents">true</feature>
    </features>
    <build>
        <optimization>-O2 -pipe</optimization>
        <jobs>$(nproc)</jobs>
        <strip_debug>false</strip_debug>
        <keep_sources>false</keep_sources>
    </build>
    <network>
        <hostname>notlfs-base</hostname>
        <enable_dhcp>true</enable_dhcp>
        <nameservers>8.8.8.8 8.8.4.4</nameservers>
    </network>
</profile>
EOF

    cat > "${profile_dir}/packages.list" << 'EOF'
binutils
gcc
linux-headers
glibc
bash
coreutils
diffutils
findutils
gawk
grep
make
patch
sed
tar
xz
util-linux
e2fsprogs
vim
nano
less
man-db
iproute2
curl
wget
openssh
procps
htop
s6
s6-rc
skalibs
EOF

    cat > "${profile_dir}/README.md" << 'EOF'
# NotLFS Base Profile
The Base profile provides a complete Linux system with development tools and networking.

## Features
- Complete Linux system with all essential packages
- Full development toolchain
- Networking support
- Version control systems
- System monitoring tools
- Multiple programming languages
- Security hardening enabled
- Documentation included

## Use Cases
- Development workstations
- General-purpose servers
- Base for custom distributions

## Default Init System
s6-rc - Dependency-based service manager
Alternative: s6, dinit, runit, sysv, systemd, openrc

## Build Configuration
./notlfs.sh -p base
./notlfs.sh -p base -i runit
EOF

    mkdir -p "${profile_dir}/services/s6-rc"
    cat > "${profile_dir}/services/s6-rc/README.md" << 'EOF'
# Base Profile - s6-rc Service Definitions
Default services: s6-rc-init, s6-svscan, cronie, openssh
EOF

    cat > "${profile_dir}/config/base.conf" << 'EOF'
BUILD_OPTIMIZATION="-O2 -pipe"
STRIP_DEBUG="false"
HOSTNAME="notlfs-base"
INIT_SYSTEM="s6-rc"
ENABLE_NETWORK="true"
INSTALL_DOCS="true"
EOF

    cat > "${profile_dir}/hooks/pre-build.sh" << 'HOOK'
#!/bin/bash
set -e
export OPTIMIZATION="-O2 -pipe"
export INSTALL_DOCS="true"
export ENABLE_NETWORK="true"
export HOSTNAME="notlfs-base"
HOOK
    chmod +x "${profile_dir}/hooks/pre-build.sh"

    cat > "${profile_dir}/hooks/post-install.sh" << 'HOOK'
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
HOOK
    chmod +x "${profile_dir}/hooks/post-install.sh"
}

create_desktop_profile() {
    local profile_name="desktop"
    local profile_dir="${PROFILES_DIR}/${profile_name}"
    create_profile_directory "$profile_name"

    cat > "${profile_dir}/profile.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<profile name="desktop">
    <description>Full NotLFS desktop system with KDE Plasma, graphical applications, and multimedia support</description>
    <author>NotLFS Team</author>
    <version>1.0</version>
    <init_system>s6-rc</init_system>
    <supported_init_systems>
        <init>s6-rc</init>
        <init>systemd</init>
        <init>openrc</init>
        <init>runit</init>
    </supported_init_systems>
    <inherits>
        <profile>base</profile>
    </inherits>
    <packages>
        <include profile="base" />
        <include category="desktop" />
        <include category="graphics" />
        <package name="kf5-plasma" enabled="true" />
        <package name="kf5-plasma-desktop" enabled="true" />
        <package name="kf5-kwin" enabled="true" />
        <package name="kf5-kate" enabled="true" />
        <package name="kf5-konsole" enabled="true" />
        <package name="kf5-dolphin" enabled="true" />
        <package name="sddm" enabled="true" />
        <package name="mesa" enabled="true" />
        <package name="xorg-server" enabled="true" />
        <package name="pulseaudio" enabled="true" />
        <package name="alsa-lib" enabled="true" />
        <package name="alsa-utils" enabled="true" />
        <package name="ffmpeg" enabled="true" />
        <package name="mpv" enabled="true" />
        <package name="firefox" enabled="true" />
        <package name="networkmanager" enabled="true" />
        <package name="dbus" enabled="true" />
        <package name="elogind" enabled="true" />
        <package name="udisks2" enabled="true" />
        <package name="polkit" enabled="true" />
    </packages>
    <features>
        <feature name="minimal">false</feature>
        <feature name="network">true</feature>
        <feature name="development">true</feature>
        <feature name="desktop">true</feature>
        <feature name="server">false</feature>
        <feature name="hardening">true</feature>
        <feature name="gui">true</feature>
        <feature name="sound">true</feature>
        <feature name="video">true</feature>
    </features>
    <desktop>
        <environment>kde</environment>
        <display_manager>sddm</display_manager>
        <window_manager>kwin</window_manager>
        <wayland_support>true</wayland_support>
        <x11_support>true</x11_support>
    </desktop>
    <network>
        <hostname>notlfs-desktop</hostname>
        <enable_dhcp>true</enable_dhcp>
        <enable_wifi>true</enable_wifi>
        <enable_bluetooth>true</enable_bluetooth>
    </network>
</profile>
EOF

    cat > "${profile_dir}/packages.list" << 'EOF'
include base
mesa
xorg-server
xorg-apps
xorg-drivers
xorg-fonts
pulseaudio
alsa-lib
alsa-utils
ffmpeg
mpv
sddm
kf5-plasma
kf5-plasma-desktop
kf5-kwin
kf5-kate
kf5-konsole
kf5-dolphin
firefox
networkmanager
dbus
elogind
udisks2
polkit
EOF

    cat > "${profile_dir}/README.md" << 'EOF'
# NotLFS Desktop Profile (KDE Plasma)
The Desktop profile provides a full desktop environment with KDE Plasma.

## Features
- Full KDE Plasma desktop environment
- Complete graphics stack (X11 and Wayland)
- Audio support (PulseAudio + ALSA)
- Video playback (ffmpeg, mpv)
- Firefox web browser
- Network management
- Bluetooth support

## Use Cases
- Desktop workstations
- Development machines with GUI
- General-purpose desktop computers

## Default Init System
s6-rc - Dependency-based service manager
Recommended alternative: systemd for best desktop integration

## Build Configuration
./notlfs.sh -p desktop
./notlfs.sh -p desktop -i systemd

## Build Dependencies
Requires on host system:
- X11 development libraries
- Wayland development libraries
- Mesa development libraries
- Qt5 development libraries
- KDE Frameworks 5 development libraries
EOF

    mkdir -p "${profile_dir}/services/s6-rc"
    cat > "${profile_dir}/services/s6-rc/README.md" << 'EOF'
# Desktop Profile - s6-rc Service Definitions
Default services: dbus, elogind, udisks2, upower, polkit, networkmanager, sddm
EOF

    cat > "${profile_dir}/config/desktop.conf" << 'EOF'
BUILD_OPTIMIZATION="-O2 -pipe"
HOSTNAME="notlfs-desktop"
DESKTOP_ENVIRONMENT="kde"
DISPLAY_MANAGER="sddm"
ENABLE_GUI="true"
ENABLE_MULTIMEDIA="true"
EOF

    cat > "${profile_dir}/hooks/pre-build.sh" << 'HOOK'
#!/bin/bash
set -e
export OPTIMIZATION="-O2 -pipe"
export ENABLE_GUI="true"
export ENABLE_MULTIMEDIA="true"
export DESKTOP_ENVIRONMENT="kde"
export DISPLAY_MANAGER="sddm"
export HOSTNAME="notlfs-desktop"
HOOK
    chmod +x "${profile_dir}/hooks/pre-build.sh"

    cat > "${profile_dir}/hooks/post-install.sh" << 'HOOK'
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
HOOK
    chmod +x "${profile_dir}/hooks/post-install.sh"
}

create_server_profile() {
    local profile_name="server"
    local profile_dir="${PROFILES_DIR}/${profile_name}"
    create_profile_directory "$profile_name"

    cat > "${profile_dir}/profile.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<profile name="server">
    <description>Server-oriented NotLFS system with web server, database, and file services</description>
    <author>NotLFS Team</author>
    <version>1.0</version>
    <init_system>runit</init_system>
    <supported_init_systems>
        <init>runit</init>
        <init>s6-rc</init>
        <init>dinit</init>
        <init>sysv</init>
        <init>systemd</init>
        <init>openrc</init>
    </supported_init_systems>
    <inherits>
        <profile>base</profile>
    </inherits>
    <packages>
        <include profile="base" />
        <package name="nginx" enabled="true" />
        <package name="postgresql" enabled="true" />
        <package name="sqlite" enabled="true" />
        <package name="redis" enabled="true" />
        <package name="samba" enabled="true" />
        <package name="nfs-utils" enabled="true" />
        <package name="postfix" enabled="true" />
        <package name="dnsmasq" enabled="true" />
        <package name="fail2ban" enabled="true" />
        <package name="iptables" enabled="true" />
        <package name="chrony" enabled="true" />
        <package name="cronie" enabled="true" />
        <package name="rsyslog" enabled="true" />
        <package name="logrotate" enabled="true" />
        <package name="sysstat" enabled="true" />
    </packages>
    <features>
        <feature name="minimal">false</feature>
        <feature name="network">true</feature>
        <feature name="development">true</feature>
        <feature name="desktop">false</feature>
        <feature name="server">true</feature>
        <feature name="hardening">true</feature>
        <feature name="headless">true</feature>
    </features>
    <server>
        <type>web</type>
        <web_server>nginx</web_server>
        <database>postgresql</database>
        <file_server>samba</file_server>
        <mail_server>postfix</mail_server>
        <dns_server>dnsmasq</dns_server>
        <monitoring>sysstat</monitoring>
        <logging>rsyslog</logging>
        <security>fail2ban</security>
        <time_sync>chrony</time_sync>
        <cron>cronie</cron>
    </server>
    <build>
        <optimization>-O2 -pipe</optimization>
        <jobs>$(nproc)</jobs>
        <strip_debug>false</strip_debug>
        <keep_sources>false</keep_sources>
    </build>
    <network>
        <hostname>notlfs-server</hostname>
        <enable_dhcp>true</enable_dhcp>
        <enable_ipv6>true</enable_ipv6>
    </network>
</profile>
EOF

    cat > "${profile_dir}/packages.list" << 'EOF'
include base
nginx
postgresql
sqlite
redis
samba
nfs-utils
postfix
dnsmasq
fail2ban
iptables
chrony
cronie
rsyslog
logrotate
sysstat
EOF

    cat > "${profile_dir}/README.md" << 'EOF'
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
EOF

    mkdir -p "${profile_dir}/services/runit"
    cat > "${profile_dir}/services/runit/README.md" << 'EOF'
# Server Profile - runit Service Definitions
Default services: sshd, nginx, postgresql, redis, samba, nmbd, postfix, dnsmasq, chrony, cronie, rsyslog, fail2ban
EOF

    cat > "${profile_dir}/config/server.conf" << 'EOF'
BUILD_OPTIMIZATION="-O2 -pipe"
HOSTNAME="notlfs-server"
INIT_SYSTEM="runit"
ENABLE_NETWORK="true"
INSTALL_DOCS="false"
SERVER_TYPE="web"
WEB_SERVER="nginx"
DATABASE="postgresql"
EOF

    cat > "${profile_dir}/hooks/pre-build.sh" << 'HOOK'
#!/bin/bash
set -e
export OPTIMIZATION="-O2 -pipe"
export ENABLE_GUI="false"
export INSTALL_DOCS="false"
export SERVER_TYPE="web"
export HOSTNAME="notlfs-server"
HOOK
    chmod +x "${profile_dir}/hooks/pre-build.sh"

    cat > "${profile_dir}/hooks/post-install.sh" << 'HOOK'
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
HOOK
    chmod +x "${profile_dir}/hooks/post-install.sh"
}

main() {
    echo "============================================================================"
    echo "  NotLFS Profiles Creation"
    echo "============================================================================"
    
    create_minimal_profile
    create_base_profile
    create_desktop_profile
    create_server_profile
    
    cat > "${PROFILES_DIR}/README.md" << 'EOF'
# NotLFS Build Profiles

This directory contains the four build profiles for the NotLFS framework.

## Available Profiles

| Profile | Description | Init System | Build Time | Disk Space |
|---------|-------------|-------------|------------|------------|
| minimal | Absolute minimal system | s6 | 30-60 min | 300-500 MB |
| base | Complete system with dev tools | s6-rc | 2-4 hours | 1.5-2.5 GB |
| desktop | Full KDE Plasma desktop | s6-rc | 6-12 hours | 8-15 GB |
| server | Server with web, DB, file services | runit | 3-6 hours | 2-4 GB |

## Quick Start

Build with a profile:
  ./notlfs.sh -p minimal
  ./notlfs.sh -p base
  ./notlfs.sh -p desktop
  ./notlfs.sh -p server

Specify init system:
  ./notlfs.sh -p minimal -i s6-rc
  ./notlfs.sh -p desktop -i systemd
  ./notlfs.sh -p server -i runit
EOF

    echo "============================================================================"
    echo "  NotLFS Profiles Creation Complete"
    echo "============================================================================"
    echo "All four profiles created successfully:"
    echo "  - minimal   (${PROFILES_DIR}/minimal)"
    echo "  - base      (${PROFILES_DIR}/base)"
    echo "  - desktop   (${PROFILES_DIR}/desktop)"
    echo "  - server    (${PROFILES_DIR}/server)"
    echo ""
    echo "To use these profiles:"
    echo "  1. Source this file: source notlfs-profiles.sh"
    echo "  2. Or copy profile directories to ${PROFILES_DIR}"
    echo "  3. Use with: ./notlfs.sh -p <profile-name>"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi