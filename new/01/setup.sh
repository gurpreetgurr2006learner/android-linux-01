#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# setup.sh — Idempotent Termux RDP setup (safe to run multiple times)
# =============================================================================
# Installs xfce4, xrdp, tigervnc and writes config files.
# Each step checks first — already-done steps are skipped, not repeated.
# Re-running this script will never overwrite existing configs or re-prompt
# for a VNC password that is already set.
#
# HOW TO RUN:
#   bash setup.sh
#   (Run in Termux — NOT inside another shell or environment)
# =============================================================================

set -e

echo ""
echo "================================================="
echo "  [setup.sh] Termux RDP setup (idempotent)"
echo "================================================="
echo ""

# ── 1. Update packages and add x11-repo ────────────────────────────────────
echo "[1/5] Updating packages and enabling x11-repo..."
pkg update -y
pkg install x11-repo -y

# ── 2. Install desktop + VNC + XRDP ────────────────────────────────────────
# pkg install is already idempotent — skips packages that are installed.
echo "[2/5] Installing XFCE4, TigerVNC, xrdp, PulseAudio, dbus..."
pkg install -y \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    xfce4-whiskermenu-plugin \
    tigervnc \
    xrdp \
    dbus \
    pulseaudio

# ── 3. Create VNC startup script (launches XFCE4 via VNC) ──────────────────
echo "[3/5] Checking ~/.vnc/xstartup..."
mkdir -p ~/.vnc

if [ ! -f ~/.vnc/xstartup ]; then
    echo "  → Writing ~/.vnc/xstartup"
    cat > ~/.vnc/xstartup << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
export DISPLAY=":1"
export XDG_RUNTIME_DIR="/data/data/com.termux/files/usr/tmp"
xrdb "$HOME/.Xresources" 2>/dev/null || true
export XKL_XMODMAP_DISABLE=1
eval "$(dbus-launch)"
export DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
    chmod +x ~/.vnc/xstartup
else
    echo "  → ~/.vnc/xstartup already exists, skipping"
fi

# Neutralize .xsession so XFCE doesn't launch twice
if [ ! -f ~/.xsession ]; then
    echo "  → Writing ~/.xsession"
    cat > ~/.xsession << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
exit 0
EOF
    chmod +x ~/.xsession
else
    echo "  → ~/.xsession already exists, skipping"
fi

# ── 4. Write xrdp.ini config (VNC backend on port 5901) ────────────────────
echo "[4/5] Checking xrdp.ini config..."
XRDP_CONF="$PREFIX/etc/xrdp/xrdp.ini"

if [ ! -f "$XRDP_CONF" ]; then
    echo "  → Writing $XRDP_CONF"
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
else
    echo "  → $XRDP_CONF already exists, skipping"
fi

# ── 5. Set a VNC password (used when connecting via RDP) ───────────────────
# ~/.vnc/passwd is the binary file vncpasswd writes — if it exists, skip.
echo "[5/5] Checking VNC password..."
if [ ! -f ~/.vnc/passwd ]; then
    echo "  → No VNC password set. Enter one now (used at the RDP login screen):"
    vncpasswd
else
    echo "  → VNC password already set (~/.vnc/passwd exists), skipping"
    echo "     To change it, run:  vncpasswd"
fi

echo ""
echo "================================================="
echo "  [setup.sh] Setup complete!"
echo "================================================="
echo ""
echo "  Now run:  bash start.sh"
echo "  Then connect via RDP to  <your-wifi-ip>:3389"
echo "  Wi-Fi IP: $(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)"
echo ""
