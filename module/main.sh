#!/system/bin/sh
# USB 智能控制 - 纯净版核心逻辑
# 作者：酷安矜持
# 说明：由原模块加壳载荷逐层还原并去除推广/自改写行为，逻辑与原版一致

MODDIR=${0%/*}
CONFIG_FILE="$MODDIR/USB-智能控制配置.prop"
CONFIG_MTIME=0

USB_DEBUG_ENABLED=""
MTP_ENABLED=""
MTP_LOCK_ENABLED=""
GAME_ADB_MODE=""
GAME_LIST_SPACE=""
USB_NODE=""
DEBUG_LOG=""

CACHED_LANDSCAPE=""
CACHED_UNLOCKED=""
LAST_CHECK_TIME=0

log() {
    [ "$DEBUG_LOG" = "开启" ] && echo "$(date '+%F %T') $*" >> /data/adb/usb_auto_debug.log
}

load_config() {
    [ ! -f "$CONFIG_FILE" ] && return
    local mtime=$(stat -c %Y "$CONFIG_FILE" 2>/dev/null)
    [ "$mtime" = "$CONFIG_MTIME" ] && return
    CONFIG_MTIME=$mtime

    local config_content=$(cat "$CONFIG_FILE")

    USB_DEBUG_ENABLED=$(echo "$config_content" | grep '^ADB调试=' | cut -d= -f2 | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    MTP_ENABLED=$(echo "$config_content" | grep '^MTP文件传输=' | cut -d= -f2 | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    MTP_LOCK_ENABLED=$(echo "$config_content" | grep '^MTP_LOCK=' | cut -d= -f2 | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    GAME_ADB_MODE=$(echo "$config_content" | grep '^Game_ADB=' | cut -d= -f2 | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    USB_NODE=$(echo "$config_content" | grep '^USB_NODE=' | cut -d= -f2 | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    DEBUG_LOG=$(echo "$config_content" | grep '^DEBUG_LOG=' | cut -d= -f2 | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    local game_list_raw=$(echo "$config_content" | sed -n '/^GAME_LIST="/,/^"$/p' | sed '1d;$d')
    GAME_LIST_SPACE=$(echo "$game_list_raw" | tr '\n' ' ')

    # 机型适配：找不到配置指定的 USB 节点时，按常见路径自动探测
    if [ -z "$USB_NODE" ] || [ ! -f "$USB_NODE" ]; then
        for node in \
            /sys/class/power_supply/usb/online \
            /sys/class/power_supply/android_usb/online \
            /sys/class/power_supply/usbpd/online \
            /sys/class/power_supply/usb_power_source/online \
            /sys/class/power_supply/switch/online \
            /sys/class/power_supply/dp_usb/online \
            /sys/class/power_supply/typec/online; do
            [ -f "$node" ] && { USB_NODE="$node"; break; }
        done
    fi
    log "config loaded: MTP=$MTP_ENABLED LOCK=$MTP_LOCK_ENABLED USB_NODE=$USB_NODE unlocked=$CACHED_UNLOCKED"
}

is_game_running() {
    [ -z "$GAME_LIST_SPACE" ] && return 1
    pidof $GAME_LIST_SPACE >/dev/null 2>&1
}

is_landscape() {
    local rotation=$(dumpsys window 2>/dev/null | grep -m1 "mCurrentRotation" | grep -oE 'ROTATION_[0-9]+')
    case "$rotation" in
        *ROTATION_90*|*ROTATION_270*) return 0 ;;
        *) return 1 ;;
    esac
}

is_unlocked() {
    # 新版系统（如 API 37）在 dumpsys window policy 中输出 showing=false 表示已解锁
    local s=$(dumpsys window policy 2>/dev/null | grep -m1 -E '^[[:space:]]*showing=' | grep -oE '(true|false)' | head -1)
    [ -z "$s" ] && s=$(dumpsys window 2>/dev/null | grep -m1 -E 'mIsShowing|mKeyguardShowing' | grep -oE '(true|false)' | head -1)
    # 解析不到时按已解锁处理，避免输出格式变化导致永远不触发
    [ -z "$s" ] && return 0
    [ "$s" = "false" ] && return 0
    return 1
}

update_screen_state() {
    local current_time=$(date +%s 2>/dev/null || echo "0")
    if [ $((current_time - LAST_CHECK_TIME)) -ge 1 ] || [ -z "$CACHED_LANDSCAPE" ]; then
        if is_landscape; then
            CACHED_LANDSCAPE="1"
        else
            CACHED_LANDSCAPE="0"
        fi
        if is_unlocked; then
            CACHED_UNLOCKED="1"
        else
            CACHED_UNLOCKED="0"
        fi
        LAST_CHECK_TIME=$current_time
    fi
}

disable_adb() {
    CURRENT_ADB=$(settings get global adb_enabled)
    [ "$CURRENT_ADB" = "null" ] && CURRENT_ADB=0
    [ "$CURRENT_ADB" -ne 0 ] && settings put global adb_enabled 0
}

should_enable_mtp() {
    [ "$MTP_ENABLED" = "开启" ] || { log "MTP skipped: MTP_ENABLED=$MTP_ENABLED"; return 1; }
    if [ "$MTP_LOCK_ENABLED" = "开启" ]; then
        [ "$CACHED_UNLOCKED" = "1" ] && return 0 || { log "MTP skipped: screen locked"; return 1; }
    fi
    return 0
}

LAST_USB_STATUS=""
MTP_EXECUTED_IN_THIS_SESSION=0
CONFIG_LOOP_COUNT=0

load_config

while true; do
    CONFIG_LOOP_COUNT=$((CONFIG_LOOP_COUNT + 1))
    [ $CONFIG_LOOP_COUNT -ge 5 ] && { load_config; CONFIG_LOOP_COUNT=0; }

    update_screen_state

    USB_STATUS=$(cat "$USB_NODE" 2>/dev/null || echo "0")
    [ -z "$USB_STATUS" ] && USB_STATUS=0
    [ "$USB_STATUS" != "$LAST_USB_STATUS" ] && log "USB status: $LAST_USB_STATUS -> $USB_STATUS (node=$USB_NODE)"

    [ "$USB_STATUS" -eq 0 ] && [ "$LAST_USB_STATUS" -eq 1 ] && MTP_EXECUTED_IN_THIS_SESSION=0

    SHOULD_DISABLE_ADB=0
    if [ "$GAME_ADB_MODE" = "游戏进程" ]; then
        is_game_running && SHOULD_DISABLE_ADB=1
    else
        (is_game_running || [ "$CACHED_LANDSCAPE" = "1" ]) && SHOULD_DISABLE_ADB=1
    fi

    if [ "$SHOULD_DISABLE_ADB" -eq 1 ]; then
        disable_adb
        if [ "$USB_STATUS" -eq 1 ] && [ "$MTP_EXECUTED_IN_THIS_SESSION" -eq 0 ] && should_enable_mtp; then
            log "set USB function -> mtp"
            svc usb setFunctions mtp
            MTP_EXECUTED_IN_THIS_SESSION=1
        fi
    else
        if [ "$USB_DEBUG_ENABLED" = "开启" ]; then
            if [ "$USB_STATUS" -eq 1 ]; then
                CURRENT_ADB=$(settings get global adb_enabled)
                [ "$CURRENT_ADB" = "null" ] && CURRENT_ADB=0
                [ "$CURRENT_ADB" -ne 1 ] && settings put global adb_enabled 1
            else
                settings put global adb_enabled 0
            fi
        else
            settings put global adb_enabled 0
        fi

        if [ "$USB_STATUS" -eq 1 ] && [ "$MTP_EXECUTED_IN_THIS_SESSION" -eq 0 ] && should_enable_mtp; then
            log "set USB function -> mtp"
            svc usb setFunctions mtp
            MTP_EXECUTED_IN_THIS_SESSION=1
        fi
    fi

    LAST_USB_STATUS=$USB_STATUS
    sleep 2
done
