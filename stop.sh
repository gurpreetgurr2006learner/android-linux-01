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
# =============================================================================

echo ""
echo "==========================================="
echo "  [stop.sh] Stopping desktop + RDP..."
echo "==========================================="
echo ""

# ── 1. Stop xRDP services ───────────────────────────────────────────────────
echo "[1/5] Stopping xrdp and xrdp-sesman..."
pkill -9 xrdp   2>/dev/null || true
pkill -9 sesman 2>/dev/null || true
sleep 0.5

# ── 2. Stop TigerVNC server ─────────────────────────────────────────────────
echo "[2/5] Stopping TigerVNC server..."
vncserver -kill :1 >/dev/null 2>&1 || true
pkill -9 Xvnc   2>/dev/null || true
sleep 0.5

# ── 3. Kill XFCE4 session ──────────────────────────────────────────────────
echo "[3/5] Stopping XFCE4 session..."
pkill -9 xfce4-session 2>/dev/null || true
pkill -9 plank         2>/dev/null || true
pkill -9 -f "dbus"     2>/dev/null || true
sleep 0.5

# ── 4. Stop Termux:X11 ─────────────────────────────────────────────────────
echo "[4/5] Stopping Termux:X11..."
pkill -9 -f "termux.x11" 2>/dev/null || true
sleep 0.5

# ── 5. Stop PulseAudio ─────────────────────────────────────────────────────
echo "[5/5] Stopping PulseAudio..."
pkill -9 -f "pulseaudio" 2>/dev/null || true

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
