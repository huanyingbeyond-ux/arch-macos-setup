#!/usr/bin/env bash
# 安装 global-menu-KDE 简体中文翻译
# 无需 sudo：gettext 会从 ~/.local/share/locale 加载用户翻译
# 用法：bash scripts/install-global-menu-zh.sh
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PO="${REPO_ROOT}/extras/global-menu-kde/po/zh_CN/plasma_applet_org.chathuranga.globalmenu.po"
DEST="${HOME}/.local/share/locale/zh_CN/LC_MESSAGES"
MO="${DEST}/plasma_applet_org.chathuranga.globalmenu.mo"

if ! command -v msgfmt >/dev/null 2>&1; then
    printf '错误：缺少 msgfmt，请先安装 gettext（sudo pacman -S gettext）\n' >&2
    exit 1
fi

mkdir -p "${DEST}"
msgfmt --check -o "${MO}" "${PO}"
printf '中文翻译已安装：%s\n' "${MO}"
printf '重新登录 Plasma（或重启 plasmashell）后生效。\n'
