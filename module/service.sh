#!/system/bin/sh
MODDIR=${0%/*}

chmod -R 755 "$MODDIR"

# 直接启动核心逻辑。锁屏状态改由 main.sh 内部判断，
# 避免因锁屏检测 DEX 在新系统上失效而卡在开机等待循环里。
/system/bin/sh "$MODDIR/main.sh" >/dev/null 2>&1 &
