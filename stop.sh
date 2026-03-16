#!/usr/bin/env bash
# =============================================================================
# stop.sh — Gracefully stop XFCE4 desktop + RDP server
# =============================================================================
# Stops everything in reverse startup order so the next boot is clean:
#   1. xRDP services
#   2. TigerVNC server
#   3. Desktop session (XFCE4 or chosen DE)
#   4. Termux:X11
#   5. PulseAudio
#   6. Lock file cleanup
#
# NOTE: set -e is intentionally omitted so every cleanup step runs
# even when a previous one returns non-zero.
# =============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
set -o pipefail   # NOTE: -e and -u intentionally omitted:
                  # -e would abort cleanup on first error (all steps must run)
                  # -u would cause sourced conf files to kill the shell

# ── Load DE selection so we kill the right session process ────────────────
# Set defaults first — conf file overrides if it exists
SESSION_PROC="xfce4-session"
PANEL_PROC="plank"

CONF="${HOME}/.config/termux-linux.conf"
if [ -f "$CONF" ]; then
    # shellcheck source=/dev/null
    source "$CONF" 2>/dev/null || true
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

echo ""
echo "==========================================="
echo "  [stop.sh] Stopping desktop + RDP..."
echo "==========================================="
echo ""

# ── 1. Stop xRDP ──────────────────────────────────────────────────────────
echo "[1/5] Stopping xrdp and xrdp-sesman..."
graceful_kill xrdp
graceful_kill sesman
sleep 0.5

# ── 2. Stop TigerVNC ──────────────────────────────────────────────────────
echo "[2/5] Stopping TigerVNC..."
vncserver -kill :1 >/dev/null 2>&1 || true
graceful_kill Xvnc
sleep 0.5

# ── 3. Stop desktop session ───────────────────────────────────────────────
echo "[3/5] Stopping ${SESSION_PROC:-desktop session}..."
graceful_kill xfce4-session
[ -n "${PANEL_PROC:-}" ] && graceful_kill "${PANEL_PROC}"
graceful_kill dbus 4 "-f"
sleep 0.5

# ── 4. Stop Termux:X11 ────────────────────────────────────────────────────
echo "[4/5] Stopping Termux:X11..."
graceful_kill "termux.x11" 4 "-f"
sleep 0.5

# ── 5. Stop PulseAudio ────────────────────────────────────────────────────
echo "[5/5] Stopping PulseAudio..."
pulseaudio --kill 2>/dev/null || graceful_kill pulseaudio 4 "-f"

# ── 6. Clean up stale lock files so next start.sh boots cleanly ──────────
echo "      Cleaning up lock files..."
rm -f ~/.vnc/*:1.pid
rm -f "${PREFIX}/tmp/.X1-lock"
rm -f "${PREFIX}/tmp/.X11-unix/X1"
rm -f "${PREFIX}/var/run/xrdp-sesman.pid"
# Also clear stale session cache so the DE starts fresh next time
rm -rf ~/.cache/sessions/ 2>/dev/null || true

echo ""
echo "==========================================="
echo "  Everything stopped cleanly."
echo "  Next boot: run ./start.sh"
echo "==========================================="
echo ""
