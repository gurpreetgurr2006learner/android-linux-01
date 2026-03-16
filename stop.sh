#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# stop.sh — Run in Termux to stop XFCE4 desktop + RDP server
# =============================================================================
# Stops everything in reverse order:
#   1. Stops xrdp services
#   2. Stops TigerVNC server
#   3. Kills XFCE4 session
#   4. Stops Termux:X11
#   5. Stops PulseAudio
#   6. Cleans up stale lock files
#
# NOTE: set -e is intentionally omitted here so that every cleanup step
# runs even if individual pkill/rm commands return non-zero.
# =============================================================================

set -uo pipefail

# ── Helper: graceful kill (SIGTERM → wait → SIGKILL) ──────────────────────
graceful_kill() {
    local pattern="$1"
    local timeout="${2:-3}"  # seconds to wait before SIGKILL
    local use_f="${3:-}"     # pass "-f" to match full command line

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

echo ""
echo "==========================================="
echo "  [stop.sh] Stopping desktop + RDP..."
echo "==========================================="
echo ""

# ── 1. Stop xRDP services ───────────────────────────────────────────────────
echo "[1/5] Stopping xrdp and xrdp-sesman..."
graceful_kill xrdp
graceful_kill sesman
sleep 0.5

# ── 2. Stop TigerVNC server ─────────────────────────────────────────────────
echo "[2/5] Stopping TigerVNC server..."
vncserver -kill :1 >/dev/null 2>&1 || true
graceful_kill Xvnc
sleep 0.5

# ── 3. Kill XFCE4 session ──────────────────────────────────────────────────
echo "[3/5] Stopping XFCE4 session..."
graceful_kill xfce4-session
graceful_kill plank
graceful_kill dbus -f
sleep 0.5

# ── 4. Stop Termux:X11 ─────────────────────────────────────────────────────
echo "[4/5] Stopping Termux:X11..."
graceful_kill "termux.x11" "" "-f"
sleep 0.5

# ── 5. Stop PulseAudio ─────────────────────────────────────────────────────
echo "[5/5] Stopping PulseAudio..."
graceful_kill pulseaudio "" "-f"

# ── 6. Clean up stale lock files ───────────────────────────────────────────
rm -f ~/.vnc/*:1.pid
rm -f /data/data/com.termux/files/usr/tmp/.X1-lock
rm -f /data/data/com.termux/files/usr/tmp/.X11-unix/X1
rm -f /data/data/com.termux/files/usr/var/run/xrdp-sesman.pid

echo ""
echo "==========================================="
echo "  Everything stopped cleanly."
echo "==========================================="
echo ""
