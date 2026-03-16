#!/data/data/com.termux/files/usr/bin/bash
echo ""
echo "[*] Starting XFCE4..."
echo ""
source ~/.config/linux-gpu.sh 2>/dev/null

echo "[*] Cleaning up old sessions..."
pkill -9 -f "termux.x11" 2>/dev/null
pkill -9 xfce4-session; pkill -9 plank 2>/dev/null
pkill -9 -f "dbus" 2>/dev/null

unset PULSE_SERVER
pulseaudio --kill 2>/dev/null
sleep 0.5
echo "[*] Starting audio server..."
pulseaudio --start --exit-idle-time=-1
sleep 1
pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 2>/dev/null
export PULSE_SERVER=127.0.0.1

echo "[*] Starting X11 server..."
termux-x11 :0 -ac &
sleep 3
export DISPLAY=:0

echo "-----------------------------------------------"
echo "  [*] Open Termux-X11 app to view desktop!"
echo "-----------------------------------------------"
echo ""
exec startxfce4