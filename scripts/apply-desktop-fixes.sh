#!/usr/bin/env bash
# 天气（Open-Meteo 直连）+ 输入法：幂等自检 / 一键修复
#
# 用法：
#   bash ~/apply-desktop-fixes.sh              # 自检 + 修能修的（不中断任何应用）
#   bash ~/apply-desktop-fixes.sh --hard-fix   # 额外用 sudo 给 /usr/bin/workbuddy 加永久兜底
#
# 2026-11-10 要点：
#  - 天气组件是新建的 QML 包 org.dean.openmeteo，不是改官方 C++ 插件。
#    面板配置不能手改：plasmashell 退出时会用内存布局写回，必须用运行时接口添加。
#  - WorkBuddy 的 GTK_IM_MODULE=xim 来自 KDE 应用启动缓存（systemd app scope
#    的 ExecStart），改 desktop 文件后必须刷新 KSycoca 并完全退出重开应用。

set -u
uid=$(id -u)
export XDG_RUNTIME_DIR="/run/user/$uid"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus"
PLUGIN=org.dean.openmeteo
CONF="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
DESKTOP="$HOME/.local/share/applications/workbuddy.desktop"

echo "== 1/5 天气数据定时刷新 =="
systemctl --user daemon-reload 2>/dev/null
systemctl --user enable --now wb-weather.timer >/dev/null 2>&1
systemctl --user start wb-weather.service 2>/dev/null
printf '  timer: %s / %s\n' \
    "$(systemctl --user is-active wb-weather.timer 2>&1)" \
    "$(systemctl --user is-enabled wb-weather.timer 2>&1)"
ls -lh "$HOME/.cache/wb-weather/weather.json" 2>/dev/null || echo "  [警告] 天气缓存未生成"

echo "== 2/5 QML 允许读取本地缓存 =="
if systemctl --user show-environment 2>/dev/null | grep -q QML_XHR_ALLOW_FILE_READ; then
    echo "  OK"
else
    systemctl --user set-environment QML_XHR_ALLOW_FILE_READ=1
    echo "  已设置（旧 plasmashell 进程需重启才带上）"
fi

echo "== 3/5 面板天气组件 =="
if grep -q "plugin=$PLUGIN" "$CONF" 2>/dev/null; then
    echo "  布局配置中已存在"
else
    echo "  运行时添加中…"
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
        "var ps=panels(); var p=ps.length?ps[0]:null; if(!p){print('WBADD no panel');} else {var w=p.addWidget('$PLUGIN'); print('WBADD '+(w?w.id:'null'));}"
fi

echo "== 4/5 fcitx5 配置 =="
fcitx5-remote -r >/dev/null 2>&1 && echo "  配置已重载"
printf '  SwitchInputMethodBehavior: %s\n' "$(grep '^SwitchInputMethodBehavior' "$HOME/.config/fcitx5/conf/pinyin.conf" 2>/dev/null)"
printf '  PredictionSize:            %s\n' "$(grep '^PredictionSize' "$HOME/.config/fcitx5/conf/pinyin.conf" 2>/dev/null)"
printf '  候选框字体:                %s\n' "$(grep '^Font=' "$HOME/.config/fcitx5/conf/classicui.conf" 2>/dev/null)"
printf '  fcitx5 实例数:             %s (应为 1)\n' "$(pgrep -c -x fcitx5 2>/dev/null)"

echo "== 5/5 WorkBuddy 输入路径（串字关键）=="
printf '  启动器 GTK_IM_MODULE=fcitx: %s 处\n' "$(grep -c 'GTK_IM_MODULE=fcitx' "$DESKTOP" 2>/dev/null)"
if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental >/dev/null 2>&1 && echo "  KSycoca 应用缓存已刷新"
fi
visible=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)
if [ "$visible" -lt 20 ]; then
    echo "  [跳过] 当前环境只可见 $visible 个进程（沙箱隔离），进程检测不可信"
    echo "         请在桌面终端运行本脚本，才能读到真实的运行中进程"
else
    xim=0
    fcitxim=0
    for p in $(pgrep -x workbuddy 2>/dev/null); do
        grep -qs 'im-xim.so' "/proc/$p/maps" 2>/dev/null && xim=$((xim + 1))
        grep -qs 'im-fcitx5.so' "/proc/$p/maps" 2>/dev/null && fcitxim=$((fcitxim + 1))
    done
    printf '  运行中进程：走 XIM %s 个 / 走 fcitx5 %s 个\n' "$xim" "$fcitxim"
    if [ "$xim" -gt 0 ]; then
        echo "  [待办] 完全退出 WorkBuddy 再重新打开（应用内重启会继承旧环境）"
        echo "         重开后本行应变成「走 XIM 0 个」"
    fi
fi

if [ "${1:-}" = "--hard-fix" ]; then
    echo "== 附：/usr/bin/workbuddy 永久兜底（需 sudo 密码）=="
    if [ -f /usr/bin/workbuddy.bak-wb ]; then
        echo "  已处理过，备份在 /usr/bin/workbuddy.bak-wb"
    elif grep -q 'GTK_IM_MODULE' /usr/bin/workbuddy 2>/dev/null; then
        echo "  已含兜底，无需改动"
    else
        sudo cp -a /usr/bin/workbuddy /usr/bin/workbuddy.bak-wb && \
        sudo sed -i '2i export GTK_IM_MODULE=fcitx' /usr/bin/workbuddy && \
        echo "  已加兜底；回滚：sudo cp -a /usr/bin/workbuddy.bak-wb /usr/bin/workbuddy"
    fi
fi

echo
echo "附：WorkBuddy worker 预热耗时（发消息 → 开始执行之间的等待窗口，CPU 峰值就在这段）"
n=0
for f in $(ls -t "$HOME"/.workbuddy/logs/perf/worker-startup-*.jsonl 2>/dev/null | head -n 20); do
    a=$(grep -o 'acquireRequestedAtEpochMs":[0-9]*' "$f" 2>/dev/null | head -n 1 | cut -d: -f2)
    b=$(grep -o 'acquireReadyAtEpochMs":[0-9]*' "$f" 2>/dev/null | head -n 1 | cut -d: -f2)
    if [ -n "$a" ] && [ -n "$b" ]; then
        printf '  %s  %s ms\n' "$(basename "$f")" "$(( b - a ))"
        n=$((n + 1))
        [ "$n" -ge 5 ] && break
    fi
done
[ "$n" -eq 0 ] && echo "  (暂无记录)"

echo
echo "验证："
echo "  journalctl --user -b | grep wb-weather"
echo "  journalctl -b | grep -c 'lagging behind'     # 应为 0"
echo "  journalctl -b | grep 'app-workbuddy.*Consumed'  # CPU 记账"
echo "  bash ~/apply-desktop-fixes.sh                # 可重复运行"
