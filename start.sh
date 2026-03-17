#!/usr/bin/env bash
# =============================================================================
# start.sh — Start XFCE4 desktop + RDP server
# =============================================================================
# What this does:
#   1. Cleans up any stale sessions/locks from previous run
#   2. Starts PulseAudio (audio)
#   3. Starts TigerVNC server on :1 (xRDP backend)
#   4. Starts xrdp-sesman + xrdp (RDP on port 3389)
#   5. Starts Termux:X11 on :0 (local phone display)
#   6. Prints connection info (IP, hostname, username)
#   7. Launches the chosen desktop environment (blocking)
# =============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
set -eo pipefail   # NOTE: -u is intentionally NOT set globally;
                   # linux-gpu.sh may reference unset vars (XDG_DATA_DIRS etc.)
                   # and set -u would silently kill the script before || true fires.

trap 'echo ""; echo "[start.sh] !! ERROR at line $LINENO — check output above."; exit 1' ERR

# ── Load DE selection ─────────────────────────────────────────────────────
# Default values first — guaranteed to be set even if conf is missing
DE_NAME="XFCE4"
START_CMD="startxfce4"
SESSION_PROC="xfce4-session"
PANEL_PROC="plank"

CONF="${HOME}/.config/termux-linux.conf"
if [ -f "$CONF" ]; then
    # shellcheck source=/dev/null
    source "$CONF"
fi

# ── Helper: graceful kill — SIGTERM → wait → SIGKILL ─────────────────────
graceful_kill() {
    local pattern="$1"
    local timeout="${2:-4}"
    local extra="${3:-}"   # pass "-f" to match full command line

    pkill $extra -TERM "$pattern" 2>/dev/null || true
    local waited=0
    while pkill $extra -0 "$pattern" 2>/dev/null; do
        if [ "$waited" -ge "$timeout" ]; then
            pkill $extra -KILL "$pattern" 2>/dev/null || true
            break
        fi
        sleep 1
        waited=$((waited + 1))
    done
}

# ── Helper: poll until a process appears ─────────────────────────────────
wait_for_process() {
    local pattern="$1"
    local timeout="${2:-15}"
    local waited=0
    while ! pgrep -f "$pattern" >/dev/null 2>&1; do
        if [ "$waited" -ge "$timeout" ]; then
            echo "  [WARN] '$pattern' did not start within ${timeout}s" >&2
            return 1
        fi
        sleep 1
        waited=$((waited + 1))
    done
    return 0
}

echo ""
echo "==========================================="
echo "  [start.sh] Starting ${DE_NAME} + RDP..."
echo "==========================================="
echo ""

# ── 0. Optional GPU/hardware acceleration ─────────────────────────────────
# IMPORTANT: source must NOT run under set -u — linux-gpu.sh may reference
# XDG_DATA_DIRS etc. before they are exported, which would make set -u kill
# the entire shell even though we have || true (|| true only catches exit codes,
# not set -u termination which happens before the command returns).
echo "[0/6] Loading GPU acceleration config..."
echo "[0/7] Loading GPU acceleration config..."
set +u
# shellcheck disable=SC1090
source ~/.config/linux-gpu.sh 2>/dev/null || true
set -u
echo "        done."

# ── 1. Prepare environment and clean up stale sessions ────────────────────
echo "[1/7] Preparing environment variables and cleaning up old sessions..."
if [ -f "$HOME/.bashrc" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.bashrc"
fi
graceful_kill "termux.x11" 4 "-f"
graceful_kill xfce4-session
graceful_kill plank
graceful_kill dbus 4 "-f"
graceful_kill xrdp
graceful_kill sesman
graceful_kill Xvnc

rm -f ~/.vnc/*:1.pid
rm -f "${PREFIX}/tmp/.X1-lock"
rm -f "${PREFIX}/tmp/.X11-unix/X1"
rm -f "${PREFIX}/var/run/xrdp-sesman.pid"
# Clear stale XFCE4 session cache — prevents blank screen on reconnect
rm -rf ~/.cache/sessions/
sleep 1

# ── 2. PulseAudio ─────────────────────────────────────────────────────────
echo "[2/6] Starting PulseAudio..."
unset PULSE_SERVER
pulseaudio --kill 2>/dev/null || true
sleep 0.5
pulseaudio --start --exit-idle-time=-1
sleep 1
pactl load-module module-native-protocol-tcp \
    auth-ip-acl=127.0.0.1 auth-anonymous=1 2>/dev/null || true
export PULSE_SERVER=127.0.0.1

# ── 3. TigerVNC on :1 (xRDP backend) ─────────────────────────────────────
echo "[3/6] Starting TigerVNC on display :1..."
vncserver -kill :1 >/dev/null 2>&1 || true
vncserver :1 -geometry 1280x720 -depth 24 -localhost no

# Wait for Xvnc to be ready before xrdp tries to connect
wait_for_process "Xvnc :1" 20 \
    || { echo "[start.sh] ERROR: TigerVNC did not start." >&2; exit 1; }
sleep 1

# ── 4. xRDP services ──────────────────────────────────────────────────────
echo "[4/6] Starting xrdp-sesman and xrdp..."
xrdp-sesman
wait_for_process "xrdp-sesman" 10 || echo "  [WARN] xrdp-sesman may not have started" >&2
xrdp
wait_for_process "xrdp" 10 || echo "  [WARN] xrdp may not have started" >&2

# ── 5. Termux:X11 on :0 (local display) ──────────────────────────────────
echo "[5/6] Starting Termux:X11 on display :0..."
termux-x11 :0 -ac &
wait_for_process "termux.x11" 10 || echo "  [WARN] Termux:X11 may not have started" >&2
sleep 1
export DISPLAY=:0

# ── 6. Print connection info ──────────────────────────────────────────────
# Detect IP
if command -v ip >/dev/null 2>&1; then
    LAN_IP=$(ip -4 addr show scope global 2>/dev/null \
        | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1 || true)
else
    LAN_IP=$(ifconfig 2>/dev/null \
        | grep -Eo '192\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1 || true)
fi

# Hostname (set by setup.sh into $PREFIX/etc/hostname)
HOSTNAME_FILE="${PREFIX}/etc/hostname"
TERMUX_HOST=$(cat "$HOSTNAME_FILE" 2>/dev/null || hostname 2>/dev/null || echo "android-linux")
RDP_USER=$(whoami)

echo ""
echo "==========================================="
echo "  Desktop is ready! (${DE_NAME})"
echo "==========================================="
echo "  Wi-Fi IP   : ${LAN_IP:-(run: ip -4 addr show scope global)}"
echo "  Hostname   : ${TERMUX_HOST}"
echo "  Username   : ${RDP_USER}"
echo "-------------------------------------------"
echo "  RDP Address: ${LAN_IP:-<phone-ip>}:3389"
echo "  Password   : your VNC password (set in setup.sh)"
echo "-------------------------------------------"
echo "  Local view : open the Termux:X11 app"
echo "==========================================="
echo ""

# ── 7. Launch desktop (blocking — keeps the terminal session alive) ───────
echo "[6/6] Launching ${DE_NAME} on local display..."
mkdir -p ~/.vnc
exec ${START_CMD} > ~/.vnc/local_display.log 2>&1
