# 01 — Termux RDP Setup Scripts

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
- [Termux:X11 APK](https://github.com/termux/termux-x11/releases/tag/nightly) — arm64 build
- Enable x11-repo in Termux: `pkg install x11-repo -y` (setup.sh does this)
