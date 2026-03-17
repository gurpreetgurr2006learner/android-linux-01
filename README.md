# Termux Linux Premium Setup & RDP Scripts

> **Author:** [abzach8](https://github.com/abzach8)

## Part 1: Simple Steps to Set Up

This repository provides scripts to install and run a hardware-accelerated Linux Desktop Environment inside **Termux** on an Android device, accessible locally through **Termux:X11** or remotely via an **RDP Client**.

**1. Prerequisites:**
- Install **Termux** from F-Droid (NOT the Google Play Store).
- Install **Termux:X11** (`app-arm64-v8a-debug.apk`) from the nightly GitHub releases.

**2. Clone and Prepare:**
Open Termux and run:
```bash
pkg update -y
termux-setup-storage
git clone https://github.com/gurpreetgurr2006learner/android-linux-01.git
cd android-linux-01
chmod +x *.sh
```

**3. Run the Installer:**
```bash
./install.sh
```
Follow the interactive prompts to select your Desktop Environment (XFCE4, LXQt, MATE, or KDE Plasma) and enter a VNC password when asked. This password will be used for your RDP connections.

**(Alternative Silent Setup):** Run `./setup.sh` instead for an idempotent, silent XFCE4 installation. It also pre-installs AI CLI tools like OpenCode AI and OpenClaw.

**4. Start the Desktop:**
```bash
./start.sh
```
The script will output your phone's Wi-Fi IP address.

**5. Connect!**
- **Locally:** Open the Termux:X11 app on your phone.
- **Remotely:** From a PC on the same Wi-Fi network, open an RDP client and connect to `<phone-ip>:3389`. Log in using any username and the VNC password you set earlier.

**6. Stop the Desktop:**
When finished, stop all processes safely to save battery:
```bash
./stop.sh
```

---

## Part 2: Overview of Documented Topics & Sections

This repository encapsulates not only installation scripts, but a rich matrix of documentation covering what works and what doesn't inside Android's Termux ecosystem.

The core modules and concepts detailed in our environment include:
- **Core Scripting Matrix:** Four primary scripts (`install.sh`, `setup.sh`, `start.sh`, `stop.sh`) manage the environment lifecycle from fetching dependencies to bringing up TigerVNC, xrdp, audio, and the display manager natively.
- **Hardware Acceleration:** Native GPU capability (Freedreno/Turnip for Adreno and Zink fallback) is wired into the scripts ensuring smooth desktop performance on Android hardware.
- **Termux Runtime Limitations:** Explanations of how Android deviates from standard Linux. Covering concepts like why some Debian packages fail, the absence of `systemd`, and how Termux's non-standard file system (Prefix) limits paths.
- **Security & Sandboxing:** Documentation on Android's rigid permissions, covering restricted `/proc/net` access, process isolation (`hidepid=2`), and external storage behaviors.
- **AI Tooling Integration:** Native installation and configuration of `opencode-ai` and `openclaw`, including necessary Node.js network patching to ensure they run seamlessly under Android network constraints.
- **Phantom Process Killing:** Insight on Android 12+ aggressive task termination algorithms and how it affects background development chains inside Termux.

---

## Part 3: AI Agent Reference & Developer Specifications

**ATTENTION AI AGENTS:** Read these rules carefully before generating, editing, or validating any code blocks for the `.sh` scripts (`install.sh`, `setup.sh`, `start.sh`, `stop.sh`) within this repository. Termux on Android operates under strict, idiosyncratic constraints that differ heavily from standard FHS-compliant Linux distributions. 

### 1. General Architectural Rules
- **Environment:** Code executes natively inside **Termux**. Do not assume a root environment unless conditionally checking for it. Scripts must primarily operate in a non-root environment.
- **Package Management:** Use `pkg install <package>` instead of `apt install` or `apt-get` for native userland tools. Termux handles `pkg` wrappers gracefully. Do NOT try to install standard Debian/Ubuntu `.deb` packages using `dpkg` directly into the Termux host due to libc (glibc vs Bionic) incompatibilities.
- **Paths & FHS Non-Compliance:** Standard paths like `/usr/bin`, `/bin`, `/etc`, and `/tmp` **DO NOT EXIST** natively in Termux. Termux utilizes `$PREFIX` (e.g., `/data/data/com.termux/files/usr`). Always rely on relative paths or `PREFIX` environment variables. If you must use absolute paths, use standard POSIX `command -v` to locate binaries instead of hardcoding `/bin/bash` or `/usr/bin/env`.
- **Shebangs:** Always use `#!/usr/bin/env bash` or `#!/data/data/com.termux/files/usr/bin/bash`. Never use `#!/bin/bash`.

### 2. Service and Init System Constraints
- **NO systemd or udev:** Android does not use `systemd`, `SysV init`, or `udev`. You CANNOT use `systemctl`, `service`, `journalctl`, or udev rules to manage daemon states. 
- **Daemon Management:** Daemons (e.g., xrdp, vncserver, pulseaudio) must be started directly as background processes and terminated by finding their specific PIDs or using tailored `pkill` flags. Ensure `start.sh` gracefully handles lingering socket / PID files and `stop.sh` diligently issues `kill` commands to clean up.
- **Phantom Processes:** Android 12+ aggressively monitors and kills apps with "Phantom Processes" (typically > 32 sub-processes). Avoid writing scripts that inadvertently spawn excessively deep process trees or excessive concurrent workers.

### 3. Permissions & System Access Limitations
- **Procfs Reading (`/proc`):** Android limits unprivileged apps from reading standard process states.
  - Commands like `ps` will **only** show Termux's own processes.
  - Do not write scripts that assume `ps -ef | grep <target>` can find arbitrary Android system services.
- **Networking (`/proc/net`):** Android 10+ severely restricts reading from `/proc/net`.
  - Tools like `netstat`, `ifconfig`, and `ip` may fail entirely or return blank outputs.
  - If your script requires IP retrieval, rely on `ip addr show` carefully, but handle cases where access is denied. (Currently, `ip addr show wlan0 | grep 'inet '` works in localized contexts, but never assume broad network interface manipulation).
- **Storage:** Termux has limited external storage access. `termux-setup-storage` must be run to access `~/storage`. Executable files and Unix sockets normally cannot reside on Android's shared storage (e.g. `/sdcard`); keep structural configuration files and scripts strictly inside `~` or `$PREFIX`.

### 4. Hardware and Display Configuration
- **Termux:X11 & VNC:** Display routing involves two layers: VNC (often on `:1` mapping port `5901`) and Termux:X11 (often on `:0`). xrdp uses VNC as its backend via `xrdp.ini`. When generating configurations for `install.sh` or `setup.sh`:
  - Ensure X11 sockets are cleaned up correctly in `/tmp/.X11-unix/` (which in Termux maps to `$PREFIX/tmp/.X11-unix/`).
  - Configure TigerVNC properly ensuring `~/.vnc/xstartup` executes the correct desktop session (e.g., `startxfce4`).
- **GPU Acceleration:** Scripts should detect GPUs using `getprop` or standard `glxinfo` checks. Native Turnip/Zink driver mapping operates via `~/.config/linux-gpu.sh` or similar injection variables. Maintain these environment variables (`MESA_LOADER_DRIVER_OVERRIDE`, `GALLIUM_DRIVER`, etc.) carefully.

### 5. Script Idempotency and Robustness
- **`install.sh` & `setup.sh`:** Must handle existing configurations without breaking. Detect if a package is already installed before downloading heavily. Use flags like `CI=true` to prevent interactive prompts (e.g. `npm install -g`).
- **`start.sh`:** Must perform pre-flight checks (clearing `.X*` locks, `.vnc/*.pid` files, `.xrdp` stale endpoints) before launching components.
- **`stop.sh`:** Must be thorough. Hunt and terminate `xrdp`, `xrdp-sesman`, `Xvnc`, `pulseaudio`, `dbus-launch`, and the specific Session Manager processes cleanly. 
- **Error Handling Details:** Prefer `set -eo pipefail` but carefully consider `set -u` (unbound variable errors) as sourced configurations (like `linux-gpu.sh`) may rely on unset variables. Use traps to catch signals and fail cleanly.

By adhering to these rules, scripts will guarantee stable, optimized configurations within the specialized Linux containerization of Android's Termux.

---

## Part 4: Command Support and Limitations in Termux on Android

### Executive Overview
Termux is an Android terminal application and Linux environment that provides a packaged userland. It is not a conventional Linux distribution and runs under Android’s app sandbox. Packages are compiled with the Android NDK against Android’s Bionic C library and installed in Termux’s private prefix rather than standard FHS paths such as `/bin` or `/usr`. As a result, binaries built for conventional Linux distributions generally cannot run directly inside Termux unless they are rebuilt or adapted for this environment.

### 1. Structural Limitations
- **Non-FHS Filesystem & Bionic libc:** Termux binaries are linked against Bionic (Android's libc) rather than glibc. Attempting to use foreign distro packages (like Debian/Ubuntu `.deb` files) directly will usually fail.
- **Android Sandboxing & `/proc` constraints:** Android isolates apps using Linux UIDs and mounts `/proc` with `hidepid=2`. This limits tools like `ps` to only showing Termux's own processes.
- **Networking (`/proc/net`):** On Android 10+, apps cannot access `/proc/net`, which means tools like `netstat` and `ifconfig` may fail or return degraded output.
- **Storage Constraints:** Termux relies on its private app data directory. Shared/external storage typically lacks POSIX semantics (like executability and Unix permissions).
- **Phantom Process Killing:** On Android 12+, the OS may kill phantom processes above a threshold (typically 32) and processes using excessive CPU. This can abruptly terminate process-heavy Termux workloads (like heavy compiles or complex session trees).

### 2. Supported Command Categories
- **Core POSIX & GNU Utilities:** Fully supported when installed from Termux repos (e.g., `bash`, `ls`, `grep`, `nano`, `vim`).
- **Development Tools:** Compilers (`clang`, `make`) and languages (`python`, `node`) are fully supported, subject to the Android 12+ phantom process risk for heavy builds.
- **System Service Management:** Init systems like `systemd` and `udev` are **not supported** since Termux does not run as PID 1.
- **Privileged Management:** Commands like `reboot`, `mount`, or kernel module tools require a native root shell and cannot be run by an unprivileged Termux session.

### 3. Supportability Assessment Matrix

| Capability area | Non-root Termux (native) | Termux + proot-distro | Rooted device + native tools |
|---|---|---|---|
| Core shells & GNU/POSIX userland | **Fully supported** when installed from Termux repos. | **Fully supported** (in-distro), but overhead and gaps possible. | **Fully supported** (highest flexibility). |
| Compilers, language runtimes | **Fully supported**, but subject to Android 12+ process killing risks for heavy builds. | **Mostly supported**; heavier process graphs increase Android 12+ risk. | **Fully supported**; still depends on device kernel/SELinux policy. |
| Full system process visibility (`ps` like desktop Linux) | **Partially supported** due to `/proc` restrictions and hidepid mounting. | **Partially supported** (inherits host kernel restrictions). | **Improved** (root can see more), but still SELinux/ROM‑dependent. |
| Network interface stats via `/proc/net` | **Partially/not supported** on Android 10+ (blocked). | Same limitation. | Root may restore access depending on policy; varies by ROM/OEM. |
| Init/service management (`systemctl`, `udev`) | **Not supported** (no PID 1 systemd in Termux). | **Not supported** in typical proot setups; systemd expects init/PID1 semantics. | Possible only with significant control and risk; device stability/security tradeoffs. |
| Arbitrary writes + POSIX semantics on shared/external storage | **Limited**: shared/external storage lacks executability and POSIX features; termux-setup-storage configures access. | Same limitation; container can’t change filesystem semantics. | Root can expand access; still constrained by filesystem type and SELinux. |

### 4. How to Determine if a Command Works
1. **Check Termux repos:** Use `pkg search <name>`. If available, it's adapted for Termux.
2. **System Binaries:** If relying on Android system binaries (e.g., under `/system/bin`), ensure they do not require root. Avoid adding `/system/bin` to `PATH` to prevent conflicts.
3. **Porting/Building:** If a tool is missing but doesn't require privileged access, compile it natively in Termux to link correctly against Bionic.
4. **Proot:** For foreign Linux user-space binaries not requiring root kernel features, `proot-distro` can provide an emulation layer, though it inherits Android OS restrictions.

---

## Part 5: Investigation Reports

### Investigation Report: hijack.js
The file `hijack.js` is a legitimate patch created by the `setup.sh` script in this repository. It is not malicious.

**Purpose**
The file is used as a "Network patch" to prevent the `openclaw` AI CLI from crashing. In some environments (like Termux on Android), certain Node.js functions that access network interfaces can cause errors.

`hijack.js` contains a simple mock that overrides the `os.networkInterfaces()` function:

```javascript
const os = require('os');
os.networkInterfaces = () => ({});
```

**How It's Created**
The logic for creating this file can be found in `setup.sh`:

```bash
# Network patch (prevents openclaw crashing when it reads network interfaces)
HIJACK_FILE="${HOME}/hijack.js"
cat > "$HIJACK_FILE" << 'EOF'
const os = require('os');
os.networkInterfaces = () => ({});
EOF
BASHRC="${HOME}/.bashrc"
if ! grep -qF "hijack.js" "$BASHRC" 2>/dev/null; then
    echo "export NODE_OPTIONS=\"-r ${HIJACK_FILE}\"" >> "$BASHRC"
fi
```

**Activation**
It is automatically loaded by Node.js whenever you run a script, because the `setup.sh` script adds it to your `NODE_OPTIONS` environment variable in your `.bashrc` file.

**Recommendation**
If you are using `openclaw` or `opencode-ai`, you should keep this file. If you remove it, those tools may crash when attempting to access network information.

If you don't intend to use those tools and want to clean up, you should:
1. Remove the line `export NODE_OPTIONS="-r /path/to/hijack.js"` from your `.bashrc`.
2. Delete the `hijack.js` file.

---

## License & Disclaimer

This project and its scripts are provided **free for personal use**.

**Author:** [abzach8](https://github.com/abzach8)

**Disclaimer:** This software is provided "as is", without warranty of any kind, express or implied. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software. You use these scripts at your own risk.
