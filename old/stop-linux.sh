#!/data/data/com.termux/files/usr/bin/bash
echo "Stopping XFCE4..."
pkill -9 -f "termux.x11" 2>/dev/null
pkill -9 -f "pulseaudio" 2>/dev/null
pkill -9 xfce4-session; pkill -9 plank 2>/dev/null
pkill -9 -f "dbus" 2>/dev/null
echo "Desktop stopped."