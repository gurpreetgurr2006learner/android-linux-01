#!/usr/bin/env bash
# =============================================================================
# setup.sh — Idempotent config writer (safe to run multiple times)
# =============================================================================
# Reads the DE choice saved by install.sh, then:
#   • Updates pkg and apt packages
#   • Writes all service config files (xstartup, xrdp.ini, etc.)
#   • Installs CLI tools via npm (opencode-ai, openclaw)
#   • Sets the Termux hostname
#   • Prompts for VNC password (if not already set)
#   • Displays connection info: IP, hostname, username
#
# HOW TO RUN: bash setup.sh  (run after install.sh, or alone for XFCE4)
# =============================================================================

set -eo pipefail   # NOTE: -u intentionally omitted — sourced conf files may
                   # reference unset vars; set -u would kill shell before || true.

trap 'echo "" >&2; echo "[setup.sh] ERROR at line $LINENO — setup aborted." >&2; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

echo ""
echo "================================================="
echo "  [setup.sh] Configuring Termux RDP environment"
echo "================================================="
echo ""

# Default values — will be overridden if conf exists
DE_NAME="XFCE4"
START_CMD="startxfce4"
SESSION_PROC="xfce4-session"
PANEL_PROC="plank"

CONF="${HOME}/.config/termux-linux.conf"
if [ -f "$CONF" ]; then
    # shellcheck source=/dev/null
    source "$CONF"
fi
echo "  DE: ${DE_NAME} / launch: ${START_CMD}"
echo ""

# ── 1. Update Termux packages (pkg wraps apt; both are run for completeness) ─
echo "[1/8] Updating Termux packages (pkg)..."
pkg update -y
pkg upgrade -y

# apt is also available directly in Termux and may be needed by proot containers
echo "[1/8] Updating apt packages..."
apt update -y  2>/dev/null || true
apt upgrade -y 2>/dev/null || true

# ── 2. Write VNC startup script ───────────────────────────────────────────
# Uses chosen DE's start command; always rewritten so re-running fixes issues.
echo "[2/8] Writing ~/.vnc/xstartup (${START_CMD})..."
mkdir -p ~/.vnc
# Note: *unquoted* EOF so ${START_CMD} is expanded into the file
cat > ~/.vnc/xstartup << EOF
#!/usr/bin/env bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR="\${PREFIX}/tmp"
export XKL_XMODMAP_DISABLE=1
xrdb "\$HOME/.Xresources" 2>/dev/null || true
exec dbus-launch --exit-with-session ${START_CMD}
EOF
chmod +x ~/.vnc/xstartup

# Neutralize .xsession so the DE doesn't launch twice on the VNC display
cat > ~/.xsession << 'EOF'
#!/usr/bin/env sh
exit 0
EOF
chmod +x ~/.xsession

# ── 3. Write xrdp.ini —  VNC backend on port 5901 ───────────────────────
echo "[3/8] Writing xrdp.ini..."
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

# ── 4. Install OpenCode AI CLI and OpenClaw (npm, idempotent) ───────────
echo "[4/8] Installing OpenCode AI CLI..."
# CI=true: prevents node postinstall scripts from running interactive REPLs.
# Do NOT use 2>/dev/null here — it hides npm output but still lets interactive
# postinstall scripts inherit the terminal (which opens a Node.js REPL).
if ! CI=true npm install -g opencode-ai; then
    echo "  [WARN] opencode-ai install failed — continuing."
fi

echo "        Installing OpenClaw AI..."
if ! CI=true npm install -g openclaw@latest; then
    echo "  [WARN] openclaw install failed — continuing."
fi

# Network patch (prevents openclaw crashing when it reads network interfaces)
HIJACK_FILE="${HOME}/hijack.js"
cat > "$HIJACK_FILE" << 'EOF'
const os = require('os');
os.networkInterfaces = () => ({});
EOF

BASHRC="${HOME}/.bashrc"
if ! grep -qF "hijack.js" "$BASHRC" 2>/dev/null; then
    echo "export NODE_OPTIONS=\"-r ${HIJACK_FILE}\"" >> "$BASHRC"
fi

# ── 5. Set Termux hostname ────────────────────────────────────────────────
echo "[5/8] Setting hostname..."
HOSTNAME_FILE="${PREFIX}/etc/hostname"
if [ ! -f "$HOSTNAME_FILE" ]; then
    echo "android-linux" > "$HOSTNAME_FILE"
fi
TERMUX_HOST=$(cat "$HOSTNAME_FILE")
hostname "$TERMUX_HOST" 2>/dev/null || true
echo "  -> Hostname: $TERMUX_HOST"

# ── 6. VNC password ───────────────────────────────────────────────────────
echo "[6/8] Checking VNC password..."
if [ ! -f ~/.vnc/passwd ]; then
    echo "  -> No VNC password set. Enter one now (used at the RDP login screen):"
    vncpasswd
else
    echo "  -> VNC password already set (~/.vnc/passwd exists), skipping."
    echo "     To change it, run: vncpasswd"
fi

# ── 7. Make scripts executable ───────────────────────────────────────────
echo "[7/8] Making scripts executable..."
chmod +x "${SCRIPT_DIR}/start.sh" "${SCRIPT_DIR}/stop.sh" 2>/dev/null || true

# ── 8. Detect network and display connection info ─────────────────────────
echo "[8/8] Gathering network info..."

if command -v ip >/dev/null 2>&1; then
    LAN_IP=$(ip -4 addr show scope global 2>/dev/null \
        | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1 || true)
else
    LAN_IP=$(ifconfig 2>/dev/null \
        | grep -Eo '192\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1 || true)
fi
RDP_USER=$(whoami)

echo ""
echo "================================================="
echo "  [setup.sh] Setup complete!"
echo "================================================="
echo ""
echo "  Hostname   : ${TERMUX_HOST}"
echo "  Username   : ${RDP_USER}"
echo "  Wi-Fi IP   : ${LAN_IP:-(unknown — run: ip -4 addr show scope global)}"
echo "  RDP Address: ${LAN_IP:-<phone-ip>}:3389"
echo ""
echo "  ┌─ Static IP (recommended) ────────────────────────┐"
echo "  │ To stop your IP from changing on every reboot:   │"
echo "  │  Android Wi-Fi Settings → long-press your network│"
echo "  │  → Modify network → Advanced → IP settings       │"
echo "  │  → Switch 'DHCP' to 'Static'                     │"
echo "  │  → Set IP address to: ${LAN_IP:-<current ip>}             │"
echo "  └───────────────────────────────────────────────────┘"
echo ""
echo "  Now run:  ./start.sh"
echo ""
