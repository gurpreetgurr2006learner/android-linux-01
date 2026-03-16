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

set -euo pipefail

# ── Error trap: report line number on unexpected failure ───────────────────
trap 'echo "" >&2; echo "[start.sh] ERROR: script failed at line $LINENO" >&2; exit 1' ERR

# ── Helper: graceful kill (SIGTERM → wait → SIGKILL) ──────────────────────
graceful_kill() {
    local pattern="$1"
    local timeout="${2:-3}"
    local use_f="${3:-}"

    # shellcheck disable=SC2086
    pkill ${use_f} -TERM "$pattern" 2>/dev/null || true
    local waited=0
    while pkill -0 "$pattern" 2>/dev/null; do
        if [ "$waited" -ge "$timeout" ]; then
            # shellcheck disable=SC2086
            pkill ${use_f} -KILL "$pattern" 2>/dev/null || true
            break
        fi
        sleep 1
        waited=$((waited + 1))
    done
}

# ── Helper: wait for a process matching a pattern to appear ───────────────
wait_for_process() {
    local pattern="$1"
    local timeout="${2:-10}"
    local waited=0
    while ! pgrep -f "$pattern" >/dev/null 2>&1; do
        if [ "$waited" -ge "$timeout" ]; then
            echo "  [WARN] Timed out waiting for '$pattern' to start" >&2
            return 1
        fi
        sleep 1
        waited=$((waited + 1))
    done
    return 0
}

echo ""
echo "==========================================="
echo "  [start.sh] Starting desktop + RDP..."
echo "==========================================="
echo ""

# ── 0. Optional hardware acceleration config ────────────────────────────────
# shellcheck disable=SC1090
source ~/.config/linux-gpu.sh 2>/dev/null || true

# ── 1. Kill any leftover processes ─────────────────────────────────────────
echo "[1/6] Cleaning up old sessions..."
graceful_kill "termux.x11" 3 "-f"
graceful_kill xfce4-session
graceful_kill plank
graceful_kill dbus 3 "-f"
graceful_kill xrdp
graceful_kill sesman
graceful_kill Xvnc

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

# Wait for VNC to actually be ready before xrdp tries to connect
wait_for_process "Xvnc :1" 15 \
    || { echo "[start.sh] ERROR: TigerVNC did not start in time." >&2; exit 1; }
sleep 1  # short additional settle time for xstartup

# ── 4. Start xRDP services (listens on port 3389) ───────────────────────────
echo "[4/6] Starting xrdp-sesman and xrdp..."
xrdp-sesman
wait_for_process "xrdp-sesman" 10 \
    || echo "  [WARN] xrdp-sesman may not have started" >&2
xrdp
wait_for_process "xrdp" 10 \
    || echo "  [WARN] xrdp may not have started" >&2

# ── 5. Start Termux:X11 display server on :0 (for local phone view) ─────────
echo "[5/6] Starting Termux:X11 on display :0..."
termux-x11 :0 -ac &
# Give Termux:X11 time to open the socket before we try to connect
wait_for_process "termux.x11" 10 \
    || echo "  [WARN] Termux:X11 may not have started" >&2
sleep 1
export DISPLAY=:0

# ── 6. Print connection info ────────────────────────────────────────────────
# Detect any active non-loopback IPv4 address (prefer `ip` over deprecated `ifconfig`)
if command -v ip >/dev/null 2>&1; then
    LAN_IP=$(ip -4 addr show scope global 2>/dev/null \
        | grep -Eo '192\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
else
    LAN_IP=$(ifconfig 2>/dev/null \
        | grep -Eo '192\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
fi
RDP_USER=$(whoami)
echo ""
echo "==========================================="
echo "  Desktop is ready!"
echo "==========================================="
if [ -n "${LAN_IP:-}" ]; then
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

# ── 7. Launch XFCE4 on local X11 display (blocking) ─────────────────────────
echo "[6/6] Launching XFCE4 on local display..."
exec startxfce4
