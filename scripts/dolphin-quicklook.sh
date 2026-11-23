#!/bin/sh
# dolphin-quicklook.sh — Dolphin 上的 macOS 风格 Quick Look（基于 gloobus-preview）
# 用法：
#   右键菜单调用：dolphin-quicklook.sh file:///...   （传入选中文件的 URL/路径）
#   键盘快捷键调用：dolphin-quicklook.sh             （自动确认 Dolphin 是当前窗口后读选中文件）
# 行为：替换式预览（再按一次/再选一个会关掉旧窗口开新的），与 macOS 一致。

PREVIEW=gloobus-preview
QDBUS=$(command -v qdbus6 || command -v qdbus || true)
KDOTOOL=$(command -v kdotool || true)

# 关掉上一个预览窗口（Quick Look 的“替换”语义）
pkill -x gloobus-preview 2>/dev/null

# —— 情况 1：右键菜单传入文件（file:// URL 或普通路径）——
if [ "$#" -gt 0 ]; then
    f=$(printf '%s' "$1" | sed -e 's#^file://localhost##' -e 's#^file://##')
    [ -n "$f" ] && exec "$PREVIEW" "$f" >/dev/null 2>&1
    exit 0
fi

# —— 情况 2：键盘快捷键。先确认当前活动窗口是 Dolphin，避免在别的程序里误触 ——
if [ -n "$KDOTOOL" ]; then
    cls=$(kdotool getactivewindow getwindowclassname 2>/dev/null | tr '[:upper:]' '[:lower:]')
    case "$cls" in
        *dolphin*) : ;;   # 是 Dolphin，继续
        *) exit 0 ;;      # 不是 Dolphin，什么都不做
    esac
fi

[ -z "$QDBUS" ] && exit 0
SVC=org.kde.dolphin
OBJ=""
for i in 1 2 3 4 5 6 7 8 9; do
    o=$("$QDBUS" "$SVC" "/dolphin/Dolphin_$i" currentView 2>/dev/null)
    if [ -n "$o" ]; then OBJ="$o"; break; fi
done
[ -z "$OBJ" ] && exit 0

# 仅在有选中文件时预览；无选中（例如只是浏览目录）则什么都不做，避免拿目录去预览报错。
SEL=$("$QDBUS" "$SVC" "$OBJ" selectedUrls 2>/dev/null)
[ -z "$SEL" ] && exit 0
F=$(printf '%s' "$SEL" | head -1 | sed -e 's#^file://localhost##' -e 's#^file://##')
[ -n "$F" ] && exec "$PREVIEW" "$F" >/dev/null 2>&1
exit 0
