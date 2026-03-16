#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# start.sh — Run in Termux to start XFCE4 desktop + RDP server
# =============================================================================
# What this does:
#   1. Kills any leftover sessions from a previous run
#   2. Starts PulseAudio (audio)
#   3. Starts TigerVNC server on display :1 (used by xRDP as its backend)
#   4. Starts xrdp-sesman and xrdp (RDP listener on port 3389)
#   5. Starts Termux:X11 display server on :0 (for local viewing on phone)
#   6. Launches XFCE4 on the local X11 display
#
# After this you can:
#   • RDP in from any device on the same Wi-Fi → <phone-ip>:3389
#   • View locally on phone → open the Termux:X11 app
# =============================================================================

set -e

echo ""
echo "==========================================="
echo "  [start.sh] Starting desktop + RDP..."
echo "==========================================="
echo ""

# ── 0. Optional hardware acceleration config ────────────────────────────────
source ~/.config/linux-gpu.sh 2>/dev/null || true

# ── 1. Kill any leftover processes ─────────────────────────────────────────
echo "[1/6] Cleaning up old sessions..."
pkill -9 -f "termux.x11" 2>/dev/null || true
pkill -9 xfce4-session   2>/dev/null || true
pkill -9 plank           2>/dev/null || true
pkill -9 -f "dbus"       2>/dev/null || true
pkill -9 xrdp            2>/dev/null || true
pkill -9 sesman          2>/dev/null || true
pkill -9 Xvnc            2>/dev/null || true

# Clean up stale lock files
rm -f ~/.vnc/*:1.pid
rm -f /data/data/com.termux/files/usr/tmp/.X1-lock
rm -f /data/data/com.termux/files/usr/tmp/.X11-unix/X1
rm -f /data/data/com.termux/files/usr/var/run/xrdp-sesman.pid
# Remove stale XFCE4 session cache — causes blank screen when XFCE4 tries to
# restore a session that no longer exists
rm -rf ~/.cache/sessions/
sleep 1

# ── 2. Start PulseAudio ─────────────────────────────────────────────────────
echo "[2/6] Starting PulseAudio..."
unset PULSE_SERVER
pulseaudio --kill 2>/dev/null || true
sleep 0.5
pulseaudio --start --exit-idle-time=-1
sleep 1
pactl load-module module-native-protocol-tcp \
    auth-ip-acl=127.0.0.1 auth-anonymous=1 2>/dev/null || true
export PULSE_SERVER=127.0.0.1

# ── 3. Start TigerVNC server on display :1 (xRDP backend) ──────────────────
echo "[3/6] Starting TigerVNC server on display :1..."
vncserver -kill :1 >/dev/null 2>&1 || true
# -depth 24: explicit 24-bit colour depth — mismatches can cause blank screen
vncserver :1 -geometry 1280x720 -depth 24 -localhost no
sleep 3  # give xstartup time to launch XFCE4 on :1 before xrdp connects

# ── 4. Start xRDP services (listens on port 3389) ───────────────────────────
echo "[4/6] Starting xrdp-sesman and xrdp..."
xrdp-sesman
sleep 1
xrdp
sleep 1

# ── 5. Start Termux:X11 display server on :0 (for local phone view) ─────────
echo "[5/6] Starting Termux:X11 on display :0..."
termux-x11 :0 -ac &
sleep 3
export DISPLAY=:0

# ── 6. Print connection info ────────────────────────────────────────────────
# Detect any active non-loopback IPv4 address (works regardless of interface name)
LAN_IP=$(ip -4 addr show scope global 2>/dev/null \
    | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -1)
RDP_USER=$(whoami)
echo ""
echo "==========================================="
echo "  Desktop is ready!"
echo "==========================================="
if [ -n "$LAN_IP" ]; then
    echo "  RDP address  →  $LAN_IP:3389"
else
    echo "  RDP address  →  run: ip -4 addr show scope global"
fi
echo "  Username     →  $RDP_USER"
echo "  Password     →  your VNC password (set in setup.sh)"
echo "-------------------------------------------"
echo "  Local view   →  open the Termux:X11 app"
echo "==========================================="
echo ""

# ── 6. Launch XFCE4 on local X11 display (blocking) ─────────────────────────
echo "[6/6] Launching XFCE4 on local display..."
exec startxfce4
