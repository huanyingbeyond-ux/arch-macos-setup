#!/usr/bin/env bash
# adapt-paths.sh — 换机 / 改用户名后，把仓库 configs/ 与 scripts/ 里的硬编码路径
#                  从原用户（默认 dean）替换成当前用户，输出到 ~/macos-setup-adapted/
# 用法：
#   bash adapt-paths.sh              # 用当前 $USER 替换 dean，uid/gid 用当前用户
#   bash adapt-paths.sh newuser 1001 1002   # 手动指定用户名/uid/gid
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OLD_USER="dean"
NEW_USER="${1:-$USER}"
OLD_UID=1000
NEW_UID="${2:-$(id -u)}"
OLD_GID=1001
NEW_GID="${3:-$(id -g)}"
OUT="$HOME/macos-setup-adapted"

echo "把 configs/ 与 scripts/ 里的路径适配为："
echo "  用户: $OLD_USER -> $NEW_USER"
echo "  uid : $OLD_UID -> $NEW_UID"
echo "  gid : $OLD_GID -> $NEW_GID"
echo "  输出: $OUT"

rm -rf "$OUT"
mkdir -p "$OUT"
cp -r "$REPO_DIR/configs" "$REPO_DIR/scripts" "$OUT/"

# 逐个替换（只处理文本文件）
find "$OUT" -type f -print0 | while IFS= read -r -d '' f; do
    if file "$f" 2>/dev/null | grep -q text; then
        sed -i \
            -e "s#/home/${OLD_USER}#/home/${NEW_USER}#g" \
            -e "s#uid=${OLD_UID}#uid=${NEW_UID}#g" \
            -e "s#gid=${OLD_GID}#gid=${NEW_GID}#g" \
            -e "s#/run/user/${OLD_UID}#/run/user/${NEW_UID}#g" \
            -e "s#\b${OLD_USER}\b#${NEW_USER}#g" \
            "$f" 2>/dev/null || true
    fi
done

echo "完成。适配后的文件在 $OUT，按 README 里各章节的目标路径放回去即可。"
echo "注意：NTFS 分区 UUID（96CD7F8... / 48BFA92...）是机器特定的，"
echo "      若换了硬盘，请用 sudo bash scripts/steam-ntfs-automount.sh 重新生成 fstab 条目。"
