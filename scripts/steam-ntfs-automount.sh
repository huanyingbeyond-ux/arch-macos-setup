#!/usr/bin/env bash
# steam-ntfs-automount.sh
#
# 作用：把「文档」「软件」两个 NTFS 分区写入 /etc/fstab，开机由 systemd 自动挂载，
#       不再需要每次开机在 Dolphin 里点一下并输入管理员密码。
#
# 关键设计：挂载点保持 udisks2 原来的 /run/media/dean/文档、/run/media/dean/软件，
#           因此 Steam 的 libraryfolders.vdf 完全不用改，Dolphin 侧边栏位置也不变。
#           nofail 保证 Windows 快速启动导致 NTFS 处于休眠状态时不会卡住开机。
#           不加 windows_names（会禁止 Wine prefix 需要的含冒号/问号文件名）。
#           不加 noexec（Proton 需要执行权限）。
#
# 用法：
#   sudo bash ~/steam-ntfs-automount.sh              # 安装（只需执行一次）
#   bash ~/steam-ntfs-automount.sh --status          # 查看当前状态（无需 root）
#   sudo bash ~/steam-ntfs-automount.sh --rollback   # 回滚到安装前备份
#
set -euo pipefail

FSTAB=/etc/fstab
TAG="# wb-steam-ntfs"
DOC_UUID=96CD7F81576EBAAE
SOFT_UUID=48BFA923C63314A4
DOC_MP=/run/media/dean/文档
SOFT_MP=/run/media/dean/软件
OPTS="rw,nosuid,nodev,noatime,uid=1000,gid=1001,iocharset=utf8,nofail,x-systemd.device-timeout=10s,x-gvfs-show"

need_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "请用 sudo 执行：sudo bash $0 $*" >&2
        exit 1
    fi
}

print_status() {
    echo "=== /etc/fstab 中的相关条目 ==="
    grep -n -E "$TAG|$DOC_UUID|$SOFT_UUID" "$FSTAB" 2>/dev/null || echo "(未配置)"
    echo
    echo "=== 当前挂载状态 ==="
    findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS -t ntfs3 2>/dev/null || echo "(未挂载)"
    echo
    echo "=== systemd 挂载单元 ==="
    for m in "run-media-dean-\\xe6\\x96\\x87\\xe6\\xa1\\xa3.mount" "run-media-dean-\\xe8\\xbd\\xaf\\xe4\\xbb\\xb6.mount"; do
        systemctl is-enabled "$m" 2>/dev/null || true
    done
    echo
    echo "=== 备份文件 ==="
    ls -1t "${FSTAB}".bak-wb-* 2>/dev/null | head -5 || echo "(无)"
}

do_rollback() {
    need_root --rollback
    BAK=$(ls -1t "${FSTAB}".bak-wb-* 2>/dev/null | head -1 || true)
    if [ -z "$BAK" ]; then
        echo "找不到备份，未做任何改动" >&2
        exit 1
    fi
    cp -a "$BAK" "$FSTAB"
    systemctl daemon-reload
    echo "已回滚到：$BAK"
    echo "重启后恢复原来的手动挂载方式。"
}

do_install() {
    need_root
    if grep -q "$TAG" "$FSTAB" 2>/dev/null; then
        echo "已经配置过，无需重复执行。当前状态："
        print_status
        exit 0
    fi

    # 1. 确认设备真实存在，避免写进不存在的 UUID
    for u in "$DOC_UUID" "$SOFT_UUID"; do
        if ! blkid -U "$u" >/dev/null 2>&1; then
            echo "找不到 UUID=$u，已中止（磁盘可能有变动）" >&2
            exit 1
        fi
    done

    # 2. 备份
    BAK="${FSTAB}.bak-wb-$(date +%Y%m%d-%H%M%S)"
    cp -a "$FSTAB" "$BAK"
    echo "已备份 fstab -> $BAK"

    # 3. 追加条目（保留原挂载点，Steam 库路径零改动）
    {
        echo ""
        echo "$TAG 开机自动挂载，生成于 $(date '+%F %T')；挂载点即 udisks2 原路径，请勿改动"
        printf 'UUID=%s\t%s\tntfs3\t%s\t0 0\n' "$DOC_UUID"  "$DOC_MP"  "$OPTS"
        printf 'UUID=%s\t%s\tntfs3\t%s\t0 0\n' "$SOFT_UUID" "$SOFT_MP" "$OPTS"
    } >> "$FSTAB"

    # 4. 语法校验，失败自动回滚
    if ! findmnt --verify >/dev/null 2>&1; then
        cp -a "$BAK" "$FSTAB"
        echo "fstab 校验未通过，已自动回滚到 $BAK" >&2
        exit 1
    fi
    echo "fstab 语法校验通过"

    # 5. 重新生成挂载单元（不卸载、不 mount -a，避免打断正在运行的 Steam）
    systemctl daemon-reload
    echo "systemd 挂载单元已生成"

    echo
    echo "==================== 完成 ===================="
    echo "下次开机起，两个分区自动挂载，不再需要输入密码，Steam 库路径完全不变。"
    echo
    echo "验证（重启后执行）："
    echo "  bash ~/steam-ntfs-automount.sh --status"
    echo "  findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS -t ntfs3"
    echo
    echo "如想本次就生效（请先完全退出 Steam 与游戏，再执行）："
    echo "  sudo umount /run/media/dean/文档 /run/media/dean/软件"
    echo "  sudo mount -a"
    echo
    echo "注意：执行后到重启前，请勿在 Dolphin 里手动卸载这两个分区。"
    echo "回滚：sudo bash ~/steam-ntfs-automount.sh --rollback"
}

case "${1:-}" in
    --status)   print_status ;;
    --rollback) do_rollback ;;
    "")         do_install ;;
    *)          echo "用法：$0 [--status|--rollback]" >&2; exit 1 ;;
esac
