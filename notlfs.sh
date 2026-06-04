#!/bin/bash
# =============================================================================
# NotLFS: A Modular Linux Build Framework with Multi-Init System Support
# =============================================================================
#
# NotLFS (Not Linux From Scratch) is an extensible framework for building
# a custom Linux system from source, inspired by LFS but with modern
# features and multi-init system support.
#
# Features:
#   - Multiple init system support (s6, s6-rc, dinit, runit, sysv, systemd)
#   - Modular package system with dependency resolution
#   - XML and YAML configuration support
#   - Auto, interactive, and manual build modes
#   - Smart build caching and resumption
#   - Service management configuration
#   - System hardening options
#   - Customizable build profiles
#
# USAGE:
#   ./notlfs.sh [OPTIONS] [COMMAND]
#
# COMMANDS:
#   build           - Start the build process (default)
#   config          - Generate/edit configuration
#   list-packages   - List available packages
#   list-profiles   - List available build profiles
#   add-package     - Add a new package definition
#   add-profile     - Add a new build profile
#   clean           - Clean build artifacts
#   shell           - Enter interactive build environment
#   init            - Initialize a new NotLFS project
#   export          - Export current configuration
#   validate        - Validate configuration and dependencies
#
# OPTIONS:
#   -c, --config FILE    Use specific configuration file
#   -p, --profile NAME    Use specific build profile
#   -m, --mode MODE       Build mode: auto|manual|interactive
#   -i, --init SYSTEM     Init system: s6, s6-rc, dinit, runit, sysv, systemd
#   -t, --target ARCH     Target architecture
#   -d, --debug           Enable debug output
#   -y, --yes             Skip confirmation prompts
#   -h, --help            Show this help
#
# EXAMPLES:
#   ./notlfs.sh -p minimal -i s6-rc
#   ./notlfs.sh --profile desktop --init runit --mode interactive
#   ./notlfs.sh list-profiles
#   ./notlfs.sh add-package neovim
#   ./notlfs.sh validate
#

set -o errexit
set -o nounset
set -o pipefail

# =============================================================================
# GLOBAL CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTLFS_ROOT="${SCRIPT_DIR}"
BUILD_ROOT="${NOTLFS_ROOT}/build"
CONFIG_DIR="${NOTLFS_ROOT}/configs"
PROFILES_DIR="${NOTLFS_ROOT}/profiles"
PACKAGES_DIR="${NOTLFS_ROOT}/packages"
INIT_DIR="${NOTLFS_ROOT}/init"
LOGS_DIR="${NOTLFS_ROOT}/logs"
SRC_DIR="${NOTLFS_ROOT}/sources"
TOOLS_DIR="${NOTLFS_ROOT}/tools"
CACHE_DIR="${NOTLFS_ROOT}/cache"
OUTPUT_DIR="${NOTLFS_ROOT}/output"

# Default values
CONFIG_FILE="${CONFIG_DIR}/notlfs.xml"
PROFILE=""
BUILD_MODE="interactive"
INIT_SYSTEM="s6-rc"  # Default to s6-rc as it's lightweight and modern
TARGET_ARCH="$(uname -m)"
DEBUG_MODE=false
YES_MODE=false
JOB_COUNT="$(nproc)"

# Supported init systems
SUPPORTED_INITS=("s6" "s6-rc" "s6-init" "dinit" "runit" "sysv" "systemd" "openrc")

# Supported architectures
SUPPORTED_ARCHS=("x86_64" "aarch64" "i386" "armv7l" "riscv64")

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if [ "$DEBUG_MODE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

log_section() {
    echo ""
    echo "============================================================================"
    echo "  $1"
    echo "============================================================================"
}

log_subsection() {
    echo ""
    echo "  --- $1 ---"
}

log_init() {
    echo -e "${CYAN}[INIT]${NC} $1"
}

# =============================================================================
# ERROR HANDLING
# =============================================================================

die() {
    log_error "$1"
    exit 1
}

assert_root() {
    if [ "$(id -u)" -ne 0 ]; then
        die "This operation requires root privileges. Please run with sudo or as root."
    fi
}

assert_command() {
    if ! command -v "$1" &> /dev/null; then
        die "Required command '$1' not found. Please install it."
    fi
}

assert_file() {
    if [ ! -f "$1" ]; then
        die "File not found: $1"
    fi
}

assert_dir() {
    if [ ! -d "$1" ]; then
        die "Directory not found: $1"
    fi
}

# =============================================================================
# DIRECTORY STRUCTURE SETUP
# =============================================================================

setup_directories() {
    log_section "Setting up NotLFS directory structure"
    
    local dirs=(
        "${BUILD_ROOT}"
        "${CONFIG_DIR}"
        "${PROFILES_DIR}"
        "${PACKAGES_DIR}"
        "${INIT_DIR}"
        "${LOGS_DIR}"
        "${SRC_DIR}"
        "${TOOLS_DIR}"
        "${CACHE_DIR}"
        "${OUTPUT_DIR}"
        "${BUILD_ROOT}/tools"
        "${BUILD_ROOT}/sources"
        "${BUILD_ROOT}/build"
        "${BUILD_ROOT}/pkg"
        "${BUILD_ROOT}/notlfs"
        "${INIT_DIR}/systems"
        "${INIT_DIR}/services"
        "${PROFILES_DIR}/base"
        "${PROFILES_DIR}/minimal"
        "${PROFILES_DIR}/desktop"
        "${PROFILES_DIR}/server"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        log_debug "Created directory: $dir"
    done
    
    # Create /tools symlink if not exists
    if [ ! -L "/tools" ] && [ ! -d "/tools" ]; then
        ln -s "${BUILD_ROOT}/tools" /tools 2>/dev/null || {
            mkdir -p /tools
        }
    fi
    
    log_info "Directory structure created at ${NOTLFS_ROOT}"
}

# =============================================================================
# INITIALIZATION
# =============================================================================

initialize() {
    log_section "Initializing NotLFS Framework"
    
    # Check if already initialized
    if [ -f "${NOTLFS_ROOT}/.notlfs-initialized" ]; then
        log_debug "NotLFS already initialized"
        return
    fi
    
    # Create directories
    setup_directories
    
    # Generate default configuration
    if [ ! -f "$CONFIG_FILE" ]; then
        generate_sample_config "$CONFIG_FILE"
    fi
    
    # Generate default profiles
    generate_default_profiles
    
    # Generate init system templates
    generate_init_templates
    
    # Create marker file
    touch "${NOTLFS_ROOT}/.notlfs-initialized"
    
    log_info "NotLFS initialization complete"
}

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

# Generate sample XML configuration
generate_sample_config() {
    local output_file="$1"
    
    cat > "$output_file" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!-- NotLFS Configuration File -->
<!-- This file defines your custom Linux system build -->

<notlfs>
    <!-- System Configuration -->
    <system>
        <name>notlfs-system</name>
        <architecture>x86_64</architecture>
        <jobs>4</jobs>
        <hostname>notlfs</hostname>
        <root_password>changeme</root_password>
        <timezone>UTC</timezone>
        <locale>en_US.UTF-8</locale>
        <kernel_version>6.6.0</kernel_version>
    </system>
    
    <!-- Build Settings -->
    <build>
        <mode>interactive</mode>
        <profile>minimal</profile>
        <init_system>s6-rc</init_system>
        <download_mirror>https://ftp.gnu.org/gnu</download_mirror>
        <optimization>-O2 -pipe</optimization>
        <strip_debug>false</strip_debug>
        <keep_sources>false</keep_sources>
        <parallel_downloads>4</parallel_downloads>
        <build_timeout>3600</build_timeout>
    </build>
    
    <!-- Security Hardening -->
    <security>
        <enable_hardening>true</enable_hardening>
        <stack_protector>true</stack_protector>
        <fortify_source>true</fortify_source>
        <relro>true</relro>
        <aslr>true</aslr>
        <noexec_stack>true</noexec_stack>
        <pie>true</pie>
    </security>
    
    <!-- Network Configuration -->
    <network>
        <hostname>notlfs</hostname>
        <domain>local</domain>
        <enable_dhcp>true</enable_dhcp>
        <nameservers>8.8.8.8 8.8.4.4</nameservers>
    </network>
    
    <!-- Package Selection -->
    <packages>
        <!-- Core System (required) -->
        <category name="core" enabled="true">
            <package name="binutils" enabled="true" />
            <package name="gcc" enabled="true" stage="1" />
            <package name="glibc" enabled="true" />
            <package name="bash" enabled="true" />
            <package name="coreutils" enabled="true" />
            <package name="diffutils" enabled="true" />
            <package name="file" enabled="true" />
            <package name="findutils" enabled="true" />
            <package name="gawk" enabled="true" />
            <package name="grep" enabled="true" />
            <package name="gzip" enabled="true" />
            <package name="m4" enabled="true" />
            <package name="make" enabled="true" />
            <package name="patch" enabled="true" />
            <package name="perl" enabled="true" />
            <package name="sed" enabled="true" />
            <package name="tar" enabled="true" />
            <package name="texinfo" enabled="true" />
            <package name="xz" enabled="true" />
            <package name="zlib" enabled="true" />
        </category>
        
        <!-- Init System -->
        <category name="init" enabled="true">
            <package name="s6" enabled="false" />
            <package name="s6-rc" enabled="true" />
            <package name="s6-init" enabled="false" />
            <package name="dinit" enabled="false" />
            <package name="runit" enabled="false" />
            <package name="sysv" enabled="false" />
            <package name="systemd" enabled="false" />
            <package name="openrc" enabled="false" />
        </category>
        
        <!-- Development Tools -->
        <category name="dev" enabled="true">
            <package name="autoconf" enabled="true" />
            <package name="automake" enabled="true" />
            <package name="bison" enabled="true" />
            <package name="flex" enabled="true" />
            <package name="git" enabled="true" />
            <package name="gperf" enabled="true" />
            <package name="libtool" enabled="true" />
            <package name="pkgconf" enabled="true" />
        </category>
        
        <!-- Utilities -->
        <category name="utils" enabled="true">
            <package name="curl" enabled="true" />
            <package name="wget" enabled="false" />
            <package name="less" enabled="true" />
            <package name="man-db" enabled="true" />
            <package name="vim" enabled="false" />
            <package name="nano" enabled="true" />
            <package name="tmux" enabled="false" />
            <package name="htop" enabled="false" />
        </category>
        
        <!-- Network -->
        <category name="network" enabled="true">
            <package name="openssl" enabled="true" />
            <package name="openssh" enabled="true" />
            <package name="iproute2" enabled="true" />
            <package name="iana-etc" enabled="true" />
            <package name="dhcpcd" enabled="false" />
            <package name="connman" enabled="false" />
        </category>
        
        <!-- Desktop (optional) -->
        <category name="desktop" enabled="false">
            <package name="mesa" enabled="true" />
            <package name="xorg-server" enabled="true" />
            <package name="xorg-apps" enabled="true" />
            <package name="wayland" enabled="false" />
            <package name="weston" enabled="false" />
            <package name="sway" enabled="false" />
        </category>
        
        <!-- Language Runtimes -->
        <category name="languages" enabled="true">
            <package name="python" enabled="true" />
            <package name="nodejs" enabled="false" />
            <package name="lua" enabled="false" />
            <package name="ruby" enabled="false" />
            <package name="go" enabled="false" />
            <package name="rust" enabled="false" />
        </category>
    </packages>
    
    <!-- Service Configuration -->
    <services>
        <service name="sshd" enabled="true" runlevel="default" />
        <service name="dhcpcd" enabled="false" runlevel="default" />
        <service name="cronie" enabled="false" runlevel="default" />
        <service name="ntpd" enabled="false" runlevel="default" />
    </services>
    
    <!-- Custom Commands (hooks) -->
    <hooks>
        <hook stage="pre-init">
            echo "NotLFS build started at $(date)"
        </hook>
        <hook stage="pre-toolchain">
            echo "Building temporary toolchain..."
        </hook>
        <hook stage="post-toolchain">
            echo "Toolchain build complete"
        </hook>
        <hook stage="pre-system">
            echo "Building base system..."
        </hook>
        <hook stage="post-system">
            echo "Base system build complete"
        </hook>
        <hook stage="pre-init-system">
            echo "Configuring init system: ${INIT_SYSTEM}"
        </hook>
        <hook stage="post-init-system">
            echo "Init system configured: ${INIT_SYSTEM}"
        </hook>
        <hook stage="pre-packages">
            echo "Installing additional packages..."
        </hook>
        <hook stage="post-install">
            echo "All packages installed successfully"
            echo "NotLFS build completed at $(date)"
        </hook>
    </hooks>
    
    <!-- Custom Environment Variables -->
    <environment>
        <variable name="CFLAGS">-O2 -pipe</variable>
        <variable name="CXXFLAGS">-O2 -pipe</variable>
        <variable name="LDFLAGS"></variable>
        <variable name="MAKEFLAGS">-j${JOB_COUNT}</variable>
    </environment>
</notlfs>
EOF
    
    log_info "Sample configuration generated at $output_file"
}

# Generate default build profiles
generate_default_profiles() {
    log_subsection "Generating default build profiles"
    
    # Minimal profile
    cat > "${PROFILES_DIR}/minimal/profile.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<profile name="minimal">
    <description>Minimal NotLFS system with essential packages only</description>
    <init_system>s6-rc</init_system>
    <packages>
        <include category="core" />
        <include category="init" />
        <package name="util-linux" />
        <package name="e2fsprogs" />
    </packages>
    <features>
        <feature name="minimal">true</feature>
        <feature name="network">false</feature>
        <feature name="development">false</feature>
    </features>
</profile>
EOF

    # Base profile
    cat > "${PROFILES_DIR}/base/profile.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<profile name="base">
    <description>Base NotLFS system with development tools and networking</description>
    <init_system>s6-rc</init_system>
    <packages>
        <include category="core" />
        <include category="init" />
        <include category="dev" />
        <include category="utils" />
        <include category="network" />
        <include category="languages" />
    </packages>
    <features>
        <feature name="minimal">false</feature>
        <feature name="network">true</feature>
        <feature name="development">true</feature>
    </features>
</profile>
EOF

    # Desktop profile
    cat > "${PROFILES_DIR}/desktop/profile.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<profile name="desktop">
    <description>Desktop-oriented NotLFS system with GUI support</description>
    <init_system>s6-rc</init_system>
    <packages>
        <include category="core" />
        <include category="init" />
        <include category="dev" />
        <include category="utils" />
        <include category="network" />
        <include category="desktop" />
        <include category="languages" />
        <package name="alsa-lib" />
        <package name="alsa-utils" />
        <package name="pulseaudio" />
        <package name="firefox" />
    </packages>
    <features>
        <feature name="minimal">false</feature>
        <feature name="network">true</feature>
        <feature name="development">true</feature>
        <feature name="gui">true</feature>
        <feature name="audio">true</feature>
    </features>
</profile>
EOF

    # Server profile
    cat > "${PROFILES_DIR}/server/profile.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<profile name="server">
    <description>Server-oriented NotLFS system with minimal GUI</description>
    <init_system>runit</init_system>
    <packages>
        <include category="core" />
        <include category="init" />
        <include category="dev" />
        <include category="utils" />
        <include category="network" />
        <package name="nginx" />
        <package name="postgresql" />
        <package name="redis" />
    </packages>
    <features>
        <feature name="minimal">false</feature>
        <feature name="network">true</feature>
        <feature name="development">true</feature>
        <feature name="server">true</feature>
    </features>
</profile>
EOF

    log_info "Generated default profiles: minimal, base, desktop, server"
}

# =============================================================================
# INIT SYSTEM TEMPLATES
# =============================================================================

generate_init_templates() {
    log_subsection "Generating init system templates"
    
    # Create init system directory structure
    for init in "${SUPPORTED_INITS[@]}"; do
        mkdir -p "${INIT_DIR}/systems/${init}"
        mkdir -p "${INIT_DIR}/services/${init}"
    done
    
    # s6 init system template
    cat > "${INIT_DIR}/systems/s6/install.sh" << 'EOF'
#!/bin/bash
# s6 init system installation

INSTALL_DIR="$1"

log_init "Installing s6 init system to ${INSTALL_DIR}"

# Create directory structure
mkdir -p "${INSTALL_DIR}/etc/s6"
mkdir -p "${INSTALL_DIR}/etc/s6/current"
mkdir -p "${INSTALL_DIR}/etc/s6/rc"

# Install s6
build_package s6

# Configure s6 as init
cat > "${INSTALL_DIR}/etc/s6/current/rc.init" << 'S6EOF'
#!/bin/sh
# s6 init script

exec s6-svscan /etc/s6/current
S6EOF

chmod +x "${INSTALL_DIR}/etc/s6/current/rc.init"

# Create symlink for init
ln -sf /etc/s6/current/rc.init "${INSTALL_DIR}/sbin/init"

log_init "s6 init system installed"
EOF

    # s6-rc init system template
    cat > "${INIT_DIR}/systems/s6-rc/install.sh" << 'EOF'
#!/bin/bash
# s6-rc init system installation

INSTALL_DIR="$1"

log_init "Installing s6-rc init system to ${INSTALL_DIR}"

# Create directory structure
mkdir -p "${INSTALL_DIR}/etc/s6-rc"
mkdir -p "${INSTALL_DIR}/etc/s6-rc/current"
mkdir -p "${INSTALL_DIR}/etc/s6-rc/rc"

# Install s6 and s6-rc
build_package s6
build_package s6-rc

# Configure s6-rc as init
cat > "${INSTALL_DIR}/etc/s6-rc/current/rc.init" << 'S6RCEOF'
#!/bin/sh
# s6-rc init script

exec s6-rc-init /etc/s6-rc/current default
S6RCEOF

chmod +x "${INSTALL_DIR}/etc/s6-rc/current/rc.init"

# Create symlink for init
ln -sf /etc/s6-rc/current/rc.init "${INSTALL_DIR}/sbin/init"

# Create default scan directory
mkdir -p "${INSTALL_DIR}/etc/s6-rc/rc.d"

log_init "s6-rc init system installed"
EOF

    # dinit init system template
    cat > "${INIT_DIR}/systems/dinit/install.sh" << 'EOF'
#!/bin/bash
# dinit init system installation

INSTALL_DIR="$1"

log_init "Installing dinit init system to ${INSTALL_DIR}"

# Install dinit
build_package dinit

# Configure dinit
mkdir -p "${INSTALL_DIR}/etc/dinit.d"

cat > "${INSTALL_DIR}/etc/dinit.conf" << 'DINITEOF'
# dinit configuration
DINIT_LOG_LEVEL=info
DINIT_SERVICE_DIR=/etc/dinit.d
DINITEOF

# Create init symlink
ln -sf /usr/bin/dinit "${INSTALL_DIR}/sbin/init"

log_init "dinit init system installed"
EOF

    # runit init system template
    cat > "${INIT_DIR}/systems/runit/install.sh" << 'EOF'
#!/bin/bash
# runit init system installation

INSTALL_DIR="$1"

log_init "Installing runit init system to ${INSTALL_DIR}"

# Install runit
build_package runit

# Configure runit
mkdir -p "${INSTALL_DIR}/etc/sv"
mkdir -p "${INSTALL_DIR}/etc/service"

cat > "${INSTALL_DIR}/etc/runit/1" << 'RUNITEOF'
#!/bin/sh
# runit stage 1

exec /usr/bin/runsvdir -P /etc/service default
RUNITEOF

chmod +x "${INSTALL_DIR}/etc/runit/1"

# Create init symlink
ln -sf /usr/bin/runit-init "${INSTALL_DIR}/sbin/init"

log_init "runit init system installed"
EOF

    # sysv init system template
    cat > "${INIT_DIR}/systems/sysv/install.sh" << 'EOF'
#!/bin/bash
# SysV init system installation

INSTALL_DIR="$1"

log_init "Installing SysV init system to ${INSTALL_DIR}"

# Install sysvinit
build_package sysvinit

# Configure SysV
mkdir -p "${INSTALL_DIR}/etc/rc.d"
mkdir -p "${INSTALL_DIR}/etc/init.d"

for level in 0 1 2 3 4 5 6; do
    mkdir -p "${INSTALL_DIR}/etc/rc${level}.d"
done

# Create basic rc files
cat > "${INSTALL_DIR}/etc/inittab" << 'SYSVEOF'
# /etc/inittab
::sysinit:/etc/init.d/rcS
::askfirst:/etc/init.d/rc
::ctrlaltdel:/sbin/reboot
::shutdown:/sbin/halt
SYSVEOF

# Create init symlink
ln -sf /sbin/init "${INSTALL_DIR}/sbin/init"

log_init "SysV init system installed"
EOF

    # systemd init system template
    cat > "${INIT_DIR}/systems/systemd/install.sh" << 'EOF'
#!/bin/bash
# systemd init system installation

INSTALL_DIR="$1"

log_init "Installing systemd init system to ${INSTALL_DIR}"

# Install systemd
build_package systemd

# Configure systemd
mkdir -p "${INSTALL_DIR}/etc/systemd/system"
mkdir -p "${INSTALL_DIR}/usr/lib/systemd/system"

# Enable basic services
ln -sf /usr/lib/systemd/system/multi-user.target "${INSTALL_DIR}/etc/systemd/system/default.target"

# Create init symlink
ln -sf /usr/lib/systemd/systemd "${INSTALL_DIR}/sbin/init"

log_init "systemd init system installed"
EOF

    # openrc init system template
    cat > "${INIT_DIR}/systems/openrc/install.sh" << 'EOF'
#!/bin/bash
# OpenRC init system installation

INSTALL_DIR="$1"

log_init "Installing OpenRC init system to ${INSTALL_DIR}"

# Install openrc
build_package openrc

# Configure OpenRC
mkdir -p "${INSTALL_DIR}/etc/runlevels"
mkdir -p "${INSTALL_DIR}/etc/init.d"

# Create basic runlevels
for level in boot sysinit; do
    mkdir -p "${INSTALL_DIR}/etc/runlevels/${level}"
done

# Create rc.conf
cat > "${INSTALL_DIR}/etc/rc.conf" << 'OPENRCEOF'
# OpenRC configuration
rc_sys="laptop"
rc_logger="yes"
rc_depend_strict="no"
OPENRCEOF

# Create init symlink
ln -sf /usr/sbin/openrc-init "${INSTALL_DIR}/sbin/init"

log_init "OpenRC init system installed"
EOF

    # Service templates for each init system
    for init in "${SUPPORTED_INITS[@]}"; do
        cat > "${INIT_DIR}/services/${init}/sshd" << EOF
# Service template for sshd on ${init}
# This is a placeholder - actual implementation depends on the init system
EOF
    done
    
    chmod +x "${INIT_DIR}"/systems/*/install.sh
    log_info "Generated init system templates for: ${SUPPORTED_INITS[*]}"
}

# Load configuration from XML file
load_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        die "Configuration file not found: $config_file"
    fi
    
    log_info "Loading configuration from $config_file"
    
    # Parse system configuration
    NOTLFS_NAME="$(parse_xml "$config_file" '//system/name/text()')" || NOTLFS_NAME="notlfs"
    TARGET_ARCH="$(parse_xml "$config_file" '//system/architecture/text()')" || TARGET_ARCH="x86_64"
    JOB_COUNT="$(parse_xml "$config_file" '//system/jobs/text()')" || JOB_COUNT="$(nproc)"
    HOSTNAME="$(parse_xml "$config_file" '//system/hostname/text()')" || HOSTNAME="notlfs"
    ROOT_PASSWORD="$(parse_xml "$config_file" '//system/root_password/text()')" || ROOT_PASSWORD="changeme"
    TIMEZONE="$(parse_xml "$config_file" '//system/timezone/text()')" || TIMEZONE="UTC"
    LOCALE="$(parse_xml "$config_file" '//system/locale/text()')" || LOCALE="en_US.UTF-8"
    KERNEL_VERSION="$(parse_xml "$config_file" '//system/kernel_version/text()')" || KERNEL_VERSION="6.6.0"
    
    # Parse build settings
    BUILD_MODE="$(parse_xml "$config_file" '//build/mode/text()')" || BUILD_MODE="interactive"
    PROFILE="$(parse_xml "$config_file" '//build/profile/text()')" || PROFILE=""
    INIT_SYSTEM="$(parse_xml "$config_file" '//build/init_system/text()')" || INIT_SYSTEM="s6-rc"
    DOWNLOAD_MIRROR="$(parse_xml "$config_file" '//build/download_mirror/text()')" || DOWNLOAD_MIRROR="https://ftp.gnu.org/gnu"
    OPTIMIZATION="$(parse_xml "$config_file" '//build/optimization/text()')" || OPTIMIZATION="-O2 -pipe"
    STRIP_DEBUG="$(parse_xml "$config_file" '//build/strip_debug/text()')" || STRIP_DEBUG="false"
    KEEP_SOURCES="$(parse_xml "$config_file" '//build/keep_sources/text()')" || KEEP_SOURCES="false"
    PARALLEL_DOWNLOADS="$(parse_xml "$config_file" '//build/parallel_downloads/text()')" || PARALLEL_DOWNLOADS="4"
    BUILD_TIMEOUT="$(parse_xml "$config_file" '//build/build_timeout/text()')" || BUILD_TIMEOUT="3600"
    
    # Parse security settings
    ENABLE_HARDENING="$(parse_xml "$config_file" '//security/enable_hardening/text()')" || ENABLE_HARDENING="true"
    STACK_PROTECTOR="$(parse_xml "$config_file" '//security/stack_protector/text()')" || STACK_PROTECTOR="true"
    FORTIFY_SOURCE="$(parse_xml "$config_file" '//security/fortify_source/text()')" || FORTIFY_SOURCE="true"
    RELRO="$(parse_xml "$config_file" '//security/relro/text()')" || RELRO="true"
    ASLR="$(parse_xml "$config_file" '//security/aslr/text()')" || ASLR="true"
    NOEXEC_STACK="$(parse_xml "$config_file" '//security/noexec_stack/text()')" || NOEXEC_STACK="true"
    PIE="$(parse_xml "$config_file" '//security/pie/text()')" || PIE="true"
    
    # Parse network settings
    NET_HOSTNAME="$(parse_xml "$config_file" '//network/hostname/text()')" || NET_HOSTNAME="$HOSTNAME"
    NET_DOMAIN="$(parse_xml "$config_file" '//network/domain/text()')" || NET_DOMAIN="local"
    ENABLE_DHCP="$(parse_xml "$config_file" '//network/enable_dhcp/text()')" || ENABLE_DHCP="true"
    NAMESERVERS="$(parse_xml "$config_file" '//network/nameservers/text()')" || NAMESERVERS="8.8.8.8 8.8.4.4"
    
    # Set LFS_TGT based on architecture
    case "$TARGET_ARCH" in
        x86_64)   LFS_TGT="x86_64-notlfs-linux-gnu" ;;
        aarch64)  LFS_TGT="aarch64-notlfs-linux-gnu" ;;
        i386)     LFS_TGT="i386-notlfs-linux-gnu" ;;
        armv7l)   LFS_TGT="armv7l-notlfs-linux-gnueabihf" ;;
        riscv64)  LFS_TGT="riscv64-notlfs-linux-gnu" ;;
        *)        LFS_TGT="${TARGET_ARCH}-notlfs-linux-gnu" ;;
    esac
    
    # Set environment variables
    export LFS="${BUILD_ROOT}/notlfs"
    export LFS_TGT
    export PATH="${LFS}/tools/bin:${PATH}"
    export MAKEFLAGS="-j${JOB_COUNT}"
    
    # Parse enabled packages
    PACKAGES_TO_BUILD=()
    local pkg_count=$(parse_xml "$config_file" "count(//packages//package[@enabled='true'])")
    
    for ((i=1; i<=pkg_count; i++)); do
        local pkg_name=$(parse_xml "$config_file" "//packages//package[@enabled='true'][$i]/@name")
        PACKAGES_TO_BUILD+=("$pkg_name")
    done
    
    # Parse services
    SERVICES_TO_ENABLE=()
    local svc_count=$(parse_xml "$config_file" "count(//services/service[@enabled='true'])")
    
    for ((i=1; i<=svc_count; i++)); do
        local svc_name=$(parse_xml "$config_file" "//services/service[@enabled='true'][$i]/@name")
        local svc_runlevel=$(parse_xml "$config_file" "//services/service[@enabled='true'][$i]/@runlevel")
        SERVICES_TO_ENABLE+=("${svc_name}:${svc_runlevel}")
    done
    
    # Parse environment variables
    ENV_VARIABLES=()
    local env_count=$(parse_xml "$config_file" "count(//environment/variable)")
    
    for ((i=1; i<=env_count; i++)); do
        local var_name=$(parse_xml "$config_file" "//environment/variable[$i]/@name")
        local var_value=$(parse_xml "$config_file" "//environment/variable[$i]/text()")
        export "$var_name=$var_value"
        ENV_VARIABLES+=("${var_name}=${var_value}")
    done
    
    # Set security-related compiler flags
    if [ "$ENABLE_HARDENING" = "true" ]; then
        export CFLAGS="${OPTIMIZATION}"
        export CXXFLAGS="${OPTIMIZATION}"
        
        [ "$STACK_PROTECTOR" = "true" ] && CFLAGS+=" -fstack-protector-strong" && CXXFLAGS+=" -fstack-protector-strong"
        [ "$FORTIFY_SOURCE" = "true" ] && CFLAGS+=" -D_FORTIFY_SOURCE=2" && CXXFLAGS+=" -D_FORTIFY_SOURCE=2"
        [ "$RELRO" = "true" ] && CFLAGS+=" -Wl,-z,now" && CXXFLAGS+=" -Wl,-z,now"
        [ "$ASLR" = "true" ] && export LDFLAGS="-Wl,-z,relro -Wl,-z,now"
        [ "$NOEXEC_STACK" = "true" ] && CFLAGS+=" -z noexecstack" && CXXFLAGS+=" -z noexecstack"
        [ "$PIE" = "true" ] && CFLAGS+=" -fPIE" && CXXFLAGS+=" -fPIE" && LDFLAGS+=" -pie"
    else
        export CFLAGS="${OPTIMIZATION}"
        export CXXFLAGS="${OPTIMIZATION}"
    fi
    
    log_info "Configuration loaded:"
    log_info "  System: ${NOTLFS_NAME} (${TARGET_ARCH})"
    log_info "  Init: ${INIT_SYSTEM}"
    log_info "  Mode: ${BUILD_MODE}"
    log_info "  Profile: ${PROFILE:-none}"
    log_info "  Packages: ${#PACKAGES_TO_BUILD[@]}"
    log_info "  Jobs: ${JOB_COUNT}"
}

# Simple XML parser using xmllint or fallback to grep/sed
parse_xml() {
    local file="$1"
    local xpath="$2"
    
    if command -v xmllint &> /dev/null; then
        xmllint --xpath "$xpath" "$file" 2>/dev/null | sed 's/<[^>]*>//g' | tr -d '[:space:]'
    else
        # Fallback: use grep and sed for simple parsing
        local result
        result=$(grep -oP "<[^>]*>${xpath#*/}<[^>]*>\K[^<]*" "$file" 2>/dev/null | head -1 | tr -d '[:space:]')
        echo "$result"
    fi
}

# Load profile configuration
load_profile() {
    local profile_name="$1"
    local profile_file="${PROFILES_DIR}/${profile_name}/profile.xml"
    
    if [ ! -f "$profile_file" ]; then
        die "Profile not found: $profile_name"
    fi
    
    log_info "Loading profile: $profile_name"
    
    # Parse profile
    PROFILE_INIT="$(parse_xml "$profile_file" '//profile/init_system/text()')"
    if [ -n "$PROFILE_INIT" ]; then
        INIT_SYSTEM="$PROFILE_INIT"
    fi
    
    # Parse included packages
    local include_count=$(parse_xml "$profile_file" "count(//profile/packages/include)")
    
    for ((i=1; i<=include_count; i++)); do
        local category=$(parse_xml "$profile_file" "//profile/packages/include[$i]/@category")
        
        # Enable all packages in this category
        local pkg_count=$(parse_xml "$CONFIG_FILE" "count(//packages/category[@name='${category}']//package)")
        
        for ((j=1; j<=pkg_count; j++)); do
            local pkg_name=$(parse_xml "$CONFIG_FILE" "//packages/category[@name='${category}']//package[$j]/@name")
            
            # Check if package is already in PACKAGES_TO_BUILD
            if ! [[ " ${PACKAGES_TO_BUILD[@]} " =~ " ${pkg_name} " ]]; then
                PACKAGES_TO_BUILD+=("$pkg_name")
            fi
        done
    done
    
    # Parse individual packages
    local pkg_count=$(parse_xml "$profile_file" "count(//profile/packages/package)")
    
    for ((i=1; i<=pkg_count; i++)); do
        local pkg_name=$(parse_xml "$profile_file" "//profile/packages/package[$i]/@name")
        
        if ! [[ " ${PACKAGES_TO_BUILD[@]} " =~ " ${pkg_name} " ]]; then
            PACKAGES_TO_BUILD+=("$pkg_name")
        fi
    done
    
    # Parse features
    local feature_count=$(parse_xml "$profile_file" "count(//profile/features/feature)")
    
    for ((i=1; i<=feature_count; i++)); do
        local feature_name=$(parse_xml "$profile_file" "//profile/features/feature[$i]/@name")
        local feature_value=$(parse_xml "$profile_file" "//profile/features/feature[$i]/text()")
        
        case "$feature_name" in
            minimal)     FEATURE_MINIMAL="$feature_value" ;;
            network)    FEATURE_NETWORK="$feature_value" ;;
            development) FEATURE_DEVELOPMENT="$feature_value" ;;
            gui)        FEATURE_GUI="$feature_value" ;;
            audio)      FEATURE_AUDIO="$feature_value" ;;
            server)     FEATURE_SERVER="$feature_value" ;;
        esac
    done
    
    log_info "Profile loaded: $profile_name (${#PACKAGES_TO_BUILD[@]} packages)"
}

# =============================================================================
# PACKAGE MANAGEMENT SYSTEM
# =============================================================================

# Package definition structure:
# Each package has a definition file in PACKAGES_DIR/<name>.pkg
# Format includes metadata, dependencies, and build functions

load_package() {
    local pkg_name="$1"
    local pkg_file="${PACKAGES_DIR}/${pkg_name}.pkg"
    
    if [ ! -f "$pkg_file" ]; then
        # Try to find package in subdirectories
        local found=0
        for dir in "${PACKAGES_DIR}"/*/; do
            if [ -f "${dir}${pkg_name}.pkg" ]; then
                pkg_file="${dir}${pkg_name}.pkg"
                found=1
                break
            fi
        done
        
        if [ $found -eq 0 ]; then
            die "Package definition not found: ${pkg_name}.pkg"
        fi
    fi
    
    # Source the package definition
    source "$pkg_file"
    
    # Validate required fields
    if [ -z "${NAME:-}" ] || [ -z "${VERSION:-}" ]; then
        die "Invalid package definition: missing required fields (NAME, VERSION) in $pkg_name"
    fi
    
    log_debug "Loaded package: ${NAME} ${VERSION}"
}

list_packages() {
    log_section "Available Packages"
    
    local categories=()
    local all_packages=()
    
    # Find all package files
    while IFS= read -r -d '' pkg_file; do
        local pkg_name=$(basename "$pkg_file" .pkg)
        local pkg_dir=$(dirname "$pkg_file")
        local category=$(basename "$pkg_dir")
        
        if [ "$category" = "packages" ]; then
            category="uncategorized"
        fi
        
        categories+=("$category")
        all_packages+=("${category}:${pkg_name}")
    done < <(find "$PACKAGES_DIR" -name '*.pkg' -print0)
    
    if [ ${#all_packages[@]} -eq 0 ]; then
        log_warn "No packages found in ${PACKAGES_DIR}"
        return
    fi
    
    # Get unique categories
    local unique_categories=()
    for cat in "${categories[@]}"; do
        if ! [[ " ${unique_categories[@]} " =~ " ${cat} " ]]; then
            unique_categories+=("$cat")
        fi
    done
    
    # Display packages by category
    for category in "${unique_categories[@]}"; do
        echo ""
        echo "  ${CYAN}${category}${NC}:"
        
        for pkg in "${all_packages[@]}"; do
            local pkg_category="${pkg%%:*}"
            local pkg_name="${pkg#*:}"
            
            if [ "$pkg_category" = "$category" ]; then
                source "${PACKAGES_DIR}/${pkg_category}/${pkg_name}.pkg" 2>/dev/null || \
                source "${PACKAGES_DIR}/${pkg_name}.pkg" 2>/dev/null
                
                local version="${VERSION:-unknown}"
                local description="${DESCRIPTION:-No description}"
                
                printf "    %-20s %s - %s\n" "$pkg_name" "$version" "$description"
            fi
        done
    done
    
    echo ""
    log_info "Found ${#all_packages[@]} packages in ${#unique_categories[@]} categories"
}

list_profiles() {
    log_section "Available Build Profiles"
    
    if [ ! -d "$PROFILES_DIR" ] || [ -z "$(ls -A "$PROFILES_DIR")" ]; then
        log_warn "No profiles found in ${PROFILES_DIR}"
        return
    fi
    
    local count=0
    for profile_dir in "${PROFILES_DIR}"/*/; do
        local profile_name=$(basename "$profile_dir")
        local profile_file="${profile_dir}profile.xml"
        
        if [ -f "$profile_file" ]; then
            local description=$(parse_xml "$profile_file" '//profile/description/text()')
            local init_system=$(parse_xml "$profile_file" '//profile/init_system/text()')
            local pkg_count=$(parse_xml "$profile_file" "count(//profile/packages//*)")
            
            printf "  %-15s %s\n" "$profile_name" "$description"
            printf "                Init: %s, Packages: ~%d\n" "$init_system" "$pkg_count"
            ((count++))
        fi
    done
    
    echo ""
    log_info "Found $count profiles"
}

# Create a new package definition template
create_package_template() {
    local pkg_name="$1"
    local category="${2:-uncategorized}"
    local pkg_dir="${PACKAGES_DIR}/${category}"
    local pkg_file="${pkg_dir}/${pkg_name}.pkg"
    
    if [ -f "$pkg_file" ]; then
        die "Package already exists: $pkg_name"
    fi
    
    mkdir -p "$pkg_dir"
    
    cat > "$pkg_file" << EOF
# Package: ${pkg_name}
# Description: 
# Maintainer: 
# Version: 0.0.1
# Category: ${category}
# Tags: 

NAME="${pkg_name}"
VERSION="0.0.1"
SOURCE=""
SOURCE_HASH=""
DESCRIPTION=""
HOMEPAGE=""
LICENSE=""

# Dependencies (space-separated list of package names)
DEPENDENCIES=""

# Build dependencies (tools needed to build this package)
BUILD_DEPENDENCIES=""

# Runtime dependencies (packages that depend on this one)
RDEPENDENCIES=""

# Conflicts (packages that cannot be installed with this one)
CONFLICTS=""

# Patches to apply (space-separated, relative to package directory)
PATCHES=""

# Build directory (relative to source)
BUILD_DIR=""

# Source subdirectory (if source is in a subdirectory of the archive)
SOURCE_SUBDIR=""

# Configuration options
CONFIG_OPTIONS="--prefix=/usr --sysconfdir=/etc --localstatedir=/var"

# Make options
MAKE_OPTIONS="-j\${JOB_COUNT}"

# Install options
INSTALL_OPTIONS=""

# Test suite command
TEST_COMMAND=""

# Service configuration (for init systems)
SERVICE_NAME=""
SERVICE_TYPE="simple"  # simple, fork, oneshot, etc.
SERVICE_DESCRIPTION=""
SERVICE_DEPENDENCIES=""
SERVICE_AFTER=""
SERVICE_BEFORE=""

# =============================================================================
# BUILD PHASE FUNCTIONS
# =============================================================================
#
# Override these functions for custom build steps.
# Each function receives the package name as \$1.
# The following variables are available:
#   \$NAME, \$VERSION, \$SOURCE, \$BUILD_DIR, \$CONFIG_OPTIONS, \$MAKE_OPTIONS
#   \$LFS (target system root), \$LFS_TGT (target tuple)
#   \$LOG_FILE (build log for this package)
#
# Return 0 on success, non-zero on failure.

# Called before downloading
pre_download() {
    return 0
}

# Called after downloading
post_download() {
    return 0
}

# Called before extraction
pre_extract() {
    log_info "Preparing to extract \${NAME} \${VERSION}"
    return 0
}

# Called after extraction
post_extract() {
    return 0
}

# Called before patching
pre_patch() {
    return 0
}

# Called after patching
post_patch() {
    return 0
}

# Called before configuration
pre_configure() {
    return 0
}

# Configure step
configure() {
    if [ -f "configure" ]; then
        log_info "Configuring \${NAME}"
        ./configure ${CONFIG_OPTIONS} 2>&1 | tee -a "\${LOG_FILE}"
    fi
    return 0
}

# Called after configuration
post_configure() {
    return 0
}

# Called before build
pre_build() {
    return 0
}

# Build step
build() {
    log_info "Building \${NAME}"
    make ${MAKE_OPTIONS} 2>&1 | tee -a "\${LOG_FILE}"
    return 0
}

# Called after build
post_build() {
    return 0
}

# Called before installation
pre_install() {
    return 0
}

# Install step
install() {
    log_info "Installing \${NAME}"
    make install ${INSTALL_OPTIONS} 2>&1 | tee -a "\${LOG_FILE}"
    return 0
}

# Called after installation
post_install() {
    return 0
}

# Called to run tests
test() {
    if [ -n "\$TEST_COMMAND" ]; then
        log_info "Running tests for \${NAME}"
        eval "\$TEST_COMMAND" 2>&1 | tee -a "\${LOG_FILE}"
    fi
    return 0
}

# =============================================================================
# INIT SYSTEM INTEGRATION
# =============================================================================
#
# These functions are called when configuring the init system.
# Override them to provide init system-specific service files.

# Generate service file for the current init system
# Arguments: \$1 = service name, \$2 = service configuration
init_generate_service() {
    local service_name="\$1"
    local service_config="\$2"
    
    case "\$INIT_SYSTEM" in
        s6|s6-rc)
            init_generate_s6_service "\$service_name" "\$service_config"
            ;;
        dinit)
            init_generate_dinit_service "\$service_name" "\$service_config"
            ;;
        runit)
            init_generate_runit_service "\$service_name" "\$service_config"
            ;;
        sysv)
            init_generate_sysv_service "\$service_name" "\$service_config"
            ;;
        systemd)
            init_generate_systemd_service "\$service_name" "\$service_config"
            ;;
        openrc)
            init_generate_openrc_service "\$service_name" "\$service_config"
            ;;
        *)
            log_warn "No service generator for init system: \$INIT_SYSTEM"
            ;;
    esac
    
    return 0
}

# s6 service generator
init_generate_s6_service() {
    local service_name="\$1"
    local service_config="\$2"
    
    mkdir -p "\${LFS}/etc/s6/${service_name}"
    
    cat > "\${LFS}/etc/s6/${service_name}/run" << EOF
#!/bin/sh
exec ${service_config:-/usr/bin/${service_name}} \$@
EOF
    
    chmod +x "\${LFS}/etc/s6/${service_name}/run"
    
    # Create finish script (optional)
    cat > "\${LFS}/etc/s6/${service_name}/finish" << 'EOF'
#!/bin/sh
exec s6-notifywhenup "\$1"
EOF
    
    chmod +x "\${LFS}/etc/s6/${service_name}/finish"
    
    # Link to current
    ln -sf "../${service_name}" "\${LFS}/etc/s6/current/${service_name}"
    
    return 0
}

# s6-rc service generator
init_generate_s6_rc_service() {
    local service_name="\$1"
    local service_config="\$2"
    
    mkdir -p "\${LFS}/etc/s6-rc/rc.d/${service_name}"
    
    cat > "\${LFS}/etc/s6-rc/rc.d/${service_name}/run" << EOF
#!/bin/sh
exec ${service_config:-/usr/bin/${service_name}} \$@
EOF
    
    chmod +x "\${LFS}/etc/s6-rc/rc.d/${service_name}/run"
    
    return 0
}

# dinit service generator
init_generate_dinit_service() {
    local service_name="\$1"
    local service_config="\$2"
    
    cat > "\${LFS}/etc/dinit.d/${service_name}" << EOF
# dinit service file for ${service_name}

${service_name} {
    type = ${SERVICE_TYPE:-simple}
    command = ${service_config:-/usr/bin/${service_name}}
    user = root
    group = root
    dependencies = ${SERVICE_DEPENDENCIES}
    after = ${SERVICE_AFTER}
    before = ${SERVICE_BEFORE}
    restart = true
    timeout = 30
}
EOF
    
    return 0
}

# runit service generator
init_generate_runit_service() {
    local service_name="\$1"
    local service_config="\$2"
    
    mkdir -p "\${LFS}/etc/sv/${service_name}/log"
    
    cat > "\${LFS}/etc/sv/${service_name}/run" << EOF
#!/bin/sh
exec ${service_config:-/usr/bin/${service_name}} \$@
EOF
    
    chmod +x "\${LFS}/etc/sv/${service_name}/run"
    
    # Create log run script
    cat > "\${LFS}/etc/sv/${service_name}/log/run" << 'EOF'
#!/bin/sh
exec logger -t \$0 -p daemon.info
EOF
    
    chmod +x "\${LFS}/etc/sv/${service_name}/log/run"
    
    # Link to service directory
    ln -sf "../sv/${service_name}" "\${LFS}/etc/service/${service_name}"
    
    return 0
}

# SysV service generator
init_generate_sysv_service() {
    local service_name="\$1"
    local service_config="\$2"
    
    cat > "\${LFS}/etc/init.d/${service_name}" << EOF
#!/bin/sh
# Init script for ${service_name}

### BEGIN INIT INFO
# Provides:          ${service_name}
# Required-Start:    \$local_fs \$remote_fs \$syslog
# Required-Stop:     \$local_fs \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ${SERVICE_DESCRIPTION:-${service_name} service}
### END INIT INFO

NAME="${service_name}"
DAEMON="${service_config:-/usr/bin/\${service_name}}"
PIDFILE="/var/run/\${NAME}.pid"

[ -x "\$DAEMON" ] || exit 0

case "\$1" in
    start)
        echo "Starting \$NAME..."
        start-stop-daemon --start --quiet --pidfile "\$PIDFILE" --exec "\$DAEMON" -- \$@
        ;;
    stop)
        echo "Stopping \$NAME..."
        start-stop-daemon --stop --quiet --pidfile "\$PIDFILE" --exec "\$DAEMON"
        ;;
    restart)
        \$0 stop
        sleep 1
        \$0 start
        ;;
    status)
        start-stop-daemon --status --pidfile "\$PIDFILE" --exec "\$DAEMON"
        ;;
    *)
        echo "Usage: /etc/init.d/\$NAME {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0
EOF
    
    chmod +x "\${LFS}/etc/init.d/${service_name}"
    
    # Enable in runlevels
    for level in 2 3 4 5; do
        ln -sf "../init.d/${service_name}" "\${LFS}/etc/rc${level}.d/S99${service_name}"
    done
    
    return 0
}

# systemd service generator
init_generate_systemd_service() {
    local service_name="\$1"
    local service_config="\$2"
    
    cat > "\${LFS}/usr/lib/systemd/system/${service_name}.service" << EOF
[Unit]
Description=${SERVICE_DESCRIPTION:-${service_name} service}
${SERVICE_AFTER:+After=${SERVICE_AFTER}}
${SERVICE_BEFORE:+Before=${SERVICE_BEFORE}}
${SERVICE_DEPENDENCIES:+Requires=${SERVICE_DEPENDENCIES}}

[Service]
Type=${SERVICE_TYPE:-simple}
ExecStart=${service_config:-/usr/bin/${service_name}}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable service
    ln -sf "../usr/lib/systemd/system/${service_name}.service" "\${LFS}/etc/systemd/system/multi-user.target.wants/${service_name}.service"
    
    return 0
}

# OpenRC service generator
init_generate_openrc_service() {
    local service_name="\$1"
    local service_config="\$2"
    
    cat > "\${LFS}/etc/init.d/${service_name}" << EOF
#!/sbin/openrc-run
# Distributed under the terms of the MIT License

name="${service_name}"
description="${SERVICE_DESCRIPTION:-${service_name} service}"
command="${service_config:-/usr/bin/\${service_name}}"
command_args="\$@"
pidfile="/run/\${service_name}.pid"
output_log="/var/log/\${service_name}.log"
error_log="/var/log/\${service_name}.err"

${SERVICE_DEPENDENCIES:+depend="\${SERVICE_DEPENDENCIES}"}

supervise_daemon_args="--stdout \${output_log} --stderr \${error_log}"
EOF
    
    chmod +x "\${LFS}/etc/init.d/${service_name}"
    
    # Enable in boot runlevel
    ln -sf "../init.d/${service_name}" "\${LFS}/etc/runlevels/boot/${service_name}"
    
    return 0
}

# =============================================================================
# DEPENDENCY RESOLUTION
# =============================================================================

# Resolve all dependencies for a package
resolve_dependencies() {
    local pkg_name="$1"
    local resolved=()
    local visited=()
    
    _resolve_deps "$pkg_name" resolved visited
    
    echo "${resolved[@]}"
}

_resolve_deps() {
    local pkg="$1"
    local -n _resolved="$2"
    local -n _visited="$3"
    
    # Check if already resolved or visited (circular dependency detection)
    if [[ " ${_resolved[@]} " =~ " ${pkg} " ]]; then
        return
    fi
    
    if [[ " ${_visited[@]} " =~ " ${pkg} " ]]; then
        die "Circular dependency detected involving package: $pkg"
    fi
    
    _visited+=("$pkg")
    
    # Load package definition
    load_package "$pkg" 2>/dev/null || return
    
    # Add build dependencies first
    if [ -n "$BUILD_DEPENDENCIES" ]; then
        for dep in $BUILD_DEPENDENCIES; do
            _resolve_deps "$dep" _resolved _visited
        done
    fi
    
    # Add regular dependencies
    if [ -n "$DEPENDENCIES" ]; then
        for dep in $DEPENDENCIES; do
            _resolve_deps "$dep" _resolved _visited
        done
    fi
    
    # Add the package itself
    _resolved+=("$pkg")
}

# Get all dependencies in build order (topological sort)
get_build_order() {
    local packages=("$@")
    local build_order=()
    local processed=()
    
    for pkg in "${packages[@]}"; do
        _get_build_order "$pkg" build_order processed
    done
    
    echo "${build_order[@]}"
}

_get_build_order() {
    local pkg="$1"
    local -n _build_order="$2"
    local -n _processed="$3"
    
    # Skip if already processed
    if [[ " ${_processed[@]} " =~ " ${pkg} " ]]; then
        return
    fi
    
    # Load package
    load_package "$pkg" 2>/dev/null || return
    
    # Process dependencies first
    if [ -n "$DEPENDENCIES" ]; then
        for dep in $DEPENDENCIES; do
            _get_build_order "$dep" _build_order _processed
        done
    fi
    
    if [ -n "$BUILD_DEPENDENCIES" ]; then
        for dep in $BUILD_DEPENDENCIES; do
            _get_build_order "$dep" _build_order _processed
        done
    fi
    
    # Add package to build order
    _build_order+=("$pkg")
    _processed+=("$pkg")
}

# =============================================================================
# DOWNLOAD MANAGEMENT
# =============================================================================

download_source() {
    local pkg_name="$1"
    
    load_package "$pkg_name"
    
    if [ -z "$SOURCE" ]; then
        log_warn "No source URL defined for package: $pkg_name"
        return 0
    fi
    
    local source_file="${SRC_DIR}/$(basename "$SOURCE")"
    local source_name=$(basename "$SOURCE")
    
    # Check cache first
    if [ -f "${CACHE_DIR}/${source_name}" ] && verify_source "${CACHE_DIR}/${source_name}"; then
        log_debug "Using cached source: ${source_name}"
        cp "${CACHE_DIR}/${source_name}" "$source_file"
        return 0
    fi
    
    # Check if already downloaded
    if [ -f "$source_file" ] && verify_source "$source_file"; then
        log_debug "Source already downloaded and verified: ${source_name}"
        return 0
    fi
    
    log_info "Downloading: $SOURCE"
    
    # Try curl first, then wget
    if command -v curl &> /dev/null; then
        if ! curl -L -o "$source_file" --connect-timeout 30 --retry 3 "$SOURCE" 2>&1 | tee -a "${LOGS_DIR}/download.log"; then
            rm -f "$source_file"
            die "Failed to download $SOURCE"
        fi
    elif command -v wget &> /dev/null; then
        if ! wget -O "$source_file" --timeout=30 --tries=3 "$SOURCE" 2>&1 | tee -a "${LOGS_DIR}/download.log"; then
            rm -f "$source_file"
            die "Failed to download $SOURCE"
        fi
    else
        die "Neither curl nor wget found. Please install one of them."
    fi
    
    # Verify hash
    if ! verify_source "$source_file"; then
        rm -f "$source_file"
        die "Hash verification failed for $SOURCE"
    fi
    
    # Cache the source
    if [ "$KEEP_SOURCES" = "true" ]; then
        cp "$source_file" "${CACHE_DIR}/${source_name}"
    fi
    
    log_info "Download complete: ${source_name}"
}

verify_source() {
    local source_file="$1"
    
    if [ ! -f "$source_file" ]; then
        return 1
    fi
    
    if [ -z "$SOURCE_HASH" ]; then
        log_warn "No hash specified for $SOURCE, skipping verification"
        return 0
    fi
    
    local hash_type="${SOURCE_HASH%%:*}"
    local expected_hash="${SOURCE_HASH#*:}"
    local actual_hash=""
    
    case "$hash_type" in
        sha256)
            actual_hash=$(sha256sum "$source_file" | cut -d' ' -f1)
            ;;
        sha512)
            actual_hash=$(sha512sum "$source_file" | cut -d' ' -f1)
            ;;
        md5)
            actual_hash=$(md5sum "$source_file" | cut -d' ' -f1)
            ;;
        *)
            die "Unsupported hash type: $hash_type"
            ;;
    esac
    
    if [ "$actual_hash" = "$expected_hash" ]; then
        return 0
    else
        log_error "Hash mismatch for $source_file"
        log_error "  Expected (${hash_type}): $expected_hash"
        log_error "  Actual (${hash_type}):   $actual_hash"
        return 1
    fi
}

# Parallel download function
download_sources_parallel() {
    local packages=("$@")
    local max_jobs="$PARALLEL_DOWNLOADS"
    local pids=()
    local index=0
    
    log_section "Downloading sources in parallel (max ${max_jobs} jobs)"
    
    for pkg in "${packages[@]}"; do
        download_source "$pkg" &
        pids+=($!)
        ((index++))
        
        # Wait if we have too many jobs running
        if [ $index -ge $max_jobs ]; then
            wait -n
            index=$((index - 1))
        fi
    done
    
    # Wait for all downloads to complete
    for pid in "${pids[@]}"; do
        wait "$pid" || return 1
    done
    
    log_info "All sources downloaded"
}

# =============================================================================
# EXTRACTION AND PATCHING
# =============================================================================

extract_source() {
    local pkg_name="$1"
    local force="${2:-false}"
    
    load_package "$pkg_name"
    
    local source_file="${SRC_DIR}/$(basename "$SOURCE")"
    local build_dir="${BUILD_ROOT}/build/${pkg_name}"
    local extract_dir="${BUILD_ROOT}/build/${pkg_name}-extract"
    
    # Clean up if force extraction
    if [ "$force" = "true" ]; then
        rm -rf "$build_dir" "$extract_dir"
    fi
    
    # Check if already extracted
    if [ -d "$build_dir" ] && [ "$force" = "false" ]; then
        log_debug "Source already extracted: $pkg_name"
        return 0
    fi
    
    # Create build directory
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"
    cd "$extract_dir" || die "Failed to enter extract directory"
    
    # Extract based on file type
    case "$source_file" in
        *.tar.gz|*.tgz)
            log_debug "Extracting .tar.gz: $source_file"
            tar -xzf "$source_file" --strip-components=1 || \
            tar -xzf "$source_file" || die "Failed to extract $source_file"
            ;;
        *.tar.bz2|*.tbz2)
            log_debug "Extracting .tar.bz2: $source_file"
            tar -xjf "$source_file" --strip-components=1 || \
            tar -xjf "$source_file" || die "Failed to extract $source_file"
            ;;
        *.tar.xz|*.txz)
            log_debug "Extracting .tar.xz: $source_file"
            tar -xJf "$source_file" --strip-components=1 || \
            tar -xJf "$source_file" || die "Failed to extract $source_file"
            ;;
        *.tar.zst)
            log_debug "Extracting .tar.zst: $source_file"
            if command -v zstd &> /dev/null; then
                zstd -d "$source_file" -o "${source_file%.zst}" && \
                tar -xf "${source_file%.zst}" --strip-components=1 || \
                tar -xf "${source_file%.zst}" || die "Failed to extract $source_file"
                rm -f "${source_file%.zst}"
            else
                die "zstd required to extract $source_file"
            fi
            ;;
        *.zip)
            log_debug "Extracting .zip: $source_file"
            unzip -q "$source_file" || die "Failed to extract $source_file"
            ;;
        *.7z)
            log_debug "Extracting .7z: $source_file"
            if command -v 7z &> /dev/null; then
                7z x "$source_file" -y || die "Failed to extract $source_file"
            else
                die "7z required to extract $source_file"
            fi
            ;;
        *)
            die "Unknown archive format: $source_file"
            ;;
    esac
    
    # Enter source subdirectory if specified
    if [ -n "$SOURCE_SUBDIR" ] && [ -d "$SOURCE_SUBDIR" ]; then
        cd "$SOURCE_SUBDIR" || die "Failed to enter source subdirectory: $SOURCE_SUBDIR"
    fi
    
    # Apply patches
    if [ -n "$PATCHES" ]; then
        log_debug "Applying patches for $pkg_name"
        local patch_dir
        if [ -d "${PACKAGES_DIR}/${pkg_name}" ]; then
            patch_dir="${PACKAGES_DIR}/${pkg_name}"
        else
            patch_dir="${PACKAGES_DIR}"
        fi
        
        for patch in $PATCHES; do
            local patch_file="${patch_dir}/${patch}"
            if [ -f "$patch_file" ]; then
                log_info "Applying patch: $patch"
                patch -p1 < "$patch_file" || die "Failed to apply patch $patch"
            else
                log_warn "Patch not found: $patch_file"
            fi
        done
    fi
    
    # Move to final build directory
    mkdir -p "$build_dir"
    
    # If there's a specific build directory, move there
    if [ -n "$BUILD_DIR" ] && [ -d "$BUILD_DIR" ]; then
        cd "$BUILD_DIR"
    fi
    
    # Copy extracted source to build directory
    if [ "$(pwd)" != "$build_dir" ]; then
        cp -a . "$build_dir/" || die "Failed to copy source to build directory"
        cd "$build_dir" || die "Failed to enter build directory"
    fi
    
    # Clean up extract directory
    rm -rf "$extract_dir"
    
    log_info "Source extracted to $build_dir"
}

# =============================================================================
# BUILD EXECUTION
# =============================================================================

# Check if a package is already built
is_package_built() {
    local pkg_name="$1"
    
    if [ -f "${LOGS_DIR}/${pkg_name}.success" ]; then
        return 0
    fi
    
    return 1
}

# Mark a package as built
mark_package_built() {
    local pkg_name="$1"
    touch "${LOGS_DIR}/${pkg_name}.success"
}

# Build a single package
build_package() {
    local pkg_name="$1"
    local log_file="${LOGS_DIR}/${pkg_name}.log"
    local skip_if_built="${2:-false}"
    
    # Check if already built
    if [ "$skip_if_built" = "true" ] && is_package_built "$pkg_name"; then
        log_debug "Package already built: $pkg_name"
        return 0
    fi
    
    # Create log file
    mkdir -p "$(dirname "$log_file")"
    touch "$log_file"
    
    log_section "Building package: $pkg_name"
    
    # Load package definition
    load_package "$pkg_name"
    
    # Set package-specific environment
    local pkg_cflags="$CFLAGS"
    local pkg_cxxflags="$CXXFLAGS"
    local pkg_ldflags="$LDFLAGS"
    
    # Allow package to override flags
    if [ -n "${PKG_CFLAGS:-}" ]; then
        pkg_cflags="$PKG_CFLAGS"
    fi
    if [ -n "${PKG_CXXFLAGS:-}" ]; then
        pkg_cxxflags="$PKG_CXXFLAGS"
    fi
    if [ -n "${PKG_LDFLAGS:-}" ]; then
        pkg_ldflags="$PKG_LDFLAGS"
    fi
    
    export CFLAGS="$pkg_cflags"
    export CXXFLAGS="$pkg_cxxflags"
    export LDFLAGS="$pkg_ldflags"
    
    # Download source
    if [ -n "$SOURCE" ]; then
        download_source "$pkg_name"
    fi
    
    # Extract source
    extract_source "$pkg_name"
    
    local build_dir="${BUILD_ROOT}/build/${pkg_name}"
    cd "$build_dir" || die "Failed to enter build directory for $pkg_name"
    
    # Execute build phases
    local build_phases=(
        "pre_download"
        "post_download"
        "pre_extract"
        "post_extract"
        "pre_patch"
        "post_patch"
        "pre_configure"
        "configure"
        "post_configure"
        "pre_build"
        "build"
        "post_build"
        "pre_install"
        "install"
        "post_install"
    )
    
    local phase_success=true
    for phase in "${build_phases[@]}"; do
        if declare -F "$phase" > /dev/null; then
            log_debug "Executing phase: $phase"
            if ! "$phase" "$pkg_name" >> "$log_file" 2>&1; then
                log_error "Failed at phase $phase for package $pkg_name"
                phase_success=false
                break
            fi
        fi
    done
    
    # Run tests if enabled and test command exists
    if [ "$phase_success" = true ] && [ -n "$TEST_COMMAND" ] && [ "${RUN_TESTS:-true}" = "true" ]; then
        if ! test "$pkg_name" >> "$log_file" 2>&1; then
            log_warn "Tests failed for package $pkg_name (continuing anyway)"
        fi
    fi
    
    if [ "$phase_success" = true ]; then
        mark_package_built "$pkg_name"
        log_info "Package built successfully: $pkg_name"
        return 0
    else
        die "Failed to build package: $pkg_name"
    fi
}

# =============================================================================
# BUILD PHASES (NotLFS-Style)
# =============================================================================

# Phase 1: Toolchain (Binutils, GCC Stage 1)
build_toolchain() {
    log_section "Phase 1: Building Temporary Toolchain"
    
    local toolchain_packages=(
        "binutils"
        "gcc:stage1"
        "glibc:headers"
        "glibc:final"
        "gcc:stage2"
    )
    
    for pkg_spec in "${toolchain_packages[@]}"; do
        local pkg_name="${pkg_spec%%:*}"
        local stage="${pkg_spec#*:}"
        
        # Set stage-specific environment
        case "$stage" in
            stage1)
                export CC="gcc -B/tools/bin/"
                export CXX="g++ -B/tools/bin/"
                ;;
            stage2)
                export CC="${LFS}/tools/bin/${LFS_TGT}-gcc"
                export CXX="${LFS}/tools/bin/${LFS_TGT}-g++"
                ;;
        esac
        
        build_package "$pkg_name"
    done
    
    log_info "Toolchain build complete"
}

# Phase 2: Base System
build_base_system() {
    log_section "Phase 2: Building Base System"
    
    # Get all packages in the core category
    local base_packages=()
    local pkg_count=$(parse_xml "$CONFIG_FILE" "count(//packages/category[@name='core']//package[@enabled='true'])")
    
    for ((i=1; i<=pkg_count; i++)); do
        local pkg_name=$(parse_xml "$CONFIG_FILE" "//packages/category[@name='core']//package[@enabled='true'][$i]/@name")
        base_packages+=("$pkg_name")
    done
    
    # Get build order with dependencies
    local build_order=($(get_build_order "${base_packages[@]}"))
    
    # Build packages in order
    for pkg in "${build_order[@]}"; do
        # Skip if already built (e.g., in toolchain)
        if is_package_built "$pkg"; then
            log_debug "Skipping already built package: $pkg"
            continue
        fi
        
        build_package "$pkg" true
    done
    
    log_info "Base system build complete"
}

# Phase 3: Init System
build_init_system() {
    log_section "Phase 3: Building and Configuring Init System"
    
    # Validate init system
    if ! [[ " ${SUPPORTED_INITS[@]} " =~ " ${INIT_SYSTEM} " ]]; then
        die "Unsupported init system: $INIT_SYSTEM. Supported: ${SUPPORTED_INITS[*]}"
    fi
    
    # Execute pre-init-system hooks
    execute_hooks "pre-init-system"
    
    # Build the init system package
    build_package "$INIT_SYSTEM"
    
    # Run init system installation script
    local init_install_script="${INIT_DIR}/systems/${INIT_SYSTEM}/install.sh"
    
    if [ -f "$init_install_script" ]; then
        log_info "Running init system installation: $INIT_SYSTEM"
        if ! bash "$init_install_script" "$LFS" >> "${LOGS_DIR}/init-system.log" 2>&1; then
            die "Failed to install init system: $INIT_SYSTEM"
        fi
    else
        die "No installation script for init system: $INIT_SYSTEM"
    fi
    
    # Configure services
    configure_services
    
    # Execute post-init-system hooks
    execute_hooks "post-init-system"
    
    log_info "Init system configured: $INIT_SYSTEM"
}

# Configure services for the selected init system
configure_services() {
    log_subsection "Configuring services for ${INIT_SYSTEM}"
    
    for service_spec in "${SERVICES_TO_ENABLE[@]}"; do
        local service_name="${service_spec%%:*}"
        local service_runlevel="${service_spec#*:}"
        
        log_info "Enabling service: $service_name (runlevel: $service_runlevel)"
        
        # Generate service file based on init system
        init_generate_service "$service_name" ""
        
        # Enable the service
        case "$INIT_SYSTEM" in
            s6-rc)
                # For s6-rc, services are enabled by default when linked to current
                ;;
            dinit)
                # dinit services are enabled by default
                ;;
            runit)
                # runit services are enabled by symlinking to /etc/service
                ;;
            sysv)
                # For sysv, enable in the specified runlevel
                if [ -n "$service_runlevel" ]; then
                    ln -sf "../init.d/${service_name}" "${LFS}/etc/rc${service_runlevel}.d/S99${service_name}"
                fi
                ;;
            systemd)
                # For systemd, enable the service
                ln -sf "../usr/lib/systemd/system/${service_name}.service" \
                    "${LFS}/etc/systemd/system/multi-user.target.wants/${service_name}.service"
                ;;
            openrc)
                # For openrc, add to runlevel
                if [ -n "$service_runlevel" ]; then
                    ln -sf "../init.d/${service_name}" "${LFS}/etc/runlevels/${service_runlevel}/${service_name}"
                fi
                ;;
        esac
    done
    
    log_info "Services configured"
}

# Phase 4: Custom Packages
build_custom_packages() {
    log_section "Phase 4: Building Custom Packages"
    
    if [ ${#PACKAGES_TO_BUILD[@]} -eq 0 ]; then
        log_info "No custom packages to build"
        return
    fi
    
    # Get build order with dependencies
    local build_order=($(get_build_order "${PACKAGES_TO_BUILD[@]}"))
    
    # Filter out packages already built
    local packages_to_build=()
    for pkg in "${build_order[@]}"; do
        if ! is_package_built "$pkg"; then
            packages_to_build+=("$pkg")
        fi
    done
    
    if [ ${#packages_to_build[@]} -eq 0 ]; then
        log_info "All custom packages already built"
        return
    fi
    
    # Build packages in order
    for pkg in "${packages_to_build[@]}"; do
        build_package "$pkg" true
    done
    
    log_info "Custom packages build complete"
}

# Phase 5: Final System Configuration
configure_system() {
    log_section "Phase 5: Final System Configuration"
    
    # Execute pre-system-config hooks
    execute_hooks "pre-system-config"
    
    # Set up basic system files
    setup_system_files
    
    # Set up network configuration
    setup_network
    
    # Set up user accounts
    setup_users
    
    # Set up locale and timezone
    setup_locale
    
    # Set up kernel
    setup_kernel
    
    # Execute post-system-config hooks
    execute_hooks "post-system-config"
    
    log_info "System configuration complete"
}

setup_system_files() {
    log_subsection "Setting up system files"
    
    # Create essential directories
    local essential_dirs=(
        "bin" "sbin" "lib" "lib64" "usr/bin" "usr/sbin" "usr/lib" "usr/lib64"
        "usr/local/bin" "usr/local/sbin" "usr/local/lib" "usr/include"
        "etc" "var" "var/log" "var/cache" "var/lib" "var/run" "var/tmp"
        "tmp" "home" "root" "opt" "srv" "media" "mnt"
        "proc" "sys" "dev" "run"
    )
    
    for dir in "${essential_dirs[@]}"; do
        mkdir -p "${LFS}/${dir}"
    done
    
    # Create symlinks
    ln -sf "usr/bin" "${LFS}/bin"
    ln -sf "usr/sbin" "${LFS}/sbin"
    ln -sf "usr/lib" "${LFS}/lib"
    ln -sf "usr/lib64" "${LFS}/lib64" 2>/dev/null || true
    
    # Create /var/run symlink
    ln -sf "../run" "${LFS}/var/run"
    
    # Create /var/lock symlink
    ln -sf "../run/lock" "${LFS}/var/lock"
    
    # Create /etc/mtab symlink
    ln -sf "/proc/self/mounts" "${LFS}/etc/mtab"
    
    # Create fstab
    cat > "${LFS}/etc/fstab" << 'EOF'
# /etc/fstab
# <device> <mount> <type> <options> <dump> <pass>
proc /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
devpts /dev/pts devpts gid=5,mode=620 0 0
tmpfs /run tmpfs defaults,nosuid,nodev,mode=0755 0 0
tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0
EOF
    
    # Create passwd, group, shadow
    cat > "${LFS}/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/bash
nobody:*:65534:65534:Nobody:/:/bin/false
EOF
    
    cat > "${LFS}/etc/group" << 'EOF'
root:x:0:
wheel:x:10:
users:x:100:
nobody:x:65534:
EOF
    
    cat > "${LFS}/etc/shadow" << 'EOF'
root:*:19453:0:99999:7:::
EOF
    
    # Set root password
    if [ -n "$ROOT_PASSWORD" ]; then
        local hashed_password
        hashed_password=$(openssl passwd -6 "$ROOT_PASSWORD" 2>/dev/null || \
                         python3 -c "import crypt; print(crypt.crypt('${ROOT_PASSWORD}', crypt.mksalt(crypt.METHOD_SHA512)))" 2>/dev/null || \
                         echo "x")
        
        if [ "$hashed_password" != "x" ]; then
            sed -i "s|^root:.*|root:${hashed_password}:19453:0:99999:7:::|" "${LFS}/etc/shadow"
        else
            log_warn "Could not hash root password. Password will need to be set manually."
        fi
    fi
    
    # Create shells file
    cat > "${LFS}/etc/shells" << 'EOF'
/bin/bash
/bin/sh
EOF
    
    # Create profile
    cat > "${LFS}/etc/profile" << 'EOF'
# /etc/profile

# System-wide environment
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export PATH

# User-specific environment
for file in /etc/profile.d/*.sh; do
    [ -r "$file" ] && . "$file"
done

unset file
EOF
    
    # Create bashrc
    cat > "${LFS}/etc/bashrc" << 'EOF'
# /etc/bashrc

# System-wide bash configuration
PS1='\u@\h:\w\$ '
umask 022
EOF
    
    # Create inputrc
    cat > "${LFS}/etc/inputrc" << 'EOF'
# /etc/inputrc

# Set editing mode
set editing-mode vi

# Disable bell
set bell-style none

# Tab completion
TAB: menu-complete
EOF
    
    log_info "System files created"
}

setup_network() {
    log_subsection "Setting up network configuration"
    
    # Create hosts file
    cat > "${LFS}/etc/hosts" << EOF
127.0.0.1 localhost
127.0.1.1 ${NET_HOSTNAME}.${NET_DOMAIN} ${NET_HOSTNAME}
::1 localhost ip6-localhost ip6-loopback
EOF
    
    # Create hostname file
    echo "${NET_HOSTNAME}" > "${LFS}/etc/hostname"
    
    # Create resolv.conf
    echo "# Generated by NotLFS" > "${LFS}/etc/resolv.conf"
    for ns in $NAMESERVERS; do
        echo "nameserver $ns" >> "${LFS}/etc/resolv.conf"
    done
    
    # Create nsswitch.conf
    cat > "${LFS}/etc/nsswitch.conf" << 'EOF'
# /etc/nsswitch.conf

passwd: files
shadow: files
group: files

hosts: files dns
networks: files dns

protocols: files
services: files
ethers: files
rpc: files
EOF
    
    log_info "Network configuration created"
}

setup_users() {
    log_subsection "Setting up user accounts"
    
    # Create root home directory
    mkdir -p "${LFS}/root"
    chmod 700 "${LFS}/root"
    
    # Create .bashrc for root
    cat > "${LFS}/root/.bashrc" << 'EOF'
# Root user bashrc
PS1='\u@\h:\w\# '
EOF
    
    # Create .profile for root
    cat > "${LFS}/root/.profile" << 'EOF'
# Root user profile
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export PATH
EOF
    
    log_info "User accounts configured"
}

setup_locale() {
    log_subsection "Setting up locale and timezone"
    
    # Create locale.conf
    echo "LANG=${LOCALE}" > "${LFS}/etc/locale.conf"
    echo "LC_ALL=${LOCALE}" >> "${LFS}/etc/locale.conf"
    
    # Create timezone symlink
    if [ -d "${LFS}/usr/share/zoneinfo" ]; then
        ln -sf "/usr/share/zoneinfo/${TIMEZONE}" "${LFS}/etc/localtime"
    fi
    
    log_info "Locale and timezone configured"
}

setup_kernel() {
    log_subsection "Setting up kernel configuration"
    
    # Create kernel command line (for bootloader)
    local kernel_cmdline="root=/dev/sda1 ro console=ttyS0,115200n8"
    
    # For different init systems
    case "$INIT_SYSTEM" in
        s6|s6-rc|s6-init)
            kernel_cmdline+=" init=/etc/s6/current/rc.init"
            ;;
        dinit)
            kernel_cmdline+=" init=/usr/bin/dinit"
            ;;
        runit)
            kernel_cmdline+=" init=/usr/sbin/runit-init"
            ;;
        sysv)
            kernel_cmdline+=" init=/sbin/init"
            ;;
        systemd)
            kernel_cmdline+=" systemd.show_status=1 systemd.log_level=debug"
            ;;
        openrc)
            kernel_cmdline+=" init=/usr/sbin/openrc-init"
            ;;
    esac
    
    # Store kernel command line for bootloader configuration
    echo "KERNEL_CMDLINE="${kernel_cmdline}"" > "${LOGS_DIR}/kernel-cmdline"
    
    log_info "Kernel configuration prepared"
}

# =============================================================================
# MANUAL MODE FUNCTIONS
# =============================================================================

manual_mode() {
    log_section "Manual Build Mode"
    log_info "You are in manual mode. Available commands:"
    echo ""
    echo "  Build Commands:"
    echo "    notlfs_download <pkg>     - Download package source"
    echo "    notlfs_extract <pkg>      - Extract package source"
    echo "    notlfs_configure <pkg>    - Configure package"
    echo "    notlfs_build <pkg>        - Build package"
    echo "    notlfs_install <pkg>      - Install package"
    echo "    notlfs_test <pkg>         - Run package tests"
    echo "    notlfs_clean <pkg>        - Clean package build"
    echo ""
    echo "  Navigation:"
    echo "    notlfs_shell [pkg]        - Enter shell (optionally in package dir)"
    echo "    notlfs_cd <dir>           - Change directory"
    echo "    notlfs_pwd               - Print working directory"
    echo ""
    echo "  Information:"
    echo "    notlfs_list               - List all packages"
    echo "    notlfs_list_profiles      - List build profiles"
    echo "    notlfs_status             - Show build status"
    echo "    notlfs_help               - Show this help"
    echo ""
    echo "  System:"
    echo "    notlfs_init <system>      - Configure init system"
    echo "    notlfs_service <name>     - Generate service file"
    echo ""
    echo "  Exit:"
    echo "    notlfs_exit               - Exit manual mode"
    echo "    exit                       - Exit manual mode"
    echo ""
    
    # Start interactive shell
    while true; do
        echo -n "notlfs> "
        read -r cmd arg1 arg2
        
        case "$cmd" in
            notlfs_download)
                download_source "$arg1"
                ;;
            notlfs_extract)
                extract_source "$arg1" "$arg2"
                ;;
            notlfs_configure)
                load_package "$arg1"
                cd "${BUILD_ROOT}/build/${arg1}" || die "Package directory not found"
                configure "$arg1"
                ;;
            notlfs_build)
                load_package "$arg1"
                cd "${BUILD_ROOT}/build/${arg1}" || die "Package directory not found"
                build "$arg1"
                ;;
            notlfs_install)
                load_package "$arg1"
                cd "${BUILD_ROOT}/build/${arg1}" || die "Package directory not found"
                install "$arg1"
                ;;
            notlfs_test)
                load_package "$arg1"
                cd "${BUILD_ROOT}/build/${arg1}" || die "Package directory not found"
                test "$arg1"
                ;;
            notlfs_clean)
                clean_package "$arg1"
                ;;
            notlfs_shell)
                if [ -n "$arg1" ]; then
                    load_package "$arg1"
                    cd "${BUILD_ROOT}/build/${arg1}" 2>/dev/null || cd "$arg1" 2>/dev/null
                fi
                bash
                ;;
            notlfs_cd)
                cd "$arg1" 2>/dev/null || log_error "Directory not found: $arg1"
                ;;
            notlfs_pwd)
                pwd
                ;;
            notlfs_list)
                list_packages
                ;;
            notlfs_list_profiles)
                list_profiles
                ;;
            notlfs_status)
                build_status
                ;;
            notlfs_init)
                if [ -n "$arg1" ]; then
                    INIT_SYSTEM="$arg1"
                    build_init_system
                else
                    log_error "Please specify an init system"
                fi
                ;;
            notlfs_service)
                if [ -n "$arg1" ]; then
                    init_generate_service "$arg1" "$arg2"
                else
                    log_error "Please specify a service name"
                fi
                ;;
            notlfs_help)
                manual_mode
                return
                ;;
            notlfs_exit|exit)
                return
                ;;
            "")
                ;;
            *)
                # Try to execute as shell command
                if eval "$cmd" 2>/dev/null; then
                    : # Success
                else
                    log_error "Unknown command: $cmd"
                fi
                ;;
        esac
    done
}

# Show build status
build_status() {
    log_section "Build Status"
    
    echo "  Configuration:"
    echo "    System: ${NOTLFS_NAME:-notlfs}"
    echo "    Architecture: ${TARGET_ARCH:-unknown}"
    echo "    Init System: ${INIT_SYSTEM:-unknown}"
    echo "    Build Mode: ${BUILD_MODE:-unknown}"
    echo ""
    
    echo "  Directories:"
    echo "    NotLFS Root: ${NOTLFS_ROOT}"
    echo "    Build Root: ${BUILD_ROOT}"
    echo "    LFS: ${LFS:-not set}"
    echo ""
    
    echo "  Built Packages:"
    local count=0
    for log_file in "${LOGS_DIR}"/*.success; do
        local pkg_name=$(basename "$log_file" .success)
        echo "    - ${pkg_name}"
        ((count++))
    done
    
    if [ $count -eq 0 ]; then
        echo "    (none)"
    fi
    echo ""
    
    echo "  Build Logs:"
    ls -1 "${LOGS_DIR}"/*.log 2>/dev/null | while read log_file; do
        local pkg_name=$(basename "$log_file" .log)
        echo "    - ${pkg_name}"
    done
}

# =============================================================================
# INTERACTIVE MODE
# =============================================================================

interactive_mode() {
    log_section "NotLFS Interactive Mode"
    
    while true; do
        echo ""
        echo "NotLFS Interactive Menu"
        echo "----------------------"
        echo "1. Configure system (edit XML config)"
        echo "2. Select build profile"
        echo "3. Select init system"
        echo "4. Select packages to build"
        echo "5. Start automated build"
        echo "6. Enter manual mode"
        echo "7. List available packages"
        echo "8. List build profiles"
        echo "9. Create new package definition"
        echo "10. Create new build profile"
        echo "11. Validate configuration"
        echo "12. Clean build artifacts"
        echo "13. Show build status"
        echo "14. Export configuration"
        echo "15. Exit"
        echo ""
        echo -n "Select option: "
        read -r option
        
        case "$option" in
            1)
                edit_config
                ;;
            2)
                select_profile_interactive
                ;;
            3)
                select_init_interactive
                ;;
            4)
                select_packages_interactive
                ;;
            5)
                BUILD_MODE="auto"
                main_build
                ;;
            6)
                manual_mode
                ;;
            7)
                list_packages
                ;;
            8)
                list_profiles
                ;;
            9)
                echo -n "Enter new package name: "
                read -r pkg_name
                echo -n "Enter category (optional, default=uncategorized): "
                read -r category
                create_package_template "$pkg_name" "${category:-uncategorized}"
                ;;
            10)
                echo -n "Enter new profile name: "
                read -r profile_name
                create_profile_template "$profile_name"
                ;;
            11)
                validate_config
                ;;
            12)
                clean_build_interactive
                ;;
            13)
                build_status
                ;;
            14)
                export_config
                ;;
            15)
                return
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac
    done
}

edit_config() {
    if command -v nano &> /dev/null; then
        nano "$CONFIG_FILE"
    elif command -v vim &> /dev/null; then
        vim "$CONFIG_FILE"
    elif command -v vi &> /dev/null; then
        vi "$CONFIG_FILE"
    else
        log_error "No text editor found. Please install nano, vim, or vi."
    fi
}

select_profile_interactive() {
    log_section "Select Build Profile"
    
    list_profiles
    
    echo ""
    echo "Enter profile name (or 'back' to return):"
    read -r profile_name
    
    if [ "$profile_name" = "back" ]; then
        return
    fi
    
    if [ -d "${PROFILES_DIR}/${profile_name}" ]; then
        PROFILE="$profile_name"
        load_profile "$profile_name"
        log_info "Selected profile: $profile_name"
    else
        log_error "Profile not found: $profile_name"
    fi
}

select_init_interactive() {
    log_section "Select Init System"
    
    echo "  Available init systems:"
    for i in "${!SUPPORTED_INITS[@]}"; do
        printf "    %d. %s\n" $((i+1)) "${SUPPORTED_INITS[$i]}"
    done
    
    echo ""
    echo "Enter init system number or name (or 'back' to return):"
    read -r init_choice
    
    if [ "$init_choice" = "back" ]; then
        return
    fi
    
    # Try to match by number
    if [[ "$init_choice" =~ ^[0-9]+$ ]]; then
        local index=$((init_choice - 1))
        if [ $index -ge 0 ] && [ $index -lt ${#SUPPORTED_INITS[@]} ]; then
            INIT_SYSTEM="${SUPPORTED_INITS[$index]}"
            log_info "Selected init system: $INIT_SYSTEM"
            return
        fi
    fi
    
    # Try to match by name
    if [[ " ${SUPPORTED_INITS[@]} " =~ " ${init_choice} " ]]; then
        INIT_SYSTEM="$init_choice"
        log_info "Selected init system: $INIT_SYSTEM"
        return
    fi
    
    log_error "Invalid init system: $init_choice"
}

select_packages_interactive() {
    log_section "Package Selection"
    
    list_packages
    
    echo ""
    echo "Options:"
    echo "  all     - Enable all packages"
    echo "  none    - Disable all packages"
    echo "  <name>  - Toggle specific package"
    echo "  done    - Finish selection"
    echo "  back    - Return to menu"
    echo ""
    
    PACKAGES_TO_BUILD=()
    
    while true; do
        echo -n "Select package: "
        read -r selection
        
        case "$selection" in
            all)
                # Enable all packages
                for pkg_file in "${PACKAGES_DIR}"/*.pkg "${PACKAGES_DIR}"/*/*.pkg 2>/dev/null; do
                    local pkg_name=$(basename "$pkg_file" .pkg)
                    if ! [[ " ${PACKAGES_TO_BUILD[@]} " =~ " ${pkg_name} " ]]; then
                        PACKAGES_TO_BUILD+=("$pkg_name")
                    fi
                done
                log_info "All packages enabled (${#PACKAGES_TO_BUILD[@]} packages)"
                ;;
            none)
                PACKAGES_TO_BUILD=()
                log_info "All packages disabled"
                ;;
            done)
                break
                ;;
            back)
                return
                ;;
            *)
                if [ -f "${PACKAGES_DIR}/${selection}.pkg" ] || \
                   [ -f "${PACKAGES_DIR}"/*/${selection}.pkg" ]; then
                    if [[ " ${PACKAGES_TO_BUILD[@]} " =~ " ${selection} " ]]; then
                        # Remove from list
                        PACKAGES_TO_BUILD=(${PACKAGES_TO_BUILD[@]/$selection})
                        log_info "Disabled package: $selection"
                    else
                        PACKAGES_TO_BUILD+=("$selection")
                        log_info "Enabled package: $selection"
                    fi
                else
                    log_error "Package not found: $selection"
                fi
                ;;
        esac
        
        echo ""
        echo "Currently selected: ${PACKAGES_TO_BUILD[*]}"
    done
}

create_profile_template() {
    local profile_name="$1"
    local profile_dir="${PROFILES_DIR}/${profile_name}"
    
    if [ -d "$profile_dir" ]; then
        die "Profile already exists: $profile_name"
    fi
    
    mkdir -p "$profile_dir"
    
    cat > "${profile_dir}/profile.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<profile name="${profile_name}">
    <description>Description of ${profile_name} profile</description>
    <init_system>s6-rc</init_system>
    <packages>
        <!-- Include entire categories -->
        <include category="core" />
        <include category="init" />
        
        <!-- Or include individual packages -->
        <!-- <package name="vim" /> -->
    </packages>
    <features>
        <feature name="minimal">false</feature>
        <feature name="network">true</feature>
        <feature name="development">true</feature>
    </features>
</profile>
EOF
    
    log_info "Profile template created: ${profile_dir}/profile.xml"
    log_info "Edit the file to customize the profile"
}

validate_config() {
    log_section "Validating Configuration"
    
    local errors=0
    
    # Check if configuration file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        ((errors++))
    fi
    
    # Check architecture
    if ! [[ " ${SUPPORTED_ARCHS[@]} " =~ " ${TARGET_ARCH} " ]]; then
        log_error "Unsupported architecture: $TARGET_ARCH. Supported: ${SUPPORTED_ARCHS[*]}"
        ((errors++))
    fi
    
    # Check init system
    if ! [[ " ${SUPPORTED_INITS[@]} " =~ " ${INIT_SYSTEM} " ]]; then
        log_error "Unsupported init system: $INIT_SYSTEM. Supported: ${SUPPORTED_INITS[*]}"
        ((errors++))
    fi
    
    # Check packages
    local missing_packages=()
    for pkg in "${PACKAGES_TO_BUILD[@]}"; do
        if ! [ -f "${PACKAGES_DIR}/${pkg}.pkg" ] && \
           ! [ -f "${PACKAGES_DIR}"/*/${pkg}.pkg" ]; then
            missing_packages+=("$pkg")
            ((errors++))
        fi
    done
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        log_error "Missing package definitions: ${missing_packages[*]}"
    fi
    
    # Check dependencies
    local unresolved_deps=()
    for pkg in "${PACKAGES_TO_BUILD[@]}"; do
        load_package "$pkg" 2>/dev/null || continue
        
        for dep in $DEPENDENCIES $BUILD_DEPENDENCIES; do
            if [ -n "$dep" ] && ! [[ " ${PACKAGES_TO_BUILD[@]} " =~ " ${dep} " ]]; then
                unresolved_deps+=("${pkg} depends on ${dep}")
                ((errors++))
            fi
        done
    done
    
    if [ ${#unresolved_deps[@]} -gt 0 ]; then
        log_error "Unresolved dependencies:"
        for dep in "${unresolved_deps[@]}"; do
            log_error "  - $dep"
        done
    fi
    
    if [ $errors -eq 0 ]; then
        log_info "Configuration is valid"
    else
        log_error "Configuration has $errors errors"
        return 1
    fi
}

clean_build_interactive() {
    echo ""
    echo "Clean Options:"
    echo "  1. Clean specific package"
    echo "  2. Clean all build artifacts"
    echo "  3. Clean sources only"
    echo "  4. Clean logs only"
    echo "  5. Cancel"
    echo ""
    echo -n "Select option: "
    read -r option
    
    case "$option" in
        1)
            echo -n "Enter package name: "
            read -r pkg_name
            clean_package "$pkg_name"
            ;;
        2)
            clean_build
            ;;
        3)
            clean_sources
            ;;
        4)
            clean_logs
            ;;
        5)
            return
            ;;
        *)
            log_error "Invalid option"
            ;;
    esac
}

export_config() {
    echo -n "Enter export filename (default: notlfs-config-$(date +%Y%m%d-%H%M%S).xml): "
    read -r filename
    
    if [ -z "$filename" ]; then
        filename="notlfs-config-$(date +%Y%m%d-%H%M%S).xml"
    fi
    
    cp "$CONFIG_FILE" "${filename}"
    log_info "Configuration exported to: ${filename}"
}

# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================

clean_build() {
    if [ "$YES_MODE" != true ]; then
        echo -n "Are you sure you want to clean ALL build artifacts? (y/N): "
        read -r confirm
        
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            log_info "Cleanup cancelled"
            return
        fi
    fi
    
    log_section "Cleaning All Build Artifacts"
    
    # Remove build directories
    rm -rf "${BUILD_ROOT}/build"
    rm -rf "${BUILD_ROOT}/tools"
    rm -rf "${BUILD_ROOT}/notlfs"
    
    # Remove sources if not keeping
    if [ "$KEEP_SOURCES" != "true" ]; then
        rm -rf "${SRC_DIR}"
        rm -rf "${CACHE_DIR}"
    fi
    
    # Remove logs
    rm -rf "${LOGS_DIR}"
    
    # Remove output
    rm -rf "${OUTPUT_DIR}"
    
    # Remove /tools symlink
    rm -f "/tools"
    
    log_info "All build artifacts cleaned"
}

clean_package() {
    local pkg_name="$1"
    
    log_info "Cleaning package: $pkg_name"
    
    # Remove build directory
    rm -rf "${BUILD_ROOT}/build/${pkg_name}"
    
    # Remove log file
    rm -f "${LOGS_DIR}/${pkg_name}.log"
    rm -f "${LOGS_DIR}/${pkg_name}.success"
    
    # Remove source if not keeping
    if [ "$KEEP_SOURCES" != "true" ]; then
        local pkg_file="${PACKAGES_DIR}/${pkg_name}.pkg"
        if [ -f "$pkg_file" ]; then
            source "$pkg_file"
            local source_file="${SRC_DIR}/$(basename "$SOURCE")"
            rm -f "$source_file"
            rm -f "${CACHE_DIR}/$(basename "$SOURCE")"
        fi
    fi
    
    log_info "Package cleaned: $pkg_name"
}

clean_sources() {
    log_section "Cleaning Source Archives"
    rm -rf "${SRC_DIR}"
    rm -rf "${CACHE_DIR}"
    mkdir -p "${SRC_DIR}" "${CACHE_DIR}"
    log_info "Source archives cleaned"
}

clean_logs() {
    log_section "Cleaning Build Logs"
    rm -rf "${LOGS_DIR}"
    mkdir -p "${LOGS_DIR}"
    log_info "Build logs cleaned"
}

# =============================================================================
# HOOK EXECUTION
# =============================================================================

execute_hooks() {
    local stage="$1"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        return
    fi
    
    local hook_count=$(parse_xml "$CONFIG_FILE" "count(//hooks/hook[@stage='${stage}'])")
    
    for ((i=1; i<=hook_count; i++)); do
        local hook_cmd=$(parse_xml "$CONFIG_FILE" "//hooks/hook[@stage='${stage}'][$i]/text()")
        
        if [ -n "$hook_cmd" ]; then
            log_info "Executing hook [${stage}]: $hook_cmd"
            
            # Expand variables in hook command
            hook_cmd=$(eval echo "\"$hook_cmd\"" 2>/dev/null || echo "$hook_cmd")
            
            if ! eval "$hook_cmd" >> "${LOGS_DIR}/hooks-${stage}.log" 2>&1; then
                log_warn "Hook failed: $hook_cmd"
            fi
        fi
    done
}

# =============================================================================
# ENVIRONMENT SETUP
# =============================================================================

setup_environment() {
    log_section "Setting up Build Environment"
    
    # Create directories
    setup_directories
    
    # Set environment variables
    export NOTLFS_NAME
    export LFS="${BUILD_ROOT}/notlfs"
    export LFS_TGT
    export PATH="${LFS}/tools/bin:${PATH}"
    export MAKEFLAGS="-j${JOB_COUNT}"
    export PARALLEL_DOWNLOADS
    
    # Create /tools symlink
    if [ ! -L "/tools" ] && [ ! -d "/tools" ]; then
        ln -sf "${BUILD_ROOT}/tools" /tools 2>/dev/null || {
            mkdir -p /tools
        }
    fi
    
    # Check for required tools
    local required_tools=(
        curl wget tar patch make gcc g++ bison flex
        sed awk grep cut tr sort uniq basename dirname
        chmod chown cp mv rm mkdir ln find xargs
    )
    
    for tool in "${required_tools[@]}"; do
        assert_command "$tool"
    done
    
    # Set umask
    umask 022
    
    log_info "Environment setup complete"
    log_info "  NotLFS Root: ${NOTLFS_ROOT}"
    log_info "  LFS: ${LFS}"
    log_info "  LFS_TGT: ${LFS_TGT}"
    log_info "  Init System: ${INIT_SYSTEM}"
    log_info "  Jobs: ${JOB_COUNT}"
}

# =============================================================================
# MAIN BUILD PROCESS
# =============================================================================

main_build() {
    log_section "Starting NotLFS Build Process"
    
    # Validate build mode
    case "$BUILD_MODE" in
        auto|manual|interactive)
            ;;
        *)
            die "Invalid build mode: $BUILD_MODE (must be auto, manual, or interactive)"
            ;;
    esac
    
    # Setup environment
    setup_environment
    
    # Load configuration
    if [ "$BUILD_MODE" != "manual" ]; then
        load_config "$CONFIG_FILE"
        
        # Load profile if specified
        if [ -n "$PROFILE" ]; then
            load_profile "$PROFILE"
        fi
        
        # Validate configuration
        if ! validate_config; then
            die "Configuration validation failed. Please fix the errors and try again."
        fi
    fi
    
    # Start build based on mode
    case "$BUILD_MODE" in
        auto)
            automated_build
            ;;
        manual)
            manual_mode
            ;;
        interactive)
            interactive_mode
            ;;
    esac
    
    log_section "NotLFS Build Process Complete"
    log_info "Your custom Linux system is ready at: ${LFS}"
    log_info "Init system: ${INIT_SYSTEM}"
    log_info "To enter the system, use: chroot ${LFS} /bin/bash"
}

automated_build() {
    log_section "Automated Build Started"
    
    # Execute pre-build hooks
    execute_hooks "pre-build"
    
    # Phase 1: Toolchain
    execute_hooks "pre-toolchain"
    build_toolchain
    execute_hooks "post-toolchain"
    
    # Phase 2: Base System
    execute_hooks "pre-system"
    build_base_system
    execute_hooks "post-system"
    
    # Phase 3: Init System
    execute_hooks "pre-init-system"
    build_init_system
    execute_hooks "post-init-system"
    
    # Phase 4: Custom Packages
    execute_hooks "pre-packages"
    build_custom_packages
    execute_hooks "post-packages"
    
    # Phase 5: System Configuration
    execute_hooks "pre-system-config"
    configure_system
    execute_hooks "post-system-config"
    
    # Execute post-install hooks
    execute_hooks "post-install"
    
    log_section "Automated Build Complete"
    
    # Show summary
    build_summary
}

build_summary() {
    log_section "Build Summary"
    
    echo "  System Information:"
    echo "    Name: ${NOTLFS_NAME:-notlfs}"
    echo "    Architecture: ${TARGET_ARCH}"
    echo "    Init System: ${INIT_SYSTEM}"
    echo "    Hostname: ${HOSTNAME}"
    echo ""
    
    echo "  Directories:"
    echo "    NotLFS Root: ${NOTLFS_ROOT}"
    echo "    System Root: ${LFS}"
    echo "    Build Dir: ${BUILD_ROOT}/build"
    echo "    Sources: ${SRC_DIR}"
    echo "    Logs: ${LOGS_DIR}"
    echo ""
    
    echo "  Built Packages:"
    local count=0
    for log_file in "${LOGS_DIR}"/*.success; do
        local pkg_name=$(basename "$log_file" .success)
        echo "    - ${pkg_name}"
        ((count++))
    done
    echo "    Total: $count packages"
    echo ""
    
    echo "  Next Steps:"
    echo "    1. Configure bootloader for your init system"
    echo "    2. Create a kernel image"
    echo "    3. Set up a partition and install to disk"
    echo "    4. Boot your new system!"
    echo ""
    
    # Save build summary to file
    {
        echo "NotLFS Build Summary"
        echo "==================="
        echo ""
        echo "Build completed at: $(date)"
        echo ""
        echo "System:"
        echo "  Name: ${NOTLFS_NAME:-notlfs}"
        echo "  Architecture: ${TARGET_ARCH}"
        echo "  Init System: ${INIT_SYSTEM}"
        echo "  System Root: ${LFS}"
        echo ""
        echo "Packages Built: $count"
    } > "${LOGS_DIR}/build-summary.txt"
    
    cp "${LOGS_DIR}/build-summary.txt" "${OUTPUT_DIR}/"
}

# =============================================================================
# PROFILE MANAGEMENT
# =============================================================================

create_profile() {
    local profile_name="$1"
    local profile_dir="${PROFILES_DIR}/${profile_name}"
    
    if [ -d "$profile_dir" ]; then
        die "Profile already exists: $profile_name"
    fi
    
    mkdir -p "$profile_dir"
    
    # Create profile.xml
    cat > "${profile_dir}/profile.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<profile name="${profile_name}">
    <description></description>
    <init_system>s6-rc</init_system>
    <packages>
        <include category="core" />
        <include category="init" />
    </packages>
    <features>
        <feature name="minimal">false</feature>
        <feature name="network">true</feature>
        <feature name="development">true</feature>
    </features>
</profile>
EOF
    
    log_info "Profile created: $profile_name"
}

# =============================================================================
# INIT SYSTEM MANAGEMENT
# =============================================================================

list_init_systems() {
    log_section "Supported Init Systems"
    
    for i in "${!SUPPORTED_INITS[@]}"; do
        local init="${SUPPORTED_INITS[$i]}"
        local description=""
        
        case "$init" in
            s6)         description="s6 supervision suite (minimalist)" ;;
            s6-rc)      description="s6 with rc (recommended)" ;;
            s6-init)    description="s6 as init" ;;
            dinit)      description="dinit service manager" ;;
            runit)      description="runit service supervisor" ;;
            sysv)       description="SysV init (traditional)" ;;
            systemd)    description="systemd (full-featured)" ;;
            openrc)     description="OpenRC init system" ;;
        esac
        
        printf "  %-12s %s\n" "$init" "$description"
    done
    
    echo ""
    log_info "Total: ${#SUPPORTED_INITS[@]} init systems supported"
}

set_init_system() {
    local init="$1"
    
    if ! [[ " ${SUPPORTED_INITS[@]} " =~ " ${init} " ]]; then
        die "Unsupported init system: $init. Supported: ${SUPPORTED_INITS[*]}"
    fi
    
    INIT_SYSTEM="$init"
    log_info "Init system set to: $INIT_SYSTEM"
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -p|--profile)
                PROFILE="$2"
                shift 2
                ;;
            -m|--mode)
                BUILD_MODE="$2"
                shift 2
                ;;
            -i|--init)
                INIT_SYSTEM="$2"
                shift 2
                ;;
            -t|--target)
                TARGET_ARCH="$2"
                shift 2
                ;;
            -d|--debug)
                DEBUG_MODE=true
                shift
                ;;
            -y|--yes)
                YES_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            build|config|list-packages|list-profiles|add-package|add-profile|clean|shell|init|export|validate)
                COMMAND="$1"
                shift
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done
}

show_help() {
    cat << EOF
NotLFS: Modular Linux Build Framework

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    build           Start the build process (default)
    config          Generate/edit configuration
    list-packages   List available packages
    list-profiles   List available build profiles
    add-package     Add a new package definition
    add-profile     Add a new build profile
    clean           Clean build artifacts
    shell           Enter interactive build environment
    init            Initialize a new NotLFS project
    export          Export current configuration
    validate        Validate configuration and dependencies

OPTIONS:
    -c, --config FILE    Use specific configuration file
    -p, --profile NAME    Use specific build profile
    -m, --mode MODE       Build mode: auto|manual|interactive
    -i, --init SYSTEM     Init system: ${SUPPORTED_INITS[*]}
    -t, --target ARCH     Target architecture: ${SUPPORTED_ARCHS[*]}
    -d, --debug           Enable debug output
    -y, --yes             Skip confirmation prompts
    -h, --help            Show this help

EXAMPLES:
    $0 -p minimal -i s6-rc
    $0 --profile desktop --init runit --mode interactive
    $0 list-profiles
    $0 add-package neovim
    $0 -c myconfig.xml -m auto
    $0 validate
    $0 clean

BUILD MODES:
    auto        - Fully automated build from configuration
    manual      - Manual step-by-step control
    interactive - Menu-driven interactive mode

INIT SYSTEMS:
    The following init systems are supported:
$(for init in "${SUPPORTED_INITS[@]}"; do echo "      - $init"; done | sed 's/^/    /')

PROFILES:
    Predefined build profiles:
      minimal    - Minimal system with essential packages only
      base       - Base system with development tools
      desktop    - Desktop system with GUI support
      server     - Server system with network services

DIRECTORY STRUCTURE:
    The framework creates the following structure:
      notlfs/           - Main framework directory
        ├── configs/     - XML configuration files
        ├── profiles/    - Build profile definitions
        ├── packages/    - Package definition files
        ├── init/       - Init system templates
        ├── build/      - Build artifacts
        │   ├── tools/   - Temporary toolchain
        │   ├── build/   - Package build directories
        │   └── notlfs/  - Final system root
        ├── logs/       - Build logs
        ├── sources/    - Downloaded source archives
        ├── cache/      - Cached source files
        └── output/     - Build outputs

CONFIGURATION:
    XML configuration files define:
      - System architecture and build settings
      - Init system selection
      - Package selection (by category or individual)
      - Service configuration
      - Security hardening options
      - Custom hooks at various build stages

PACKAGE DEFINITIONS:
    Each package has a .pkg file in packages/ directory with:
      - Metadata (name, version, source URL, hash)
      - Dependencies (runtime and build-time)
      - Build functions (configure, build, install)
      - Init system integration (service generation)

ENVIRONMENT VARIABLES:
    The following variables are set during the build:
      NOTLFS_ROOT  - Root directory of the NotLFS framework
      LFS          - Target system root (${BUILD_ROOT}/notlfs)
      LFS_TGT      - Target system tuple (e.g., x86_64-notlfs-linux-gnu)
      INIT_SYSTEM  - Selected init system
      JOB_COUNT    - Number of parallel jobs

EOF
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

main() {
    # Initialize
    initialize
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Set default command if not specified
    if [ -z "${COMMAND:-}" ]; then
        COMMAND="build"
    fi
    
    # Execute command
    case "$COMMAND" in
        build)
            main_build
            ;;
        config)
            if [ -n "${1:-}" ]; then
                generate_sample_config "$1"
            else
                generate_sample_config "$CONFIG_FILE"
            fi
            ;;
        list-packages)
            list_packages
            ;;
        list-profiles)
            list_profiles
            ;;
        list-inits)
            list_init_systems
            ;;
        add-package)
            if [ -n "${1:-}" ]; then
                local category="${2:-uncategorized}"
                create_package_template "$1" "$category"
            else
                die "Please specify a package name"
            fi
            ;;
        add-profile)
            if [ -n "${1:-}" ]; then
                create_profile "$1"
            else
                die "Please specify a profile name"
            fi
            ;;
        clean)
            if [ -n "${1:-}" ]; then
                clean_package "$1"
            else
                clean_build
            fi
            ;;
        shell)
            BUILD_MODE="manual"
            setup_environment
            manual_mode
            ;;
        init)
            if [ -n "${1:-}" ]; then
                set_init_system "$1"
            else
                list_init_systems
            fi
            ;;
        export)
            export_config
            ;;
        validate)
            load_config "$CONFIG_FILE"
            if [ -n "$PROFILE" ]; then
                load_profile "$PROFILE"
            fi
            validate_config
            ;;
        *)
            die "Unknown command: $COMMAND"
            ;;
    esac
}

# Run main function with all arguments
main "$@"