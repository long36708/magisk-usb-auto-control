#!/system/bin/sh
# 仅设置文件权限，无任何推广/跳转行为
set_perm_recursive 0 0 0755 0644 "$MODDIR"
set_perm "$MODDIR/service.sh" 0 0 0755
set_perm "$MODDIR/main.sh" 0 0 0755
