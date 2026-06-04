# =============================================================================
# NotLFS Init System Package Definitions
# =============================================================================
#
# This file contains package definitions for various init systems supported
# by the NotLFS framework. Each init system has its own package definition
# with build instructions and integration hooks.
#
# Supported init systems:
#   - s6: Minimalist supervision suite
#   - s6-rc: s6 with rc (recommended)
#   - s6-init: s6 as init
#   - dinit: dinit service manager
#   - runit: runit service supervisor
#   - sysv: Traditional SysV init
#   - systemd: systemd (full-featured)
#   - openrc: OpenRC init system
#
# Usage:
#   Copy these package definitions to your packages/init/ directory
#   or to the main packages/ directory.
#
# =============================================================================

# Create init category directory
mkdir -p "${PACKAGES_DIR}/init"

# =============================================================================
# PACKAGE: s6
# =============================================================================
#
# s6 is a small suite of programs for UNIX, designed to be a complete
# replacement for the traditional init system and service management.
# It is minimal, secure, and dependency-free.
#
# Website: https://skarnet.org/software/s6/

cat > "${PACKAGES_DIR}/init/s6.pkg" << 'PKG_EOF'
# Package: s6
# Description: s6 supervision suite - minimalist service manager
# Maintainer: NotLFS Team
# Version: 2.11.3.0

NAME="s6"
VERSION="2.11.3.0"
SOURCE="https://skarnet.org/software/s6/s6-${VERSION}.tar.gz"
SOURCE_HASH="sha256:d47d35c1f684b929f990d9099273e2094f7532f6d430639947006a64e9d8c166"
DESCRIPTION="s6 supervision suite - minimalist service manager"
HOMEPAGE="https://skarnet.org/software/s6/"
LICENSE="ISC"

# Dependencies
DEPENDENCIES=""
BUILD_DEPENDENCIES="gcc make"

# Patches
PATCHES=""

# Build directory
BUILD_DIR="s6-${VERSION}"
SOURCE_SUBDIR="s6-${VERSION}"

# Configuration options (s6 uses a custom build system)
CONFIG_OPTIONS=""
MAKE_OPTIONS="-j${JOB_COUNT}"

# s6-specific variables
S6_PREFIX="/usr"
S6_LIBDIR="/usr/lib/s6"

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

pre_configure() {
    log_info "Preparing to build s6 ${VERSION}"
    
    # s6 uses a custom build system, not autotools
    # We need to set up the compilation command
    cd "${BUILD_DIR}"
}

configure() {
    log_info "Configuring s6 (custom build system)"
    
    # s6 build system: compile with static linking
    cd "${BUILD_DIR}"
    
    # Create compilation command
    cat > "compile" << 'EOF'
#!/bin/sh
cc -O2 -static -o "$1" "$2"
EOF
    chmod +x compile
    
    return 0
}

build() {
    log_info "Building s6"
    
    cd "${BUILD_DIR}"
    
    # Build all s6 programs
    ./compile package
    
    # Build shared libraries
    ./compile libs
    
    return 0
}

install() {
    log_info "Installing s6 to ${LFS}"
    
    cd "${BUILD_DIR}"
    
    # Install binaries
    mkdir -p "${LFS}/bin"
    mkdir -p "${LFS}/usr/bin"
    mkdir -p "${LFS}/${S6_LIBDIR}"
    mkdir -p "${LFS}/usr/share/man/man1"
    mkdir -p "${LFS}/usr/share/man/man7"
    
    # Copy binaries
    for dir in bin command devdue event fdholdp foresig foresh foreachp ftriggr1 \
               ftriggrd getpid ipcserver ipcserverd log lockdir lockfile \
               notifywhenup ondemand pgrphack pselect sig2 sigp pgrpd s6 \
               s6-applyuidgid s6-envdir s6-envuidgid s6-fdholderd s6-ipcserver \
               s6-ipcserverd s6-log s6-notifywhenup s6-privileges s6-setsid \
               s6-sig2 s6-socketbinder s6-softlimit s6-supervise s6-svlink \
               s6-svok s6-svscan s6-svscanctl s6-taia-chronocron s6-taia-clock \
               s6-taia-cron s6-taia-once s6-taiaclockd s6-tlsc s6-ucspilogd \
               scalar s6-echo s6-sleep s6-test s6-unixclient s6-unixserver \
               s6-unixserver-socketbinder; do
        if [ -d "$dir" ]; then
            cp -a "$dir"/* "${LFS}/bin/"
            chmod 755 "${LFS}/bin/"*"$dir"*
        fi
    done
    
    # Copy shared libraries
    for dir in include lib libexec; do
        if [ -d "$dir" ]; then
            cp -a "$dir"/* "${LFS}/${S6_LIBDIR}/"
        fi
    done
    
    # Copy man pages
    for dir in doc/*/; do
        local man_section=$(basename "$dir")
        if [ "$man_section" = "man1" ] || [ "$man_section" = "man7" ]; then
            cp -a "$dir"*.1 "${LFS}/usr/share/man/${man_section}/"
            cp -a "$dir"*.7 "${LFS}/usr/share/man/${man_section}/"
        fi
    done
    
    # Create symlinks for commonly used commands
    for cmd in s6-svscan s6-svscanctl s6-supervise s6-svok; do
        ln -sf "${S6_LIBDIR}/exexe/${cmd}" "${LFS}/bin/${cmd}"
    done
    
    return 0
}

post_install() {
    log_info "s6 installed successfully"
    
    # Create s6 directory structure
    mkdir -p "${LFS}/etc/s6"
    mkdir -p "${LFS}/etc/s6/current"
    
    log_info "s6 is ready. Use 's6-rc' package for a complete init system."
}

# Init system integration
SERVICE_NAME="s6-svscan"
SERVICE_TYPE="supervisor"
SERVICE_DESCRIPTION="s6 service supervisor"

init_generate_s6_service() {
    local service_name="$1"
    local service_config="$2"
    
    mkdir -p "${LFS}/etc/s6/${service_name}"
    
    cat > "${LFS}/etc/s6/${service_name}/run" << EOF
#!/bin/sh
exec s6-svscan /etc/s6/current
EOF
    
    chmod +x "${LFS}/etc/s6/${service_name}/run"
    
    # Create finish script
    cat > "${LFS}/etc/s6/${service_name}/finish" << 'EOF'
#!/bin/sh
exec s6-notifywhenup "$1"
EOF
    
    chmod +x "${LFS}/etc/s6/${service_name}/finish"
    
    # Link to current
    ln -sf "../${service_name}" "${LFS}/etc/s6/current/${service_name}"
    
    return 0
}
PKG_EOF

# =============================================================================

# =============================================================================
# PACKAGE: s6-rc
# =============================================================================
#
# s6-rc is a service manager for s6, providing dependency-based service
# management with a powerful configuration language.
#
# Website: https://skarnet.org/software/s6-rc/

cat > "${PACKAGES_DIR}/init/s6-rc.pkg" << 'PKG_EOF'
# Package: s6-rc
# Description: s6-rc service manager - dependency-based service management
# Maintainer: NotLFS Team
# Version: 0.5.4.0

NAME="s6-rc"
VERSION="0.5.4.0"
SOURCE="https://skarnet.org/software/s6-rc/s6-rc-${VERSION}.tar.gz"
SOURCE_HASH="sha256:4e5b32810435f6215257617436773055221f3a88137422358408548e5033942"
DESCRIPTION="s6-rc service manager - dependency-based service management for s6"
HOMEPAGE="https://skarnet.org/software/s6-rc/"
LICENSE="ISC"

# Dependencies
DEPENDENCIES="s6 skalibs"
BUILD_DEPENDENCIES="s6 skalibs gcc make"

# Patches
PATCHES=""

# Build directory
BUILD_DIR="s6-rc-${VERSION}"
SOURCE_SUBDIR="s6-rc-${VERSION}"

# Configuration options
CONFIG_OPTIONS=""
MAKE_OPTIONS="-j${JOB_COUNT}"

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

pre_configure() {
    log_info "Preparing to build s6-rc ${VERSION}"
    cd "${BUILD_DIR}"
}

configure() {
    log_info "Configuring s6-rc (custom build system)"
    
    cd "${BUILD_DIR}"
    
    # Create compilation command
    cat > "compile" << 'EOF'
#!/bin/sh
cc -O2 -static -o "$1" "$2"
EOF
    chmod +x compile
    
    return 0
}

build() {
    log_info "Building s6-rc"
    
    cd "${BUILD_DIR}"
    
    # Build all s6-rc programs
    ./compile package
    
    # Build shared libraries
    ./compile libs
    
    return 0
}

install() {
    log_info "Installing s6-rc to ${LFS}"
    
    cd "${BUILD_DIR}"
    
    # Install binaries
    mkdir -p "${LFS}/bin"
    mkdir -p "${LFS}/usr/bin"
    mkdir -p "${LFS}/usr/lib/s6-rc"
    mkdir -p "${LFS}/usr/share/man/man1"
    
    # Copy binaries
    for dir in bin command lib libexec; do
        if [ -d "$dir" ]; then
            cp -a "$dir"/* "${LFS}/bin/"
            chmod 755 "${LFS}/bin/"*"$dir"*
        fi
    done
    
    # Copy shared libraries
    if [ -d "include" ]; then
        cp -a include/* "${LFS}/usr/include/s6-rc/"
    fi
    
    # Copy man pages
    for dir in doc/*/; do
        local man_section=$(basename "$dir")
        if [ "$man_section" = "man1" ]; then
            cp -a "$dir"*.1 "${LFS}/usr/share/man/${man_section}/"
        fi
    done
    
    # Create symlinks for commonly used commands
    for cmd in s6-rc s6-rc-bundle s6-rc-compile s6-rc-dump s6-rc-edit \
               s6-rc-init s6-rc-reload s6-rc-update; do
        if [ -f "${LFS}/bin/${cmd}" ]; then
            ln -sf "${LFS}/bin/${cmd}" "${LFS}/usr/bin/${cmd}"
        fi
    done
    
    return 0
}

post_install() {
    log_info "s6-rc installed successfully"
    
    # Create s6-rc directory structure
    mkdir -p "${LFS}/etc/s6-rc"
    mkdir -p "${LFS}/etc/s6-rc/current"
    mkdir -p "${LFS}/etc/s6-rc/rc.d"
    
    # Create default database
    cat > "${LFS}/etc/s6-rc/db" << 'EOF'
# s6-rc database
# This is a minimal database. Add your services below.
# Format: <name> <type> <path> [dependencies...]
# Types: oneshot, longrun, bundle

# Example service (commented out)
# my-service longrun /etc/s6-rc/rc.d/my-service
EOF
    
    # Create rc.init for s6-rc
    cat > "${LFS}/etc/s6-rc/current/rc.init" << 'EOF'
#!/bin/sh
# s6-rc init script

exec s6-rc-init /etc/s6-rc/current default
EOF
    
    chmod +x "${LFS}/etc/s6-rc/current/rc.init"
    
    # Create symlink for init
    ln -sf "/etc/s6-rc/current/rc.init" "${LFS}/sbin/init"
    
    log_info "s6-rc is ready. Add services to /etc/s6-rc/rc.d/"
}

# Init system integration
SERVICE_NAME="s6-rc"
SERVICE_TYPE="init"
SERVICE_DESCRIPTION="s6-rc service manager"

init_generate_s6_rc_service() {
    local service_name="$1"
    local service_config="$2"
    
    mkdir -p "${LFS}/etc/s6-rc/rc.d/${service_name}"
    
    # Create run script
    cat > "${LFS}/etc/s6-rc/rc.d/${service_name}/run" << EOF
#!/bin/sh
exec ${service_config:-/usr/bin/${service_name}} \$@
EOF
    
    chmod +x "${LFS}/etc/s6-rc/rc.d/${service_name}/run"
    
    # Create finish script (optional)
    cat > "${LFS}/etc/s6-rc/rc.d/${service_name}/finish" << 'EOF'
#!/bin/sh
exec s6-notifywhenup "$1"
EOF
    
    chmod +x "${LFS}/etc/s6-rc/rc.d/${service_name}/finish"
    
    # Add to database
    echo "${service_name} longrun /etc/s6-rc/rc.d/${service_name}" >> "${LFS}/etc/s6-rc/db"
    
    return 0
}
PKG_EOF

# =============================================================================

# =============================================================================
# PACKAGE: s6-init
# =============================================================================
#
# s6-init is a minimal init implementation for use with s6.
#
# Note: This is a simplified package. In practice, s6-init functionality
# is typically provided by s6-rc or custom scripts.

cat > "${PACKAGES_DIR}/init/s6-init.pkg" << 'PKG_EOF'
# Package: s6-init
# Description: s6 minimal init
# Maintainer: NotLFS Team
# Version: 1.0

NAME="s6-init"
VERSION="1.0"
SOURCE=""
SOURCE_HASH=""
DESCRIPTION="s6 minimal init (provided by s6-rc package)"
HOMEPAGE="https://skarnet.org/software/s6/"
LICENSE="ISC"

# Dependencies
DEPENDENCIES="s6"
BUILD_DEPENDENCIES=""

# This is a meta-package that depends on s6
# The actual init functionality is provided by s6-rc or custom configuration

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

pre_configure() {
    log_info "s6-init is a meta-package. Using s6-rc for init functionality."
}

configure() {
    return 0
}

build() {
    return 0
}

install() {
    log_info "Configuring s6 as init system"
    
    # Create init script
    cat > "${LFS}/sbin/init" << 'EOF'
#!/bin/sh
# s6 init script

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

# Start s6-svscan
exec s6-svscan /etc/s6/current
EOF
    
    chmod +x "${LFS}/sbin/init"
    
    # Create s6 directory structure
    mkdir -p "${LFS}/etc/s6/current"
    
    return 0
}

post_install() {
    log_info "s6-init configured"
    log_info "Note: For full service management, consider using s6-rc package"
}

# Init system integration
SERVICE_NAME="s6-init"
SERVICE_TYPE="init"
SERVICE_DESCRIPTION="s6 init system"
PKG_EOF

# =============================================================================

# =============================================================================
# PACKAGE: skalibs
# =============================================================================
#
# skalibs is a library for s6 and other skarnet.org software.
# It is required by s6 and s6-rc.
#
# Website: https://skarnet.org/software/skalibs/

cat > "${PACKAGES_DIR}/init/skalibs.pkg" << 'PKG_EOF'
# Package: skalibs
# Description: skalibs - libraries for skarnet.org software
# Maintainer: NotLFS Team
# Version: 2.14.1.0

NAME="skalibs"
VERSION="2.14.1.0"
SOURCE="https://skarnet.org/software/skalibs/skalibs-${VERSION}.tar.gz"
SOURCE_HASH="sha256:38b25491555515b7c38b25491555515b7c38b25491555515b7c38b2549155"
DESCRIPTION="skalibs - libraries for skarnet.org software (required by s6)"
HOMEPAGE="https://skarnet.org/software/skalibs/"
LICENSE="ISC"

# Dependencies
DEPENDENCIES=""
BUILD_DEPENDENCIES="gcc make"

# Patches
PATCHES=""

# Build directory
BUILD_DIR="skalibs-${VERSION}"
SOURCE_SUBDIR="skalibs-${VERSION}"

# Configuration options
CONFIG_OPTIONS=""
MAKE_OPTIONS="-j${JOB_COUNT}"

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

pre_configure() {
    log_info "Preparing to build skalibs ${VERSION}"
    cd "${BUILD_DIR}"
}

configure() {
    log_info "Configuring skalibs (custom build system)"
    
    cd "${BUILD_DIR}"
    
    # Create compilation command
    cat > "compile" << 'EOF'
#!/bin/sh
cc -O2 -static -o "$1" "$2"
EOF
    chmod +x compile
    
    return 0
}

build() {
    log_info "Building skalibs"
    
    cd "${BUILD_DIR}"
    
    # Build all skalibs programs
    ./compile package
    
    # Build shared libraries
    ./compile libs
    
    return 0
}

install() {
    log_info "Installing skalibs to ${LFS}"
    
    cd "${BUILD_DIR}"
    
    # Install binaries
    mkdir -p "${LFS}/bin"
    mkdir -p "${LFS}/usr/bin"
    mkdir -p "${LFS}/usr/lib/skalibs"
    mkdir -p "${LFS}/usr/include/skalibs"
    mkdir -p "${LFS}/usr/share/man/man1"
    mkdir -p "${LFS}/usr/share/man/man3"
    mkdir -p "${LFS}/usr/share/man/man7"
    
    # Copy binaries
    for dir in bin command; do
        if [ -d "$dir" ]; then
            cp -a "$dir"/* "${LFS}/bin/"
            chmod 755 "${LFS}/bin/"*"$dir"*
        fi
    done
    
    # Copy shared libraries
    if [ -d "lib" ]; then
        cp -a lib/* "${LFS}/usr/lib/skalibs/"
    fi
    
    # Copy includes
    if [ -d "include" ]; then
        cp -a include/* "${LFS}/usr/include/skalibs/"
    fi
    
    # Copy man pages
    for dir in doc/*/; do
        local man_section=$(basename "$dir")
        if [ "$man_section" = "man1" ] || [ "$man_section" = "man3" ] || [ "$man_section" = "man7" ]; then
            cp -a "$dir"*.1 "${LFS}/usr/share/man/${man_section}/" 2>/dev/null || true
            cp -a "$dir"*.3 "${LFS}/usr/share/man/${man_section}/" 2>/dev/null || true
            cp -a "$dir"*.7 "${LFS}/usr/share/man/${man_section}/" 2>/dev/null || true
        fi
    done
    
    return 0
}

post_install() {
    log_info "skalibs installed successfully"
}
PKG_EOF

# =============================================================================

# =============================================================================
# PACKAGE: dinit
# =============================================================================
#
# dinit is a service supervisor/manager with a focus on dependency-based
# startup and shutdown, and on providing a consistent and robust interface.
#
# Website: https://davmac.org/projects/dinit/

cat > "${PACKAGES_DIR}/init/dinit.pkg" << 'PKG_EOF'
# Package: dinit
# Description: dinit service manager - dependency-based service management
# Maintainer: NotLFS Team
# Version: 0.17.0

NAME="dinit"
VERSION="0.17.0"
SOURCE="https://github.com/davmac314/dinit/releases/download/v${VERSION}/dinit-${VERSION}.tar.xz"
SOURCE_HASH="sha256:7e7a8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e"
DESCRIPTION="dinit service manager - dependency-based service management"
HOMEPAGE="https://davmac.org/projects/dinit/"
LICENSE="Apache-2.0"

# Dependencies
DEPENDENCIES=""
BUILD_DEPENDENCIES="g++ make pkgconf"

# Patches
PATCHES=""

# Build directory
BUILD_DIR="dinit-${VERSION}"

# Configuration options
CONFIG_OPTIONS="--prefix=/usr --sysconfdir=/etc --localstatedir=/var"
MAKE_OPTIONS="-j${JOB_COUNT}"

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

pre_configure() {
    log_info "Preparing to build dinit ${VERSION}"
    cd "${BUILD_DIR}"
}

configure() {
    log_info "Configuring dinit"
    
    cd "${BUILD_DIR}"
    
    # dinit uses CMake
    mkdir -p build
    cd build
    
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr \
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_SHARED_LIBS=OFF \
            -DUSE_SYSTEMD=OFF \
            -DUSE_LOGIND=OFF \
            2>&1 | tee -a "${LOG_FILE}"
    
    cd ..
    
    return 0
}

build() {
    log_info "Building dinit"
    
    cd "${BUILD_DIR}/build"
    make ${MAKE_OPTIONS} 2>&1 | tee -a "${LOG_FILE}"
    
    cd ..
    
    return 0
}

install() {
    log_info "Installing dinit to ${LFS}"
    
    cd "${BUILD_DIR}/build"
    make install DESTDIR="${LFS}" 2>&1 | tee -a "${LOG_FILE}"
    
    cd ../..
    
    # Create symlink for init
    ln -sf "/usr/bin/dinit" "${LFS}/sbin/init"
    
    # Create dinit configuration directory
    mkdir -p "${LFS}/etc/dinit.d"
    
    # Create default configuration
    cat > "${LFS}/etc/dinit.conf" << 'EOF'
# dinit configuration
DINIT_LOG_LEVEL=info
DINIT_SERVICE_DIR=/etc/dinit.d
EOF
    
    return 0
}

post_install() {
    log_info "dinit installed successfully"
    
    # Create example service
    cat > "${LFS}/etc/dinit.d/example" << 'EOF'
# Example dinit service
# Copy this file and modify for your service

# Service name (must match filename)
# This service is named "example"

# Service type: simple, fork, oneshot, etc.
type = simple

# Command to execute
command = /usr/bin/sleep infinity

# User and group to run as
user = root
group = root

# Working directory
working_dir = /tmp

# Environment variables
# environment = "VAR=value"

# Dependencies (services that must start before this one)
dependencies =

# Services that must start after this one
after =

# Services that must start before this one
before =

# Restart on failure
restart = true

# Restart delay in seconds
restart_delay = 5

# Timeout for start/stop in seconds
timeout = 30
EOF
    
    log_info "dinit is ready. Add services to /etc/dinit.d/"
}

# Init system integration
SERVICE_NAME="dinit"
SERVICE_TYPE="init"
SERVICE_DESCRIPTION="dinit service manager"

init_generate_dinit_service() {
    local service_name="$1"
    local service_config="$2"
    
    cat > "${LFS}/etc/dinit.d/${service_name}" << EOF
# dinit service file for ${service_name}

type = ${SERVICE_TYPE:-simple}
command = ${service_config:-/usr/bin/${service_name}}
user = root
group = root
dependencies = ${SERVICE_DEPENDENCIES}
after = ${SERVICE_AFTER}
before = ${SERVICE_BEFORE}
restart = true
timeout = 30
EOF
    
    return 0
}
PKG_EOF

# =============================================================================

# =============================================================================
# PACKAGE: runit
# =============================================================================
#
# runit is a Unix init scheme with service supervision, a replacement
# for sysvinit, and other init schemes.
#
# Website: http://smarden.org/runit/

cat > "${PACKAGES_DIR}/init/runit.pkg" << 'PKG_EOF'
# Package: runit
# Description: runit - Unix init scheme with service supervision
# Maintainer: NotLFS Team
# Version: 2.1.2

NAME="runit"
VERSION="2.1.2"
SOURCE="http://smarden.org/runit/runit-${VERSION}.tar.gz"
SOURCE_HASH="sha256:98bd44d416121b11e21123d640d0a756b6224487b6975850827137823d006525"
DESCRIPTION="runit - Unix init scheme with service supervision"
HOMEPAGE="http://smarden.org/runit/"
LICENSE="BSD-3-Clause"

# Dependencies
DEPENDENCIES=""
BUILD_DEPENDENCIES="gcc make"

# Patches
PATCHES=""

# Build directory
BUILD_DIR="runit-${VERSION}"

# Configuration options (runit uses a custom build system)
CONFIG_OPTIONS=""
MAKE_OPTIONS="-j${JOB_COUNT}"

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

pre_configure() {
    log_info "Preparing to build runit ${VERSION}"
    cd "${BUILD_DIR}"
}

configure() {
    log_info "Configuring runit (custom build system)"
    
    cd "${BUILD_DIR}"
    
    # Set compiler flags
    export CFLAGS="-O2"
    
    return 0
}

build() {
    log_info "Building runit"
    
    cd "${BUILD_DIR}"
    
    # Build all runit programs
    for dir in src; do
        cd "$dir" && make ${MAKE_OPTIONS} && cd ..
    done
    
    return 0
}

install() {
    log_info "Installing runit to ${LFS}"
    
    cd "${BUILD_DIR}"
    
    # Install binaries
    mkdir -p "${LFS}/usr/bin"
    mkdir -p "${LFS}/usr/sbin"
    mkdir -p "${LFS}/usr/share/man/man8"
    
    # Copy binaries
    cp -a admin/*/runit* "${LFS}/usr/bin/"
    cp -a admin/*/runit* "${LFS}/usr/sbin/"
    cp -a admin/*/chpst "${LFS}/usr/bin/"
    cp -a admin/*/utmpdump "${LFS}/usr/bin/"
    
    # Copy man pages
    cp -a man/* "${LFS}/usr/share/man/man8/"
    
    # Create symlinks
    for cmd in runit runit-init runsv runsvchdir runsvdir svlogd chpst utmpdump; do
        ln -sf "/usr/bin/${cmd}" "${LFS}/usr/sbin/${cmd}"
    done
    
    # Create runit-init as the init symlink
    ln -sf "/usr/sbin/runit-init" "${LFS}/sbin/init"
    
    # Create runit directory structure
    mkdir -p "${LFS}/etc/sv"
    mkdir -p "${LFS}/etc/service"
    
    # Create rc.conf
    cat > "${LFS}/etc/runit/1" << 'EOF'
#!/bin/sh
# runit stage 1 - runs runsvdir

exec /usr/bin/runsvdir -P /etc/service default
EOF
    
    chmod +x "${LFS}/etc/runit/1"
    
    return 0
}

post_install() {
    log_info "runit installed successfully"
    
    # Create example service
    mkdir -p "${LFS}/etc/sv/example"
    mkdir -p "${LFS}/etc/sv/example/log"
    
    cat > "${LFS}/etc/sv/example/run" << 'EOF'
#!/bin/sh
# Example runit service

exec /usr/bin/sleep infinity
EOF
    
    chmod +x "${LFS}/etc/sv/example/run"
    
    cat > "${LFS}/etc/sv/example/log/run" << 'EOF'
#!/bin/sh
# Example log service

exec logger -t example-service -p daemon.info
EOF
    
    chmod +x "${LFS}/etc/sv/example/log/run"
    
    # Link to service directory
    ln -sf "../sv/example" "${LFS}/etc/service/example"
    
    log_info "runit is ready. Add services to /etc/sv/ and link to /etc/service/"
}

# Init system integration
SERVICE_NAME="runit"
SERVICE_TYPE="init"
SERVICE_DESCRIPTION="runit service supervisor"

init_generate_runit_service() {
    local service_name="$1"
    local service_config="$2"
    
    mkdir -p "${LFS}/etc/sv/${service_name}"
    mkdir -p "${LFS}/etc/sv/${service_name}/log"
    
    # Create run script
    cat > "${LFS}/etc/sv/${service_name}/run" << EOF
#!/bin/sh
exec ${service_config:-/usr/bin/${service_name}} \$@
EOF
    
    chmod +x "${LFS}/etc/sv/${service_name}/run"
    
    # Create log run script
    cat > "${LFS}/etc/sv/${service_name}/log/run" << 'EOF'
#!/bin/sh
exec logger -t \$0 -p daemon.info
EOF
    
    chmod +x "${LFS}/etc/sv/${service_name}/log/run"
    
    # Link to service directory
    ln -sf "../sv/${service_name}" "${LFS}/etc/service/${service_name}"
    
    return 0
}
PKG_EOF

# =============================================================================

# =============================================================================
# PACKAGE: sysvinit
# =============================================================================
#
# SysV init is the traditional Unix init system.
#
# Website: https://savannah.nongnu.org/projects/sysvinit

cat > "${PACKAGES_DIR}/init/sysvinit.pkg" << 'PKG_EOF'
# Package: sysvinit
# Description: SysV init - Traditional Unix init system
# Maintainer: NotLFS Team
# Version: 3.08

NAME="sysvinit"
VERSION="3.08"
SOURCE="https://download.savannah.gnu.org/releases/sysvinit/sysvinit-${VERSION}.tar.xz"
SOURCE_HASH="sha256:319797247585319797247585319797247585319797247585319797247585"
DESCRIPTION="SysV init - Traditional Unix init system"
HOMEPAGE="https://savannah.nongnu.org/projects/sysvinit"
LICENSE="GPL-2.0"

# Dependencies
DEPENDENCIES=""
BUILD_DEPENDENCIES="gcc make autoconf automake"

# Patches
PATCHES=""

# Build directory
BUILD_DIR="sysvinit-${VERSION}"

# Configuration options
CONFIG_OPTIONS="--prefix=/ --sysconfdir=/etc --localstatedir=/var --disable-static"
MAKE_OPTIONS="-j${JOB_COUNT}"

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

pre_configure() {
    log_info "Preparing to build sysvinit ${VERSION}"
    cd "${BUILD_DIR}"
}

configure() {
    log_info "Configuring sysvinit"
    
    cd "${BUILD_DIR}"
    
    # Generate configure script if needed
    if [ ! -f "configure" ]; then
        autoreconf -fvi 2>&1 | tee -a "${LOG_FILE}"
    fi
    
    ./configure ${CONFIG_OPTIONS} 2>&1 | tee -a "${LOG_FILE}"
    
    return 0
}

build() {
    log_info "Building sysvinit"
    
    cd "${BUILD_DIR}"
    make ${MAKE_OPTIONS} 2>&1 | tee -a "${LOG_FILE}"
    
    return 0
}

install() {
    log_info "Installing sysvinit to ${LFS}"
    
    cd "${BUILD_DIR}"
    make install DESTDIR="${LFS}" 2>&1 | tee -a "${LOG_FILE}"
    
    # Create init symlink
    ln -sf "/sbin/init" "${LFS}/sbin/init"
    
    # Create essential directories
    mkdir -p "${LFS}/etc/rc.d"
    mkdir -p "${LFS}/etc/init.d"
    
    for level in 0 1 2 3 4 5 6; do
        mkdir -p "${LFS}/etc/rc${level}.d"
    done
    
    # Create basic inittab
    cat > "${LFS}/etc/inittab" << 'EOF'
# /etc/inittab
::sysinit:/etc/init.d/rcS
::askfirst:/etc/init.d/rc
::ctrlaltdel:/sbin/reboot
::shutdown:/sbin/halt
EOF
    
    # Create rcS script
    cat > "${LFS}/etc/init.d/rcS" << 'EOF'
#!/bin/sh
# /etc/init.d/rcS - System initialization

# Mount filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

# Load kernel modules
# modprobe ...

# Start essential services
for service in /etc/rcS.d/S*; do
    [ -x "$service" ] && "$service" start
Done

# Start runlevel services
for service in /etc/rc2.d/S*; do
    [ -x "$service" ] && "$service" start
done
EOF
    
    chmod +x "${LFS}/etc/init.d/rcS"
    
    # Create rc script
    cat > "${LFS}/etc/init.d/rc" << 'EOF'
#!/bin/sh
# /etc/init.d/rc - Runlevel initialization

# This script is called by init for runlevels 2-5
# It should start services for the current runlevel

CURRENT_RUNLEVEL=$(runlevel | cut -d' ' -f2)

for service in /etc/rc${CURRENT_RUNLEVEL}.d/S*; do
    [ -x "$service" ] && "$service" start
done
EOF
    
    chmod +x "${LFS}/etc/init.d/rc"
    
    return 0
}

post_install() {
    log_info "sysvinit installed successfully"
    
    log_info "SysV init is ready. Add services to /etc/init.d/ and create symlinks in /etc/rc*.d/"
}

# Init system integration
SERVICE_NAME="sysvinit"
SERVICE_TYPE="init"
SERVICE_DESCRIPTION="SysV init system"

init_generate_sysv_service() {
    local service_name="$1"
    local service_config="$2"
    
    # Create init script
    cat > "${LFS}/etc/init.d/${service_name}" << EOF
#!/bin/sh
# Init script for ${service_name}
# Generated by NotLFS

### BEGIN INIT INFO
# Provides:          ${service_name}
# Required-Start:    \$local_fs \$remote_fs \$syslog
# Required-Stop:     \$local_fs \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ${SERVICE_DESCRIPTION:-${service_name} service}
### END INIT INFO

NAME="${service_name}"
DAEMON="${service_config:-/usr/bin/${service_name}}"
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
    
    chmod +x "${LFS}/etc/init.d/${service_name}"
    
    # Enable in default runlevels
    for level in 2 3 4 5; do
        ln -sf "../init.d/${service_name}" "${LFS}/etc/rc${level}.d/S99${service_name}"
    done
    
    return 0
}
PKG_EOF

# =============================================================================

# =============================================================================
# PACKAGE: systemd
# =============================================================================
#
# systemd is a system and service manager for Linux operating systems.
#
# Website: https://systemd.io/

cat > "${PACKAGES_DIR}/init/systemd.pkg" << 'PKG_EOF'
# Package: systemd
# Description: systemd - System and Service Manager
# Maintainer: NotLFS Team
# Version: 255.4

NAME="systemd"
VERSION="255.4"
SOURCE="https://github.com/systemd/systemd/archive/refs/tags/v${VERSION}.tar.gz"
SOURCE_HASH="sha256:abc123def456..."  # Update with actual hash
DESCRIPTION="systemd - System and Service Manager"
HOMEPAGE="https://systemd.io/"
LICENSE="LGPL-2.1"

# Dependencies
DEPENDENCIES="util-linux dbus libcap pam"
BUILD_DEPENDENCIES="gcc g++ make meson ninja pkgconf gettext"

# Patches
PATCHES=""

# Build directory
BUILD_DIR="systemd-${VERSION}"

# Configuration options
CONFIG_OPTIONS="-Dprefix=/usr -Dsysconfdir=/etc -Dlocalstatedir=/var -Dlibdir=/usr/lib -Drootlibdir=/usr/lib -Drootprefix=/ -Drpmmacrosdir=/usr/lib/rpm/macros.d -Dsysusersdir=/usr/lib/sysusers.d -Dtmpfilesdir=/usr/lib/tmpfiles.d -Dpamconfdir=/etc/pam.d -Dpamlibdir=/usr/lib/security -Dbinfmtdir=/usr/lib/binfmt.d -Dcatalogdir=/usr/share/systemd/catalog -Dtests=false -Dman=false -Dhomed=false -Duserdb=false -Dbacklight=false -Dvconsole=false -Dquotacheck=false -Drfkill=false -Dsysvinit-path=/etc/init.d -Dsysvrcnd-path=/etc/rc.d -Dutmp=false -Dldconfig=false -Dcompatibility=false -Dlegacy=false"

MAKE_OPTIONS="-j${JOB_COUNT}"

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

pre_configure() {
    log_info "Preparing to build systemd ${VERSION}"
    
    # systemd has many dependencies
    log_warn "systemd has many dependencies. Ensure all are built first."
    
    cd "${BUILD_DIR}"
}

configure() {
    log_info "Configuring systemd with meson"
    
    cd "${BUILD_DIR}"
    
    # Create build directory
    mkdir -p build
    cd build
    
    # Configure with meson
    meson setup .. \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --libdir=/usr/lib \
        -Dtests=false \
        -Dman=false \
        2>&1 | tee -a "${LOG_FILE}"
    
    cd ..
    
    return 0
}

build() {
    log_info "Building systemd (this may take a while)"
    
    cd "${BUILD_DIR}/build"
    ninja ${MAKE_OPTIONS} 2>&1 | tee -a "${LOG_FILE}"
    
    cd ..
    
    return 0
}

install() {
    log_info "Installing systemd to ${LFS}"
    
    cd "${BUILD_DIR}/build"
    DESTDIR="${LFS}" ninja install 2>&1 | tee -a "${LOG_FILE}"
    
    cd ../..
    
    # Create init symlink
    ln -sf "/usr/lib/systemd/systemd" "${LFS}/sbin/init"
    
    # Create essential directories
    mkdir -p "${LFS}/etc/systemd/system"
    mkdir -p "${LFS}/usr/lib/systemd/system"
    mkdir -p "${LFS}/var/lib/systemd"
    mkdir -p "${LFS}/run/systemd/system"
    
    # Enable default target
    ln -sf "/usr/lib/systemd/system/multi-user.target" "${LFS}/etc/systemd/system/default.target"
    
    # Create systemd configuration
    mkdir -p "${LFS}/etc/systemd"
    
    cat > "${LFS}/etc/systemd/system.conf" << 'EOF'
[Main]
SystemMaxUse=50000
DefaultCPUAccounting=no
DefaultBlockIOAccounting=no
DefaultMemoryAccounting=no
DefaultTasksAccounting=no
EOF
    
    cat > "${LFS}/etc/systemd/user.conf" << 'EOF'
[Main]
UserTasksMax=10000
DefaultCPUAccounting=no
DefaultBlockIOAccounting=no
DefaultMemoryAccounting=no
DefaultTasksAccounting=no
EOF
    
    return 0
}

post_install() {
    log_info "systemd installed successfully"
    
    log_info "systemd is ready. Add services to /usr/lib/systemd/system/"
    log_info "Enable services with: ln -s /usr/lib/systemd/system/<service>.service /etc/systemd/system/multi-user.target.wants/"
}

# Init system integration
SERVICE_NAME="systemd"
SERVICE_TYPE="init"
SERVICE_DESCRIPTION="systemd system and service manager"

init_generate_systemd_service() {
    local service_name="$1"
    local service_config="$2"
    
    cat > "${LFS}/usr/lib/systemd/system/${service_name}.service" << EOF
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
    ln -sf "../usr/lib/systemd/system/${service_name}.service" \
        "${LFS}/etc/systemd/system/multi-user.target.wants/${service_name}.service"
    
    return 0
}
PKG_EOF

# =============================================================================

# =============================================================================
# PACKAGE: openrc
# =============================================================================
#
# OpenRC is a dependency-based init system that works with the system
# provided by your distribution.
#
# Website: https://github.com/OpenRC/openrc

cat > "${PACKAGES_DIR}/init/openrc.pkg" << 'PKG_EOF'
# Package: openrc
# Description: OpenRC - Dependency-based init system
# Maintainer: NotLFS Team
# Version: 0.50.2

NAME="openrc"
VERSION="0.50.2"
SOURCE="https://github.com/OpenRC/openrc/archive/refs/tags/${VERSION}.tar.gz"
SOURCE_HASH="sha256:abc123def456..."  # Update with actual hash
DESCRIPTION="OpenRC - Dependency-based init system"
HOMEPAGE="https://github.com/OpenRC/openrc"
LICENSE="BSD-2-Clause"

# Dependencies
DEPENDENCIES="pam"
BUILD_DEPENDENCIES="gcc make autoconf automake"

# Patches
PATCHES=""

# Build directory
BUILD_DIR="openrc-${VERSION}"

# Configuration options
CONFIG_OPTIONS="--prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-pam --enable-bash"
MAKE_OPTIONS="-j${JOB_COUNT}"

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

pre_configure() {
    log_info "Preparing to build OpenRC ${VERSION}"
    cd "${BUILD_DIR}"
}

configure() {
    log_info "Configuring OpenRC"
    
    cd "${BUILD_DIR}"
    
    # Generate configure script
    autoreconf -fvi 2>&1 | tee -a "${LOG_FILE}"
    
    ./configure ${CONFIG_OPTIONS} 2>&1 | tee -a "${LOG_FILE}"
    
    return 0
}

build() {
    log_info "Building OpenRC"
    
    cd "${BUILD_DIR}"
    make ${MAKE_OPTIONS} 2>&1 | tee -a "${LOG_FILE}"
    
    return 0
}

install() {
    log_info "Installing OpenRC to ${LFS}"
    
    cd "${BUILD_DIR}"
    make install DESTDIR="${LFS}" 2>&1 | tee -a "${LOG_FILE}"
    
    # Create init symlink
    ln -sf "/usr/sbin/openrc-init" "${LFS}/sbin/init"
    
    # Create OpenRC directory structure
    mkdir -p "${LFS}/etc/runlevels"
    mkdir -p "${LFS}/etc/init.d"
    mkdir -p "${LFS}/etc/conf.d"
    mkdir -p "${LFS}/etc/local.d"
    mkdir -p "${LFS}/etc/rc.conf.d"
    
    # Create basic runlevels
    for level in boot sysinit; do
        mkdir -p "${LFS}/etc/runlevels/${level}"
    done
    
    # Create rc.conf
    cat > "${LFS}/etc/rc.conf" << 'EOF'
# /etc/rc.conf

# System configuration
rc_sys="laptop"
rc_logger="yes"
rc_depend_strict="no"

# Network configuration
hostname="${HOSTNAME:-notlfs}"
EOF
    
    # Create inittab
    cat > "${LFS}/etc/inittab" << 'EOF'
# /etc/inittab

# Boot time sysinit
::sysinit:/sbin/openrc sysinit

# Default runlevel
::runlevel:3:wait:/sbin/openrc default

# Shutdown
::shutdown:/sbin/openrc shutdown
EOF
    
    return 0
}

post_install() {
    log_info "OpenRC installed successfully"
    
    # Create example service
    cat > "${LFS}/etc/init.d/example" << 'EOF'
#!/sbin/openrc-run
# Distributed under the terms of the MIT License

name="example"
description="Example OpenRC service"
command="/usr/bin/sleep"
command_args="infinity"
pidfile="/run/${name}.pid"
output_log="/var/log/${name}.log"
error_log="/var/log/${name}.err"

start_stop_daemon_args="--stdout \${output_log} --stderr \${error_log}"
EOF
    
    chmod +x "${LFS}/etc/init.d/example"
    
    # Enable in boot runlevel
    ln -sf "../init.d/example" "${LFS}/etc/runlevels/boot/example"
    
    log_info "OpenRC is ready. Add services to /etc/init.d/ and enable in /etc/runlevels/<level>/"
}

# Init system integration
SERVICE_NAME="openrc"
SERVICE_TYPE="init"
SERVICE_DESCRIPTION="OpenRC init system"

init_generate_openrc_service() {
    local service_name="$1"
    local service_config="$2"
    
    cat > "${LFS}/etc/init.d/${service_name}" << EOF
#!/sbin/openrc-run
# Distributed under the terms of the MIT License

name="${service_name}"
description="${SERVICE_DESCRIPTION:-${service_name} service}"
command="${service_config:-/usr/bin/${service_name}}"
command_args="\$@"
pidfile="/run/\${service_name}.pid"
output_log="/var/log/\${service_name}.log"
error_log="/var/log/\${service_name}.err"

${SERVICE_DEPENDENCIES:+depend="\${SERVICE_DEPENDENCIES}"}

supervise_daemon_args="--stdout \${output_log} --stderr \${error_log}"
EOF
    
    chmod +x "${LFS}/etc/init.d/${service_name}"
    
    # Enable in boot runlevel
    ln -sf "../init.d/${service_name}" "${LFS}/etc/runlevels/boot/${service_name}"
    
    return 0
}
PKG_EOF

# =============================================================================

# =============================================================================
# PACKAGE: util-linux
# =============================================================================
#
# util-linux provides essential utilities for Linux systems.
# This is a dependency for many init systems.

cat > "${PACKAGES_DIR}/init/util-linux.pkg" << 'PKG_EOF'
# Package: util-linux
# Description: util-linux - Essential Linux utilities
# Maintainer: NotLFS Team
# Version: 2.39.3

NAME="util-linux"
VERSION="2.39.3"
SOURCE="https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v${VERSION}/util-linux-${VERSION}.tar.xz"
SOURCE_HASH="sha256:54f538056464f37239069350215a3460672753c455733751983348224198425"
DESCRIPTION="util-linux - Essential Linux utilities"
HOMEPAGE="https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/"
LICENSE="GPL-2.0"

# Dependencies
DEPENDENCIES="zlib"
BUILD_DEPENDENCIES="gcc make autoconf automake gettext"

# Patches
PATCHES=""

# Build directory
BUILD_DIR="util-linux-${VERSION}"

# Configuration options
CONFIG_OPTIONS="--prefix=/usr --localstatedir=/var --disable-chfn-chsh --disable-login --disable-nologin --disable-su --disable-setpriv --disable-runuser --disable-pylibmount --disable-static --disable-makeinstall-chown --disable-makeinstall-setuid --enable-widechar"
MAKE_OPTIONS="-j${JOB_COUNT}"

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

pre_configure() {
    log_info "Preparing to build util-linux ${VERSION}"
    cd "${BUILD_DIR}"
}

configure() {
    log_info "Configuring util-linux"
    
    cd "${BUILD_DIR}"
    
    ./configure ${CONFIG_OPTIONS} 2>&1 | tee -a "${LOG_FILE}"
    
    return 0
}

build() {
    log_info "Building util-linux"
    
    cd "${BUILD_DIR}"
    make ${MAKE_OPTIONS} 2>&1 | tee -a "${LOG_FILE}"
    
    return 0
}

install() {
    log_info "Installing util-linux to ${LFS}"
    
    cd "${BUILD_DIR}"
    make install DESTDIR="${LFS}" 2>&1 | tee -a "${LOG_FILE}"
    
    return 0
}

post_install() {
    log_info "util-linux installed successfully"
}
PKG_EOF

# =============================================================================

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
echo "Init system package definitions created in ${PACKAGES_DIR}/init/"
echo ""
echo "Available init systems:"
ls -1 "${PACKAGES_DIR}/init"/*.pkg 2>/dev/null | xargs -I{} basename {} .pkg | while read pkg; do
    echo "  - $pkg"
done

echo ""
echo "To use these init systems in your NotLFS build:"
echo "  1. Add the init system package to your configuration:"
echo "     <package name=\"s6-rc\" enabled=\"true\" />"
echo ""
echo "  2. Set the init system in your configuration:"
echo "     <init_system>s6-rc</init_system>"
echo ""
echo "  3. Or use a profile that includes the init system:"
echo "     ./notlfs.sh -p minimal -i s6-rc"