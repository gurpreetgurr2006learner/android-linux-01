#!/usr/bin/env bash
# =============================================================================
# install.sh — One-time Termux prerequisite installer
# =============================================================================
# Installs all packages and configures GPU acceleration.
# Does NOT write service config files (xstartup, xrdp.ini, etc.) —
# that is handled by setup.sh so configs can be re-applied without
# re-installing everything.
#
# WORKFLOW:
#   1. bash install.sh   (once)
#   2. bash setup.sh     (once, or again to reset configs)
#   3. bash start.sh     (every time you want the desktop)
#   4. bash stop.sh      (when done)
# =============================================================================

set -euo pipefail
export CI=true

# ── Error trap ─────────────────────────────────────────────────────────────
trap 'echo "" >&2; echo "[install.sh] ERROR at line $LINENO — installation aborted." >&2; exit 1' ERR

# ── Resolve script directory ───────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

# ── Helper: check if package is installed ──────────────────────────────────
is_installed() {
    pkg list-installed "$1" 2>/dev/null | grep -q "^$1/"
}

# -------------- COLORS -------------------------------------------------------
GREEN='\033[0;32m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}"
cat << 'EOF'
===================================================
      Termux Linux — Prerequisite Installer
===================================================
  After this script finishes, run: ./setup.sh
===================================================
EOF
echo -e "${NC}"

# -------------- DEVICE DETECTION ---------------------------------------------
echo -e "${PURPLE}[*] Detecting device capabilities...${NC}"
DEVICE_BRAND=$(getprop ro.product.brand 2>/dev/null || echo "Unknown")
GPU_VENDOR=$(getprop ro.hardware.egl    2>/dev/null || echo "Unknown")
echo -e "  -> Brand: ${WHITE}${DEVICE_BRAND}${NC} | GPU: ${WHITE}${GPU_VENDOR}${NC}"

GPU_VENDOR_LOWER=$(echo "$GPU_VENDOR"    | tr '[:upper:]' '[:lower:]')
DEVICE_BRAND_LOWER=$(echo "$DEVICE_BRAND" | tr '[:upper:]' '[:lower:]')

if [[ "$GPU_VENDOR_LOWER" == *"adreno"* ]] \
    || [[ "$DEVICE_BRAND_LOWER" == "samsung" ]] \
    || [[ "$DEVICE_BRAND_LOWER" == "oneplus" ]] \
    || [[ "$DEVICE_BRAND_LOWER" == "xiaomi" ]]; then
    GPU_DRIVER="freedreno"
    echo -e "  -> Acceleration: ${GREEN}Supported (Adreno/Turnip)${NC}"
else
    GPU_DRIVER="zink_native"
    echo -e "  -> Acceleration: ${YELLOW}Zink Native (software fallback)${NC}"
fi
echo ""

# -------------- DE SELECTION -------------------------------------------------
echo -e "${CYAN}Choose your Desktop Environment:${NC}"
echo -e "  ${WHITE}1) XFCE4${NC}       (Recommended — fast, RDP-optimised)"
echo -e "  ${WHITE}2) LXQt${NC}        (Ultra lightweight)"
echo -e "  ${WHITE}3) MATE${NC}        (Classic UI)"
echo -e "  ${WHITE}4) KDE Plasma${NC}  (Heavy — requires strong GPU/RAM)"
echo ""
while true; do
    read -r -p "Enter number (1-4) [default: 1]: " DE_INPUT
    DE_INPUT="${DE_INPUT:-1}"
    if [[ "$DE_INPUT" =~ ^[1-4]$ ]]; then break; fi
    echo "Invalid input. Enter 1, 2, 3, or 4."
done

case "$DE_INPUT" in
    1) DE_NAME="XFCE4";      START_CMD="startxfce4";      SESSION_PROC="xfce4-session";   PANEL_PROC="plank"     ;;
    2) DE_NAME="LXQt";       START_CMD="startlxqt";       SESSION_PROC="lxqt-session";    PANEL_PROC=""          ;;
    3) DE_NAME="MATE";       START_CMD="mate-session";    SESSION_PROC="mate-session";    PANEL_PROC="plank"     ;;
    4) DE_NAME="KDE Plasma"; START_CMD="startplasma-x11"; SESSION_PROC="startplasma-x11"; PANEL_PROC="kwin_x11"  ;;
esac

# Save selection so setup.sh and start.sh can read it without re-asking
mkdir -p ~/.config
cat > ~/.config/termux-linux.conf << EOF
DE_NAME="${DE_NAME}"
START_CMD="${START_CMD}"
SESSION_PROC="${SESSION_PROC}"
PANEL_PROC="${PANEL_PROC}"
EOF

echo -e "\n${GREEN}[+] Selected: ${DE_NAME}${NC}\n"

# -------------- 1. REPOS & UPDATE --------------------------------------------
echo -e "${PURPLE}[1/6] Adding Termux repositories...${NC}"
pkg update -y
pkg install -y x11-repo tur-repo
pkg update -y   # refresh after new repos

# -------------- 2. CORE PACKAGES ---------------------------------------------
echo -e "${PURPLE}[2/6] Installing core display, audio, and RDP packages...${NC}"
pkg install -y \
    termux-x11-nightly \
    xorg-xrandr \
    pulseaudio \
    tigervnc \
    xrdp \
    dbus \
    nodejs \
    git \
    wget \
    curl

# -------------- 3. DESKTOP ENVIRONMENT --------------------------------------
echo -e "${PURPLE}[3/6] Installing ${DE_NAME} desktop...${NC}"
case "$DE_INPUT" in
    1) pkg install -y xfce4 xfce4-goodies xfce4-terminal xfce4-whiskermenu-plugin plank thunar mousepad ;;
    2) pkg install -y lxqt qterminal pcmanfm-qt featherpad ;;
    3) pkg install -y mate mate-tweak plank mate-terminal ;;
    4) pkg install -y plasma-desktop konsole dolphin ;;
esac

# -------------- 4. GPU ACCELERATION ------------------------------------------
echo -e "${PURPLE}[4/6] Installing GPU acceleration packages...${NC}"
pkg install -y mesa-zink vulkan-loader-android
[ "$GPU_DRIVER" == "freedreno" ] && pkg install -y mesa-vulkan-icd-freedreno

cat > ~/.config/linux-gpu.sh << 'EOF'
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLES_VERSION_OVERRIDE=3.2
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
export MESA_VK_WSI_PRESENT_MODE=immediate
export ZINK_DESCRIPTORS=lazy
export XDG_DATA_DIRS="${PREFIX}/share:${XDG_DATA_DIRS:-}"
export XDG_CONFIG_DIRS="${PREFIX}/etc/xdg:${XDG_CONFIG_DIRS:-}"
EOF
[ "$DE_INPUT" == "4" ] && echo "export KWIN_COMPOSE=O2ES" >> ~/.config/linux-gpu.sh

# -------------- 5. EXTRA APPS ------------------------------------------------
echo -e "${PURPLE}[5/6] Installing extra apps (browser, media, Python, Wine)...${NC}"
pkg install -y firefox vlc python hangover-wine hangover-wowbox64

# Python demo app
mkdir -p ~/demo_python
pip install flask >/dev/null 2>&1 || true
cat > ~/demo_python/app.py << 'EOF'
from flask import Flask, render_template_string
app = Flask(__name__)
@app.route("/")
def hello():
    return render_template_string("""
    <html>
      <body style="background-color:#1e1e1e;color:#00ff00;font-family:monospace;text-align:center;padding:50px">
        <h1>Hardware Accelerated Linux</h1>
        <h3>Python server running natively on Android!</h3>
      </body>
    </html>
    """)
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF

# Wine convenience symlinks
WINE_OPT="${PREFIX}/opt/hangover-wine/bin"
TERMUX_BIN="${PREFIX}/bin"
ln -sf "${WINE_OPT}/wine"    "${TERMUX_BIN}/wine"    || true
ln -sf "${WINE_OPT}/winecfg" "${TERMUX_BIN}/winecfg" || true

# Desktop shortcuts
mkdir -p ~/Desktop
cat > ~/Desktop/Firefox.desktop << 'EOF'
[Desktop Entry]
Name=Firefox
Exec=firefox
Icon=firefox
Type=Application
EOF
cat > ~/Desktop/VLC.desktop << 'EOF'
[Desktop Entry]
Name=VLC Media Player
Exec=vlc
Icon=vlc
Type=Application
EOF
chmod +x ~/Desktop/Firefox.desktop ~/Desktop/VLC.desktop 2>/dev/null || true

# -------------- 6. PATCH start.sh / stop.sh ---------------------------------
echo -e "${PURPLE}[6/6] Patching start.sh and stop.sh for ${DE_NAME}...${NC}"

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
    echo "  -> Patched: $(basename "$target")"
}

patch_script "${SCRIPT_DIR}/start.sh"
patch_script "${SCRIPT_DIR}/stop.sh"

# -------------- DONE ---------------------------------------------------------
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  [install.sh] Packages installed! [${DE_NAME}]${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "  Next step → run: ${WHITE}bash setup.sh${NC}"
echo ""
