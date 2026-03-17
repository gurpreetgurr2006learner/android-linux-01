#!/usr/bin/env bash
# =============================================================================
# setup.sh — RDP, Node.js, and System Config (Idempotent)
# =============================================================================
# Run this after install.sh to generate required configuration files for RDP,
# VNC, xstartup, Node.js CLI tools, etc. Safe to run multiple times!
#
# HOW TO RUN: bash setup.sh
# =============================================================================

set -eo pipefail   # NOTE: -u intentionally omitted — sourced conf files may
                   # reference unset vars; set -u would kill shell before || true.

trap 'echo "" >&2; echo "[setup.sh] ERROR at line $LINENO — setup aborted." >&2; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

# -------------- COLORS -------------------------------------------------------
GREEN='\033[0;32m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

echo ""
echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}  [setup.sh] Configuring Termux RDP environment${NC}"
echo -e "${CYAN}=================================================${NC}"
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
echo "[1/6] Updating packages..."
apt update -y  2>/dev/null || true
apt upgrade -y 2>/dev/null || true

# ── 2. Write VNC startup script ───────────────────────────────────────────
echo -e "${PURPLE}[2/6] Writing ~/.vnc/xstartup (${START_CMD})...${NC}"
mkdir -p ~/.vnc
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

cat > ~/.xsession << 'EOF'
#!/usr/bin/env sh
exit 0
EOF
chmod +x ~/.xsession

# ── 3. Write xrdp.ini ───────────────────────────────────────────────────
echo -e "${PURPLE}[3/6] Writing xrdp.ini...${NC}"
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

# ── 4. Install OpenCode AI CLI and OpenClaw ────────────────────────────
echo -e "${PURPLE}[4/6] Installing OpenCode AI CLI & OpenClaw...${NC}"

HIJACK_FILE="${HOME}/hijack.js"
cat > "$HIJACK_FILE" << 'EOF'
const os = require('os');
os.networkInterfaces = () => ({});
EOF

if [ "$(uname -o 2>/dev/null)" = "Android" ]; then
    if ! npm i -g opencode-ai opencode-android-arm64 --ignore-scripts; then
        echo "  [WARN] opencode-ai install failed via npm — continuing."
    fi
else
    if ! curl -fsSL https://opencode.ai/install | bash; then
        echo "  [WARN] opencode-ai install failed via curl, trying npm..."
        if ! npm i -g opencode-ai; then
            echo "  [WARN] opencode-ai install failed — continuing."
        fi
    fi
fi
if ! CI=true npm install -g openclaw@latest >/dev/null 2>&1; then
    echo "  [WARN] openclaw install failed — continuing."
fi



BASHRC="${HOME}/.bashrc"
if ! grep -qF "hijack.js" "$BASHRC" 2>/dev/null; then
    echo "export NODE_OPTIONS=\"-r ${HIJACK_FILE}\"" >> "$BASHRC"
fi

# ── 5. Set Termux hostname ─────────────────────────────────────────────
echo -e "${PURPLE}[5/6] Setting hostname...${NC}"
HOSTNAME_FILE="${PREFIX}/etc/hostname"
if [ ! -f "$HOSTNAME_FILE" ]; then
    echo "android-linux" > "$HOSTNAME_FILE"
fi
TERMUX_HOST=$(cat "$HOSTNAME_FILE")
if [ "$(uname -o 2>/dev/null)" != "Android" ]; then
    hostname "$TERMUX_HOST" 2>/dev/null || true
fi
echo "  -> Hostname: $TERMUX_HOST"

# ── 6. VNC password ────────────────────────────────────────────────────
echo -e "${PURPLE}[6/6] Checking VNC password...${NC}"
if [ ! -f ~/.vnc/passwd ]; then
    echo -e "${YELLOW}  -> No VNC password set. Enter one now (used at the RDP login screen):${NC}"
    vncpasswd
else
    echo "  -> VNC password already set (~/.vnc/passwd exists), skipping."
fi

# ── PATH PATCH START/STOP SCRIPTS ───────────────────────────────────────
echo -e "${PURPLE}[*] Patching local start.sh and stop.sh for ${DE_NAME}...${NC}"

ALL_START_CMDS=("startxfce4" "startlxqt" "mate-session" "startplasma-x11")
ALL_SESSION_PROCS=("xfce4-session" "lxqt-session" "mate-session" "startplasma-x11")
ALL_PANEL_PROCS=("plank" "kwin_x11")

patch_script() {
    local target="$1"
    [ -f "$target" ] || return 0
    for cmd in "${ALL_START_CMDS[@]}"; do
        sed -i "s|exec ${cmd}|exec ${START_CMD}|g" "$target"
    done
    for proc in "${ALL_SESSION_PROCS[@]}"; do
        sed -i "s|graceful_kill ${proc}|graceful_kill ${SESSION_PROC}|g" "$target"
    done
    if [ -n "${PANEL_PROC}" ]; then
        for proc in "${ALL_PANEL_PROCS[@]}"; do
            sed -i "s|graceful_kill ${proc}|graceful_kill ${PANEL_PROC}|g" "$target"
        done
    fi
    chmod +x "$target"
}

patch_script "${SCRIPT_DIR}/start.sh"
patch_script "${SCRIPT_DIR}/stop.sh"

# ── Detect network and display connection info ─────────────────────────
if command -v ip >/dev/null 2>&1; then
    LAN_IP=$(ip -4 addr show scope global 2>/dev/null \
        | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1 || true)
else
    LAN_IP=$(ifconfig 2>/dev/null \
        | grep -Eo '192\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1 || true)
fi
RDP_USER=$(whoami)

echo ""
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}  [setup.sh] Setup complete!${NC}"
echo -e "${GREEN}=================================================${NC}"
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
echo ""
echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}  [setup.sh] Testing Environment Startup (Verification)${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""

# ── 1. Start everything in the background ─────────────────────────────────
echo "▶ [1/4] Starting the environment (asynchronous)..."
"${SCRIPT_DIR}/start.sh" &
START_PID=$!

# Give start.sh a moment to launch Xvnc and xrdp
sleep 5

# ── 2. Wait properly for key processes and port ────────────────────────────
echo "▶ [2/4] Waiting for services to fully initialize..."
WAIT_TIMEOUT=60
WAITED=0
SERVICES_READY=false

while [ $WAITED -lt $WAIT_TIMEOUT ]; do
    if pgrep -f "xrdp" >/dev/null && pgrep -f "Xvnc" >/dev/null; then
        SERVICES_READY=true
        break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
done

if [ "$SERVICES_READY" = true ]; then
    echo "  -> Services are up after ${WAITED}s."
    sleep 5
else
    echo "  -> [WARN] Timed out waiting for Xvnc/xrdp after ${WAIT_TIMEOUT}s."
    echo "  -> Continuing to verification anyway..."
fi

# ── 3. Tool verification ───────────────────────────────────────────────────
echo "▶ [3/4] Verifying CLI tools and OpenCode..."
ALL_GOOD=true
TOOLS_TO_CHECK=("opencode-ai" "openclaw" "node" "npm")

for tool in "${TOOLS_TO_CHECK[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        VER=$("$tool" --version 2>/dev/null | head -n 1 || echo "installed")
        echo "  -> [OK] ${tool} is available (version/status: ${VER})"
    else
        echo "  -> [FAIL] ${tool} is missing from PATH or not installed."
        ALL_GOOD=false
    fi
done

echo ""
if [ "$ALL_GOOD" = true ]; then
    echo "  ✅ All essential tools verified!"
else
    echo "  ❌ Some tools were not found. Please review the output above."
fi
echo ""

# ── 4. Graceful stop ───────────────────────────────────────────────────────
echo "▶ [4/4] Stopping the environment gracefully..."
"${SCRIPT_DIR}/stop.sh"

kill "$START_PID" 2>/dev/null || true
wait "$START_PID" 2>/dev/null || true

echo ""
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}  [setup.sh] First-time verification complete.${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""

echo -e "  Now run:  ${WHITE}./start.sh${NC}"
echo ""
