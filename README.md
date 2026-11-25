# magisk-usb-auto-control

> USB 智能控制 · 纯净版 —— 手机插上电脑时自动切换为「传输文件（MTP）」模式，并按配置自动开关 USB 调试。

一个轻量的 Magisk / KernelSU 模块。**无加壳二进制、无推广跳转、无网络请求**，全部逻辑为可读的 shell 脚本。

## 功能特性

- 检测 USB 插入 / 拔出，自动执行 `svc usb setFunctions mtp` 切换到文件传输模式（一次插入会话只执行一次）。
- 按配置自动开启 / 关闭 USB 调试（`adb_enabled`）。
- 可选「解锁屏幕后才切换 MTP」。
- 游戏进程运行或横屏时自动关闭 ADB；支持「仅按游戏进程」和「横屏或游戏进程」两种模式。
- 配置文件约每 10 秒热重载，改配置无需重启。
- 自动探测多种 USB 状态节点，适配不同机型（含 Android 15/16 等新版系统）。
- 可选调试日志，方便排查不触发的原因。

## 安装

1. 在 Magisk / KernelSU 中**先卸载旧版同名模块**（`id=USB_Auto`）。
   > 覆盖刷入不会替换已存在的文件，可能导致修复不生效。务必先卸载。
2. 刷入 [`magisk-usb-auto-control.zip`](magisk-usb-auto-control.zip)。
3. 重启，插上电脑，解锁屏幕，等待约 2 秒。

配置文件位于：`/data/adb/modules/USB_Auto/USB-智能控制配置.prop`

## 配置说明

```properties
ADB调试=开启          # USB 插入时自动打开 USB 调试；拔出或关闭时自动关
MTP文件传输=开启       # 总开关：是否自动切换到 MTP
MTP_LOCK=开启         # 开启=仅解锁屏幕后才切 MTP；关闭=锁屏也切
Game_ADB=屏幕横竖      # 可选：屏幕横竖 / 游戏进程
USB_NODE=             # 可选：手动指定 USB 状态节点，留空自动探测
DEBUG_LOG=关闭         # 开启后写日志到 /data/adb/usb_auto_debug.log

GAME_LIST="
com.tencent.tmgp.sgame
...
"
```

`Game_ADB=屏幕横竖` 表示「横屏 **或** 检测到游戏进程」时关闭 ADB；`游戏进程` 表示只在游戏运行时关闭。

## 工作原理

- `service.sh`：开机后直接启动核心脚本（不依赖锁屏检测 DEX，避免新版系统上卡死）。
- `main.sh`：轮询 `/sys/class/power_supply/*/online` 判断 USB 状态，用 `dumpsys window policy` 判断锁屏，用 `pidof` 判断游戏进程，然后按配置设置 `adb_enabled` 与 USB function。
- `customize.sh`：仅设置文件权限，不做任何跳转。

## 故障排查

如果插上电脑仍是「仅充电」，打开 `DEBUG_LOG=开启`，重启后查看：

```sh
cat /data/adb/usb_auto_debug.log
getprop sys.usb.config      # 期望 mtp 或 mtp,adb
cat /sys/class/power_supply/usb/online
```

- 日志出现 `set USB function -> mtp`：模块已正常执行，问题在系统 ROM 侧。
- 日志出现 `MTP skipped: screen locked`：把 `MTP_LOCK` 改为 `关闭`。
- 没有任何日志：确认模块已启用、进程在跑（`pgrep -af main.sh`）。

部分定制 ROM 会自行接管 USB 功能；可用 `svc usb setFunctions mtp` 手动验证。

## 构建

```bash
python build.py
```

会由 `module/` 目录重新生成根目录的刷入包（脚本权限 0755，其余 0644）。

## 来源

本项目基于一个第三方 Magisk USB 控制模块逆向还原并重写：去除了原模块的 ELF 加壳、多层混淆、推广跳转与运行时自改写行为，保留并改进了其核心功能。仅用于学习与技术交流。

## 许可证

[MIT](LICENSE) © 酷安矜持
