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

**(Alternative Silent Setup):** Run `./setup.sh` instead for an idempotent, silent XFCE4 installation.

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
- **`install.sh` & `setup.sh`:** Must handle existing configurations without breaking. Detect if a package is already installed before downloading heavily.
- **`start.sh`:** Must perform pre-flight checks (clearing `.X*` locks, `.vnc/*.pid` files, `.xrdp` stale endpoints) before launching components.
- **`stop.sh`:** Must be thorough. Hunt and terminate `xrdp`, `xrdp-sesman`, `Xvnc`, `pulseaudio`, `dbus-launch`, and the specific Session Manager processes cleanly. 

By adhering to these rules, scripts will guarantee stable, optimized configurations within the specialized Linux containerization of Android's Termux.

---

## License & Disclaimer

This project and its scripts are provided **free for personal use**.

**Author:** [abzach8](https://github.com/abzach8)

**Disclaimer:** This software is provided "as is", without warranty of any kind, express or implied. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software. You use these scripts at your own risk.
