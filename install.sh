#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# install.sh — Feature-rich, interactive Termux Linux Setup
# =============================================================================
# This script integrates with start.sh and stop.sh in the same directory.
# It allows selecting a Desktop Environment (DE), configures VNC/xRDP,
# installs GPU acceleration, Python demo, Windows apps support (Wine),
# and updates start.sh/stop.sh automatically based on your choice.
#
# HOW TO RUN: bash install.sh
# =============================================================================

set -e

# -------------- COLORS & UI --------------
GREEN='\033[0;32m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}"
cat << 'EOF'
===================================================
      Termux Linux Premium Setup (Interactive)
===================================================
EOF
echo -e "${NC}"

# -------------- DEVICE DETECTION --------------
echo -e "${PURPLE}[*] Detecting device capabilities...${NC}"
DEVICE_BRAND=$(getprop ro.product.brand 2>/dev/null || echo "Unknown")
GPU_VENDOR=$(getprop ro.hardware.egl 2>/dev/null || echo "Unknown")
echo -e "  -> Brand: ${WHITE}${DEVICE_BRAND}${NC} | GPU: ${WHITE}${GPU_VENDOR}${NC}"

if [[ "$GPU_VENDOR" == *"adreno"* ]] || [[ "$DEVICE_BRAND" =~ ^(?i)(samsung|oneplus|xiaomi)$ ]]; then
    GPU_DRIVER="freedreno"
    echo -e "  -> Hardware Acceleration: ${GREEN}Supported (Adreno/Turnip)${NC}"
else
    GPU_DRIVER="zink_native"
    echo -e "  -> Hardware Acceleration: ${YELLOW}Zink Native (Software fallback possible)${NC}"
fi
echo ""

# -------------- DE SELECTION --------------
echo -e "${CYAN}Please choose your Desktop Environment:${NC}"
echo -e "  ${WHITE}1) XFCE4${NC}       (Recommended - Fast, integrates perfectly with RDP)"
echo -e "  ${WHITE}2) LXQt${NC}        (Ultra lightweight)"
echo -e "  ${WHITE}3) MATE${NC}        (Classic UI)"
echo -e "  ${WHITE}4) KDE Plasma${NC}  (Heavy, requires strong GPU/RAM)"
echo ""
while true; do
    read -p "Enter number (1-4) [default: 1]: " DE_INPUT
    DE_INPUT=${DE_INPUT:-1}
    if [[ "$DE_INPUT" =~ ^[1-4]$ ]]; then
        break
    else
        echo "Invalid input. Enter 1, 2, 3, or 4."
    fi
done

DE_CHOICE=$DE_INPUT
case $DE_CHOICE in
    1) DE_NAME="XFCE4"; START_CMD="startxfce4"; SESSION_PROC="xfce4-session"; PANEL_PROC="plank" ;;
    2) DE_NAME="LXQt"; START_CMD="startlxqt"; SESSION_PROC="lxqt-session"; PANEL_PROC="" ;;
    3) DE_NAME="MATE"; START_CMD="mate-session"; SESSION_PROC="mate-session"; PANEL_PROC="plank" ;;
    4) DE_NAME="KDE Plasma"; START_CMD="startplasma-x11"; SESSION_PROC="startplasma-x11"; PANEL_PROC="kwin_x11" ;;
esac

echo -e "\n${GREEN}[+] Selected: ${DE_NAME}${NC}\n"

# -------------- 1. UPDATE & REPOS --------------
echo -e "${PURPLE}[1/7] Updating Termux and adding repositories...${NC}"
pkg update -y
pkg install x11-repo tur-repo -y

# -------------- 2. CORE PACKAGES --------------
echo -e "${PURPLE}[2/7] Installing Display, Audio, and RDP Core...${NC}"
pkg install -y termux-x11-nightly xorg-xrandr pulseaudio tigervnc xrdp dbus

# -------------- 3. DESKTOP ENVIRONMENT --------------
echo -e "${PURPLE}[3/7] Installing ${DE_NAME} Desktop...${NC}"
if [ "$DE_CHOICE" == "1" ]; then
    pkg install -y xfce4 xfce4-goodies xfce4-terminal xfce4-whiskermenu-plugin plank thunar mousepad
elif [ "$DE_CHOICE" == "2" ]; then
    pkg install -y lxqt qterminal pcmanfm-qt featherpad
elif [ "$DE_CHOICE" == "3" ]; then
    pkg install -y mate mate-tweak plank mate-terminal
elif [ "$DE_CHOICE" == "4" ]; then
    pkg install -y plasma-desktop konsole dolphin
fi

# -------------- 4. GPU & ACCELERATION --------------
echo -e "${PURPLE}[4/7] Configuring Hardware Acceleration...${NC}"
pkg install -y mesa-zink vulkan-loader-android
if [ "$GPU_DRIVER" == "freedreno" ]; then
    pkg install -y mesa-vulkan-icd-freedreno
fi

mkdir -p ~/.config
cat > ~/.config/linux-gpu.sh << 'EOF'
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLES_VERSION_OVERRIDE=3.2
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
export MESA_VK_WSI_PRESENT_MODE=immediate
export ZINK_DESCRIPTORS=lazy
export XDG_DATA_DIRS=/data/data/com.termux/files/usr/share:${XDG_DATA_DIRS}
export XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg:${XDG_CONFIG_DIRS}
EOF

if [ "$DE_CHOICE" == "4" ]; then
    echo "export KWIN_COMPOSE=O2ES" >> ~/.config/linux-gpu.sh
fi

# -------------- 5. APPS & EXTRAS --------------
echo -e "${PURPLE}[5/7] Installing Web Browsers, Media, Python, Node.js, Wine, OpenCode...${NC}"
pkg install -y firefox vlc git wget curl python nodejs hangover-wine hangover-wowbox64

# OpenCode AI
echo "  -> Installing OpenCode AI CLI..."
npm install -g opencode-ai

# Python Demo
mkdir -p ~/demo_python
(pip install flask >/dev/null 2>&1 || true)
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

# Wine Fixes
ln -sf /data/data/com.termux/files/usr/opt/hangover-wine/bin/wine /data/data/com.termux/files/usr/bin/wine || true
ln -sf /data/data/com.termux/files/usr/opt/hangover-wine/bin/winecfg /data/data/com.termux/files/usr/bin/winecfg || true

# Shortcuts
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
chmod +x ~/Desktop/*.desktop 2>/dev/null || true

# -------------- 6. RDP & VNC CONFIG --------------
echo -e "${PURPLE}[6/7] Configuring VNC and xRDP for ${DE_NAME}...${NC}"
mkdir -p ~/.vnc
cat > ~/.vnc/xstartup << EOF
#!/data/data/com.termux/files/usr/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR="/data/data/com.termux/files/usr/tmp"
export XKL_XMODMAP_DISABLE=1
xrdb "\$HOME/.Xresources" 2>/dev/null || true
exec dbus-launch --exit-with-session ${START_CMD}
EOF
chmod +x ~/.vnc/xstartup

cat > ~/.xsession << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
exit 0
EOF
chmod +x ~/.xsession

XRDP_CONF="$PREFIX/etc/xrdp/xrdp.ini"
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

if [ ! -f ~/.vnc/passwd ]; then
    echo "  -> No VNC password set. Enter one now (used at the RDP login screen):"
    vncpasswd
fi

# -------------- 7. PATCH START/STOP SCRIPTS --------------
echo -e "${PURPLE}[7/7] Updating local start.sh and stop.sh for ${DE_NAME}...${NC}"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

if [ -f "$SCRIPT_DIR/start.sh" ]; then
    # Patch the exec line at the end
    sed -i "s/exec startxfce4/exec ${START_CMD}/g" "$SCRIPT_DIR/start.sh"
    sed -i "s/exec startlxqt/exec ${START_CMD}/g" "$SCRIPT_DIR/start.sh"
    sed -i "s/exec mate-session/exec ${START_CMD}/g" "$SCRIPT_DIR/start.sh"
    sed -i "s/exec startplasma-x11/exec ${START_CMD}/g" "$SCRIPT_DIR/start.sh"

    # Patch process kills
    sed -i "s/pkill -9 xfce4-session/pkill -9 ${SESSION_PROC}/g" "$SCRIPT_DIR/start.sh"
    sed -i "s/pkill -9 lxqt-session/pkill -9 ${SESSION_PROC}/g" "$SCRIPT_DIR/start.sh"
    sed -i "s/pkill -9 mate-session/pkill -9 ${SESSION_PROC}/g" "$SCRIPT_DIR/start.sh"
    sed -i "s/pkill -9 startplasma-x11/pkill -9 ${SESSION_PROC}/g" "$SCRIPT_DIR/start.sh"
    
    if [ -n "$PANEL_PROC" ]; then
        sed -i "s/pkill -9 plank/pkill -9 ${PANEL_PROC}/g" "$SCRIPT_DIR/start.sh"
    fi
fi

if [ -f "$SCRIPT_DIR/stop.sh" ]; then
    sed -i "s/pkill -9 xfce4-session/pkill -9 ${SESSION_PROC}/g" "$SCRIPT_DIR/stop.sh"
    sed -i "s/pkill -9 lxqt-session/pkill -9 ${SESSION_PROC}/g" "$SCRIPT_DIR/stop.sh"
    sed -i "s/pkill -9 mate-session/pkill -9 ${SESSION_PROC}/g" "$SCRIPT_DIR/stop.sh"
    sed -i "s/pkill -9 startplasma-x11/pkill -9 ${SESSION_PROC}/g" "$SCRIPT_DIR/stop.sh"
    
    if [ -n "$PANEL_PROC" ]; then
        sed -i "s/pkill -9 plank/pkill -9 ${PANEL_PROC}/g" "$SCRIPT_DIR/stop.sh"
    fi
fi

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  [*] INSTALLATION COMPLETE! [${DE_NAME}]       ${NC}"
echo -e "${GREEN}================================================${NC}"
echo -e "  - GPU Acceleration Configured"
echo -e "  - Apps Installed: Firefox, VLC, Python Demo, Wine"
echo -e "  - Local Scripts Updated: start.sh / stop.sh"
echo -e "\nTo start your desktop, run:  ${WHITE}bash start.sh${NC}"
echo ""
