#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# setup.sh — Idempotent Termux RDP setup (safe to run multiple times)
# =============================================================================
# Installs xfce4, xrdp, tigervnc and writes config files.
# Config files (xstartup, xsession, xrdp.ini) are always rewritten so fixes
# are always applied on re-run. Only vncpasswd is skipped if already set.
#
# HOW TO RUN:
#   bash setup.sh
#   (Run in Termux — NOT inside another shell or environment)
# =============================================================================

set -euo pipefail

# ── Resolve the directory where this script lives ──────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Error trap: report line number on unexpected failure ───────────────────
trap 'echo "" >&2; echo "[setup.sh] ERROR: script failed at line $LINENO" >&2; exit 1' ERR

echo ""
echo "================================================="
echo "  [setup.sh] Termux RDP setup (idempotent)"
echo "================================================="
echo ""

# ── 1. Update packages and add x11-repo ────────────────────────────────────
echo "[1/7] Updating packages and enabling x11-repo..."
pkg update -y
pkg install x11-repo -y

# ── 2. Install desktop + VNC + XRDP ────────────────────────────────────────
# pkg install is already idempotent — skips packages that are installed.
echo "[2/7] Installing XFCE4, TigerVNC, xrdp, PulseAudio, dbus, Node.js, Git..."
pkg install -y \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    xfce4-whiskermenu-plugin \
    tigervnc \
    xrdp \
    dbus \
    pulseaudio \
    nodejs \
    git

# ── 3. Create VNC startup script (launches XFCE4 via VNC) ──────────────────
# Always rewritten — this is a generated config, not user-edited.
# IMPORTANT: Uses `exec dbus-launch --exit-with-session startxfce4` (not the
# `eval "$(dbus-launch)"` form). The eval form can silently fail on Termux,
# leaving the VNC display :1 blank and causing a blank screen after RDP login.
echo "[3/7] Writing ~/.vnc/xstartup..."
mkdir -p ~/.vnc
cat > ~/.vnc/xstartup << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR="/data/data/com.termux/files/usr/tmp"
export XKL_XMODMAP_DISABLE=1
xrdb "$HOME/.Xresources" 2>/dev/null || true
exec dbus-launch --exit-with-session startxfce4
EOF
chmod +x ~/.vnc/xstartup

# Neutralize .xsession so XFCE doesn't launch twice on the VNC display
cat > ~/.xsession << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
exit 0
EOF
chmod +x ~/.xsession

# ── 4. Write xrdp.ini config (VNC backend on port 5901) ────────────────────
# Always rewritten — ensures the correct VNC backend config is always in place.
echo "[4/7] Writing xrdp.ini config..."
XRDP_CONF="${PREFIX}/etc/xrdp/xrdp.ini"
mkdir -p "$(dirname "$XRDP_CONF")"
cat > "$XRDP_CONF" << 'EOF'
[Globals]
ini_version=1
fork=true
port=3389
tcp_nodelay=true
tcp_keepalive=true
security_layer=negotiate
crypt_level=high
certificate=
key_file=
ssl_protocols=TLSv1.2, TLSv1.3
autorun=
allow_channels=true
allow_multimon=true
bitmap_cache=true
bitmap_compression=true
bulk_compression=true
max_bpp=32
new_cursors=true
use_fastpath=both

[Logging]
LogFile=xrdp.log
LogLevel=WARNING
EnableSyslog=false

[Channels]
rdpdr=true
rdpsnd=true
drdynvc=true
cliprdr=true
rail=true

[Xvnc]
name=Xvnc
lib=libvnc.so
username=ask
password=ask
ip=127.0.0.1
port=5901
EOF

# ── 5. Install OpenCode AI CLI ─────────────────────────────────────────────
# Installed globally via NPM. Safe to run multiple times.
echo "[5/7] Installing OpenCode AI CLI..."
if ! npm install -g opencode-ai; then
    echo "  [WARN] opencode-ai npm install failed — continuing without it." >&2
fi

# ── 6. Install OpenClaw AI ─────────────────────────────────────────────────
echo "[6/7] Installing OpenClaw AI and applying network patch..."
if ! npm install -g openclaw@latest; then
    echo "  [WARN] openclaw npm install failed — continuing without it." >&2
fi

HIJACK_FILE="${HOME}/hijack.js"
cat > "$HIJACK_FILE" << 'EOF'
const os = require('os');
os.networkInterfaces = () => ({});
EOF

BASHRC="${HOME}/.bashrc"
if ! grep -qF "hijack.js" "$BASHRC" 2>/dev/null; then
    echo "export NODE_OPTIONS=\"-r ${HIJACK_FILE}\"" >> "$BASHRC"
fi

# ── 7. Set a VNC password (used when connecting via RDP) ───────────────────
# ~/.vnc/passwd is the binary file vncpasswd writes — if it exists, skip.
echo "[7/7] Checking VNC password..."
if [ ! -f ~/.vnc/passwd ]; then
    echo "  -> No VNC password set. Enter one now (used at the RDP login screen):"
    vncpasswd
else
    echo "  -> VNC password already set (~/.vnc/passwd exists), skipping"
    echo "     To change it, run:  vncpasswd"
fi

echo ""
echo "================================================="
echo "  [setup.sh] Setup complete!"
echo "================================================="
echo ""
echo "  Now run:  ./start.sh"
echo "  Then connect via RDP to  <your-wifi-ip>:3389"

# Detect Wi-Fi IP (prefer `ip` over deprecated `ifconfig`)
if command -v ip >/dev/null 2>&1; then
    WIFI_IP=$(ip -4 addr show scope global 2>/dev/null \
        | grep -Eo '192\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
else
    WIFI_IP=$(ifconfig 2>/dev/null \
        | grep -Eo '192\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
fi
if [ -n "${WIFI_IP:-}" ]; then
    echo "  Wi-Fi IP: $WIFI_IP"
else
    echo "  Wi-Fi IP: (run: ip -4 addr show scope global)"
fi
echo ""

# Ensure start.sh and stop.sh are executable
chmod +x "${SCRIPT_DIR}/start.sh" "${SCRIPT_DIR}/stop.sh" 2>/dev/null || true
