# NotLFS: Modular Linux Build Framework

> **NotLFS** (Not Linux From Scratch) is a smart, extensible framework for building custom Linux systems from source, with multi-init system support.

---

## 🎯 **Overview**

NotLFS is a **meta-build system** that automates the process of building a Linux distribution from source code, inspired by Linux From Scratch (LFS) but with modern features and extensive customization options.

### **Key Differences from LFS**


| Feature               | LFS           | NotLFS                                           |
| --------------------- | ------------- | ------------------------------------------------ |
| Build automation      | Manual        | ✅ Automated                                      |
| Init system support   | sysv or now systemd🤮 only     | ✅ s6, s6-rc, dinit, runit, sysv, systemd, openrc |
| Package management    | Manual        | ✅ Modular .pkg files                             |
| Build profiles        | ❌ None        | ✅ Minimal, Base, Desktop, Server                 |
| Service management    | ❌ Manual      | ✅ Auto-generated for each init system            |
| Configuration         | ❌ Manual      | ✅ XML config with hooks                          |
| Dependency resolution | ❌ Manual      | ✅ Automatic                                      |
| Build modes           | ❌ Manual only | ✅ Auto, Interactive, Manual                      |


### **Philosophy**

NotLFS aims to provide:

- **Flexibility**: Choose your init system, packages, and build process
- **Automation**: Reduce repetitive manual steps while maintaining control
- **Education**: Learn how Linux systems work under the hood
- **Extensibility**: Easy to add new packages and customize builds
- **Smart defaults**: Sensible defaults with the ability to override everything
- **For Newbies**: A lot easier to setup for newbies in the linux community that want their 'own' distro
  
---

## 🚀 **Quick Start**

### **1. Initialize the Framework**

```bash
# Clone or download NotLFS
cd /path/to/notlfs

# Make the main script executable
chmod +x notlfs.sh

# Initialize (creates directories and default config)
./notlfs.sh init
```

### **2. Choose a Build Profile**

NotLFS comes with predefined profiles:


| Profile   | Description            | Init System | Packages |
| --------- | ---------------------- | ----------- | -------- |
| `minimal` | Barebones system       | s6-rc       | ~20      |
| `base`    | Development system     | s6-rc       | ~50      |
| `desktop` | GUI-enabled system     | s6-rc       | ~100     |
| `server`  | Server-oriented system | runit       | ~60      |


```bash
# List available profiles
./notlfs.sh list-profiles

# Select a profile
./notlfs.sh -p desktop
```

### **3. Choose an Init System**

Supported init systems:


| Init System | Description                  | Complexity | Recommended |
| ----------- | ---------------------------- | ---------- | ----------- |
| **s6-rc**   | s6 with rc, dependency-based | Medium     | ✅ Yes       |
| **s6**      | Minimalist supervision suite | Low        | ⚠️ Advanced |
| **dinit**   | Dependency-based supervisor  | Medium     | ✅ Yes       |
| **runit**   | Service supervisor           | Low        | ✅ Yes       |
| **sysv**    | Traditional SysV init        | Low        | ⚠️ Legacy   |
| **systemd** | Full-featured system manager | High       | ⚠️ Heavy and is systemd 🤮   |
| **openrc**  | Dependency-based init        | Medium     | ✅ Yes       |


```bash
# List supported init systems
./notlfs.sh list-inits

# Select an init system
./notlfs.sh -i s6-rc
```

### **4. Start the Build**

```bash
# Interactive mode (recommended for first use)
./notlfs.sh -p base -i s6-rc -m interactive

# Auto mode (unattended)
./notlfs.sh -p minimal -i runit -m auto

# Manual mode (step-by-step)
./notlfs.sh -m manual
```

---

## 📁 **Directory Structure**

```
notlfs/
├── notlfs.sh                    # Main controller script
├── configs/
│   └── notlfs.xml               # Default XML configuration
├── profiles/
│   ├── minimal/
│   │   └── profile.xml          # Minimal system profile
│   ├── base/
│   │   └── profile.xml          # Base system profile
│   ├── desktop/
│   │   └── profile.xml          # Desktop system profile
│   └── server/
│       └── profile.xml          # Server system profile
├── packages/
│   ├── init/                    # Init system packages
│   │   ├── s6.pkg
│   │   ├── s6-rc.pkg
│   │   ├── dinit.pkg
│   │   ├── runit.pkg
│   │   ├── sysvinit.pkg
│   │   ├── systemd.pkg
│   │   └── openrc.pkg
│   ├── binutils.pkg
│   ├── gcc.pkg
│   ├── glibc.pkg
│   └── ...
├── init/
│   ├── systems/                 # Init system templates
│   │   ├── s6/
│   │   │   └── install.sh
│   │   ├── s6-rc/
│   │   │   └── install.sh
│   │   └── ...
│   └── services/                # Service templates
│       ├── s6/
│       ├── s6-rc/
│       └── ...
├── build/                      # Build artifacts
│   ├── tools/                  # Temporary toolchain
│   ├── build/                  # Package build directories
│   ├── sources/                # Downloaded sources
│   └── notlfs/                 # Final system root
├── logs/                       # Build logs
│   ├── binutils.log
│   ├── gcc.log
│   └── ...
├── sources/                    # Downloaded source archives
├── cache/                      # Cached source files
└── output/                     # Build outputs
```

---

## 📝 **Configuration**

### **XML Configuration File**

The main configuration file (`configs/notlfs.xml`) defines your entire system build.

#### **Basic Structure**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<notlfs>
    <!-- System Configuration -->
    <system>
        <name>my-system</name>
        <architecture>x86_64</architecture>
        <jobs>4</jobs>
        <hostname>notlfs</hostname>
        <timezone>UTC</timezone>
        <locale>en_US.UTF-8</locale>
    </system>
    
    <!-- Build Settings -->
    <build>
        <mode>interactive</mode>
        <profile>base</profile>
        <init_system>s6-rc</init_system>
        <optimization>-O2 -pipe</optimization>
        <strip_debug>false</strip_debug>
    </build>
    
    <!-- Package Selection -->
    <packages>
        <category name="core" enabled="true">
            <package name="binutils" enabled="true" />
            <package name="gcc" enabled="true" />
            <!-- ... -->
        </category>
        <category name="init" enabled="true">
            <package name="s6-rc" enabled="true" />
        </category>
    </packages>
    
    <!-- Service Configuration -->
    <services>
        <service name="sshd" enabled="true" runlevel="default" />
        <service name="dhcpcd" enabled="false" runlevel="default" />
    </services>
    
    <!-- Custom Hooks -->
    <hooks>
        <hook stage="pre-build">
            echo "Build started at $(date)"
        </hook>
    </hooks>
</notlfs>
```

#### **Configuration Sections**

##### **System Configuration**


| Element          | Description             | Default         |
| ---------------- | ----------------------- | --------------- |
| `name`           | System name             | `notlfs-system` |
| `architecture`   | CPU architecture        | `x86_64`        |
| `jobs`           | Parallel build jobs     | `$(nproc)`      |
| `hostname`       | System hostname         | `notlfs`        |
| `root_password`  | Root password           | `changeme`      |
| `timezone`       | System timezone         | `UTC`           |
| `locale`         | System locale           | `en_US.UTF-8`   |
| `kernel_version` | Kernel version to build | `6.6.0`         |


##### **Build Settings**


| Element              | Description                          | Default                   |
| -------------------- | ------------------------------------ | ------------------------- |
| `mode`               | Build mode (auto/manual/interactive) | `interactive`             |
| `profile`            | Build profile to use                 | `base`                    |
| `init_system`        | Init system to install               | `s6-rc`                   |
| `download_mirror`    | Primary download mirror              | `https://ftp.gnu.org/gnu` |
| `optimization`       | Compiler optimization flags          | `-O2 -pipe`               |
| `strip_debug`        | Strip debug symbols                  | `false`                   |
| `keep_sources`       | Keep downloaded sources              | `false`                   |
| `parallel_downloads` | Number of parallel downloads         | `4`                       |
| `build_timeout`      | Build timeout in seconds             | `3600`                    |


##### **Security Hardening**


| Element            | Description               | Default |
| ------------------ | ------------------------- | ------- |
| `enable_hardening` | Enable security hardening | `true`  |
| `stack_protector`  | Enable stack protector    | `true`  |
| `fortify_source`   | Enable fortify source     | `true`  |
| `relro`            | Enable RELRO              | `true`  |
| `aslr`             | Enable ASLR               | `true`  |
| `noexec_stack`     | Enable no-exec stack      | `true`  |
| `pie`              | Enable PIE                | `true`  |


##### **Network Configuration**


| Element       | Description      | Default           |
| ------------- | ---------------- | ----------------- |
| `hostname`    | Network hostname | `notlfs`          |
| `domain`      | Network domain   | `local`           |
| `enable_dhcp` | Enable DHCP      | `true`            |
| `nameservers` | DNS nameservers  | `8.8.8.8 8.8.4.4` |


##### **Package Selection**

Packages are organized into **categories** for easier management:

```xml
<packages>
    <!-- Enable entire category -->
    <category name="core" enabled="true">
        <package name="binutils" enabled="true" />
        <package name="gcc" enabled="true" />
        <!-- ... -->
    </category>
    
    <!-- Or enable individual packages -->
    <category name="init" enabled="true">
        <package name="s6-rc" enabled="true" />
    </category>
    
    <!-- Disable a specific package in a category -->
    <category name="utils" enabled="true">
        <package name="vim" enabled="false" />
    </category>
</packages>
```

**Predefined Categories:**


| Category    | Description               | Packages                                           |
| ----------- | ------------------------- | -------------------------------------------------- |
| `core`      | Essential system packages | binutils, gcc, glibc, bash, coreutils, etc.        |
| `init`      | Init system packages      | s6, s6-rc, dinit, runit, sysvinit, systemd, openrc |
| `dev`       | Development tools         | autoconf, automake, bison, flex, git, etc.         |
| `utils`     | Utility programs          | curl, wget, less, man-db, vim, nano, etc.          |
| `network`   | Network utilities         | openssl, openssh, iproute2, dhcpcd, etc.           |
| `desktop`   | Desktop packages          | mesa, xorg-server, wayland, sway, etc.             |
| `languages` | Language runtimes         | python, nodejs, lua, ruby, go, rust                |


##### **Service Configuration**

```xml
<services>
    <service name="sshd" enabled="true" runlevel="default" />
    <service name="dhcpcd" enabled="false" runlevel="default" />
    <service name="cronie" enabled="false" runlevel="2" />
</services>
```

##### **Custom Hooks**

Hooks are commands that run at specific stages of the build process:

```xml
<hooks>
    <hook stage="pre-build">
        echo "Starting build at $(date)"
        mkdir -p /tmp/notlfs-build
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
        echo "Init system configured"
    </hook>
    
    <hook stage="pre-packages">
        echo "Installing additional packages..."
    </hook>
    
    <hook stage="post-install">
        echo "All packages installed successfully"
        echo "Build completed at $(date)"
    </hook>
</hooks>
```

**Available Hook Stages:**

- `pre-build` - Before any building starts
- `pre-toolchain` - Before building the temporary toolchain
- `post-toolchain` - After building the temporary toolchain
- `pre-system` - Before building the base system
- `post-system` - After building the base system
- `pre-init-system` - Before configuring the init system
- `post-init-system` - After configuring the init system
- `pre-packages` - Before installing custom packages
- `post-packages` - After installing custom packages
- `pre-system-config` - Before final system configuration
- `post-system-config` - After final system configuration
- `post-install` - After everything is complete

##### **Environment Variables**

```xml
<environment>
    <variable name="CFLAGS">-O2 -pipe</variable>
    <variable name="CXXFLAGS">-O2 -pipe</variable>
    <variable name="LDFLAGS"></variable>
    <variable name="MAKEFLAGS">-j4</variable>
</environment>
```

### **Build Profiles**

Profiles are predefined package sets with specific configurations.

#### **Profile Structure**

Each profile is defined in `profiles/<name>/profile.xml`:

```xml
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
```

#### **Creating a Custom Profile**

```bash
# Create a new profile
./notlfs.sh add-profile my-profile

# Edit the profile
nano profiles/my-profile/profile.xml

# Use the profile
./notlfs.sh -p my-profile
```

#### **Profile Features**


| Feature       | Description                                  |
| ------------- | -------------------------------------------- |
| `minimal`     | Minimal system with only essential packages  |
| `network`     | Enable network-related packages and services |
| `development` | Include development tools and headers        |
| `gui`         | Include GUI-related packages                 |
| `audio`       | Include audio-related packages               |
| `server`      | Include server-related packages              |


---

## 📦 **Package Definitions**

### **Package Definition Format**

Each package is defined in a `.pkg` file in the `packages/` directory or a subdirectory (for categories).

**Basic Structure:**

```bash
# Package metadata
NAME="package-name"
VERSION="1.0.0"
SOURCE="https://example.com/package-1.0.0.tar.xz"
SOURCE_HASH="sha256:abc123..."
DESCRIPTION="Package description"
HOMEPAGE="https://example.com"
LICENSE="GPL-3.0"

# Dependencies
DEPENDENCIES="dep1 dep2 dep3"
BUILD_DEPENDENCIES="build-dep1 build-dep2"
RDEPENDENCIES="reverse-dep1 reverse-dep2"
CONFLICTS="conflicting-pkg1 conflicting-pkg2"

# Source configuration
PATCHES="patch1.patch patch2.patch"
BUILD_DIR="package-1.0.0"
SOURCE_SUBDIR="source-subdir"

# Build configuration
CONFIG_OPTIONS="--prefix=/usr --sysconfdir=/etc"
MAKE_OPTIONS="-j${JOB_COUNT}"
INSTALL_OPTIONS=""
TEST_COMMAND="make check"

# Service configuration (for init systems)
SERVICE_NAME="service-name"
SERVICE_TYPE="simple"  # simple, fork, oneshot, etc.
SERVICE_DESCRIPTION="Service description"
SERVICE_DEPENDENCIES="dep1 dep2"
SERVICE_AFTER="service1 service2"
SERVICE_BEFORE="service3 service4"

# Build phase functions
pre_configure() {
    # Custom pre-configure steps
    return 0
}

configure() {
    # Custom configure step
    ./configure ${CONFIG_OPTIONS} 2>&1 | tee -a "${LOG_FILE}"
    return 0
}

build() {
    # Custom build step
    make ${MAKE_OPTIONS} 2>&1 | tee -a "${LOG_FILE}"
    return 0
}

install() {
    # Custom install step
    make install ${INSTALL_OPTIONS} 2>&1 | tee -a "${LOG_FILE}"
    return 0
}

# Init system integration
init_generate_s6_service() {
    # Generate service file for s6
    return 0
}

init_generate_dinit_service() {
    # Generate service file for dinit
    return 0
}
```

### **Package Definition Fields**


| Field                | Required | Description                                         |
| -------------------- | -------- | --------------------------------------------------- |
| `NAME`               | ✅ Yes    | Package name (used for references)                  |
| `VERSION`            | ✅ Yes    | Package version                                     |
| `SOURCE`             | ✅ Yes    | URL to source archive                               |
| `SOURCE_HASH`        | ❌ No     | Expected hash (sha256, sha512, md5)                 |
| `DESCRIPTION`        | ❌ No     | Human-readable description                          |
| `HOMEPAGE`           | ❌ No     | Project homepage URL                                |
| `LICENSE`            | ❌ No     | Software license                                    |
| `DEPENDENCIES`       | ❌ No     | Runtime dependencies (space-separated)              |
| `BUILD_DEPENDENCIES` | ❌ No     | Build-time dependencies (space-separated)           |
| `RDEPENDENCIES`      | ❌ No     | Reverse dependencies (packages that depend on this) |
| `CONFLICTS`          | ❌ No     | Conflicting packages (space-separated)              |
| `PATCHES`            | ❌ No     | Patches to apply (space-separated)                  |
| `BUILD_DIR`          | ❌ No     | Subdirectory for build (default: source root)       |
| `SOURCE_SUBDIR`      | ❌ No     | Source subdirectory in archive                      |
| `CONFIG_OPTIONS`     | ❌ No     | Options for ./configure                             |
| `MAKE_OPTIONS`       | ❌ No     | Options for make                                    |
| `INSTALL_OPTIONS`    | ❌ No     | Options for make install                            |
| `TEST_COMMAND`       | ❌ No     | Command to run tests                                |


### **Build Phase Functions**

The following functions can be overridden for custom build steps:


| Function           | When Called                 | Purpose                        |
| ------------------ | --------------------------- | ------------------------------ |
| `pre_download()`   | Before downloading source   | Pre-download setup             |
| `post_download()`  | After downloading source    | Post-download setup            |
| `pre_extract()`    | Before extracting source    | Pre-extraction setup           |
| `post_extract()`   | After extracting source     | Post-extraction setup          |
| `pre_patch()`      | Before applying patches     | Pre-patching setup             |
| `post_patch()`     | After applying patches      | Post-patching setup            |
| `pre_configure()`  | Before running configure    | Pre-configure setup            |
| `configure()`      | Configure step              | Run ./configure or equivalent  |
| `post_configure()` | After running configure     | Post-configure setup           |
| `pre_build()`      | Before running make         | Pre-build setup                |
| `build()`          | Build step                  | Run make or equivalent         |
| `post_build()`     | After running make          | Post-build setup               |
| `pre_install()`    | Before running make install | Pre-install setup              |
| `install()`        | Install step                | Run make install or equivalent |
| `post_install()`   | After running make install  | Post-install setup             |
| `test()`           | After successful build      | Run tests                      |


### **Init System Integration Functions**

For each init system, you can override service generation:


| Function                          | Init System | Purpose                          |
| --------------------------------- | ----------- | -------------------------------- |
| `init_generate_s6_service()`      | s6, s6-rc   | Generate s6 service directory    |
| `init_generate_dinit_service()`   | dinit       | Generate dinit service file      |
| `init_generate_runit_service()`   | runit       | Generate runit service directory |
| `init_generate_sysv_service()`    | sysv        | Generate SysV init script        |
| `init_generate_systemd_service()` | systemd     | Generate systemd unit file       |
| `init_generate_openrc_service()`  | openrc      | Generate OpenRC init script      |


### **Creating a New Package**

```bash
# Create a new package template
./notlfs.sh add-package my-package

# Or create in a specific category
./notlfs.sh add-package my-package utils

# Edit the package definition
nano packages/utils/my-package.pkg

# Add the package to your configuration
# Edit configs/notlfs.xml and add:
# <package name="my-package" enabled="true" />
```

### **Package Categories**

Packages can be organized into categories by placing them in subdirectories:

```
packages/
├── core/
│   ├── binutils.pkg
│   ├── gcc.pkg
│   └── glibc.pkg
├── init/
│   ├── s6.pkg
│   ├── dinit.pkg
│   └── runit.pkg
├── utils/
│   ├── vim.pkg
│   ├── curl.pkg
│   └── wget.pkg
└── my-package.pkg  # Uncategorized
```

---

## 🎛️ **Init Systems**

### **Overview**

NotLFS supports **8 different init systems**, each with its own philosophy and approach to service management.


| Init System | Type            | Philosophy                   | Complexity | Best For                       |
| ----------- | --------------- | ---------------------------- | ---------- | ------------------------------ |
| **s6**      | Supervisor      | Minimalist, dependency-free  | Low        | Embedded, minimal systems      |
| **s6-rc**   | Supervisor + RC | Dependency-based, flexible   | Medium     | **Recommended** for most users |
| **dinit**   | Service Manager | Dependency-based, robust     | Medium     | Servers, desktops              |
| **runit**   | Supervisor      | Simple, reliable             | Low        | Servers, containers            |
| **sysv**    | Traditional     | Legacy, compatible           | Low        | Legacy systems                 |
| **systemd** | System Manager  | Full-featured, integrated    | High       | Desktops, servers              |
| **openrc**  | Service Manager | Dependency-based, compatible | Medium     | Gentoo-like systems            |


### **Choosing an Init System**

#### **s6 (Recommended for Minimalism)**

- **Pros**: Very small, no dependencies, secure, simple
- **Cons**: Manual service management, no dependency tracking
- **Best for**: Embedded systems, minimal installations, security-focused systems

```bash
./notlfs.sh -i s6
```

#### **s6-rc (Recommended for Most Users)**

- **Pros**: Dependency-based, flexible, lightweight, powerful
- **Cons**: Slightly more complex than plain s6
- **Best for**: Most systems, servers, desktops

```bash
./notlfs.sh -i s6-rc
```

#### **dinit (Recommended for Simplicity)**

- **Pros**: Dependency-based, clean design, good documentation
- **Cons**: Less widely used
- **Best for**: Servers, desktops, users who want dependency-based startup

```bash
./notlfs.sh -i dinit
```

#### **runit (Recommended for Reliability)**

- **Pros**: Simple, reliable, proven in production (Void Linux)
- **Cons**: No built-in dependency tracking
- **Best for**: Servers, containers, reliability-focused systems

```bash
./notlfs.sh -i runit
```

#### **sysv (For Legacy Compatibility)**

- **Pros**: Well-known, compatible with many scripts
- **Cons**: Slow, no dependency tracking, outdated