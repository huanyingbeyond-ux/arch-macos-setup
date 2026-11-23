#!/usr/bin/env bash
# 安装 global-menu-KDE（macOS 风格通用顶栏 Plasmoid）
# 规避四个安装坑：不全系统升级 / 不占 10MB /tmp / sudo 只输一次 / 不改面板配置
# 用法：在仓库根目录执行 bash scripts/install-global-menu-kde.sh
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${GLOBAL_MENU_SRC:-${REPO_ROOT}/extras/global-menu-kde/source}"
REPO_URL="${GLOBAL_MENU_KDE_REPO:-https://github.com/ChathurangaBW/global-menu-KDE.git}"

if [[ ! -f "${SRC_DIR}/CMakeLists.txt" ]]; then
    printf '==> 源码不存在，克隆上游到 %s\n' "${SRC_DIR}"
    mkdir -p "$(dirname "${SRC_DIR}")"
    git clone --depth 1 "${REPO_URL}" "${SRC_DIR}"
fi

BUILD_TMP="${SRC_DIR}/.build-tmp"
mkdir -p "${BUILD_TMP}"
export TMPDIR="${BUILD_TMP}"

printf '==> 1/4 激活 sudo 缓存（本次只需输入一次密码）\n'
sudo -v

printf '==> 2/4 只补缺失的构建依赖（不带 -y，不触发全系统升级）\n'
MISSING=()
for pkg in ninja extra-cmake-modules; do
    if ! pacman -Q "${pkg}" >/dev/null 2>&1; then
        MISSING+=("${pkg}")
    fi
done
if ((${#MISSING[@]})); then
    printf '    需要安装: %s\n' "${MISSING[*]}"
    sudo pacman -S --needed --noconfirm "${MISSING[@]}"
else
    printf '    构建依赖已齐全\n'
fi

printf '==> 3/4 编译 + CTest 自检 + 安装到 /usr\n'
cd "${SRC_DIR}"
bash scripts/install-system.sh

printf '==> 4/4 安装简体中文翻译（无需 sudo）\n'
if [[ -f "${REPO_ROOT}/scripts/install-global-menu-zh.sh" ]]; then
    GLOBAL_MENU_SRC="${SRC_DIR}" bash "${REPO_ROOT}/scripts/install-global-menu-zh.sh"
fi

printf '\n==> 全部完成\n'
printf '    下一步：退出并重新登录 Plasma 一次，\n'
printf '    然后 编辑模式 → 添加小组件 → 搜索 "KDE Global Menu" 拖入顶栏。\n'
printf '    原生 org.kde.plasma.appmenu 与新插件功能重叠，确认新菜单可用后手动移除原生那个即可。\n'
printf '    回滚：global-menu-kde-uninstall\n'
