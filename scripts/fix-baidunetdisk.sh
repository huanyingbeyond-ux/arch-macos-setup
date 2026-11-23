#!/usr/bin/env bash
# fix-baidunetdisk.sh — 修复百度网盘 Linux 版 (8.9.7) 点击后闪退
#
# 【根因】
#   ~/.local/opt/baidunetdisk/libbrowserengine.so 的 DT_NEEDED 需要 10 个
#   GTK2 / gtkmm-2.4 老 ABI 库：libgtkmm-2.4.so.1、libatkmm-1.6.so.1、
#   libgdkmm-2.4.so.1、libgiomm-2.4.so.1、libpangomm-1.4.so.1、
#   libgtk-x11-2.0.so.0、libglibmm-2.4.so.1、libcairomm-1.0.so.1、
#   libsigc-2.0.so.0、libgdk-x11-2.0.so.0。
#   Arch/EndeavourOS 官方仓库已移除 GTK2 系列，系统里只有 gtkmm-4.0 /
#   glibmm-2.68 / libsigc-3.0（soname 不同，不兼容）。
#   deb 自身声明 Depends: libgtkmm-2.4-1v5。
#   主进程通过 koffi 加载 libbrowserengine.so 失败 ->
#   "Failed to load shared library: libgtkmm-2.4.so.1" -> Uncaught Exception -> 闪退。
#   注意：这些是运行时 dlopen 依赖，ldd 主程序查不出来，必须 ldd libbrowserengine.so。
#
# 【方案】
#   从 Debian 12 bookworm 官方仓库取 7 个预编译运行时包，逐个校验 SHA256，
#   只把 .so 解到应用私有目录 lib/；用 wrapper 设置 LD_LIBRARY_PATH 后启动。
#   不装系统包、不改系统库、不需要 root、不影响任何其他程序。
#
# 【用法】
#   bash ~/fix-baidunetdisk.sh              # 安装修复（含自动验证）
#   bash ~/fix-baidunetdisk.sh --check      # 只检查依赖是否齐全
#   bash ~/fix-baidunetdisk.sh --rollback   # 回滚（恢复启动器、删私有库与 wrapper）
#
set -euo pipefail

APP=/home/dean/.local/opt/baidunetdisk
LIBDIR="$APP/lib"
DESKTOP=/home/dean/.local/share/applications/baidunetdisk.desktop
WRAPPER=/home/dean/.local/bin/baidunetdisk
BASE=https://deb.debian.org/debian/
STAMP=$(date +%Y%m%d-%H%M%S)

# 全局临时目录（EXIT trap 只能引用全局变量；用 find -delete 清理，避免 rm -rf）
WB_WORK=""
cleanup() {
    if [ -n "$WB_WORK" ] && [ -d "$WB_WORK" ]; then
        find "$WB_WORK" -mindepth 1 -delete 2>/dev/null || true
        rmdir "$WB_WORK" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# pkg|version|filename|sha256 —— 取自 bookworm main 官方 Packages 索引
PACKAGES=(
'libgtkmm-2.4-1v5|1:2.24.5-4+b1|pool/main/g/gtkmm2.4/libgtkmm-2.4-1v5_2.24.5-4+b1_amd64.deb|028c21afe635dfcad591118049364f15bacc5dc0af18ea814f3bebb1e9c00afa'
'libatkmm-1.6-1v5|2.28.3-1|pool/main/a/atkmm1.6/libatkmm-1.6-1v5_2.28.3-1_amd64.deb|f98c29a1962bb98d147c72e05a92eeba36f829ff1538eaaed550301a841fad95'
'libpangomm-1.4-1v5|2.46.3-1|pool/main/p/pangomm/libpangomm-1.4-1v5_2.46.3-1_amd64.deb|3bcb2bb2c7dece7be81cd12f0c2eb25a0964642ba1e62e7a98264cb0ab4cde9e'
'libcairomm-1.0-1v5|1.14.4-2|pool/main/c/cairomm/libcairomm-1.0-1v5_1.14.4-2_amd64.deb|6cb05750d23a03c4a3161e023e44051240bb27458da06c316fbe0c31b9807a49'
'libglibmm-2.4-1v5|2.66.5-2|pool/main/g/glibmm2.4/libglibmm-2.4-1v5_2.66.5-2_amd64.deb|a11c03dd8f9b454eaeae38ce782ceb45d9b52f5695d86d1d262c9062c678a2ba'
'libsigc++-2.0-0v5|2.12.0-1|pool/main/libs/libsigc++-2.0/libsigc++-2.0-0v5_2.12.0-1_amd64.deb|60d62e980e199094e37a09c5896f736fc64354c0b0b9dbefb1b588ec26bc0bf9'
'libgtk2.0-0|2.24.33-2+deb12u1|pool/main/g/gtk+2.0/libgtk2.0-0_2.24.33-2+deb12u1_amd64.deb|d1e9a26a5961748f220c5989c89516fead2a5054b80914f94c71c3fee6fdebe3'
)

SONAMES=(
libgtkmm-2.4.so.1 libatkmm-1.6.so.1 libgdkmm-2.4.so.1 libgiomm-2.4.so.1
libpangomm-1.4.so.1 libgtk-x11-2.0.so.0 libglibmm-2.4.so.1
libcairomm-1.0.so.1 libsigc-2.0.so.0 libgdk-x11-2.0.so.0
)

check() {
    echo "=== 依赖检查 ==="
    local miss=0 s
    for s in "${SONAMES[@]}"; do
        if [ ! -e "$LIBDIR/$s" ]; then echo "  缺失: $s"; miss=1; fi
    done
    [ "$miss" -eq 0 ] || return 1
    echo "  10 个 soname 齐全 -> $LIBDIR"
    local nf
    nf=$(LD_LIBRARY_PATH="$LIBDIR" ldd "$APP/libbrowserengine.so" 2>/dev/null | grep 'not found' || true)
    if [ -n "$nf" ]; then echo "  ldd 仍有未解析:"; echo "$nf"; return 1; fi
    echo "  libbrowserengine.so 的 DT_NEEDED 全部可解析"
    return 0
}

do_check() {
    if ! check; then echo "状态：未修复"; exit 1; fi
    echo "状态：已修复"
    grep -n '^Exec=' "$DESKTOP" 2>/dev/null || true
}

do_rollback() {
    echo "=== 回滚 ==="
    local b
    b=$(ls -1t "$DESKTOP".bak-wb-* 2>/dev/null | head -1 || true)
    if [ -n "$b" ]; then cp "$b" "$DESKTOP"; echo "  已恢复启动器：$b"; fi
    rm -f "$WRAPPER" && echo "  已删除 wrapper"
    if [ -d "$LIBDIR" ]; then
        find "$LIBDIR" -mindepth 1 -delete 2>/dev/null || true
        rmdir "$LIBDIR" 2>/dev/null || true
        echo "  已删除私有库目录 $LIBDIR"
    fi
    echo "  回滚完成（本次安装的库全部移除，系统库未受任何改动）"
}

verify_run() {
    echo "=== 启动验证（隔离 HOME，18 秒超时） ==="
    local th out
    th=$(mktemp -d /home/dean/.wb-bnd-home.XXXXXX)
    out=$(timeout 18s env HOME="$th" LD_LIBRARY_PATH="$LIBDIR" \
          "$APP/baidunetdisk" --no-sandbox --disable-gpu 2>&1 || true)
    find "$th" -mindepth 1 -delete 2>/dev/null || true
    rmdir "$th" 2>/dev/null || true
    if echo "$out" | grep -q 'Failed to load shared library'; then
        echo "  [失败] 仍报库加载失败："
        echo "$out" | grep -iE 'Failed to load|Uncaught|Error:' | head -8
        return 1
    fi
    if echo "$out" | grep -q 'A JavaScript error occurred in the main process'; then
        echo "  [失败] 主进程仍有未捕获异常："
        echo "$out" | grep -A3 'Uncaught Exception' | head -8
        return 1
    fi
    echo "  未再出现 libgtkmm 加载失败 / 主进程 JS 异常"
    echo "  启动输出前 12 行（Fontconfig / libva 警告为非致命）："
    echo "$out" | head -12 | sed 's/^/    /'
    return 0
}

do_install() {
    echo "=== 前置检查 ==="
    [ -f "$APP/libbrowserengine.so" ] || { echo "找不到 $APP/libbrowserengine.so" >&2; exit 1; }
    [ -f "$DESKTOP" ] || { echo "找不到启动器 $DESKTOP" >&2; exit 1; }
    command -v ar >/dev/null || { echo "缺少 ar (binutils)" >&2; exit 1; }

    if check 2>/dev/null; then
        echo "依赖已齐全，跳过下载；仅重建 wrapper 与启动器"
    else
        local work
        # 注意：沙箱内 /tmp 是 10MB tmpfs，必须用 /home（13G 可用）
        work=$(mktemp -d /home/dean/.wb-bnd-work.XXXXXX)
        WB_WORK="$work"
        mkdir -p "$LIBDIR" "$work/x"
        echo
        echo "=== 下载并校验 7 个 Debian 官方包 ==="
        local entry pkg ver path sha url deb member dec
        for entry in "${PACKAGES[@]}"; do
            IFS='|' read -r pkg ver path sha <<< "$entry"
            url="$BASE$path"
            deb="$work/$(basename "$path")"
            printf '  %-28s ' "$pkg"
            curl -s --noproxy '*' --max-time 120 -o "$deb" "$url"
            if ! echo "$sha  $deb" | sha256sum -c --status -; then
                echo "SHA256 校验失败，已中止（未做任何安装）" >&2; exit 1
            fi
            member=$(ar t "$deb" | grep '^data\.tar' | head -1)
            # -m: 沙箱不允许恢复 mtime，跳过时间戳即可（Deb 解包无需保留 mtime）
            case "$member" in
                *.xz)  dec=(tar -xmJ) ;;
                *.gz)  dec=(tar -xmz) ;;
                *.bz2) dec=(tar -xmj) ;;
                *) echo "未知压缩格式 $member" >&2; exit 1 ;;
            esac
            # 只取运行时 .so，不解出 /usr/share/doc 等文档，省空间也省时间
            ar p "$deb" "$member" | "${dec[@]}" -C "$work/x" \
                --wildcards './usr/lib/x86_64-linux-gnu/*.so*' 2>/dev/null || true
            echo "OK ($ver)"
        done
        echo
        echo "=== 复制 .so 到应用私有目录（保留符号链接） ==="
        local src=/usr/lib/x86_64-linux-gnu
        [ -d "$work/x$src" ] || { echo "解包后找不到 $src" >&2; exit 1; }
        # -d 保留符号链接本身；不用 -a，沙箱不允许恢复 mtime
        find "$work/x$src" -maxdepth 1 -name '*.so*' -exec cp -d {} "$LIBDIR/" \;
        echo "  已复制 $(find "$LIBDIR" -name '*.so*' | wc -l) 个文件/链接"
    fi

    echo
    if ! check; then echo "依赖仍不齐全，已中止（未改启动器）" >&2; exit 1; fi

    echo
    echo "=== 创建 wrapper ==="
    mkdir -p /home/dean/.local/bin
    cat > "$WRAPPER" <<EOF
#!/bin/sh
# 百度网盘启动包装：只对本进程补 GTK2/gtkmm-2.4 运行时库路径
# --no-sandbox 是必需的：用户级解包丢失了 chrome-sandbox 的 setuid 位
export LD_LIBRARY_PATH="$LIBDIR\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "$APP/baidunetdisk" --no-sandbox "\$@"
EOF
    chmod +x "$WRAPPER"
    echo "  $WRAPPER"

    echo
    echo "=== 备份并更新启动器 ==="
    cp "$DESKTOP" "$DESKTOP.bak-wb-$STAMP"
    sed -i "s|^Exec=.*|Exec=$WRAPPER %U|" "$DESKTOP"
    echo "  备份：$DESKTOP.bak-wb-$STAMP"
    grep -n '^Exec=' "$DESKTOP"

    echo
    if ! verify_run; then
        echo "启动验证未通过，可用 --rollback 回滚" >&2
        exit 1
    fi

    echo
    echo "==================== 修复完成 ===================="
    echo "现在从应用菜单点「百度网盘」即可启动。"
    echo "验证：bash ~/fix-baidunetdisk.sh --check"
    echo "回滚：bash ~/fix-baidunetdisk.sh --rollback"
}

case "${1:-}" in
    --check)    do_check ;;
    --rollback) do_rollback ;;
    "")         do_install ;;
    *)          echo "用法：$0 [--check|--rollback]" >&2; exit 1 ;;
esac
