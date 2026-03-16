# Termux Linux Premium Setup & RDP Scripts

This directory (`new/`) contains scripts to set up a full, hardware-accelerated Linux Desktop Environment natively within **Termux** on Android. The environment can be accessed locally via **Termux:X11** or remotely via an **RDP client**.

## 1. Prerequisites (App Downloads)

To follow this set up, you need specific versions of the Termux and Termux:X11 applications on your Android phone. *Do NOT install Termux from the Google Play Store.*

- **Termux (Terminal Emulator):**
  Download the stable version from F-Droid:
  [https://f-droid.org/en/packages/com.termux/](https://f-droid.org/en/packages/com.termux/)
- **Termux:X11 (X server):**
  Download the `app-arm64-v8a-debug.apk` asset from the nightly releases page:
  [https://github.com/termux/termux-x11/releases/tag/nightly](https://github.com/termux/termux-x11/releases/tag/nightly)

Install these APKs on your Android phone before proceeding.

## 2. Included Scripts Overview

| Script | Description |
|---|---|
| `install.sh` | **[NEW]** Feature-rich interactive installer. Prompts you to select a Desktop Environment (XFCE4, LXQt, MATE, or KDE Plasma), configures VNC/xRDP, handles GPU acceleration based on your device, and installs extra software like Firefox, VLC, Python, and Wine for Windows app compatibility. |
| `setup.sh` | An alternative, fully idempotent, silent setup script tailored to XFCE4. Can be re-run continuously without issues. Great for immediate non-interactive use. |
| `start.sh` | Launches your active desktop environment (configured via `install.sh`), PulseAudio, VNC as a backend, and xRDP for client connections. Cleans up old processes reliably first. |
| `stop.sh` | Safely and cleanly terminates all desktop, VNC, audio, and RDP processes created by `start.sh`. |

## 3. Step-by-Step Configuration Guide

Follow these steps exactly on your Android phone.

### Step 1: Prepare Termux
1. Open the **Termux** app.
2. Run `pkg update` initially to ensure your base packages are fresh.
3. Run `termux-setup-storage` to grant the application necessary internal storage access.
4. Navigate (`cd`) into this script directory on your phone.

### Step 2: Run the Installer
Launch the interactive installer script to download assets and configure the system:

```bash
bash install.sh
```

**Options and Prompts Explained:**

- **Device Detection:**
  The script automatically checks your device brand and GPU property.
  - If it identifies an *Adreno* GPU or specific vendors (Samsung, OnePlus, Xiaomi), it inherently configures **Freedreno/Turnip** drivers, enabling rich hardware acceleration.
  - If it cannot safely assume the GPU, it employs **Zink Native** to formulate a software fallback.

- **Desktop Environment Selection:**
  You will be prompted to enter a number (1-4) to pick your layout:
  1. **XFCE4 (Recommended):** The default. It is very fast, polished, and exceptionally stable over RDP/VNC environments, providing minimal stuttering.
  2. **LXQt:** A stark, ultra-lightweight layer, ideal for older Android variants.
  3. **MATE:** Familiar, relatively lightweight environment modeled on classic architectures.
  4. **KDE Plasma:** A full-featured desktop UI. Do not install this unless you own a modern flagship device with abundant RAM.

- **Automated Installation Phase:**
  The script now downloads gigabytes of native structural components:
  - Repositories (`x11-repo`, `tur-repo`), X11 libraries, and Audio instances (PulseAudio, dbus).
  - Maps GPU overrides to `~/.config/linux-gpu.sh` ensuring all applications know about the Android drivers.
  - Installs **Apps & Extras**: Firefox browser, VLC player, Hangover-Wine (plus wowbox64 to natively run Windows executables), and a native Python testing environment with Flask.
  - Quietly modifies the internal settings of `start.sh` and `stop.sh` so they accurately hook into the specific Desktop Environment you selected above.

- **VNC Password Prompt (CRITICAL):**
  As the setup concludes, you will be alerted (if not already set previously):
  > `"No VNC password set. Enter one now (used at the RDP login screen):"`
  You must input and verify a custom password here. **This is the main password you will type in your RDP client to access your container space remotely.**

### Step 3: Start the Environment

When you are ready to use the desktop, explicitly run the start script:
```bash
bash start.sh
```

**What the Start Script Does:**
1. Kills off any previous lingering sessions or "Stale Session Caches" preventing the notorious "black screen" xrdp error.
2. Starts the PulseAudio module natively resolving TCP connections to `127.0.0.1`.
3. Hosts a local TigerVNC monitor (display `:1`), with 24-bit color depth bindings. This acts solely as an intermediary visual output block.
4. Starts the `xrdp-sesman` server and primary `xrdp` routing hub mapping RDP protocol functionality onto internal port **3389**.
5. Initializes the Termux:X11 display socket loopers (display `:0`).

Termux will then print a clear console block containing your exact local **Wi-Fi IP Address**, current Username, and a reminder to use the VNC password set globally earlier.

### Step 4: Connecting to your Desktop

**Method A: Native Phone View (Local)**
Open the newly installed **Termux:X11** application natively on your host Android device. Your desktop will already be routed visually directly onto its output layout.

**Method B: Remote PC View (RDP via Wi-Fi)**
1. Ensure your PC, Tablet, or secondary system is physically connected to the exact same Wi-Fi router network as your Android phone.
2. Open your preferred RDP client (`Remote Desktop Connection` on Windows natively, Microsoft Remote Desktop on macOS, Remmina on Linux).
3. Instruct the client to connect to the IP outputted by Termux followed by the 3389 port, standard format: `<phone-LAN-ip>:3389`
4. Accept any unrecognized TLS certificate warnings securely.
5. In the graphical RDP login menu:
   - Provide your generic Termux username (any text is typically permitted universally, or the specific text outputted by `start.sh`).
   - Specifically input the **VNC Password** that was configured by the step 2 installer sequence.

### Step 5: Graceful Shutdown

To preserve battery efficiency and system resources on Android, thoroughly cease operations. Resume Termux manually, press Control-C if `start.sh` runs interactively in the foreground, and decisively run:

```bash
bash stop.sh
```

This sequentially hunts down and securely terminates xrdp daemons, TigerVNC virtual servers, pulse-audio endpoints, X11 socket handlers, and specific UI elements like the Whisker menu or Plasma session bindings.
