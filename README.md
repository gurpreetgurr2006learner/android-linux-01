# android-linux-01

Scripts to start/stop Ubuntu (proot-distro) with XFCE4 desktop + RDP access inside **Termux** + **Termux:X11** on Android.

---

## Scripts

| Script | Where to run | When to run |
|---|---|---|
| `setup.sh` | Termux | **Once only** — installs xfce4, TigerVNC, xrdp |
| `start.sh` | Termux | Every time you want to start the desktop |
| `stop.sh` | Termux | Before turning off the desktop |

---

## First-time setup

> Run **once** in Termux. No sudo needed — everything installs via `pkg`.

```bash
bash setup.sh
```

This will:
- `pkg install` xfce4, xfce4-goodies, tigervnc, xrdp, pulseaudio, dbus
- Write `~/.vnc/xstartup` (launches XFCE4 via VNC)
- Write `$PREFIX/etc/xrdp/xrdp.ini` (VNC backend on port 5901)
- Prompt you to set a **VNC password** — this is what you enter in the RDP login screen

---

## Daily usage

### Start desktop + RDP
```bash
bash start.sh
```
This starts in order:
1. PulseAudio (audio)
2. TigerVNC on display `:1` — used as the xRDP backend
3. `xrdp-sesman` + `xrdp` — RDP listener on port **3389**
4. Termux:X11 on display `:0` — for local view on phone
5. XFCE4 on the local display

### Connect via RDP (from PC / another device)
- Your phone's Wi-Fi IP is printed by `start.sh`. Or find it with:
  ```bash
  ip addr show wlan0 | grep 'inet '
  ```
- Open any RDP client and connect to: `<phone-ip>:3389`
- At the login screen: enter any username, and the **VNC password** set in `setup.sh`

### View locally on phone
- Open the **Termux:X11** app on your phone.

### Stop desktop
```bash
bash stop.sh
```

---

## Requirements
- [Termux](https://f-droid.org/repo/com.termux_118.apk) (from F-Droid, **not** Play Store)
- [Termux:X11 APK](https://github.com/termux/termux-x11/releases/tag/nightly) — arm64 build for Mi Note 8 Pro
- Enable x11-repo in Termux: `pkg install x11-repo -y` (setup.sh does this)

---

# Command Support and Limitations in Termux on Android

## Executive overview

Termux is a terminal emulator plus a self-contained Linux distribution for Android that provides a large set of GNU/Linux command-line tools via its own package repositories. However, it runs on top of Android's user space and kernel, so command support is constrained by Android's filesystem layout, security model, and lack of traditional Linux components such as glibc and systemd. This report explains how command support in Termux works, what types of commands are fully supported, which ones are unavailable or partially functional, and how to reason about these limitations when using Termux on an Android phone.

## How Termux provides commands

### Termux as its own distribution

Termux is not an emulation of a traditional distribution like Debian or Ubuntu; it is a distinct Linux userland built specifically for Android. Packages are compiled with the Android NDK against Android's Bionic C library and installed in Termux's private prefix rather than standard FHS paths such as `/bin` or `/usr`. As a result, binaries built for conventional Linux distributions generally cannot run directly inside Termux unless they are rebuilt or adapted for this environment.

### Package management and repositories

Termux uses `apt` and `dpkg` under the hood, but users are strongly encouraged to use the `pkg` wrapper for package management tasks. The main repository and optional repos (game-repo, science-repo, root-repo, x11-repo) together provide hundreds to thousands of packages, including core utilities, compilers, interpreters, editors, and networking tools. Packages are hosted on dedicated Termux servers and are built from scripts maintained in the Termux GitHub organization, not from upstream Debian/Ubuntu repositories.

### System binaries from Android

In addition to Termux-packaged commands, many Android devices ship with system binaries such as `toybox` or `busybox` under `/system/bin` and `/system/xbin`. These can be invoked from Termux either by adding them to `PATH` or by using their full paths, but they remain subject to Android's permission and SELinux policies, so privileged operations (for example `reboot`) are normally blocked for regular apps.

### Termux add-ons and termux-specific commands

The Termux ecosystem includes add-on apps such as Termux:API, Termux:Boot, and Termux:GUI that expose additional functionality via dedicated `termux-*` commands. These commands integrate Android capabilities (sensors, intents, notifications, boot hooks, simple GUIs) into the Termux environment but do not change Android's underlying security model or grant root privileges.

## Commonly supported command categories

### Core POSIX and GNU utilities

Termux repositories provide standard shells (e.g., `bash`, `zsh`), core file and text utilities (`ls`, `cp`, `mv`, `grep`, `sed`, `awk`), and many other tools via packages such as `busybox` and GNU `coreutils`. For typical scripting and automation tasks that use these userspace tools without requiring privileged kernel operations, Termux behaves similarly to a modern Linux distribution.

### Development tools and build chain

Termux supports a broad development toolchain, including compilers (`clang`, `gcc` equivalents via `clang`), linkers, `make`, `cmake`, and debuggers, along with language runtimes for Python, Node.js, PHP, Ruby, and others. The Termux build infrastructure itself is documented in the "Building packages" guide, which explains how to compile and package additional software for Termux's non-FHS, Bionic-based environment.

### Networking and remote access

Packages such as `curl`, `wget`, `openssh`, and other networking tools are available for installing and managing network connections, downloading data, and using SSH for remote access. On older Android versions, tools like `ip`, `ifconfig`, and `netstat` can inspect network interfaces and connections, though newer Android privacy restrictions significantly curtail what they can see for non-privileged apps.

### Editors, shells, and user-level tools

Termux provides popular editors (`nano`, `vim`, `neovim`), shells (`bash`, `zsh`, `fish`), and numerous CLI utilities that are widely used for development and system administration on conventional Linux. For many developer workflows that only require manipulating files within Termux's own directory tree or permitted storage locations, these commands are effectively "fully supported" on Android.

### Security and penetration-testing tools (with caveats)

Some security tools such as `nmap` and Metasploit can be installed through Termux or community repositories and used for network and application testing. However, Termux runs without root by default and is constrained by Android sandboxing, so many advanced options that depend on raw socket access, interface reconfiguration, or wireless injection will not function unless the device is rooted or a chroot/proot-based full distribution is used.

## Structural limitations that affect command support

### Non-FHS filesystem layout

Termux does not follow the Filesystem Hierarchy Standard used by most Linux distributions: standard directories like `/bin`, `/etc`, `/usr`, and `/tmp` are not located where typical Linux binaries expect them. Instead, Termux installs its environment under a private prefix inside the app's internal storage (e.g., `$PREFIX`), and packages must be patched and recompiled to look for configuration files and data in these non-standard locations.

Because of this, native binaries copied directly from Debian, Ubuntu, or other Linux distributions usually fail: dynamic binaries look for the dynamic linker and libraries in paths that do not exist, and statically linked networking tools often rely on glibc behaviors that are not available under Android. Termux therefore does not support using Debian/Ubuntu repositories or packages directly; all supported commands come from Termux-specific builds.

### Use of Bionic libc instead of glibc

Termux links its binaries against Android's Bionic C library via the NDK, rather than GNU glibc. Many precompiled Linux binaries expect glibc, so even if copied into Termux they will fail to run due to ABI mismatches or missing loader paths. Static binaries that rely on DNS resolution or other glibc features may also fail, and on non-rooted Android 8+ some statically linked programs are blocked entirely by Android's seccomp filters.

### Android security and sandboxing

Android's permission model and SELinux policies restrict what a regular app, including Termux, can see and modify in `/proc`, `/sys`, and other kernel interfaces. From Android 7 onward, non-privileged processes cannot inspect other apps' processes in `/proc`, which is why commands like `ps` inside Termux only list Termux's own processes rather than the entire system. Starting with Android 10, access to `/proc/net` and related networking pseudo-files is restricted, causing tools like `ip`, `ifconfig`, and `netstat` to either return limited information or fail with `Permission denied` for non-root users.

Android also blocks operations such as rebooting the device or changing kernel parameters from regular apps, so even if binaries like `reboot` or `sysctl` exist, invoking them from Termux without an elevated, native root shell will generally fail or be disallowed.

### Storage and filesystem constraints

Termux cannot be installed on external storage (SD cards) on non-rooted devices because it requires a native Linux filesystem (e.g., ext4 or f2fs) that supports symlinks, Unix permissions, sockets, and other special file types; Android overlays general-purpose storage with a FAT-like abstraction that lacks these features. Access to shared and external storage is also restricted: Termux can read from common locations like `/storage/emulated/0`, but write access is only allowed in specific Termux-managed directories such as `$HOME/storage/external-1`, and broad write access like a file manager's is not possible.

Commands that expect unconstrained direct write access to arbitrary paths on shared storage, or that rely heavily on POSIX permissions and symlinks outside Termux's private directory tree, will therefore either fail or need to be adapted.

## Examples of unsupported or restricted commands and features

### Init systems, services, and udev

Android does not use systemd or traditional SysV init, and Termux sessions are started by the Android app framework rather than as PID 1. Within proot-based distributions running on Termux (for example Ubuntu or Debian roots), attempts to start `systemd` or `udev` generally fail or are explicitly unsupported: `systemctl` reports that the system has not been booted with systemd as init, and udev will not work under proot because it requires full root access and can conflict with Android's own device management.

As a result, commands and workflows that assume a functioning init system or udev — such as `systemctl`, `service`, `journalctl`, automated `/dev` device node creation, or hotplug rules — are effectively "not supported" in a typical Termux setup. Even on rooted devices, using full init systems inside Termux or proot is considered unstable and can crash Android.

### Process and networking inspection commands

On modern Android versions, non-privileged Termux sessions cannot fully inspect system processes or detailed network information because `/proc` entries for other apps and some `/proc/net` files are hidden. This means:

- `ps` will only show Termux's own processes instead of a full process list for the device.
- `ifconfig`, `ip`, and `netstat` may show partial or no output, and attempts to read `/proc/net/dev` often result in `Permission denied`.
- Even for users who enable the `root-repo` and install tools that normally require root, the underlying Android kernel and SELinux policies can still prevent these commands from accessing restricted kernel interfaces.

On older Android releases (e.g., Android 7), many of these tools work more like they do on a normal Linux system, which is why Termux developers continue to ship them even though they are partially or wholly broken on newer stock ROMs.

### Privileged system management commands

Commands that change system-wide state — such as `reboot`, `mount`, `modprobe`, `ifconfig` with interface reconfiguration, or tools that manipulate kernel modules and device nodes — are generally unavailable or ineffective in a non-root Termux session. A Termux maintainer notes that running `ifconfig` fails to open `/proc/net/dev` on newer Android versions and explicitly states that this "requires root, nothing we can do about this".

Similarly, attempts to call `reboot` from Termux as a regular app are blocked; one discussion notes that rebooting the device without root is only possible via `adb`, not from an installed app like Termux. Even when a device is rooted, correct use of these commands often requires dropping into a native system shell (`/system/bin/sh` with appropriate SELinux context) rather than relying solely on Termux's userland.

### Direct use of foreign distribution packages

Termux's documentation emphasizes that it does not support using Debian or Ubuntu packages directly, because the environment is not FHS compliant and binaries are linked against Bionic rather than glibc. Attempting to install `.deb` files from standard distributions or to point `apt` at Debian/Ubuntu repositories will at best fail to resolve dependencies and at worst produce binaries that cannot run.

Instead, users who need software not in the Termux repositories are expected to port and build it using the Termux build system, which handles the necessary path and toolchain adaptations.

### Proot and full Linux distributions inside Termux

Tools like `proot` and `proot-distro` can run full userland distributions (for example Debian, Ubuntu, or Arch) inside Termux without requiring root, but these environments still inherit Android and proot limitations. A widely cited explanation of proot limitations notes that:

- System V shared memory calls are effectively no-ops.
- Root inside proot is "fake" and cannot change kernel or device settings.
- Device nodes cannot be created in `/dev`.
- Namespaces cannot be manipulated and init systems cannot be run.
- File ownership is simplified and `setuid`/`setgid` behavior is limited.

As a result, even when commands like `systemctl` or `udevadm` exist inside a proot distribution, they cannot function as they would on a real Linux installation, and many advanced system-administration workflows remain unsupported on Android.

### Storage-related commands and expectations

Because Termux cannot be installed on external SD storage on non-rooted devices and has only restricted write access to shared storage, some commands that assume full POSIX behavior on all mounted filesystems may not work as expected. This affects operations such as symbolic linking, setting file ownership and permissions, and manipulating Unix sockets on SD-card or emulated storage paths, which can break tools that assume a uniform Linux filesystem.

## Examples table: supported vs restricted commands/features

The table below summarizes representative examples of command categories and their typical support status in a non-root Termux installation.

| Area / command type | Example commands or tools | Typical support in Termux on Android | Notes |
|---|---|---|---|
| Core shell & POSIX tools | `bash`, `sh`, `ls`, `cp`, `mv`, `grep`, `sed`, `awk` | Fully supported | Provided via `bash`, `busybox`, `coreutils`; behave similarly to standard Linux. |
| Text editors | `nano`, `vim`, `neovim` | Fully supported | Installed from Termux repos; operate normally within permitted filesystems. |
| Compilers and build tools | `clang`, `make`, `cmake` | Fully supported | Used to build software targeting Termux's Bionic-based, non-FHS environment. |
| Scripting languages | `python`, `node`, `php`, `ruby` | Fully supported | Provided as Termux packages; versions follow Termux repo updates. |
| Network clients | `curl`, `wget`, `ssh` | Fully supported | Standard user-space networking is allowed; subject to device network connectivity. |
| Process listing | `ps` | Partially supported | Only Termux's own processes are visible due to `/proc` restrictions on Android 7+. |
| Network inspection | `ifconfig`, `ip`, `netstat` | Partially or not supported on modern Android | On newer Android these often fail or show limited info because `/proc/net` is restricted. |
| Init and service management | `systemctl`, `service`, `udevadm` | Not supported in standard Termux/proot setups | Require a real init system and udev as PID 1 with root; not available under Android+proot. |
| System management | `reboot`, `mount`, kernel-module tools | Not supported without native root shell | Android blocks such operations for regular apps; even with root they require leaving Termux. |
| Foreign distro packages | Debian/Ubuntu `.deb` files | Not supported | Termux is not FHS compliant and uses Bionic, so foreign binaries usually cannot run. |
| Security tools with hardware access | Wi-Fi injection, full wireless suites | Limited or unavailable | Many advanced features require root and deeper hardware access than non-root Termux can provide. |

## How to determine whether a command is supported

### Checking availability in Termux repositories

To see whether a command is directly supported by Termux, first search the Termux repositories using `pkg search <name>` or list all packages with `pkg list-all`. If a package exists, it can normally be installed and used within the constraints of Android's security model; if no package is found, the command is not natively supported and may require porting or an alternative approach.

### Inspecting installed commands and paths

You can list currently installed packages with `pkg list-installed` and locate specific commands with `which <command>` or `command -v <command>`. If a command resolves to a path under Termux's prefix (for example `$PREFIX/bin`), it is part of the Termux environment; if it resolves under `/system/bin` or similar, it is an Android system binary and constrained by Android's policies.

### Consulting Termux documentation and issue trackers

The Termux Wiki, especially the "Differences from Linux", "FAQ", "Package Management", and "Building packages" pages, documents many of the structural differences and known limitations relative to conventional Linux distributions. GitHub issues in `termux-packages` and `termux-app` also contain concrete examples where commands like `ifconfig` or `reboot` fail due to Android-level permission changes, often with explanations from Termux maintainers.

## Workarounds and advanced setups

### Using proot-based distributions

If a required command is not easily ported to Termux or relies heavily on a conventional Linux userspace, installing a full distribution via `proot-distro` can provide a more standard environment for user-space software. This allows running many more unmodified Linux packages, but still does not overcome Android's kernel-level and SELinux restrictions, so init systems, low-level networking, and device management remain limited.

### Rooting the device and using chroot or Nethunter

Rooting the Android device can relax some of the sandbox restrictions and enable tools that require deeper system access, including more complete security-testing toolchains. With root, one can use chroot-based environments or projects like Kali Nethunter to run a full Linux distribution more tightly integrated with the hardware, though this comes with significant security and stability trade-offs and is outside the scope of standard Termux usage.

### Porting and building missing tools

For commands that are not available in Termux repositories but do not fundamentally require privileged kernel features, Termux's build system can be used to port and package them. The recommended process is to install the `build-essential` package group, study the software's `README`/`INSTALL` files, and follow the Termux packaging guidelines to adapt paths and build flags for the non-FHS, Bionic-based environment.

## Conclusion

In practice, Termux supports a very wide range of user-space commands — especially shells, compilers, interpreters, editors, and standard CLI tools — making it a powerful development and automation environment on Android. However, its command support is fundamentally bounded by Android's non-FHS filesystem layout, use of Bionic rather than glibc, and strict sandboxing of processes, networking, and storage, which collectively prevent Termux from acting as a full general-purpose Linux system for low-level administration or hardware access. Understanding these structural constraints helps clarify which commands are truly supported on an Android phone via Termux and which will remain partially functional or unavailable without deeper modifications such as rooting or moving to a different platform.
