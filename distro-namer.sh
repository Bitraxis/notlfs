#!/bin/bash
# =============================================================================
# NotLFS Distro Name Changer
# =============================================================================
#
# This tool allows you to customize the name and branding of your NotLFS-based
# Linux distribution. It can be used:
#   1. During the build process (integrated with NotLFS)
#   2. After build completion (standalone mode)
#   3. On an existing system (post-install mode)
#
# Features:
#   - Set custom distribution name, version, and ID
#   - Generate /etc/os-release with custom information
#   - Customize /etc/issue, /etc/issue.net, /etc/motd
#   - Set custom hostname and domain
#   - Configure login banners
#   - Generate GRUB bootloader entries
#   - Create custom package repository names
#   - Support for multiple init systems
#
# USAGE:
#   ./distro-namer.sh [OPTIONS] [COMMAND]
#
# COMMANDS:
#   set           - Set distribution name and details (interactive)
#   apply         - Apply current settings to the system
#   generate      - Generate configuration files
#   preview       - Preview current settings
#   reset         - Reset to default NotLFS branding
#   export        - Export current configuration
#   import        - Import configuration from file
#
# OPTIONS:
#   -n, --name NAME        Distribution name
#   -v, --version VERSION  Distribution version
#   -i, --id ID            Distribution ID (lowercase, no spaces)
#   -p, --pretty-name NAME  Pretty name for display
#   -d, --description DESC  Description
#   -c, --config FILE       Configuration file
#   -t, --target DIR        Target directory (default: /)
#   -y, --yes              Skip confirmation
#   -f, --force            Force overwrite existing files
#   -h, --help             Show this help
#
# EXAMPLES:
#   ./distro-namer.sh -n "MyLinux" -v "1.0" -i "mylinux" -p "My Custom Linux"
#   ./distro-namer.sh set
#   ./distro-namer.sh apply -t /mnt/my-system
#   ./distro-namer.sh preview
#   ./distro-namer.sh reset
#
# INTEGRATION WITH NOTLFS:
#   Add to your NotLFS configuration:
#   <distro>
#       <name>MyLinux</name>
#       <version>1.0</version>
#       <id>mylinux</id>
#       <pretty_name>My Custom Linux 1.0</pretty_name>
#       <description>My custom Linux distribution</description>
#       <homepage>https://example.com</homepage>
#       <bug_report_url>https://example.com/bugs</bug_report_url>
#   </distro>
#
#   Or use the distro-namer during build hooks:
#   <hook stage="post-system-config">
#       /path/to/distro-namer.sh apply -t ${LFS}
#   </hook>
#

set -o errexit
set -o nounset
set -o pipefail

# =============================================================================
# GLOBAL CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/configs"
DEFAULT_CONFIG="${CONFIG_DIR}/distro-name.conf"

# Default values
DISTRO_NAME="NotLFS"
DISTRO_VERSION="rolling"
DISTRO_ID="notlfs"
DISTRO_PRETTY_NAME="NotLFS Linux"
DISTRO_DESCRIPTION="A custom Linux distribution built with NotLFS"
DISTRO_HOMEPAGE="https://github.com/notlfs/notlfs"
DISTRO_BUG_REPORT_URL="https://github.com/notlfs/notlfs/issues"
DISTRO_SUPPORT_URL="https://github.com/notlfs/notlfs"
DISTRO_PRIVACY_POLICY_URL=""

# Target directory
TARGET_DIR="/"

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
    if [ "${DEBUG:-false}" = true ]; then
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

# =============================================================================
# ERROR HANDLING
# =============================================================================

die() {
    log_error "$1"
    exit 1
}

assert_root() {
    if [ "$(id -u)" -ne 0 ] && [ "$TARGET_DIR" = "/" ]; then
        die "This operation requires root privileges when targeting the host system."
    fi
}

assert_command() {
    if ! command -v "$1" &> /dev/null; then
        die "Required command '$1' not found. Please install it."
    fi
}

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

# Load configuration from file
load_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        die "Configuration file not found: $config_file"
    fi
    
    log_info "Loading configuration from $config_file"
    
    # Source the configuration file
    source "$config_file"
    
    # Validate required fields
    DISTRO_NAME="${DISTRO_NAME:-NotLFS}"
    DISTRO_VERSION="${DISTRO_VERSION:-rolling}"
    DISTRO_ID="${DISTRO_ID:-notlfs}"
    DISTRO_PRETTY_NAME="${DISTRO_PRETTY_NAME:-${DISTRO_NAME} Linux}"
    DISTRO_DESCRIPTION="${DISTRO_DESCRIPTION:-A custom Linux distribution built with NotLFS}"
    DISTRO_HOMEPAGE="${DISTRO_HOMEPAGE:-}"
    DISTRO_BUG_REPORT_URL="${DISTRO_BUG_REPORT_URL:-}"
    DISTRO_SUPPORT_URL="${DISTRO_SUPPORT_URL:-}"
    DISTRO_PRIVACY_POLICY_URL="${DISTRO_PRIVACY_POLICY_URL:-}"
    
    log_debug "Loaded: NAME=$DISTRO_NAME, VERSION=$DISTRO_VERSION, ID=$DISTRO_ID"
}

# Save configuration to file
save_config() {
    local config_file="$1"
    
    mkdir -p "$(dirname "$config_file")"
    
    cat > "$config_file" << EOF
# NotLFS Distro Name Configuration
# Generated by distro-namer.sh

# Distribution identity
DISTRO_NAME="${DISTRO_NAME}"
DISTRO_VERSION="${DISTRO_VERSION}"
DISTRO_ID="${DISTRO_ID}"
DISTRO_PRETTY_NAME="${DISTRO_PRETTY_NAME}"
DISTRO_DESCRIPTION="${DISTRO_DESCRIPTION}"

# URLs
DISTRO_HOMEPAGE="${DISTRO_HOMEPAGE}"
DISTRO_BUG_REPORT_URL="${DISTRO_BUG_REPORT_URL}"
DISTRO_SUPPORT_URL="${DISTRO_SUPPORT_URL}"
DISTRO_PRIVACY_POLICY_URL="${DISTRO_PRIVACY_POLICY_URL}"

# Additional fields (optional)
DISTRO_CPE_NAME="${DISTRO_CPE_NAME:-}"
DISTRO_ANSI_COLOR="${DISTRO_ANSI_COLOR:-0;34}"
DISTRO_LOGO="${DISTRO_LOGO:-}"
DISTRO_BUILD_ID="${DISTRO_BUILD_ID:-}"
DISTRO_VARIANT="${DISTRO_VARIANT:-}"
DISTRO_VARIANT_ID="${DISTRO_VARIANT_ID:-}"
EOF
    
    log_info "Configuration saved to $config_file"
}

# Generate default configuration
generate_default_config() {
    local config_file="$1"
    
    DISTRO_NAME="NotLFS"
    DISTRO_VERSION="rolling"
    DISTRO_ID="notlfs"
    DISTRO_PRETTY_NAME="NotLFS Linux"
    DISTRO_DESCRIPTION="A custom Linux distribution built with NotLFS"
    DISTRO_HOMEPAGE="https://github.com/notlfs/notlfs"
    DISTRO_BUG_REPORT_URL="https://github.com/notlfs/notlfs/issues"
    
    save_config "$config_file"
}

# =============================================================================
# DISTRO IDENTIFICATION FILES
# =============================================================================

# Generate /etc/os-release
# Reference: https://www.freedesktop.org/software/systemd/man/os-release.html
generate_os_release() {
    local target="$1"
    local os_release_file="${target}/etc/os-release"
    
    log_info "Generating /etc/os-release"
    
    cat > "$os_release_file" << EOF
# This file is generated by NotLFS Distro Name Changer
# Do not edit manually - use distro-namer.sh instead

NAME="${DISTRO_NAME}"
VERSION="${DISTRO_VERSION}"
ID=${DISTRO_ID}
ID_LIKE="linux"
PRETTY_NAME="${DISTRO_PRETTY_NAME}"
VERSION_CODENAME=""
VERSION_ID="${DISTRO_VERSION}"
HOME_URL="${DISTRO_HOMEPAGE}"
SUPPORT_URL="${DISTRO_SUPPORT_URL}"
BUG_REPORT_URL="${DISTRO_BUG_REPORT_URL}"
PRIVACY_POLICY_URL="${DISTRO_PRIVACY_POLICY_URL}"
BUILD_ID="${DISTRO_BUILD_ID:-}"
VARIANT="${DISTRO_VARIANT:-}"
VARIANT_ID="${DISTRO_VARIANT_ID:-}"
EOF
    
    # Add ANSI color if specified
    if [ -n "$DISTRO_ANSI_COLOR" ]; then
        echo "ANSI_COLOR="${DISTRO_ANSI_COLOR}"" >> "$os_release_file"
    fi
    
    # Add CPE name if specified
    if [ -n "$DISTRO_CPE_NAME" ]; then
        echo "CPE_NAME="${DISTRO_CPE_NAME}"" >> "$os_release_file"
    fi
    
    # Add logo if specified
    if [ -n "$DISTRO_LOGO" ]; then
        echo "LOGO="${DISTRO_LOGO}"" >> "$os_release_file"
    fi
    
    chmod 644 "$os_release_file"
    log_debug "Generated: $os_release_file"
}

# Generate /etc/lsb-release (for LSB compatibility)
generate_lsb_release() {
    local target="$1"
    local lsb_release_file="${target}/etc/lsb-release"
    
    log_info "Generating /etc/lsb-release"
    
    cat > "$lsb_release_file" << EOF
# This file is generated by NotLFS Distro Name Changer
# LSB Version:    n/a
# Distributor ID: ${DISTRO_ID}
# Description:    ${DISTRO_DESCRIPTION}
# Release:        ${DISTRO_VERSION}
# Codename:       n/a

DISTRIB_ID=${DISTRO_ID}
DISTRIB_RELEASE=${DISTRO_VERSION}
DISTRIB_CODENAME=""
DISTRIB_DESCRIPTION="${DISTRO_DESCRIPTION}"
EOF
    
    chmod 644 "$lsb_release_file"
    log_debug "Generated: $lsb_release_file"
}

# Generate /etc/issue
generate_issue() {
    local target="$1"
    local issue_file="${target}/etc/issue"
    
    log_info "Generating /etc/issue"
    
    # Create a basic issue file
    cat > "$issue_file" << EOF
${DISTRO_PRETTY_NAME} \r (\n or \l) \m \v
EOF
    
    chmod 644 "$issue_file"
    log_debug "Generated: $issue_file"
}

# Generate /etc/issue.net
generate_issue_net() {
    local target="$1"
    local issue_net_file="${target}/etc/issue.net"
    
    log_info "Generating /etc/issue.net"
    
    cat > "$issue_net_file" << EOF
${DISTRO_PRETTY_NAME}
EOF
    
    chmod 644 "$issue_net_file"
    log_debug "Generated: $issue_net_file"
}

# Generate /etc/motd (Message of the Day)
generate_motd() {
    local target="$1"
    local motd_file="${target}/etc/motd"
    
    log_info "Generating /etc/motd"
    
    cat > "$motd_file" << EOF
  _____       _   _      _   _
 |  __ \     | | | |    | | | |
 | |  | | ___| |_| | ___ | |_| | ___  ___
 | |  | |/ _ \ __| |/ _ \| __| |/ _ \/ __|
 | |__| |  __/ |_| |  __/ | |_| | (_) \__ \
 |_____/ \___|\__|_|\___| \__|_|\___/|___/

Welcome to ${DISTRO_PRETTY_NAME} ${DISTRO_VERSION}

${DISTRO_DESCRIPTION}

Homepage: ${DISTRO_HOMEPAGE}

EOF
    
    chmod 644 "$motd_file"
    log_debug "Generated: $motd_file"
}

# Generate custom /etc/issue with ASCII art
generate_fancy_issue() {
    local target="$1"
    local issue_file="${target}/etc/issue"
    
    log_info "Generating fancy /etc/issue"
    
    # Get terminal width
    local cols=${COLUMNS:-80}
    
    # Create border
    local border=""
    for ((i=0; i<cols; i++)); do
        border+="="
    done
    
    cat > "$issue_file" << EOF
${border}
${DISTRO_PRETTY_NAME} ${DISTRO_VERSION}
${border}

Kernel \r on an \m (\l)

${DISTRO_DESCRIPTION}

${border}

EOF
    
    chmod 644 "$issue_file"
    log_debug "Generated: $issue_file"
}

# Generate /etc/hostname
generate_hostname() {
    local target="$1"
    local hostname_file="${target}/etc/hostname"
    local hostname="${HOSTNAME:-${DISTRO_ID}}"
    
    log_info "Generating /etc/hostname"
    
    echo "$hostname" > "$hostname_file"
    chmod 644 "$hostname_file"
    log_debug "Generated: $hostname_file"
}

# Generate /etc/machine-info (for systemd)
generate_machine_info() {
    local target="$1"
    local machine_info_file="${target}/etc/machine-info"
    
    log_info "Generating /etc/machine-info"
    
    cat > "$machine_info_file" << EOF
PRETTY_HOSTNAME=${DISTRO_PRETTY_NAME}
ICON_NAME=computer
CHASSIS=desktop
DEPLOYMENT=development
LOCATION=local
EOF
    
    chmod 644 "$machine_info_file"
    log_debug "Generated: $machine_info_file"
}

# Generate GRUB configuration entries
generate_grub_config() {
    local target="$1"
    local grub_dir="${target}/etc/default"
    local grub_file="${grub_dir}/grub"
    
    log_info "Generating GRUB configuration"
    
    mkdir -p "$grub_dir"
    
    cat > "$grub_file" << EOF
# GRUB configuration for ${DISTRO_PRETTY_NAME}
# Generated by NotLFS Distro Name Changer

GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="${DISTRO_PRETTY_NAME}"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""

# Uncomment to disable graphical terminal
# GRUB_TERMINAL=console

# The resolution used on graphical terminal
# Note that you can use only modes which your graphic card supports via VBE
# You can see them in real GRUB with the command 'vbeinfo'
GRUB_GFXMODE=1024x768

# Uncomment if you don't want to get a beep when GRUB starts
# GRUB_INIT_TUNE="480 440 1"
EOF
    
    chmod 644 "$grub_file"
    log_debug "Generated: $grub_file"
}

# Generate package manager configuration (for future package management)
generate_pkg_config() {
    local target="$1"
    local pkg_dir="${target}/etc/pkg"
    
    log_info "Generating package manager configuration"
    
    mkdir -p "$pkg_dir"
    
    cat > "${pkg_dir}/repos.conf" << EOF
# Package repository configuration for ${DISTRO_PRETTY_NAME}
# Generated by NotLFS Distro Name Changer

[main]
url = ${DISTRO_HOMEPAGE}/repos/main
enabled = true

[testing]
url = ${DISTRO_HOMEPAGE}/repos/testing
enabled = false

[unstable]
url = ${DISTRO_HOMEPAGE}/repos/unstable
enabled = false
EOF
    
    chmod 644 "${pkg_dir}/repos.conf"
    log_debug "Generated: ${pkg_dir}/repos.conf"
}

# =============================================================================
# BRANDING FUNCTIONS
# =============================================================================

# Generate custom bash prompt
generate_bash_prompt() {
    local target="$1"
    local bashrc_file="${target}/etc/bashrc"
    
    log_info "Customizing bash prompt"
    
    # Backup existing file if it exists
    if [ -f "$bashrc_file" ]; then
        cp "$bashrc_file" "${bashrc_file}.bak"
    fi
    
    # Add custom prompt
    cat >> "$bashrc_file" << 'EOF'

# Custom prompt for ${DISTRO_PRETTY_NAME}
if [ "$PS1" ]; then
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
fi
EOF
    
    log_debug "Updated: $bashrc_file"
}

# Generate custom login banner
generate_login_banner() {
    local target="$1"
    local profile_d_file="${target}/etc/profile.d"
    local banner_file="${profile_d_file}/distro-banner.sh"
    
    log_info "Generating login banner"
    
    mkdir -p "$profile_d_file"
    
    cat > "$banner_file" << EOF
#!/bin/sh
# Distro banner for ${DISTRO_PRETTY_NAME}

cat << 'BANNER'

  ${DISTRO_PRETTY_NAME} ${DISTRO_VERSION}
  ${DISTRO_DESCRIPTION}

  Homepage: ${DISTRO_HOMEPAGE}

BANNER
EOF
    
    chmod 755 "$banner_file"
    log_debug "Generated: $banner_file"
}

# Generate custom SSH banner
generate_ssh_banner() {
    local target="$1"
    local ssh_banner_file="${target}/etc/ssh/sshd_config.d/distro-banner.conf"
    
    log_info "Generating SSH banner configuration"
    
    mkdir -p "$(dirname "$ssh_banner_file")"
    
    # Create banner file
    local banner_file="${target}/etc/ssh/distro-banner"
    cat > "$banner_file" << EOF
  _____       _   _      _   _
 |  __ \     | | | |    | | | |
 | |  | | ___| |_| | ___ | |_| | ___  ___
 | |  | |/ _ \ __| |/ _ \| __| |/ _ \/ __|
 | |__| |  __/ |_| |  __/ | |_| | (_) \__ \
 |_____/ \___|\__|_|\___| \__|_|\___/|___/

Welcome to ${DISTRO_PRETTY_NAME} ${DISTRO_VERSION}

${DISTRO_DESCRIPTION}

Homepage: ${DISTRO_HOMEPAGE}
EOF
    
    # Create SSH config
    cat > "$ssh_banner_file" << EOF
# SSH banner configuration for ${DISTRO_PRETTY_NAME}
Banner=/etc/ssh/distro-banner
EOF
    
    chmod 644 "$banner_file" "$ssh_banner_file"
    log_debug "Generated: $banner_file and $ssh_banner_file"
}

# =============================================================================
# INIT SYSTEM BRANDING
# =============================================================================

# Generate branding for s6/s6-rc
generate_s6_branding() {
    local target="$1"
    
    log_info "Generating s6 branding"
    
    # Create s6 service for distro info
    mkdir -p "${target}/etc/s6/distro-info"
    
    cat > "${target}/etc/s6/distro-info/run" << EOF
#!/bin/sh
exec cat << DISTROINFO
${DISTRO_PRETTY_NAME} ${DISTRO_VERSION}
${DISTRO_DESCRIPTION}
DISTROINFO
EOF
    
    chmod +x "${target}/etc/s6/distro-info/run"
    ln -sf "../distro-info" "${target}/etc/s6/current/distro-info" 2>/dev/null || true
    
    log_debug "Generated s6 branding"
}

# Generate branding for dinit
generate_dinit_branding() {
    local target="$1"
    
    log_info "Generating dinit branding"
    
    # Create dinit service for distro info
    cat > "${target}/etc/dinit.d/distro-info" << EOF
# Distro info service for dinit

distro-info {
    type = oneshot
    command = /bin/cat
    command_args = << DISTROINFO
${DISTRO_PRETTY_NAME} ${DISTRO_VERSION}
${DISTRO_DESCRIPTION}
DISTROINFO
    user = root
    group = root
    timeout = 5
}
EOF
    
    log_debug "Generated dinit branding"
}

# Generate branding for runit
generate_runit_branding() {
    local target="$1"
    
    log_info "Generating runit branding"
    
    # Create runit service for distro info
    mkdir -p "${target}/etc/sv/distro-info/log"
    
    cat > "${target}/etc/sv/distro-info/run" << EOF
#!/bin/sh
cat << DISTROINFO
${DISTRO_PRETTY_NAME} ${DISTRO_VERSION}
${DISTRO_DESCRIPTION}
DISTROINFO
EOF
    
    chmod +x "${target}/etc/sv/distro-info/run"
    
    cat > "${target}/etc/sv/distro-info/log/run" << 'EOF'
#!/bin/sh
exec logger -t distro-info -p daemon.info
EOF
    
    chmod +x "${target}/etc/sv/distro-info/log/run"
    ln -sf "../sv/distro-info" "${target}/etc/service/distro-info" 2>/dev/null || true
    
    log_debug "Generated runit branding"
}

# Generate branding for systemd
generate_systemd_branding() {
    local target="$1"
    
    log_info "Generating systemd branding"
    
    # Override systemd machine info
    cat > "${target}/etc/machine-info" << EOF
PRETTY_HOSTNAME=${DISTRO_PRETTY_NAME}
ICON_NAME=computer
CHASSIS=desktop
DEPLOYMENT=development
LOCATION=local
EOF
    
    # Create systemd drop-in for branding
    mkdir -p "${target}/etc/systemd/system.conf.d"
    
    cat > "${target}/etc/systemd/system.conf.d/distro-branding.conf" << EOF
[Main]
DefaultCPUAccounting=no
DefaultBlockIOAccounting=no
DefaultMemoryAccounting=no
DefaultTasksAccounting=no
EOF
    
    log_debug "Generated systemd branding"
}

# =============================================================================
# MAIN APPLY FUNCTION
# =============================================================================

# Apply all branding to the target system
apply_branding() {
    local target="$1"
    local force="$2"
    
    log_section "Applying ${DISTRO_PRETTY_NAME} branding to ${target}"
    
    # Check if we need root
    if [ "$target" = "/" ]; then
        assert_root
    fi
    
    # Check if target exists
    if [ ! -d "$target" ]; then
        die "Target directory does not exist: $target"
    fi
    
    # Create etc directory if it doesn't exist
    mkdir -p "${target}/etc" "${target}/etc/ssh" "${target}/etc/ssh/sshd_config.d"
    
    # Generate all files
    generate_os_release "$target"
    generate_lsb_release "$target"
    generate_issue "$target"
    generate_issue_net "$target"
    generate_motd "$target"
    generate_hostname "$target"
    generate_machine_info "$target"
    generate_grub_config "$target"
    generate_pkg_config "$target"
    generate_bash_prompt "$target"
    generate_login_banner "$target"
    generate_ssh_banner "$target"
    
    # Generate init system specific branding
    if [ -d "${target}/etc/s6" ]; then
        generate_s6_branding "$target"
    fi
    
    if [ -d "${target}/etc/dinit.d" ]; then
        generate_dinit_branding "$target"
    fi
    
    if [ -d "${target}/etc/sv" ]; then
        generate_runit_branding "$target"
    fi
    
    if [ -d "${target}/usr/lib/systemd" ]; then
        generate_systemd_branding "$target"
    fi
    
    log_success "Successfully applied ${DISTRO_PRETTY_NAME} branding to ${target}"
}

# =============================================================================
# INTERACTIVE SETUP
# =============================================================================

interactive_setup() {
    log_section "NotLFS Distro Name Changer - Interactive Setup"
    
    echo ""
    echo "This tool will help you customize your distribution name and branding."
    echo "Press Enter to accept the default value shown in [brackets]."
    echo ""
    
    # Distribution Name
    echo -n "Distribution Name [${DISTRO_NAME}]: "
    read -r input
    if [ -n "$input" ]; then
        DISTRO_NAME="$input"
    fi
    
    # Distribution Version
    echo -n "Version [${DISTRO_VERSION}]: "
    read -r input
    if [ -n "$input" ]; then
        DISTRO_VERSION="$input"
    fi
    
    # Distribution ID (must be lowercase, no spaces)
    local default_id=$(echo "$DISTRO_NAME" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    echo -n "ID [${DISTRO_ID:-$default_id}]: "
    read -r input
    if [ -n "$input" ]; then
        DISTRO_ID="$input"
    else
        DISTRO_ID="$default_id"
    fi
    
    # Pretty Name
    echo -n "Pretty Name [${DISTRO_PRETTY_NAME}]: "
    read -r input
    if [ -n "$input" ]; then
        DISTRO_PRETTY_NAME="$input"
    fi
    
    # Description
    echo -n "Description [${DISTRO_DESCRIPTION}]: "
    read -r input
    if [ -n "$input" ]; then
        DISTRO_DESCRIPTION="$input"
    fi
    
    # Homepage URL
    echo -n "Homepage URL [${DISTRO_HOMEPAGE}]: "
    read -r input
    if [ -n "$input" ]; then
        DISTRO_HOMEPAGE="$input"
    fi
    
    # Bug Report URL
    echo -n "Bug Report URL [${DISTRO_BUG_REPORT_URL}]: "
    read -r input
    if [ -n "$input" ]; then
        DISTRO_BUG_REPORT_URL="$input"
    fi
    
    # Support URL
    echo -n "Support URL [${DISTRO_SUPPORT_URL}]: "
    read -r input
    if [ -n "$input" ]; then
        DISTRO_SUPPORT_URL="$input"
    fi
    
    # ANSI Color (for terminal)
    echo -n "ANSI Color (e.g., 0;34 for blue) [${DISTRO_ANSI_COLOR:-0;34}]: "
    read -r input
    if [ -n "$input" ]; then
        DISTRO_ANSI_COLOR="$input"
    fi
    
    # Preview
    echo ""
    preview_settings
    
    # Confirm
    echo ""
    echo -n "Apply these settings? [y/N]: "
    read -r confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# PREVIEW FUNCTIONS
# =============================================================================

preview_settings() {
    log_section "Current Settings Preview"
    
    echo "  Distribution Name:    ${DISTRO_NAME}"
    echo "  Version:             ${DISTRO_VERSION}"
    echo "  ID:                 ${DISTRO_ID}"
    echo "  Pretty Name:        ${DISTRO_PRETTY_NAME}"
    echo "  Description:         ${DISTRO_DESCRIPTION}"
    echo ""
    echo "  Homepage:           ${DISTRO_HOMEPAGE}"
    echo "  Bug Report URL:     ${DISTRO_BUG_REPORT_URL}"
    echo "  Support URL:        ${DISTRO_SUPPORT_URL}"
    echo "  ANSI Color:         ${DISTRO_ANSI_COLOR:-0;34}"
    echo ""
    
    echo "  /etc/os-release Preview:"
    echo "  -------------------------"
    echo "  NAME=\"${DISTRO_NAME}\""
    echo "  VERSION=\"${DISTRO_VERSION}\""
    echo "  ID=${DISTRO_ID}"
    echo "  PRETTY_NAME=\"${DISTRO_PRETTY_NAME}\""
    echo "  ..."
}

preview_applied() {
    local target="$1"
    
    log_section "Preview of Applied Branding"
    
    echo ""
    echo "Files that will be created/modified in ${target}:"
    echo ""
    
    local files=(
        "etc/os-release"
        "etc/lsb-release"
        "etc/issue"
        "etc/issue.net"
        "etc/motd"
        "etc/hostname"
        "etc/machine-info"
        "etc/default/grub"
        "etc/pkg/repos.conf"
        "etc/bashrc"
        "etc/profile.d/distro-banner.sh"
        "etc/ssh/sshd_config.d/distro-banner.conf"
        "etc/ssh/distro-banner"
    )
    
    for file in "${files[@]}"; do
        if [ -f "${target}/${file}" ]; then
            echo "  [MODIFY] ${file}"
        else
            echo "  [CREATE] ${file}"
        fi
    done
    
    echo ""
    
    # Show sample /etc/os-release
    echo "Sample /etc/os-release:"
    echo "----------------------"
    cat << EOF
NAME="${DISTRO_NAME}"
VERSION="${DISTRO_VERSION}"
ID=${DISTRO_ID}
ID_LIKE="linux"
PRETTY_NAME="${DISTRO_PRETTY_NAME}"
HOME_URL="${DISTRO_HOMEPAGE}"
SUPPORT_URL="${DISTRO_SUPPORT_URL}"
BUG_REPORT_URL="${DISTRO_BUG_REPORT_URL}"
EOF
}

# =============================================================================
# RESET FUNCTIONS
# =============================================================================

reset_to_default() {
    local target="$1"
    local force="$2"
    
    log_section "Resetting to Default NotLFS Branding"
    
    # Set default values
    DISTRO_NAME="NotLFS"
    DISTRO_VERSION="rolling"
    DISTRO_ID="notlfs"
    DISTRO_PRETTY_NAME="NotLFS Linux"
    DISTRO_DESCRIPTION="A custom Linux distribution built with NotLFS"
    DISTRO_HOMEPAGE="https://github.com/notlfs/notlfs"
    DISTRO_BUG_REPORT_URL="https://github.com/notlfs/notlfs/issues"
    DISTRO_SUPPORT_URL="https://github.com/notlfs/notlfs"
    DISTRO_ANSI_COLOR="0;34"
    
    if [ "$force" = "true" ] || [ "$YES_MODE" = "true" ]; then
        apply_branding "$target" "true"
    else
        preview_applied "$target"
        echo ""
        echo -n "Reset to default NotLFS branding? [y/N]: "
        read -r confirm
        
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            apply_branding "$target" "true"
        else
            log_info "Reset cancelled"
        fi
    fi
}

# =============================================================================
# EXPORT/IMPORT FUNCTIONS
# =============================================================================

export_config() {
    local output_file="$1"
    
    if [ -z "$output_file" ]; then
        output_file="distro-name-$(date +%Y%m%d-%H%M%S).conf"
    fi
    
    save_config "$output_file"
    log_success "Configuration exported to: $output_file"
}

import_config() {
    local input_file="$1"
    
    if [ ! -f "$input_file" ]; then
        die "Configuration file not found: $input_file"
    fi
    
    load_config "$input_file"
    log_success "Configuration imported from: $input_file"
}

# =============================================================================
# INTEGRATION WITH NOTLFS
# =============================================================================

# This function can be called from NotLFS hooks to apply branding
distro_namer_hook() {
    local stage="$1"
    local target="$2"
    
    case "$stage" in
        pre-build)
            log_info "NotLFS Distro Namer: Build starting"
            ;;
        post-system-config)
            log_info "NotLFS Distro Namer: Applying branding"
            apply_branding "$target"
            ;;
        post-install)
            log_info "NotLFS Distro Namer: Final branding"
            apply_branding "$target"
            ;;
        *)
            log_debug "NotLFS Distro Namer: Hook $stage ignored"
            ;;
    esac
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_name() {
    local name="$1"
    
    # Check if name is empty
    if [ -z "$name" ]; then
        die "Distribution name cannot be empty"
    fi
    
    # Check if name contains problematic characters
    if [[ "$name" =~ [";\'\"\$\`\|\&\<\>\\] ]]; then
        die "Distribution name contains invalid characters: $name"
    fi
    
    return 0
}

validate_id() {
    local id="$1"
    
    # Check if ID is empty
    if [ -z "$id" ]; then
        die "Distribution ID cannot be empty"
    fi
    
    # Check if ID contains uppercase letters
    if [[ "$id" =~ [A-Z] ]]; then
        die "Distribution ID must be lowercase: $id"
    fi
    
    # Check if ID contains spaces
    if [[ "$id" =~ [\ ] ]]; then
        die "Distribution ID cannot contain spaces: $id"
    fi
    
    # Check if ID contains special characters (except hyphens and underscores)
    if [[ "$id" =~ [^a-z0-9_-] ]]; then
        die "Distribution ID contains invalid characters (use a-z, 0-9, -, _): $id"
    fi
    
    return 0
}

validate_version() {
    local version="$1"
    
    # Version can be empty (rolling release)
    if [ -n "$version" ]; then
        # Check for problematic characters
        if [[ "$version" =~ [";\'\"\$\`\|\&\<\>\\] ]]; then
            die "Version contains invalid characters: $version"
        fi
    fi
    
    return 0
}

validate_url() {
    local url="$1"
    
    # URL can be empty
    if [ -z "$url" ]; then
        return 0
    fi
    
    # Basic URL validation
    if [[ ! "$url" =~ ^https?:// ]]; then
        die "URL must start with http:// or https://: $url"
    fi
    
    return 0
}

validate_all() {
    validate_name "$DISTRO_NAME"
    validate_id "$DISTRO_ID"
    validate_version "$DISTRO_VERSION"
    validate_url "$DISTRO_HOMEPAGE"
    validate_url "$DISTRO_BUG_REPORT_URL"
    validate_url "$DISTRO_SUPPORT_URL"
    
    return 0
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                DISTRO_NAME="$2"
                shift 2
                ;;
            -v|--version)
                DISTRO_VERSION="$2"
                shift 2
                ;;
            -i|--id)
                DISTRO_ID="$2"
                shift 2
                ;;
            --pretty-name)
                DISTRO_PRETTY_NAME="$2"
                shift 2
                ;;
            -d|--description)
                DISTRO_DESCRIPTION="$2"
                shift 2
                ;;
            --homepage)
                DISTRO_HOMEPAGE="$2"
                shift 2
                ;;
            --bug-report-url)
                DISTRO_BUG_REPORT_URL="$2"
                shift 2
                ;;
            --support-url)
                DISTRO_SUPPORT_URL="$2"
                shift 2
                ;;
            --ansi-color)
                DISTRO_ANSI_COLOR="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -t|--target)
                TARGET_DIR="$2"
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
            -h|--help)
                show_help
                exit 0
                ;;
            set|apply|generate|preview|reset|export|import)
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
NotLFS Distro Name Changer

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    set           Set distribution name and details (interactive)
    apply         Apply current settings to the system
    generate      Generate configuration files only
    preview       Preview current settings
    reset         Reset to default NotLFS branding
    export        Export current configuration to file
    import        Import configuration from file

OPTIONS:
    -n, --name NAME            Distribution name
    -v, --version VERSION      Distribution version
    -i, --id ID                Distribution ID (lowercase, no spaces)
    --pretty-name NAME        Pretty name for display
    -d, --description DESC      Description
    --homepage URL            Homepage URL
    --bug-report-url URL      Bug report URL
    --support-url URL         Support URL
    --ansi-color COLOR        ANSI color for terminal (e.g., 0;34)
    -c, --config FILE          Configuration file
    -t, --target DIR           Target directory (default: /)
    -y, --yes                 Skip confirmation prompts
    -f, --force               Force overwrite existing files
    -h, --help                Show this help

EXAMPLES:
    # Interactive setup
    $0 set

    # Set name and apply to current system
    $0 -n "MyLinux" -v "1.0" -i "mylinux" apply

    # Apply to a different directory
    $0 -n "MyLinux" -t /mnt/my-system apply

    # Preview current settings
    $0 preview

    # Reset to default NotLFS branding
    $0 reset

    # Export configuration
    $0 export

    # Import configuration
    $0 -c my-config.conf import

INTEGRATION WITH NOTLFS:
    Add to your NotLFS configuration:
    
    <distro>
        <name>MyLinux</name>
        <version>1.0</version>
        <id>mylinux</id>
        <pretty_name>My Custom Linux 1.0</pretty_name>
        <description>My custom distribution</description>
        <homepage>https://example.com</homepage>
    </distro>
    
    Or use in a hook:
    
    <hook stage="post-system-config">
        /path/to/distro-namer.sh apply -t \${LFS}
    </hook>

FILES GENERATED:
    The following files are created/modified:
    - /etc/os-release          (Primary OS identification)
    - /etc/lsb-release        (LSB compatibility)
    - /etc/issue              (Login issue)
    - /etc/issue.net          (Network login issue)
    - /etc/motd               (Message of the Day)
    - /etc/hostname           (System hostname)
    - /etc/machine-info       (Systemd machine info)
    - /etc/default/grub       (GRUB configuration)
    - /etc/pkg/repos.conf     (Package repository config)
    - /etc/bashrc             (Custom bash prompt)
    - /etc/profile.d/distro-banner.sh (Login banner)
    - /etc/ssh/sshd_config.d/distro-banner.conf (SSH banner)
    - /etc/ssh/distro-banner  (SSH banner text)
    
    Plus init system-specific branding files.

NOTES:
    - Distribution ID must be lowercase with no spaces (use hyphens or underscores)
    - Distribution name can contain spaces and mixed case
    - All URLs should start with http:// or https://
    - ANSI color codes: 0;30=black, 0;31=red, 0;32=green, 0;33=yellow
                     0;34=blue, 0;35=magenta, 0;36=cyan, 0;37=white

EOF
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Load default configuration if no command specified
    if [ -z "${COMMAND:-}" ] && [ -z "${DISTRO_NAME:-}" ]; then
        if [ -f "$DEFAULT_CONFIG" ]; then
            load_config "$DEFAULT_CONFIG"
        else
            generate_default_config "$DEFAULT_CONFIG"
            load_config "$DEFAULT_CONFIG"
        fi
    fi
    
    # Set default command if not specified
    if [ -z "${COMMAND:-}" ]; then
        COMMAND="set"
    fi
    
    # Execute command
    case "$COMMAND" in
        set)
            if interactive_setup; then
                # Save configuration
                save_config "$DEFAULT_CONFIG"
                
                # Apply branding
                if [ "$YES_MODE" = "true" ]; then
                    apply_branding "$TARGET_DIR" "$FORCE_MODE"
                else
                    preview_applied "$TARGET_DIR"
                    echo ""
                    echo -n "Apply branding now? [y/N]: "
                    read -r confirm
                    
                    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                        apply_branding "$TARGET_DIR" "$FORCE_MODE"
                    fi
                fi
            fi
            ;;
        apply)
            validate_all
            if [ "$YES_MODE" = "true" ] || [ "$FORCE_MODE" = "true" ]; then
                apply_branding "$TARGET_DIR" "$FORCE_MODE"
            else
                preview_applied "$TARGET_DIR"
                echo ""
                echo -n "Apply branding? [y/N]: "
                read -r confirm
                
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    apply_branding "$TARGET_DIR" "$FORCE_MODE"
                fi
            fi
            ;;
        generate)
            validate_all
            echo ""
            echo "Configuration files will be generated in ${TARGET_DIR}"
            echo ""
            apply_branding "$TARGET_DIR" "$FORCE_MODE"
            ;;
        preview)
            preview_settings
            ;;
        reset)
            reset_to_default "$TARGET_DIR" "$FORCE_MODE"
            ;;
        export)
            export_config "$1"
            ;;
        import)
            import_config "$1"
            preview_settings
            ;;
        *)
            die "Unknown command: $COMMAND"
            ;;
    esac
}

# Run main function with all arguments
main "$@"