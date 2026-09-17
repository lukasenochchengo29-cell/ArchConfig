#!/usr/bin/env bash

# Caffeine Mode for Hyprland / HyDE
# Fully inhibits system sleep, DPMS, lock, and hypridle timers.

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/caffeine.pid"
WAYBAR_SIGNAL=9

is_active() {
    if [ -f "$PIDFILE" ]; then
        local pid
        pid=$(cat "$PIDFILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    if pgrep -f "systemd-inhibit.*--who=Caffeine" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

activate() {
    systemd-inhibit --what=idle:sleep:handle-lid-switch \
                    --who="Caffeine" \
                    --why="Caffeine Mode active - Laptop sleep inhibited" \
                    --mode=block \
                    sleep infinity &
    local inhp_pid=$!
    echo "$inhp_pid" > "$PIDFILE"

    pkill -STOP hypridle 2>/dev/null

    notify-send -a "Caffeine" -i "preferences-desktop-screensaver" \
        "󰅶 Caffeine Mode ON" "Sleep, screen lock, and display dimming are disabled."
}

deactivate() {
    if [ -f "$PIDFILE" ]; then
        local pid
        pid=$(cat "$PIDFILE" 2>/dev/null)
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null
        fi
        rm -f "$PIDFILE"
    fi
    pkill -f "systemd-inhibit.*--who=Caffeine" 2>/dev/null

    pkill -CONT hypridle 2>/dev/null

    notify-send -a "Caffeine" -i "preferences-desktop-screensaver" \
        "󱻪 Caffeine Mode OFF" "Normal power saving and sleep settings restored."
}

toggle() {
    if is_active; then
        deactivate
    else
        activate
    fi
    pkill -RTMIN+${WAYBAR_SIGNAL} waybar 2>/dev/null
}

status_json() {
    if is_active; then
        echo '{"text":"󰅶","alt":"activated","tooltip":"<span foreground=\"#a6e3a1\"><b>󰅶 Caffeine Mode Active</b></span>\nLaptop will stay awake (no sleep, lock, or dim)\n<i>Click to disable</i>","class":"activated"}'
    else
        echo '{"text":"󱻪","alt":"deactivated","tooltip":"<span foreground=\"#f38ba8\"><b>󱻪 Caffeine Mode Inactive</b></span>\nSystem follows normal sleep rules\n<i>Click to enable</i>","class":"deactivated"}'
    fi
}

case "$1" in
    toggle)
        toggle
        ;;
    on|activate)
        activate
        pkill -RTMIN+${WAYBAR_SIGNAL} waybar 2>/dev/null
        ;;
    off|deactivate)
        deactivate
        pkill -RTMIN+${WAYBAR_SIGNAL} waybar 2>/dev/null
        ;;
    status)
        status_json
        ;;
    *)
        status_json
        ;;
esac
