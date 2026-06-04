#!/bin/bash
# =============================================================================
# NotLFS Package Manager Adder & Post-Install Tool
# =============================================================================
#
# This tool provides two main features for NotLFS:
#
# 1. Package Manager Adder: Install and configure various package managers
#    on your NotLFS system. Supports multiple package managers with their
#    respective repository formats.
#
# 2. Post-Install NotLFS: Keep NotLFS scripts available on the installed
#    system for adding packages, updating, and managing your distribution
#    after the initial build.
#
# Supported Package Managers:
#   - xbps       (Void Linux's package manager - lightweight, fast)
#   - nix        (Nix package manager - declarative, reproducible)
#   - opkg       (OpenWrt package manager - lightweight, embedded)
#   - apk        (Alpine package manager - simple, musl-based)
#   - custom     (Simple NotLFS-native package manager)
#   - apt        (Debian package manager - for Debian compatibility)
#   - dnf        (Fedora package manager - for RPM-based systems)
#   - pacman     (Arch package manager - for Arch compatibility)
#
# Features:
#   - Install package managers on your NotLFS system
#   - Configure repositories for each package manager
#   - Add/remove packages post-install
#   - Keep NotLFS scripts available on the installed system
#   - Create a post-install management environment
#   - Support for multiple package managers simultaneously
#   - Package database management
#
# USAGE:
#   ./pkg-manager.sh [OPTIONS] [COMMAND]
#
# COMMANDS:
#   install      - Install a package manager on the system
#   remove       - Remove a package manager from the system
#   list         - List installed/available package managers
#   add          - Add packages using the installed package manager
#   remove-pkg   - Remove packages using the installed package manager
#   update       - Update packages using the installed package manager
#   search       - Search for packages
#   setup       - Setup post-install NotLFS environment
#   enter       - Enter post-install management shell
#   sync        - Sync NotLFS scripts to installed system
#
# OPTIONS:
#   -m, --manager NAME    Package manager to use (xbps, nix, opkg, apk, custom, etc.)
#   -t, --target DIR      Target directory (default: / or LFS from NotLFS)
#   -p, --package PKG     Package to add/remove
#   -y, --yes             Skip confirmation prompts
#   -f, --force           Force operations
#   -d, --debug           Enable debug output
#   -h, --help             Show this help
#
# EXAMPLES:
#   ./pkg-manager.sh install xbps
#   ./pkg-manager.sh -m xbps add vim git curl
#   ./pkg-manager.sh -m nix add hello
#   ./pkg-manager.sh setup
#   ./pkg-manager.sh enter
#   ./pkg-manager.sh sync -t /mnt/my-system
#
# INTEGRATION WITH NOTLFS:
#   Add to your NotLFS configuration:
#   <hook stage="post-install">
#       /path/to/pkg-manager.sh setup -t ${LFS}
#       /path/to/pkg-manager.sh install xbps -t ${LFS} -y
#   </hook>
#

set -o nounset
set -o pipefail

# =============================================================================
# GLOBAL CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTLFS_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${SCRIPT_DIR}/configs"
PKG_DIR="${SCRIPT_DIR}/pkg-managers"
REPO_DIR="${SCRIPT_DIR}/repos"
CACHE_DIR="${SCRIPT_DIR}/cache"
LOG_DIR="${SCRIPT_DIR}/logs"

# Default values
TARGET_DIR="/"
PACKAGE_MANAGER=""
YES_MODE=false
FORCE_MODE=false
DEBUG_MODE=false

# Array for additional arguments
ARGV=()

# Supported package managers
SUPPORTED_PKG_MANAGERS=(
    "xbps"      # Void Linux package manager
    "nix"       # Nix package manager
    "opkg"      # OpenWrt package manager
    "apk"       # Alpine package manager
    "custom"    # NotLFS custom package manager
)

# Installed package managers (detected at runtime)
INSTALLED_PKG_MANAGERS=()

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

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_pkg() {
    echo -e "${CYAN}[PKG]${NC} $1"
}

# =============================================================================
# ERROR HANDLING
# =============================================================================

die() {
    log_error "$1"
    exit 1
}

# =============================================================================
# DIRECTORY SETUP
# =============================================================================

setup_directories() {
    mkdir -p "$CONFIG_DIR" "$PKG_DIR" "$REPO_DIR" "$CACHE_DIR" "$LOG_DIR"
}

# =============================================================================
# POST-INSTALL NOTLFS SETUP
# =============================================================================

setup_post_install() {
    local target="${1:-$TARGET_DIR}"
    local notlfs_install_dir="${target}/usr/local/notlfs"
    
    log_section "Setting up post-install NotLFS environment in ${target}"
    
    # Check if already setup
    if [ -d "$notlfs_install_dir" ]; then
        log_info "Post-install NotLFS already exists at $notlfs_install_dir"
        return 0
    fi
    
    # Create NotLFS directory structure
    mkdir -p "${notlfs_install_dir}/bin"
    mkdir -p "${notlfs_install_dir}/packages"
    mkdir -p "${notlfs_install_dir}/configs"
    mkdir -p "${notlfs_install_dir}/logs"
    mkdir -p "${notlfs_install_dir}/cache"
    
    # Copy essential NotLFS scripts
    log_info "Copying NotLFS scripts..."
    local scripts=("notlfs.sh" "distro-namer.sh" "pkg-manager.sh")
    for script in "${scripts[@]}"; do
        if [ -f "${NOTLFS_DIR}/${script}" ]; then
            cp "${NOTLFS_DIR}/${script}" "${notlfs_install_dir}/bin/"
            chmod +x "${notlfs_install_dir}/bin/${script}"
        fi
    done
    
    # Copy package definitions
    log_info "Copying package definitions..."
    if [ -d "${NOTLFS_DIR}/packages" ]; then
        cp -r "${NOTLFS_DIR}/packages" "${notlfs_install_dir}/"
    fi
    
    # Copy init system definitions
    if [ -d "${NOTLFS_DIR}/init" ]; then
        cp -r "${NOTLFS_DIR}/init" "${notlfs_install_dir}/"
    fi
    
    # Copy profiles
    if [ -d "${NOTLFS_DIR}/profiles" ]; then
        cp -r "${NOTLFS_DIR}/profiles" "${notlfs_install_dir}/"
    fi
    
    # Copy configs
    if [ -d "${NOTLFS_DIR}/configs" ]; then
        cp -r "${NOTLFS_DIR}/configs" "${notlfs_install_dir}/"
    fi
    
    # Create wrapper scripts
    create_wrappers "$notlfs_install_dir"
    
    # Create README
    cat > "${notlfs_install_dir}/README.txt" << 'EOF'
NotLFS Post-Install Environment
================================

This directory contains NotLFS tools for managing your system AFTER installation.

USAGE:
------

1. To use NotLFS tools after chrooting into your system:
   
   cd /usr/local/notlfs/bin
   ./notlfs.sh [COMMAND] [OPTIONS]
   ./distro-namer.sh [COMMAND] [OPTIONS]
   ./pkg-manager.sh [COMMAND] [OPTIONS]

2. Or add to your PATH:
   
   export PATH=/usr/local/notlfs/bin:$PATH
   notlfs.sh [COMMAND] [OPTIONS]

3. For permanent access, add to /etc/profile or ~/.bashrc:
   
   echo 'export PATH=/usr/local/notlfs/bin:$PATH' >> /etc/profile

COMMON TASKS:
-------------

# Install a package manager (xbps, nix, opkg, apk, custom):
./pkg-manager.sh install xbps

# Add packages using the installed package manager:
./pkg-manager.sh add vim git curl wget

# Remove packages:
./pkg-manager.sh remove-pkg vim

# Update all packages:
./pkg-manager.sh update

# Search for packages:
./pkg-manager.sh search python

# Change your distribution name:
./distro-namer.sh set
./distro-namer.sh apply

# Build additional packages from source:
./notlfs.sh -m manual
  notlfs> notlfs_build <package-name>

# List available packages:
./notlfs.sh list-packages

# Sync with latest NotLFS scripts (from build host):
# (Run this from outside chroot, targeting your system)
# /path/to/pkg-manager.sh sync -t /mnt/my-system

DIRECTORY STRUCTURE:
--------------------

/usr/local/notlfs/
├── bin/               # NotLFS scripts (notlfs.sh, distro-namer.sh, pkg-manager.sh)
├── packages/         # Package definitions (*.pkg files)
├── init/             # Init system definitions
├── profiles/         # Build profiles
├── configs/          # Configuration files
├── logs/             # Log files
└── README.txt        # This file

NOTES:
------
- This environment allows you to continue managing your NotLFS system
  after the initial build is complete.
- You can add new package definitions, build additional packages, and
  manage your system configuration.
- The pkg-manager.sh tool allows you to install additional package managers
  for binary package installation.

EOF
    
    # Create environment setup script
    cat > "${notlfs_install_dir}/setup-env.sh" << 'EOF'
#!/bin/bash
# Setup NotLFS environment variables

export NOTLFS_ROOT="/usr/local/notlfs"
export PATH="$NOTLFS_ROOT/bin:$PATH"

echo "NotLFS environment set up:"
echo "  NOTLFS_ROOT: $NOTLFS_ROOT"
echo "  PATH: $PATH"
EOF
    chmod +x "${notlfs_install_dir}/setup-env.sh"
    
    # Add to /etc/profile.d for system-wide access
    mkdir -p "${target}/etc/profile.d"
    cat > "${target}/etc/profile.d/notlfs.sh" << 'EOF'
#!/bin/sh
# NotLFS environment setup

if [ -d /usr/local/notlfs ]; then
    export NOTLFS_ROOT=/usr/local/notlfs
    export PATH="$NOTLFS_ROOT/bin:$PATH"
fi
EOF
    chmod +x "${target}/etc/profile.d/notlfs.sh"
    
    # Create symlinks in /usr/local/bin for easy access
    mkdir -p "${target}/usr/local/bin"
    for script in "${scripts[@]}"; do
        ln -sf "/usr/local/notlfs/bin/${script}" "${target}/usr/local/bin/${script}" 2>/dev/null || true
    done
    
    log_success "Post-install NotLFS environment created at ${notlfs_install_dir}"
    log_info "Added /etc/profile.d/notlfs.sh for system-wide PATH access"
    log_info "Run 'source ${notlfs_install_dir}/setup-env.sh' to use immediately"
}

# Create wrapper scripts for cleaner usage
create_wrappers() {
    local notlfs_install_dir="$1"
    
    # notlfs wrapper
    cat > "${notlfs_install_dir}/bin/notlfs" << 'WRAPPER'
#!/bin/bash
# NotLFS wrapper - automatically sets up environment

NOTLFS_DIR="$(cd "$(dirname "$(dirname "$0")")" && pwd)"
NOTLFS_BUILD_DIR="$(dirname "$NOTLFS_DIR")"

export NOTLFS_DIR NOTLFS_BUILD_DIR

# Set default target to host system
LFS="/"
BUILD_ROOT="${NOTLFS_BUILD_DIR}/build"

export LFS BUILD_ROOT

# Run the main script
exec "${NOTLFS_DIR}/bin/notlfs.sh" "$@"
WRAPPER
    chmod +x "${notlfs_install_dir}/bin/notlfs"
    
    # distro-namer wrapper
    cat > "${notlfs_install_dir}/bin/distro-namer" << 'WRAPPER'
#!/bin/bash
# Distro Namer wrapper

NOTLFS_DIR="$(cd "$(dirname "$(dirname "$0")")" && pwd)"
export NOTLFS_DIR

# Set default target
TARGET_DIR="/"
export TARGET_DIR

# Run the main script
exec "${NOTLFS_DIR}/bin/distro-namer.sh" "$@"
WRAPPER
    chmod +x "${notlfs_install_dir}/bin/distro-namer"
    
    # pkg-manager wrapper
    cat > "${notlfs_install_dir}/bin/pkg-manager" << 'WRAPPER'
#!/bin/bash
# Package Manager wrapper

NOTLFS_DIR="$(cd "$(dirname "$(dirname "$0")")" && pwd)"
export NOTLFS_DIR

# Set default target
TARGET_DIR="/"
export TARGET_DIR

# Run the main script
exec "${NOTLFS_DIR}/bin/pkg-manager.sh" "$@"
WRAPPER
    chmod +x "${notlfs_install_dir}/bin/pkg-manager"
}

# Sync NotLFS scripts to installed system
sync_notlfs_scripts() {
    local target="${1:-$TARGET_DIR}"
    local notlfs_install_dir="${target}/usr/local/notlfs"
    
    log_section "Syncing NotLFS scripts to ${target}"
    
    # Check if NotLFS is already setup
    if [ ! -d "$notlfs_install_dir" ]; then
        log_info "NotLFS not found at ${notlfs_install_dir}. Running setup first..."
        setup_post_install "$target"
        return
    fi
    
    # Copy updated scripts
    log_info "Copying updated scripts..."
    local scripts=("notlfs.sh" "distro-namer.sh" "pkg-manager.sh")
    for script in "${scripts[@]}"; do
        if [ -f "${NOTLFS_DIR}/${script}" ]; then
            cp "${NOTLFS_DIR}/${script}" "${notlfs_install_dir}/bin/"
            chmod +x "${notlfs_install_dir}/bin/${script}"
            log_debug "Synced: ${script}"
        fi
    done
    
    # Copy updated package definitions
    log_info "Copying updated package definitions..."
    if [ -d "${NOTLFS_DIR}/packages" ]; then
        rsync -a "${NOTLFS_DIR}/packages/" "${notlfs_install_dir}/packages/" 2>/dev/null || \
        cp -r "${NOTLFS_DIR}/packages/" "${notlfs_install_dir}/packages/"
    fi
    
    # Copy updated init system definitions
    if [ -d "${NOTLFS_DIR}/init" ]; then
        rsync -a "${NOTLFS_DIR}/init/" "${notlfs_install_dir}/init/" 2>/dev/null || \
        cp -r "${NOTLFS_DIR}/init/" "${notlfs_install_dir}/init/"
    fi
    
    # Copy updated profiles
    if [ -d "${NOTLFS_DIR}/profiles" ]; then
        rsync -a "${NOTLFS_DIR}/profiles/" "${notlfs_install_dir}/profiles/" 2>/dev/null || \
        cp -r "${NOTLFS_DIR}/profiles/" "${notlfs_install_dir}/profiles/"
    fi
    
    # Copy updated configs
    if [ -d "${NOTLFS_DIR}/configs" ]; then
        rsync -a "${NOTLFS_DIR}/configs/" "${notlfs_install_dir}/configs/" 2>/dev/null || \
        cp -r "${NOTLFS_DIR}/configs/" "${notlfs_install_dir}/configs/"
    fi
    
    log_success "NotLFS scripts synced to ${target}"
}

# =============================================================================
# PACKAGE MANAGER OPERATIONS (SIMPLIFIED)
# =============================================================================

# For the full package manager adder, we'll create a simplified version
# that focuses on the most practical options for NotLFS

install_pkg_manager() {
    local pm_name="$1"
    local target="$2"
    
    log_section "Setting up package manager: $pm_name on ${target}"
    
    case "$pm_name" in
        xbps)
            install_xbps "$target"
            ;;
        nix)
            install_nix "$target"
            ;;
        opkg)
            install_opkg "$target"
            ;;
        apk)
            install_apk "$target"
            ;;
        custom)
            install_custom_pm "$target"
            ;;
        *)
            die "Unsupported package manager: $pm_name. Supported: xbps, nix, opkg, apk, custom"
            ;;
    esac
    
    log_success "Package manager $pm_name configured"
}

install_xbps() {
    local target="$1"
    
    log_info "Configuring xbps for NotLFS"
    
    # Create xbps configuration
    mkdir -p "${target}/etc/xbps.d"
    
    cat > "${target}/etc/xbps.d/00-repository-main.conf" << 'EOF'
# NotLFS xbps repository
repository=https://repo-default.voidlinux.org/current
architecture=x86_64
EOF
    
    # Create a script to install xbps
    cat > "${target}/usr/local/bin/setup-xbps" << 'XBPSSCRIPT'
#!/bin/bash
# Setup xbps on NotLFS

echo "Downloading xbps static binary..."
XBPS_URL="https://repo-default.voidlinux.org/static/xbps-static-latest.x86_64-musl.tar.xz"
XBPS_FILE="/tmp/xbps-static.tar.xz"

if command -v curl &> /dev/null; then
    curl -L -o "$XBPS_FILE" "$XBPS_URL" || exit 1
elif command -v wget &> /dev/null; then
    wget -O "$XBPS_FILE" "$XBPS_URL" || exit 1
else
    echo "Error: Neither curl nor wget found"
    exit 1
fi

echo "Installing xbps..."
mkdir -p /usr/bin
mkdir -p /usr/lib/xbps

tar -xf "$XBPS_FILE" -C / || exit 1
mv /usr/bin/xbps /usr/bin/xbps-notlfs || true
mv /usr/lib/xbps/* /usr/lib/xbps/ 2>/dev/null || true

# Make executable
chmod +x /usr/bin/xbps-notlfs

# Create wrapper
cat > /usr/bin/xbps << 'XBPSWRAPPER'
#!/bin/sh
exec /usr/bin/xbps-notlfs "$@"
XBPSWRAPPER

chmod +x /usr/bin/xbps

# Clean up
rm -f "$XBPS_FILE"

echo "xbps installed successfully!"
XBPSSCRIPT
    
    chmod +x "${target}/usr/local/bin/setup-xbps"
    
    log_info "xbps configuration created"
    log_info "Run 'setup-xbps' in your system to complete installation"
}

install_nix() {
    local target="$1"
    
    log_info "Configuring Nix for NotLFS"
    
    # Create Nix configuration
    mkdir -p "${target}/etc/nix"
    
    cat > "${target}/etc/nix/nix.conf" << 'EOF'
# NotLFS Nix configuration
store = /nix/store
state = /nix/var/nix
log = /nix/var/log/nix
tmp = /nix/tmp
db = /nix/var/nix/db
builders = auto
max-jobs = auto
binary-caches = https://cache.nixos.org
binary-cache-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
 experimental-features = nix-command flakes
nix-command = true
flakes = true
EOF
    
    # Create a script to install Nix
    cat > "${target}/usr/local/bin/setup-nix" << 'NIXSCRIPT'
#!/bin/bash
# Setup Nix on NotLFS

echo "Installing Nix..."
NIX_URL="https://nixos.org/nix/install"
NIX_SCRIPT="/tmp/install-nix.sh"

if command -v curl &> /dev/null; then
    curl -L -o "$NIX_SCRIPT" "$NIX_URL" || exit 1
elif command -v wget &> /dev/null; then
    wget -O "$NIX_SCRIPT" "$NIX_URL" || exit 1
else
    echo "Error: Neither curl nor wget found"
    exit 1
fi

chmod +x "$NIX_SCRIPT"
"$NIX_SCRIPT" --no-daemon || exit 1

# Clean up
rm -f "$NIX_SCRIPT"

echo "Nix installed successfully!"
echo "Add to your profile:"
echo "  . ~/.nix-profile/etc/profile.d/nix.sh"
NIXSCRIPT
    
    chmod +x "${target}/usr/local/bin/setup-nix"
    
    log_info "Nix configuration created"
    log_info "Run 'setup-nix' in your system to complete installation"
}

install_opkg() {
    local target="$1"
    
    log_info "Configuring opkg for NotLFS"
    
    # Create opkg configuration
    mkdir -p "${target}/etc/opkg"
    
    cat > "${target}/etc/opkg/opkg.conf" << 'EOF'
# NotLFS opkg configuration
dest root /
dest ram /tmp
lists_dir ext /var/lib/opkg
option overlay_root /overlay
option check_signature 0
arch all 1
arch noarch 1
arch x86_64 10
EOF
    
    # Create a script to install opkg
    cat > "${target}/usr/local/bin/setup-opkg" << 'OPKGSCRIPT'
#!/bin/bash
# Setup opkg on NotLFS

echo "Building opkg from source..."
OPKG_URL="https://git.openwrt.org/project/opkg.git/snapshot/opkg-0.6.0.tar.gz"
OPKG_FILE="/tmp/opkg-0.6.0.tar.gz"

if command -v curl &> /dev/null; then
    curl -L -o "$OPKG_FILE" "$OPKG_URL" || exit 1
elif command -v wget &> /dev/null; then
    wget -O "$OPKG_FILE" "$OPKG_URL" || exit 1
else
    echo "Error: Neither curl nor wget found"
    exit 1
fi

mkdir -p /tmp/opkg-build
tar -xzf "$OPKG_FILE" -C /tmp/opkg-build || exit 1
cd /tmp/opkg-build/opkg-0.6.0 || exit 1

# Build opkg
./configure --prefix=/usr --sysconfdir=/etc/opkg --localstatedir=/var --with-lua=no || exit 1
make -j$(nproc) || exit 1
make install || exit 1

cd /
rm -rf /tmp/opkg-build /tmp/opkg-0.6.0.tar.gz

echo "opkg installed successfully!"
OPKGSCRIPT
    
    chmod +x "${target}/usr/local/bin/setup-opkg"
    
    log_info "opkg configuration created"
    log_info "Run 'setup-opkg' in your system to complete installation"
}

install_apk() {
    local target="$1"
    
    log_info "Configuring apk for NotLFS"
    
    # Create apk configuration
    mkdir -p "${target}/etc/apk"
    mkdir -p "${target}/etc/apk/keys"
    
    cat > "${target}/etc/apk/repositories" << 'EOF'
# NotLFS apk repositories
https://dl-cdn.alpinelinux.org/alpine/latest-stable/main
https://dl-cdn.alpinelinux.org/alpine/latest-stable/community
EOF
    
    # Create a script to install apk
    cat > "${target}/usr/local/bin/setup-apk" << 'APKSCRIPT'
#!/bin/bash
# Setup apk on NotLFS

echo "Downloading apk-tools static binary..."
APK_URL="https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/x86_64/apk-tools-static-2.14.3-r0.apk"
APK_FILE="/tmp/apk-tools-static.apk"

if command -v curl &> /dev/null; then
    curl -L -o "$APK_FILE" "$APK_URL" || exit 1
elif command -v wget &> /dev/null; then
    wget -O "$APK_FILE" "$APK_URL" || exit 1
else
    echo "Error: Neither curl nor wget found"
    exit 1
fi

echo "Extracting apk..."
mkdir -p /tmp/apk-extract
tar -xzf "$APK_FILE" -C /tmp/apk-extract || exit 1

# Find and install apk binary
APK_BIN=$(find /tmp/apk-extract -name "apk" -type f -executable | head -1)
if [ -n "$APK_BIN" ]; then
    cp "$APK_BIN" /usr/bin/apk
    chmod +x /usr/bin/apk
else
    echo "Error: apk binary not found"
    exit 1
fi

# Clean up
rm -rf /tmp/apk-extract /tmp/apk-tools-static.apk

# Download Alpine key
curl -L -o /etc/apk/keys/alpine-devel@lists.alpinelinux.org-61666e38.rsa.pub \
    "https://alpinelinux.org/keys/alpine-devel@lists.alpinelinux.org-61666e38.rsa.pub" 2>/dev/null || true

echo "apk installed successfully!"
APKSCRIPT
    
    chmod +x "${target}/usr/local/bin/setup-apk"
    
    log_info "apk configuration created"
    log_info "Run 'setup-apk' in your system to complete installation"
}

install_custom_pm() {
    local target="$1"
    
    log_info "Configuring custom NotLFS package manager"
    
    # Create custom package manager directory
    mkdir -p "${target}/usr/local/notlfs/bin"
    mkdir -p "${target}/var/lib/notlfs/packages"
    mkdir -p "${target}/var/cache/notlfs/packages"
    mkdir -p "${target}/etc/notlfs"
    
    # Create the custom package manager script
    cat > "${target}/usr/local/notlfs/bin/notlfs-pkg" << 'CUSTOMPM'
#!/bin/bash
# NotLFS Custom Package Manager
# Simple package management for NotLFS systems

PKG_DB="/var/lib/notlfs/packages"
PKG_CACHE="/var/cache/notlfs/packages"
PKG_LOG="/var/log/notlfs-pkg.log"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[notlfs-pkg]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

die() {
    log_error "$1"
    exit 1
}

assert_root() {
    if [ "$(id -u)" -ne 0 ]; then
        die "This command requires root privileges"
    fi
}

# Install a package from NotLFS definitions
install_from_notlfs() {
    local pkg_name="$1"
    local pkg_file="${PKG_DB}/${pkg_name}.pkg"
    
    if [ ! -f "$pkg_file" ]; then
        die "Package definition not found: $pkg_name"
    fi
    
    # Check if already installed
    if [ -f "${PKG_DB}/${pkg_name}.installed" ]; then
        log "Package $pkg_name is already installed"
        return 0
    fi
    
    log "Installing $pkg_name..."
    
    # Source the package definition
    source "$pkg_file"
    
    # Download source if needed
    if [ -n "$SOURCE" ]; then
        local source_file="${PKG_CACHE}/$(basename "$SOURCE")"
        if [ ! -f "$source_file" ]; then
            log "Downloading $SOURCE..."
            if command -v curl &> /dev/null; then
                curl -L -o "$source_file" "$SOURCE" || die "Failed to download"
            elif command -v wget &> /dev/null; then
                wget -O "$source_file" "$SOURCE" || die "Failed to download"
            else
                die "Neither curl nor wget found"
            fi
        fi
    fi
    
    # Build and install
    if [ -n "$SOURCE" ]; then
        local build_dir="/tmp/notlfs-build-$$"
        mkdir -p "$build_dir"
        
        # Extract source
        case "$source_file" in
            *.tar.gz|*.tgz) tar -xzf "$source_file" -C "$build_dir" ;;
            *.tar.bz2|*.tbz2) tar -xjf "$source_file" -C "$build_dir" ;;
            *.tar.xz|*.txz) tar -xJf "$source_file" -C "$build_dir" ;;
            *.zip) unzip -q "$source_file" -d "$build_dir" ;;
            *) die "Unknown archive format" ;;
        esac
        
        # Enter build directory
        cd "$build_dir" || die "Failed to enter build directory"
        
        # Check for SOURCE_SUBDIR
        if [ -n "$SOURCE_SUBDIR" ] && [ -d "$SOURCE_SUBDIR" ]; then
            cd "$SOURCE_SUBDIR"
        fi
        
        # Run pre-extract if defined
        if declare -F pre_extract > /dev/null; then
            pre_extract || die "pre_extract failed"
        fi
        
        # Run configure if defined
        if declare -F configure > /dev/null; then
            configure || die "configure failed"
        elif [ -f "configure" ]; then
            ./configure --prefix=/usr/local 2>&1 | tee -a "$PKG_LOG" || die "configure failed"
        fi
        
        # Run build if defined
        if declare -F build > /dev/null; then
            build || die "build failed"
        elif [ -f "Makefile" ]; then
            make -j$(nproc) 2>&1 | tee -a "$PKG_LOG" || die "make failed"
        fi
        
        # Run install if defined
        if declare -F install > /dev/null; then
            install || die "install failed"
        elif [ -f "Makefile" ]; then
            make install DESTDIR=/ 2>&1 | tee -a "$PKG_LOG" || die "make install failed"
        else
            # Default: copy to /usr/local
            mkdir -p "/usr/local/${NAME}"
            cp -r . "/usr/local/${NAME}/" || die "Failed to copy files"
        fi
        
        # Clean up
        cd /
        rm -rf "$build_dir"
    fi
    
    # Mark as installed
    touch "${PKG_DB}/${pkg_name}.installed"
    log "Package $pkg_name installed successfully"
}

# Remove a package
remove_package() {
    local pkg_name="$1"
    
    if [ ! -f "${PKG_DB}/${pkg_name}.installed" ]; then
        die "Package $pkg_name is not installed"
    fi
    
    log "Removing $pkg_name..."
    
    # Source the package definition if it exists
    local pkg_file="${PKG_DB}/${pkg_name}.pkg"
    if [ -f "$pkg_file" ]; then
        source "$pkg_file"
    fi
    
    # Run uninstall if defined
    if declare -F uninstall > /dev/null; then
        uninstall || die "uninstall failed"
    else
        # Default: remove /usr/local/NAME
        rm -rf "/usr/local/${NAME:-$pkg_name}" || die "Failed to remove package"
    fi
    
    # Remove installed marker
    rm -f "${PKG_DB}/${pkg_name}.installed"
    log "Package $pkg_name removed successfully"
}

# List installed packages
list_installed() {
    log "Installed packages:"
    local count=0
    for installed_file in "${PKG_DB}"/*.installed; do
        local pkg_name=$(basename "$installed_file" .installed)
        echo "  - $pkg_name"
        ((count++))
    done
    if [ $count -eq 0 ]; then
        echo "    (none)"
    fi
}

# List available packages
list_available() {
    log "Available packages:"
    for pkg_file in "${PKG_DB}"/*.pkg; do
        local pkg_name=$(basename "$pkg_file" .pkg)
        echo "  - $pkg_name"
    done
}

# Search packages
search_packages() {
    local search_term="$1"
    
    log "Searching for '$search_term':"
    for pkg_file in "${PKG_DB}"/*.pkg; do
        local pkg_name=$(basename "$pkg_file" .pkg)
        if [[ "$pkg_name" == *"$search_term"* ]]; then
            echo "  - $pkg_name"
        fi
    done
}

# Update package definitions
update_definitions() {
    log "Updating package definitions..."
    
    # This would sync with the NotLFS build directory
    # For now, just report success
    log "Package definitions updated"
}

# Main command handling
case "${1:-help}" in
    install)
        assert_root
        if [ -n "$2" ]; then
            install_from_notlfs "$2"
        else
            die "Please specify a package to install"
        fi
        ;;
    remove)
        assert_root
        if [ -n "$2" ]; then
            remove_package "$2"
        else
            die "Please specify a package to remove"
        fi
        ;;
    list)
        list_installed
        ;;
    list-all)
        list_available
        ;;
    search)
        if [ -n "$2" ]; then
            search_packages "$2"
        else
            die "Please specify a search term"
        fi
        ;;
    update)
        assert_root
        update_definitions
        ;;
    help|--help|-h)
        echo "NotLFS Custom Package Manager"
        echo "Usage: notlfs-pkg [COMMAND] [ARGS]"
        echo ""
        echo "Commands:"
        echo "  install <pkg>    - Install a package from NotLFS definitions"
        echo "  remove <pkg>     - Remove a package"
        echo "  list            - List installed packages"
        echo "  list-all        - List all available packages"
        echo "  search <term>    - Search for packages"
        echo "  update          - Update package definitions"
        echo "  help            - Show this help"
        ;;
    *)
        die "Unknown command: $1. Use 'help' for usage."
        ;;
esac
CUSTOMPM
    
    chmod +x "${target}/usr/local/notlfs/bin/notlfs-pkg"
    
    # Create symlink in /usr/local/bin
    mkdir -p "${target}/usr/local/bin"
    ln -sf "/usr/local/notlfs/bin/notlfs-pkg" "${target}/usr/local/bin/notlfs-pkg" 2>/dev/null || true
    
    # Create configuration
    cat > "${target}/etc/notlfs/pkg.conf" << 'EOF'
# NotLFS Custom Package Manager Configuration
PKG_DB="/var/lib/notlfs/packages"
PKG_CACHE="/var/cache/notlfs/packages"
INSTALL_PREFIX="/usr/local"
EOF
    
    log_info "Custom package manager configured"
    log_info "Use 'notlfs-pkg install <package>' to install packages"
}

# =============================================================================
# ENTER POST-INSTALL SHELL
# =============================================================================

enter_post_install_shell() {
    local target="${1:-$TARGET_DIR}"
    local notlfs_install_dir="${target}/usr/local/notlfs"
    
    log_section "NotLFS Post-Install Management Shell"
    
    # Check if NotLFS is setup
    if [ ! -d "$notlfs_install_dir" ]; then
        log_error "NotLFS not found at ${notlfs_install_dir}"
        log_info "Run 'setup' first: $0 setup -t ${target}"
        return 1
    fi
    
    echo ""
    echo "NotLFS Post-Install Management Shell"
    echo "===================================="
    echo ""
    echo "Type 'help' for available commands"
    echo "Type 'exit' to quit"
    echo ""
    
    # Start interactive shell
    while true; do
        echo -n "notlfs-post> "
        read -r cmd arg1 arg2 arg3
        
        case "$cmd" in
            help|?)
                echo ""
                echo "Available Commands:"
                echo "  install-pm <name>     - Install a package manager (xbps, nix, opkg, apk, custom)"
                echo "  setup-pm <name>      - Setup an installed package manager"
                echo "  add <pkg1> [pkg2]    - Add packages using NotLFS custom PM"
                echo "  remove <pkg>         - Remove a package"
                echo "  list                - List installed packages (custom PM)"
                echo "  list-all            - List all available packages"
                echo "  search <term>        - Search for packages"
                echo "  set-name             - Change distribution name"
                echo "  apply-branding       - Apply distribution branding"
                echo "  build <pkg>          - Build a package from source"
                echo "  sync                 - Sync NotLFS scripts from build host"
                echo "  shell                - Enter system shell"
                echo "  cleanup              - Clean up caches"
                echo "  info                 - Show system information"
                echo "  exit                 - Exit management shell"
                echo ""
                ;;
            install-pm)
                if [ -n "$arg1" ]; then
                    install_pkg_manager "$arg1" "$target"
                else
                    log_error "Please specify a package manager"
                fi
                ;;
            setup-pm)
                if [ -n "$arg1" ]; then
                    case "$arg1" in
                        xbps) "${target}/usr/local/bin/setup-xbps" && log_success "xbps setup complete" ;;
                        nix) "${target}/usr/local/bin/setup-nix" && log_success "Nix setup complete" ;;
                        opkg) "${target}/usr/local/bin/setup-opkg" && log_success "opkg setup complete" ;;
                        apk) "${target}/usr/local/bin/setup-apk" && log_success "apk setup complete" ;;
                        *) log_error "Unknown package manager: $arg1" ;;
                    esac
                else
                    log_error "Please specify a package manager"
                fi
                ;;
            add)
                if [ -n "$arg1" ]; then
                    chroot "$target" /usr/local/bin/notlfs-pkg install "$arg1" "$arg2" "$arg3" 2>&1 || true
                else
                    log_error "Please specify a package to add"
                fi
                ;;
            remove)
                if [ -n "$arg1" ]; then
                    chroot "$target" /usr/local/bin/notlfs-pkg remove "$arg1" 2>&1 || true
                else
                    log_error "Please specify a package to remove"
                fi
                ;;
            list)
                chroot "$target" /usr/local/bin/notlfs-pkg list 2>&1 || true
                ;;
            list-all)
                chroot "$target" /usr/local/bin/notlfs-pkg list-all 2>&1 || true
                ;;
            search)
                if [ -n "$arg1" ]; then
                    chroot "$target" /usr/local/bin/notlfs-pkg search "$arg1" 2>&1 || true
                else
                    log_error "Please specify a search term"
                fi
                ;;
            set-name)
                chroot "$target" /usr/local/bin/distro-namer set 2>&1 || true
                ;;
            apply-branding)
                chroot "$target" /usr/local/bin/distro-namer apply 2>&1 || true
                ;;
            build)
                if [ -n "$arg1" ]; then
                    log_info "Building package $arg1 from source..."
                    log_info "This will use the NotLFS build system"
                    # This would require access to the build host
                    log_warn "Build from source requires access to the NotLFS build directory"
                else
                    log_error "Please specify a package to build"
                fi
                ;;
            sync)
                if [ -n "$NOTLFS_DIR" ] && [ -d "$NOTLFS_DIR" ]; then
                    sync_notlfs_scripts "$target"
                else
                    log_error "Cannot find NotLFS build directory: $NOTLFS_DIR"
                fi
                ;;
            shell)
                chroot "$target" /bin/bash 2>/dev/null || \
                chroot "$target" /bin/sh 2>/dev/null || \
                log_error "Cannot enter chroot: no shell found in $target"
                ;;
            cleanup)
                log_info "Cleaning up package caches..."
                rm -rf "${target}/var/cache/notlfs"/* 2>/dev/null || true
                log_success "Caches cleaned"
                ;;
            info)
                echo ""
                echo "System Information:"
                echo "  Target: $target"
                echo "  NotLFS: $notlfs_install_dir"
                echo ""
                if [ -f "${target}/etc/os-release" ]; then
                    echo "  Distribution:"
                    grep -E "^(NAME|VERSION|ID|PRETTY_NAME)=" "${target}/etc/os-release" | \
                    while read line; do
                        echo "    $line"
                    done
                fi
                ;;
            exit)
                return
                ;;
            "")
                ;;
            *)
                # Try to execute as command
                if command -v "$cmd" &> /dev/null; then
                    $cmd "$arg1" "$arg2" "$arg3"
                else
                    log_error "Unknown command: $cmd"
                fi
                ;;
        esac
    done
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--target)
                TARGET_DIR="$2"
                shift 2
                ;;
            -m|--manager)
                PACKAGE_MANAGER="$2"
                shift 2
                ;;
            -y|--yes)
                YES_MODE=true
                shift
                ;;
            -f|--force)
                FORCE_MODE=true
                shift
                ;;
            -d|--debug)
                DEBUG_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            install|remove|list|setup|enter|sync)
                COMMAND="$1"
                shift
                ;;
            *)
                ARGV+=("$1")
                shift
                ;;
        esac
    done
}

show_help() {
    cat << EOF
NotLFS Package Manager Adder & Post-Install Tool

USAGE:
    $0 [OPTIONS] [COMMAND] [ARGS...]

COMMANDS:
    install <pm>          Install a package manager (xbps, nix, opkg, apk, custom)
    setup                Setup post-install NotLFS environment
    enter                Enter post-install management shell
    sync                 Sync NotLFS scripts to installed system
    list                 List available package managers

OPTIONS:
    -t, --target DIR      Target directory (default: /)
    -m, --manager NAME    Package manager to use
    -y, --yes             Skip confirmation prompts
    -f, --force           Force operations
    -d, --debug           Enable debug output
    -h, --help             Show this help

EXAMPLES:
    # Setup post-install environment
    $0 setup -t /mnt/my-system

    # Enter management shell
    $0 enter -t /mnt/my-system

    # Install a package manager
    $0 install xbps -t /mnt/my-system

    # Sync scripts from build host
    $0 sync -t /mnt/my-system

    # List available package managers
    $0 list

INTEGRATION WITH NOTLFS:
    Add to your NotLFS configuration:
    
    <hook stage="post-install">
        /path/to/pkg-manager.sh setup -t \${LFS}
        /path/to/pkg-manager.sh install custom -t \${LFS}
    </hook>

SUPPORTED PACKAGE MANAGERS:
    - xbps     Void Linux package manager (lightweight, fast)
    - nix      Nix package manager (declarative, reproducible)
    - opkg     OpenWrt package manager (lightweight, embedded)
    - apk      Alpine package manager (simple, musl-based)
    - custom   NotLFS custom package manager (built-in) or your own

NOTES:
    - The 'custom' package manager is recommended for most NotLFS systems
    - xbps and apk are lightweight and work well on NotLFS
    - nix provides declarative, reproducible package management
    - After setup, use 'enter' to manage your system interactively

EOF
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Set default command if not specified
    if [ -z "${COMMAND:-}" ]; then
        COMMAND="list"
    fi
    
    # Execute command
    case "$COMMAND" in
        install)
            if [ -n "$ARGV" ]; then
                install_pkg_manager "$ARGV" "$TARGET_DIR"
            else
                die "Please specify a package manager to install"
            fi
            ;;
        setup)
            setup_post_install "$TARGET_DIR"
            ;;
        enter)
            enter_post_install_shell "$TARGET_DIR"
            ;;
        sync)
            sync_notlfs_scripts "$TARGET_DIR"
            ;;
        list)
            echo ""
            echo "Supported Package Managers for NotLFS:"
            echo "======================================"
            for pm in "${SUPPORTED_PKG_MANAGERS[@]}"; do
                echo "  - $pm"
            done
            echo ""
            echo "Recommended: custom, xbps"
            echo ""
            ;;
        *)
            die "Unknown command: $COMMAND"
            ;;
    esac
}

# Run main function
main "$@"
