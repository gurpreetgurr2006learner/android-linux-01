#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# Termux Linux Environment Bootstrapper
# ==============================================================================

# --- Configuration Constants ---
MAX_PHASES=11
CURRENT_PHASE=0
DEV_BRAND=$(getprop ro.product.brand 2>/dev/null || echo "Unknown")
DEV_MODEL=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
SYS_VERSION=$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")
GPU_EGL=$(getprop ro.hardware.egl 2>/dev/null || echo "")

CHOSEN_INTERFACE="1"
UI_IDENTIFIER="XFCE4"
STARTUP_APP="startxfce4"
SESSION_LEADER="xfce4-session"
DOCK_COMPONENT="plank"

# --- Styling Options ---
COL_RED='\033[38;5;196m'
COL_GRN='\033[38;5;46m'
COL_YLW='\033[38;5;226m'
COL_BLU='\033[38;5;33m'
COL_MAG='\033[38;5;201m'
COL_CYN='\033[38;5;51m'
COL_WHT='\033[38;5;231m'
COL_GRY='\033[38;5;244m'
NO_COL='\033[0m'
TXT_BLD='\033[1m'

# --- UI Elements ---
show_header() {
    clear
    echo -e "${COL_CYN}"
    cat << 'EOF'
  ===========================================
    Android-to-Linux Setup Utility for Termux
  ===========================================
EOF
    echo -e "${NO_COL}\n"
}

render_bar() {
    ((CURRENT_PHASE++))
    local pct=$((CURRENT_PHASE * 100 / MAX_PHASES))
    local active=$((pct / 5))
    local inactive=$((20 - active))
    local pbar="${COL_GRN}"
    for ((i=0; i<active; i++)); do pbar+="█"; done
    pbar="${pbar}${COL_GRY}"
    for ((i=0; i<inactive; i++)); do pbar+="░"; done
    pbar="${pbar}${NO_COL}"
    echo -e "\n${COL_BLU}---> Phase ${CURRENT_PHASE}/${MAX_PHASES} | ${pbar} ${COL_WHT}${pct}%${NO_COL}\n"
}

async_loader() {
    local bg_task=$1
    local label=$2
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local idx=0
    
    while kill -0 $bg_task 2>/dev/null; do
        printf "\r ${COL_CYN}${frames[$idx]}${NO_COL} %s..." "$label"
        idx=$(( (idx+1) % 10 ))
        sleep 0.1
    done
    wait $bg_task
    local outcome=$?
    if [ $outcome -eq 0 ]; then
        printf "\r ${COL_GRN}✔${NO_COL} %s               \n" "$label"
    else
        printf "\r ${COL_RED}✘${NO_COL} %s (Failed)      \n" "$label"
    fi
    return $outcome
}

grab_pkg() {
    local target_pkg=$1
    local display_val=${2:-$target_pkg}
    (pkg install -y "$target_pkg" > /dev/null 2>&1) &
    async_loader $! "Procuring $display_val"
}

# --- Initialization Phase ---
init_env() {
    echo -e "${COL_MAG}[*] Analyzing hardware specs...${NO_COL}\n"
    echo -e "  - Hardware: ${COL_WHT}${DEV_BRAND} ${DEV_MODEL}${NO_COL}"
    echo -e "  - OS Version: ${COL_WHT}${SYS_VERSION}${NO_COL}"
    
    if [[ "${GPU_EGL,,}" == *"adreno"* ]] || [[ "${DEV_BRAND,,}" == *"samsung"* ]] || [[ "${DEV_BRAND,,}" == *"oneplus"* ]] || [[ "${DEV_BRAND,,}" == *"xiaomi"* ]]; then
        GRAPHICS_MODE="freedreno"
        echo -e "  - GPU Accelerator: ${COL_WHT}Mesa Turnip / Adreno Supported${NO_COL}"
    else
        GRAPHICS_MODE="zink_native"
        echo -e "  - GPU Accelerator: ${COL_WHT}Zink Native Override${NO_COL}"
        echo -e "${COL_YLW}    [!] Note: Limited hardware acceleration due to non-Adreno chip.${NO_COL}"
    fi
    echo ""
    
    echo -e "${COL_CYN}Pick a graphic environment layer:${NO_COL}"
    echo -e "  ${COL_WHT}1) XFCE4${NO_COL} (Balanced, Mac-like, High stability)"
    echo -e "  ${COL_WHT}2) LXQt${NO_COL}  (Minimalist, optimized for old hardware)"
    echo -e "  ${COL_WHT}3) MATE${NO_COL}  (Standard traditional desktop)"
    echo -e "  ${COL_WHT}4) KDE Plasma${NO_COL} (Aesthetically focused, high resource usage)"
    echo ""
    while true; do
        read -p "Select [1-4] (default: 1): " INPUT_SEL
        INPUT_SEL=${INPUT_SEL:-1}
        if [[ "$INPUT_SEL" =~ ^[1-4]$ ]]; then
            CHOSEN_INTERFACE="$INPUT_SEL"
            break
        else
            echo "Bad selection."
        fi
    done
    
    case $CHOSEN_INTERFACE in
        1) UI_IDENTIFIER="XFCE4"; STARTUP_APP="startxfce4"; SESSION_LEADER="xfce4-session"; DOCK_COMPONENT="plank" ;;
        2) UI_IDENTIFIER="LXQt"; STARTUP_APP="startlxqt"; SESSION_LEADER="lxqt-session"; DOCK_COMPONENT="" ;;
        3) UI_IDENTIFIER="MATE"; STARTUP_APP="mate-session"; SESSION_LEADER="mate-session"; DOCK_COMPONENT="plank" ;;
        4) UI_IDENTIFIER="KDE Plasma"; STARTUP_APP="startplasma-x11"; SESSION_LEADER="startplasma-x11"; DOCK_COMPONENT="kwin_x11" ;;
    esac
    
    # Store settings for VNC/RDP helper scripts
    mkdir -p ~/.config
    cat > ~/.config/termux-linux.conf << CONF_EOF
DE_NAME="${UI_IDENTIFIER}"
START_CMD="${STARTUP_APP}"
SESSION_PROC="${SESSION_LEADER}"
PANEL_PROC="${DOCK_COMPONENT}"
DE_INPUT="${CHOSEN_INTERFACE}"
CONF_EOF

    echo -e "\n${COL_GRN}[+] Environment set to: ${UI_IDENTIFIER}.${NO_COL}"
    sleep 2
}

# --- Module Executors ---
module_base_sync() {
    render_bar
    echo -e "${COL_MAG}Synchronizing package indices...${NO_COL}\n"
    (pkg update -y > /dev/null 2>&1) &
    async_loader $! "Syncing apt cache"
    (pkg upgrade -y > /dev/null 2>&1) &
    async_loader $! "Patching out-of-date bins"
}

module_external_repos() {
    render_bar
    echo -e "${COL_MAG}Binding custom APT repos...${NO_COL}\n"
    grab_pkg "x11-repo" "Termux X11 Core"
    grab_pkg "tur-repo" "Termux User Repo"
}

module_xorg_server() {
    render_bar
    echo -e "${COL_MAG}Setting up display pipeline...${NO_COL}\n"
    grab_pkg "termux-x11-nightly" "X11 Display Interface"
    grab_pkg "xorg-xrandr" "Resolution Controller"
    grab_pkg "tigervnc" "VNC Server Integration"
    grab_pkg "xrdp" "Microsoft RDP Backend"
    grab_pkg "dbus" "D-Bus Daemon"
    grab_pkg "nodejs" "Node Runtime"
}

module_gui_layer() {
    render_bar
    echo -e "${COL_MAG}Deploying ${UI_IDENTIFIER} assets...${NO_COL}\n"
    
    if [ "$CHOSEN_INTERFACE" == "1" ]; then
        grab_pkg "xfce4" "XFCE Base System"
        grab_pkg "xfce4-terminal" "Terminal Emulator"
        grab_pkg "xfce4-whiskermenu-plugin" "App Launcher Menu"
        grab_pkg "plank-reloaded" "Dock Extension"
        grab_pkg "thunar" "File Navigator"
        grab_pkg "mousepad" "Text Editor"
    elif [ "$CHOSEN_INTERFACE" == "2" ]; then
        grab_pkg "lxqt" "LXQt Core"
        grab_pkg "qterminal" "QTerminal App"
        grab_pkg "pcmanfm-qt" "PCMan File Manager"
        grab_pkg "featherpad" "Lightweight Editor"
    elif [ "$CHOSEN_INTERFACE" == "3" ]; then
        grab_pkg "mate" "MATE Framework"
        grab_pkg "mate-tweak" "MATE Customizer"
        grab_pkg "plank-reloaded" "Dock App"
        grab_pkg "mate-terminal" "MATE Prompt"
    elif [ "$CHOSEN_INTERFACE" == "4" ]; then
        grab_pkg "plasma-desktop" "KDE Plasma Workspaces"
        grab_pkg "konsole" "Konsole Tracker"
        grab_pkg "dolphin" "Dolphin FM"
    fi
}

module_gfx_drivers() {
    render_bar
    echo -e "${COL_MAG}Binding hardware GPU APIs...${NO_COL}\n"
    grab_pkg "mesa-zink" "Zink Vulkan Layer"
    if [ "$GRAPHICS_MODE" == "freedreno" ]; then
        grab_pkg "mesa-vulkan-icd-freedreno" "Turnip Mesa Wrapper"
    fi
    grab_pkg "vulkan-loader-android" "Native Android Vulkan"
}

module_audio_subsys() {
    render_bar
    echo -e "${COL_MAG}Applying audio patches...${NO_COL}\n"
    grab_pkg "pulseaudio" "PA Network Daemon"
}

module_extra_utilities() {
    render_bar
    echo -e "${COL_MAG}Injecting productivity suite...${NO_COL}\n"
    grab_pkg "firefox" "Mozilla Web Browser"
    grab_pkg "vlc" "VLC Video Framework"
    grab_pkg "git" "Git SCM Hub"
    grab_pkg "wget" "Wget Web Fetcher"
    grab_pkg "curl" "Curl Network Requestor"
}

module_python_demo() {
    render_bar
    echo -e "${COL_MAG}Configuring scripting environment...${NO_COL}\n"
    grab_pkg "python" "Python Interpreter"
    
    (pip install flask > /dev/null 2>&1) &
    async_loader $! "Building Flask bindings"
    
    mkdir -p "$HOME/demo_python"
    cat > "$HOME/demo_python/app.py" << 'PY_EOF'
from flask import Flask, render_template_string
app = Flask(__name__)

@app.route("/")
def hello():
    return render_template_string("""
    <html>
        <body style="background-color:#0d1117;color:#58a6ff;font-family:monospace;text-align:center;padding:50px">
            <h1>Termux Hosted Hardware Environment</h1>
            <h3>This endpoint is successfully routing mapped via Python Flask!</h3>
        </body>
    </html>
    """)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
PY_EOF
    echo -e "  [+] Sample Python demo compiled at ~/demo_python/app.py"
}

module_wine_wrapper() {
    render_bar
    echo -e "${COL_MAG}Provisioning Windows translation layers...${NO_COL}\n"
    (pkg remove wine-stable -y > /dev/null 2>&1) &
    async_loader $! "Purging deprecated Wine instances"
    
    grab_pkg "hangover-wine" "Hangover x86 Engine"
    grab_pkg "hangover-wowbox64" "x64 Emulator Box"
    
    ln -sf /data/data/com.termux/files/usr/opt/hangover-wine/bin/wine /data/data/com.termux/files/usr/bin/wine
    ln -sf /data/data/com.termux/files/usr/opt/hangover-wine/bin/winecfg /data/data/com.termux/files/usr/bin/winecfg
}

module_system_scripts() {
    render_bar
    echo -e "${COL_MAG}Fleshing out bash control scrips...${NO_COL}\n"
    
    mkdir -p ~/.config
    
    local XDG_PATHS="export XDG_DATA_DIRS=/data/data/com.termux/files/usr/share:\${XDG_DATA_DIRS}\nexport XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg:\${XDG_CONFIG_DIRS}"

    if [ "$CHOSEN_INTERFACE" == "4" ]; then
        mkdir -p ~/.config/plasma-workspace/env
        echo -e "#!/data/data/com.termux/files/usr/bin/bash\n$XDG_PATHS" > ~/.config/plasma-workspace/env/xdg_override.sh
        chmod +x ~/.config/plasma-workspace/env/xdg_override.sh
    fi
    
    cat > ~/.config/gpu-profile.sh << GPU_EOF
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLES_VERSION_OVERRIDE=3.2
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
export MESA_VK_WSI_PRESENT_MODE=immediate
export ZINK_DESCRIPTORS=lazy
GPU_EOF

    if [ "$CHOSEN_INTERFACE" == "4" ]; then
        echo "export KWIN_COMPOSE=O2ES" >> ~/.config/gpu-profile.sh
    else
        echo -e "$XDG_PATHS" >> ~/.config/gpu-profile.sh
    fi
    
    # Plank integration
    if [[ "$CHOSEN_INTERFACE" == "1" || "$CHOSEN_INTERFACE" == "3" ]]; then
        mkdir -p ~/.config/autostart
        cat > ~/.config/autostart/plank.desktop << 'PLANK_EXT'
[Desktop Entry]
Type=Application
Exec=plank
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Plank
PLANK_EXT
    else
        rm -f ~/.config/autostart/plank.desktop 2>/dev/null
    fi

    # Build terminator commands
    local TERM_CMD=""
    if [ "$CHOSEN_INTERFACE" == "1" ]; then TERM_CMD="pkill -9 xfce4-session; pkill -9 plank"; fi
    if [ "$CHOSEN_INTERFACE" == "2" ]; then TERM_CMD="pkill -9 lxqt-session"; fi
    if [ "$CHOSEN_INTERFACE" == "3" ]; then TERM_CMD="pkill -9 mate-session; pkill -9 plank"; fi
    if [ "$CHOSEN_INTERFACE" == "4" ]; then
        STARTUP_APP="(sleep 5 && pkill -9 plasmashell && plasmashell) > /dev/null 2>&1 &\nexec startplasma-x11"
        TERM_CMD="pkill -9 startplasma-x11; pkill -9 kwin_x11"
    else
        STARTUP_APP="exec ${STARTUP_APP}"
    fi

    cat > ~/start-linux.sh << SH_START
#!/data/data/com.termux/files/usr/bin/bash
echo ""
echo "[*] Initializing ${UI_IDENTIFIER} workspace..."
echo ""
source ~/.config/gpu-profile.sh 2>/dev/null

echo "[*] Terminating ghost processes..."
pkill -9 -f "termux.x11" 2>/dev/null
${TERM_CMD} 2>/dev/null
pkill -9 -f "dbus" 2>/dev/null

unset PULSE_SERVER
pulseaudio --kill 2>/dev/null
sleep 0.5
echo "[*] Booting PA subsystem..."
pulseaudio --start --exit-idle-time=-1
sleep 1
pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 2>/dev/null
export PULSE_SERVER=127.0.0.1

echo "[*] Launching Wayland/X11 surface..."
termux-x11 :0 -ac &
sleep 3
export DISPLAY=:0

echo -e "\n  [>] Open the Termux-X11 android app now to view the stream!\n"
${STARTUP_APP}
SH_START

    cat > ~/stop-linux.sh << SH_KILL
#!/data/data/com.termux/files/usr/bin/bash
echo "Halting ${UI_IDENTIFIER} workspace..."
pkill -9 -f "termux.x11" 2>/dev/null
pkill -9 -f "pulseaudio" 2>/dev/null
${TERM_CMD} 2>/dev/null
pkill -9 -f "dbus" 2>/dev/null
echo "Session cleanly unmounted."
SH_KILL

    chmod +x ~/start-linux.sh ~/stop-linux.sh
    echo -e "  [+] Hooks generated at ~/start-linux.sh & ~/stop-linux.sh"
}

module_desktop_links() {
    render_bar
    echo -e "${COL_MAG}Plotting icon grid layout...${NO_COL}\n"
    mkdir -p ~/Desktop
    
    cat > ~/Desktop/Firefox.desktop << 'EXT'
[Desktop Entry]
Name=Firefox
Exec=firefox
Icon=firefox
Type=Application
EXT

    cat > ~/Desktop/VLC.desktop << 'EXT'
[Desktop Entry]
Name=VLC Media Player
Exec=vlc
Icon=vlc
Type=Application
EXT

    cat > ~/Desktop/Wine_Config.desktop << 'EXT'
[Desktop Entry]
Name=Wine Configuration
Exec=wine winecfg
Icon=wine
Type=Application
EXT

    local default_term="xfce4-terminal"
    local default_icon="utilities-terminal"
    if [ "$CHOSEN_INTERFACE" == "2" ]; then default_term="qterminal"; fi
    if [ "$CHOSEN_INTERFACE" == "3" ]; then default_term="mate-terminal"; fi
    if [ "$CHOSEN_INTERFACE" == "4" ]; then default_term="konsole"; fi
    
    cat > ~/Desktop/Terminal.desktop << EXT
[Desktop Entry]
Name=Root Terminal
Exec=${default_term}
Icon=${default_icon}
Type=Application
EXT

    chmod +x ~/Desktop/*.desktop 2>/dev/null
}

# --- Teardown & Exit ---
print_footer() {
    echo -e "\n${COL_GRN}"
    cat << 'FOOT_EOF'
   ========================================================
     [✔] BASE INSTALLATION METRICS SATISFIED
   ========================================================
FOOT_EOF
    echo -e "${NO_COL}"
    echo -e "${COL_WHT}[*] Your custom ${UI_IDENTIFIER} profile is standing by.${NO_COL}"
    echo -e "    - Prebuilt Web Framework included at ~/demo_python"
    echo -e "    - VNC & X11 Server binaries present"
    echo -e "    - Hardware 3D Acceleration flags built into ~/start-linux.sh"
    echo ""
    echo -e "${COL_YLW}------------------------------------------------------------${NO_COL}"
    echo -e "${COL_WHT}* TO BIND RDP & VNC HOOKS:${NO_COL} ${COL_CYN}./setup.sh${NO_COL}"
    echo -e "${COL_WHT}* NATIVE LOCAL EXECUTION:${NO_COL}  ${COL_CYN}~/start-linux.sh${NO_COL} (or ./start.sh)"
    echo -e "${COL_WHT}* HARD KILL ALL PROCS:${NO_COL}     ${COL_CYN}~/stop-linux.sh${NO_COL} (or ./stop.sh)"
    echo -e "${COL_YLW}------------------------------------------------------------${NO_COL}\n"
}

# --- System Exec ---
execute_pipeline() {
    show_header
    init_env
    module_base_sync
    module_external_repos
    module_xorg_server
    module_gui_layer
    module_gfx_drivers
    module_audio_subsys
    module_extra_utilities
    module_python_demo
    module_wine_wrapper
    module_system_scripts
    module_desktop_links
    print_footer
}

execute_pipeline
