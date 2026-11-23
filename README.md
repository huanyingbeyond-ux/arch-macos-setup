# Arch / EndeavourOS → 类 macOS 桌面：完整重建手册

> 一手把这台机器从"普通 Arch + KDE"改造成"接近 macOS 观感与手感"的全过程记录。
> 目标：**重装系统或换机时，照着这份文档就能原封不动复现**，不用再翻聊天记录、不用重新踩坑。
>
> 适用基线（本机的实际情况，换机时按需调整）：
> - 发行版：EndeavourOS（Arch），内核常规版
> - 桌面：KDE Plasma **6.8.2**，**Wayland** 会话（KWin）
> - CPU：i5-4210U（4 线程，HD4400 核显）；独显 AMD R5 M230（1002:666f）
> - 屏幕：1366×768；主题 `MacVentura-Light`；图标/光标 `WhiteSur` 系
> - 用户名：`dean`（家目录 `/home/dean`）；构建日期 2026-11-23
> - GitHub 账号：`huanyingbeyond-ux`

本仓库伴随另一个项目：[plasma-ai-plasmoids](https://github.com/huanyingbeyond-ux/plasma-ai-plasmoids)（让 DSH / WorkBuddy 长成桌面原生小组件）。本手册记录的是**整机层面的 macOS 化改造**，两者互补。

---

## 目录

- [0. 怎么用这份手册（先读）](#0-怎么用这份手册先读)
- [1. 环境与基线确认](#1-环境与基线确认)
- [2. 显卡驱动：修复 Steam 启动导致全系统崩溃](#2-显卡驱动修复-steam-启动导致全系统崩溃)
- [3. 输入法：根治"打串字 / 延迟 / 错别字"](#3-输入法根治打串字--延迟--错别字)
- [4. 天气小组件：直连 Open-Meteo，不翻墙](#4-天气小组件直连-open-meteo不翻墙)
- [5. 关闭 KDE 开机自动恢复上次 App](#5-关闭-kde-开机自动恢复上次-app)
- [6. 光标：把"箭头 + 风火轮"改成纯风火轮](#6-光标把箭头--风火轮改成纯风火轮)
- [7. Dolphin Quick Look：macOS 风格敲键预览](#7-dolphin-quick-lookmacos-风格敲键预览)
- [8. icns 图标预览与转换](#8-icns-图标预览与转换)
- [9. NTFS 游戏分区：开机免密自动挂载](#9-ntfs-游戏分区开机免密自动挂载)
- [10. 百度网盘：deb 解包安装 + 闪退修复](#10-百度网盘deb-解包安装--闪退修复)
- [11. 外观主题与拟物笔记 App](#11-外观主题与拟物笔记-app)
- [12. DSH / WorkBuddy 原生桌面小组件](#12-dsh--workbuddy-原生桌面小组件)
- [13. GitHub CLI：命令行上传仓库一劳永逸](#13-github-cli命令行上传仓库一劳永逸)
- [14. Steam / Proton 注意事项](#14-steam--proton-注意事项)
- [15. 磁盘空间：字体与缓存占用真相](#15-磁盘空间字体与缓存占用真相)
- [16. 文件路径速查表](#16-文件路径速查表)
- [17. 一键校验脚本](#17-一键校验脚本)
- [18. 踩过的坑与经验教训](#18-踩过的坑与经验教训)
- [19. macOS 风格通用顶栏：global-menu-KDE + 中文翻译](#19-macos-风格通用顶栏global-menu-kde--中文翻译)

---

## 0. 怎么用这份手册（先读）

### 三种"复现"场景

| 场景 | 做法 |
|---|---|
| **同机重装**（磁盘 UUID 不变、用户名仍是 dean） | 从"第 1 节"按顺序往下做；UUID、用户名、路径都不用改，绝大多数可直接复制命令 |
| **同机恢复某项**（系统还在，只是某个功能坏了） | 直接跳到对应章节，每节都有"验证"和"回滚" |
| **换机 / 改用户名** | 先跑一键适配脚本（见下），再逐节执行。文末 [16. 文件路径速查表](#16-文件路径速查表) 列出全部需要替换的位置 |

**换机一键适配**（把 configs/ 与 scripts/ 里硬编码的 `/home/dean`、uid 1000、gid 1001 换成当前用户）：

```bash
bash scripts/adapt-paths.sh                    # 用当前 $USER / uid / gid
bash scripts/adapt-paths.sh newuser 1001 1002  # 或手动指定
# 输出在 ~/macos-setup-adapted/，按 README 各章节目标路径放回去即可
```

> 适配脚本改不了机器特定的硬件值：NTFS 分区 UUID、Wayland socket 名、天气坐标、分区设备名。这些要按新机实际确认（见第 4、9 节）。

### 本仓库的两类内容

- `README.md`：就是这份手册（唯一主文档）。
- `scripts/`：**已经写好并在本机验证过的一键脚本**，重装时直接拷到对应位置即可。
- `configs/`：**关键配置文件的原样副本**，按注释里的目标路径放回去。

### 三个重要原则（血泪总结）

1. **网页登录 GitHub ≠ 命令行授权**，`gh` 要单独走设备码流程（第 13 节）。
2. **KDE 面板布局不能手动改配置文件**——plasmashell 退出时会用内存布局写回覆盖。要用运行时 `addWidget` 接口（第 4 节）。
3. **Wayland 下输入法不要同时设 `GTK_IM_MODULE` 和 compositor 转发**——这是打串字的总根源（第 3 节）。

### 全部改动一览（按依赖顺序）

| # | 改造项 | 是否需 root | 是否需联网 | 关键脚本/配置 |
|---|---|---|---|---|
| 1 | 独显切 amdgpu | 是（改配置文件） | 否 | `/etc/X11/xorg.conf.d/` 或 modprobe.d |
| 2 | 输入法链路 + fcitx5 配置 | 否 | 否 | `scripts/apply-desktop-fixes.sh` |
| 3 | 天气组件（自建 Plasmoid） | 否 | 是（Open-Meteo） | `scripts/wb-weather-fetch.sh` + 包 |
| 4 | 关闭会话恢复 | 否 | 否 | `configs/plasma/ksmserverrc` |
| 5 | 纯风火轮光标 | 否 | 否 | 直接改主题文件 |
| 6 | Quick Look | 装包需 sudo | 否 | `scripts/dolphin-quicklook.sh` |
| 7 | icns 工具 | 装包需 sudo | 是（pacman） | `sudo pacman -S libicns` |
| 8 | NTFS 自动挂载 | 是 | 否 | `scripts/steam-ntfs-automount.sh` |
| 9 | 百度网盘 deb + GTK2 库 | 安装需 root/解包免 root | 是（下载 deb/Debian 包） | `scripts/fix-baidunetdisk.sh` |
| 10 | 外观主题 | 否 | 否（主题文件需自备） | MacVentura-Light / WhiteSur |
| 11 | AI 小组件 | 否（编译需开发包） | 否 | 见 plasma-ai-plasmoids 仓库 |
| 12 | GitHub CLI | 否（下载二进制） | 是 | `gh` 设备码授权 |

---

## 1. 环境与基线确认

动手前先确认会话与硬件，避免"在假环境里排真问题"（本机多次因沙箱 PID 隔离、假 D-Bus 走弯路）。

```bash
# 会话类型必须是 wayland
echo "$XDG_SESSION_TYPE"          # wayland
echo "$WAYLAND_DISPLAY"           # wayland-1（本机）
echo "$XDG_RUNTIME_DIR"           # /run/user/1000

# 显卡驱动（独显应为 amdgpu，核显 i915）
lspci -k | grep -A3 -iE 'vga|3d|display'

# 桌面版本
plasmashell --version             # plasmashell 6.8.2
kwin_wayland --version 2>/dev/null || true

# 主题
grep '^name=' ~/.config/plasmarc   # name=MacVentura-Light
```

> **坑**：本机工具容器看到的进程表是隔离的（只看到几个进程），`/proc/<pid>/maps`、`pgrep` 在容器里不可信；`glxinfo` 在容器里报 `llvmpipe` 是命名空间假象。判断真实运行状态要在**桌面终端**里执行，或用 `DISPLAY=:0 xprop` / `gdbus` 直连真机 session bus。

---

## 2. 显卡驱动：修复 Steam 启动导致全系统崩溃

**现象**：一开 Steam，全系统 GPU lockup、Xwayland SIGABRT、所有 X11 程序断连、合成器卡死。

**根因**：AMD R5 M230（PCI `1002:666f`）用 `radeon` 驱动时 ring 0 stalled 20s+，resume 报 `ib ring test failed -35`，级联拖垮整个桌面。

### 修复（用户已在本机做，重装时照此确认）

在 modprobe 配置里强制该卡走 `amdgpu`：

```bash
# 查看当前驱动
lspci -k | grep -A3 'R5 M230'    # Kernel driver in use: amdgpu  ← 目标状态
```

如果仍是 `radeon`，创建（以 root）：

```bash
sudo tee /etc/modprobe.d/amdgpu-force.conf >/dev/null <<'EOF'
# AMD R5 M230 (1002:666f) 用 radeon 会 GPU lockup，强制走 amdgpu
options amdgpu si_support=1 cik_support=1
options radeon si_support=0 cik_support=0
blacklist radeon
EOF
sudo mkinitcpio -P    # 或 dracut --force，取决于发行版
```

然后重启验证 `lspci -k` 显示 `Kernel driver in use: amdgpu`，且 `dmesg` 无 lockup。

**验证**：启动 Steam 后 `journalctl -b -k | grep -i 'lockup\|ring.*stall'` 应为空；Xwayland 不再崩溃。

**回滚**：删掉 `/etc/modprobe.d/amdgpu-force.conf`，重建 initramfs，重启。

> 另一条独立结论（11-09 确认）：造成"打字延迟"的**不是** GPU，而是 `dsh-web.service` 的无限重启循环，见第 3 节之外的 `configs/systemd-user/dsh-web.service`（`Restart=no`、`Nice=5`、`IOSchedulingClass=idle`）。端口 3080 冲突导致 systemd 反复拉起 Node 实例，每次耗 26 CPU 秒 / 1.1G 内存，实测一开机重启 **1130+ 次**。服务文件副本已存 `configs/systemd-user/dsh-web.service`，重装时直接用它覆盖即可。

---

## 3. 输入法：根治"打串字 / 延迟 / 错别字"

这是整个改造里**排查最曲折**的一项，有两个独立根因，缺一不可。

### 根因 A：CPU 被 dsh-web 无限重启占满
见上节——服务副本 `configs/systemd-user/dsh-web.service` 已把 `Restart=on-failure` 改成 `Restart=no`。放回去后：

```bash
cp configs/systemd-user/dsh-web.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user restart dsh-web.service
# 确认不再疯狂重启
systemctl --user show dsh-web.service -p NRestarts -p ActiveState
```

### 根因 B（主因）：Wayland 下走了两条输入路径

**原理**（Arch Wiki `Fcitx5 > Integration > Wayland` 已核实）：Plasma Wayland 要求 fcitx5 由 **KWin** 启动，原生应用走 Wayland `text-input-v3` 协议。如果再显式设置 `GTK_IM_MODULE` / `QT_IM_MODULE`，应用会**同时**走 IM 模块路径和 compositor 转发，按键与候选词时序错乱 → 打串字。

但WorkBuddy 的启动器原本硬塞了 `GTK_IM_MODULE=xim`（Xwayland 同步往返），这是"在 WorkBuddy 里串字"的直接元凶。

### 完整改动（4 处，副本都在 configs/）

**① `~/.config/plasma-workspace/env/ime.sh`** —— 只保留 XMODIFIERS：

```sh
export XMODIFIERS="@im=fcitx"
```

> 不要设 `GTK_IM_MODULE` / `QT_IM_MODULE`！副本：`configs/plasma-workspace/env/ime.sh`

**② `~/.config/autostart/org.fcitx.Fcitx5.desktop`** —— 用户级 `Hidden=true` 覆盖系统级 autostart，消除第二个 fcitx5 实例（KWin 已经启动了一个）：

```ini
[Desktop Entry]
Type=Application
Name=Fcitx 5 (disabled: launched by KWin on Wayland)
Hidden=true
```

> KWin 的 `kwinrc: InputMethod` 指向 `/usr/share/applications/org.fcitx.Fcitx5.desktop`，不受此覆盖影响。副本：`configs/autostart/org.fcitx.Fcitx5.desktop`

**③ `~/.local/share/applications/workbuddy.desktop`** —— 所有 6 处 `Exec` 从 `GTK_IM_MODULE=xim` 改为 `GTK_IM_MODULE=fcitx`：

```ini
Exec=env XMODIFIERS=@im=fcitx GTK_IM_MODULE=fcitx /usr/bin/workbuddy %U
```

> 副本：`configs/applications/workbuddy.desktop`。WorkBuddy 是 GTK 应用，装了 `im-fcitx5.so`；走 fcitx immodule 而非 xim。改完必须 `kbuildsycoca6 --noincremental`，然后**完全退出 WorkBuddy 再重开**（应用内"重启"会继承旧环境）。

**④ fcitx5 配置**（副本 `configs/fcitx5/conf/`）：

```ini
# ~/.config/fcitx5/conf/pinyin.conf
SwitchInputMethodBehavior=Clear   # 切中英文不再把拼音串/默认候选顶上屏
PredictionSize=0                  # 关掉预测（本机配置里是注释模板，显式设 0）
# ~/.config/fcitx5/conf/classicui.conf
Font="Sans 16"                    # 候选框字体从 38 调回 16
```

### 一键自检 / 修复

把 `scripts/apply-desktop-fixes.sh` 放到 `~/` 并执行：

```bash
cp scripts/apply-desktop-fixes.sh ~/apply-desktop-fixes.sh
bash ~/apply-desktop-fixes.sh
# 需要永久兜底时（需 sudo，给 /usr/bin/workbuddy 插入 export）：
bash ~/apply-desktop-fixes.sh --hard-fix
```

脚本做 5 步幂等自检：天气 timer、QML 文件读取权限、面板组件、fcitx5 配置、WorkBuddy 输入路径（含检测运行中进程实际加载的 immodule、自动刷 KSycoca）。脚本内置"沙箱进程数 <20 就跳过检测"的保护，避免误判。

### 验证与生效

- 改完后**完全退出 WorkBuddy 再重开**（必要时注销重登一次，让 env 钩子生效）。
- `echo $QT_IM_MODULE` 应为空；`pgrep -c fcitx5` 应为 **1**。
- 在桌面终端跑 `/proc/<workbuddy-pid>/maps | grep im-xim` 应为 0，`grep im-fcitx5` 应 >0。
- `journalctl -b | grep 'without a context'`（kwin 输入上下文报错）应接近 0。

### 回滚

- 恢复备份的 `workbuddy.desktop.bak-*`、fcitx5 `*.bak-20261110`。
- 删掉用户级 autostart 覆盖；恢复 `ime.sh`（若要回到 xim 路线）。
- `/usr/bin/workbuddy` 兜底：`sudo cp -a /usr/bin/workbuddy.bak-wb /usr/bin/workbuddy`。

---

## 4. 天气小组件：直连 Open-Meteo，不翻墙

**问题**：KDE 内置 4 个天气源全部不可用——`bbcukmet` 域名被 TLS 阻断；`dwd` 只认德国站点（沈阳 `54342` 返回 404/空）；`noaa`/`envcan` 仅美加。**结论：官方源无一能直连覆盖中国**。

**方案**：**全新自建**用户级 QML Plasmoid `org.dean.openmeteo`（不是改官方组件——官方是 C++ 二进制 `/usr/lib/qt6/plugins/plasma/applets/org.kde.plasma.weather.so`，无法覆盖）。

> 数据链路：`curl --noproxy '*'` 抓 Open-Meteo（沈阳 41.80/123.43，30 分钟刷新）→ 本地 JSON 缓存 → QML 优先读缓存、网络兜底。

### 安装步骤

**① 抓数据脚本 + systemd timer**

```bash
cp scripts/wb-weather-fetch.sh ~/.local/bin/wb-weather-fetch.sh
chmod +x ~/.local/bin/wb-weather-fetch.sh
cp configs/systemd-user/wb-weather.service configs/systemd-user/wb-weather.timer ~/.config/systemd/user/
cp configs/environment.d/wb-weather.conf ~/.config/environment.d/
systemctl --user daemon-reload
systemctl --user enable --now wb-weather.timer
```

脚本核心：`curl --noproxy '*'` 强制绕开系统/KDE 代理，这是"不翻墙也能拿到"的关键。缓存写在 `~/.cache/wb-weather/weather.json`。

**② QML 允许读本地文件**（`~/.config/environment.d/wb-weather.conf`）：

```ini
QML_XHR_ALLOW_FILE_READ=1
```

```bash
systemctl --user set-environment QML_XHR_ALLOW_FILE_READ=1
```

> Qt 默认禁止 QML 通过 XHR 读 `file://`，不设这个，组件读不到缓存。旧 plasmashell 进程需重启才带上该变量。

**③ 建 Plasmoid 包** `~/.local/share/plasma/plasmoids/org.dean.openmeteo/`（QML + metadata，结构同普通 Plasmoid）。**面板组件必须用运行时接口添加**，不能手改配置：

```bash
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
  'var p=panels()[0]; p.addWidget("org.dean.openmeteo")'
```

> **关键坑**： Plasmashell 退出时会把内存布局写回 `plasma-org.kde.plasma.desktop-appletsrc`，手改 `plugin=` 行会被还原。用 `addWidget` 由 Plasma 自己落盘才持久。`evaluateScript` 脚本里不能用顶层 `return`，用 `print()`。
>
> 本机最终状态：面板上新增了 Applet 379（`plugin=org.dean.openmeteo`），官方天气那条（id=210）仍在配置里但不再被使用；BBC 请求停止。

### 验证

```bash
journalctl --user -b | grep wb-weather     # 组件加载 / 缓存读取 / 网络兜底日志
ls -lh ~/.cache/wb-weather/weather.json    # 有缓存文件
curl --noproxy '*' -s 'https://api.open-meteo.com/v1/forecast?latitude=41.80&longitude=123.43&current=temperature_2m' | head -c 200
systemctl --user is-active wb-weather.timer
```

### 回滚

删掉面板上的 openmeteo 组件（编辑模式移除）即可；timer 停用 `systemctl --user disable --now wb-weather.timer`。官方 C++ 天气组件始终没被改动，随时可加回（但要翻墙）。

---

## 5. 关闭 KDE 开机自动恢复上次 App

**现象**：每次开机自动启动上次关闭的 Edge / WorkBuddy / Konsole / Clash Verge。

**根因**：Plasma 6.8 默认 `loginMode` 未显式设置 → 走 "On last logout"。待恢复清单存在 `~/.local/state/plasmasessionrestorestaterc`（Plasma 6 从 `.local/share` 迁到 `.local/state`）。传统 `~/.config/ksmserverrc` 是空壳，Wayland 下真正恢复靠 `plasma-restoresession.service`。

`loginMode` 合法值（从 `/usr/bin/ksmserver` strings 确认）：`default`（空会话）、`restorePreviousLogout`、`restoreSavedSession`。

### 已执行改动（可回滚）

```bash
# 1. 备份
cp ~/.config/ksmserverrc ~/.config/ksmserverrc.bak-wb-20261118
cp ~/.local/state/plasmasessionrestorestaterc ~/.local/state/plasmasessionrestorestaterc.bak-wb-20261118
mv ~/.local/state/plasmasessionrestorestaterc ~/.local/state/plasmasessionrestorestaterc.disabled-wb-20261118

# 2. 设为空会话
kwriteconfig6 --file ~/.config/ksmserverrc --group General --key loginMode default

# 3. 验证
kreadconfig6 --file ~/.config/ksmserverrc --group General --key loginMode    # default
```

> 副本：`configs/plasma/ksmserverrc`。`kwriteconfig6` 必须显式给 value 参数，否则只打印 usage。

**生效**：下次登录后完全生效；当前会话已开着的 App 需手动关。

**回滚**：
```bash
cp ~/.config/ksmserverrc.bak-wb-20261118 ~/.config/ksmserverrc
cp ~/.local/state/plasmasessionrestorestaterc.disabled-wb-20261118 ~/.local/state/plasmasessionrestorestaterc
kwriteconfig6 --file ~/.config/ksmserverrc --group General --key loginMode restorePreviousLogout
```

> 未动 autostart 里的固定自启（netdisk_service / fcitx5 / win-shadow），它们不是本次现象成因。

---

## 6. 光标：把"箭头 + 风火轮"改成纯风火轮

**观察**：程序加载时出现两种风火轮——纯彩虹球 / 黑箭头+彩虹球。Apple 官方只有纯风火轮，**不存在箭头+球**——用户观察正确。

**根因**：Xcursor 规范里 `wait`=完全忙（纯球），`progress`/`left_ptr_watch`=忙但仍可操作（画箭头+球）。主题 `WhiteSur-cursors` 里 `progress` 是箭头+球，`left_ptr_watch`/`half-busy` 都是指向它的符号链接。

### 修复（已执行，方案 A）

```bash
cd ~/.icons/WhiteSur-cursors/cursors
cp -p progress progress.bak-20261110
cp wait progress          # 用纯球覆盖箭头+球
```

> 注意 `/usr/share/icons/` 下还有一份独立 inode 的副本，若某些 Qt 程序仍显示箭头+球，对那份也做同样处理。

**验证**：
```bash
md5sum ~/.icons/WhiteSur-cursors/cursors/{progress,wait}   # 两者应相同
```
本机实测两者 md5 均为 `2a78665ac0209b9637f7ead73dacd38e`。

**生效**：同名主题改文件后 KDE 可能不自动重读——登出重登，或「系统设置→外观→光标」切到别的主题再切回。Chrome / VS Code / Edge 等 Electron 缓存了光标，需重启。

**回滚**：`cd ~/.icons/WhiteSur-cursors/cursors && mv progress.bak-20261110 progress`。

---

## 7. Dolphin Quick Look：macOS 风格敲键预览

**方案选型**：klook（KDE 原生）已从 Arch 下架；**gloobus-preview**（C/Vala/GTK，extra 仓库，225KB）是 Linux 最正宗的 Quick Look 克隆。

### 安装

```bash
sudo pacman -S gloobus-preview kdotool
cp scripts/dolphin-quicklook.sh ~/.local/bin/dolphin-quicklook.sh
chmod +x ~/.local/bin/dolphin-quicklook.sh
cp configs/kio/servicemenus/gloobus-preview.desktop ~/.local/share/kio/servicemenus/
chmod +x ~/.local/share/kio/servicemenus/gloobus-preview.desktop   # 必须有执行位，否则右键报"没有权限"
```

脚本行为：右键预览传 `%U` 直接预览；键盘调用时经 `kdotool` 确认活动窗口是 Dolphin，再用 `qdbus` 读 Dolphin 选中文件（`currentView`→`selectedUrls`，遍历 `Dolphin_1..9`）。`pkill -x gloobus-preview` 实现 macOS 式替换式预览。

### 快捷键（Plasma 6 的重要变动）

> **Plasma 6 彻底移除了 KHotKeys「自定义快捷键」整页**（并入 KGlobalAccel）。所以 `configs/khotkeys/dolphin-quicklook.khotkeys` 在 Plasma 6 **完全无用**，不要浪费时间导入。
>
> 新 KCM「系统设置→键盘→快捷键→新增→命令或脚本」，命令填 `~/.local/bin/dolphin-quicklook.sh`，绑定 **`Meta+回车`（Meta+Return）**。

**为什么是 Meta+回车**：
- 裸 Space / `Meta+Space` 都不行——`Meta+Space` 被 Plasma 启动器占用，裸 Space 会误绑到 KDE 内置选择动作（导致"变多选"）且会吞掉 fcitx5 的空格选词。
- `Ctrl+Space` 是 fcitx5 默认切换键，绝不可绑。
- `Meta+回车` 经核查全表空闲、无冲突。脚本已内置 Dolphin 窗口类判断，即使在别的程序误触也会静默退出。

**先撤销**：如果之前误绑过裸 Space 那条，先在快捷键设置里删掉。

### 验证

- 重开 Dolphin，右键菜单应出现「预览 (Quick Look)」。
- 选中文件按 `Meta+回车` 弹出预览；无选中时不反应（符合预期）。
- 真实 icns 文件可用于验证脚本链路。

---

## 8. icns 图标预览与转换

**需求**：macOS 的 `.icns` 图标在 Linux 直接查看/转换。

**结论**：`libicns` 在 Arch **官方 extra 仓库**（不是 AUR、免编译）：

```bash
sudo pacman -S libicns
# 提供：
icns2png -x icon.icns      # 解出内嵌的多分辨率 PNG
png2icns out.icns a.png b.png
```

> 本机 ImageMagick 的 `magick`/`convert` **没有编译 icns 支持**，不能直接 `convert x.icns`；Gwenview 也打不开 icns 本体。正确流程：先 `icns2png -x` 解成 PNG，再用 `magick` 转 jpg/webp/ico/tiff，或用 Gwenview 看解出的 PNG。

---

## 9. NTFS 游戏分区：开机免密自动挂载

**问题**：Steam 游戏库在 NTFS 分区「文档」「软件」，每次开机 Dolphin 点挂载都要输管理员密码。

**根因**：polkit `org.freedesktop.udisks2.filesystem-mount-system` 的 `allow_active=auth_admin_keep`（内置固定盘需管理员密码，缓存不跨重启）；分区本身未加密。

### 已执行（脚本副本 `scripts/steam-ntfs-automount.sh`）

```bash
sudo bash scripts/steam-ntfs-automount.sh            # 安装，只需一次
bash scripts/steam-ntfs-automount.sh --status         # 查看状态（免 root）
sudo bash scripts/steam-ntfs-automount.sh --rollback  # 回滚
```

脚本按 UUID 写 `/etc/fstab`，**挂载点保持 udisks2 原路径**（`/run/media/dean/文档`、`/run/media/dean/软件`），所以 Steam 的 `libraryfolders.vdf` 和 Dolphin 侧边栏**零改动**。

本机已写入的条目（重装同机 UUID 不变，可直接用；换机需改 UUID）：

```
# wb-steam-ntfs 开机自动挂载，生成于 2026-11-10 09:31:04
UUID=96CD7F81576EBAAE  /run/media/dean/文档  ntfs3  rw,nosuid,nodev,noatime,uid=1000,gid=1001,iocharset=utf8,nofail,x-systemd.device-timeout=10s,x-gvfs-show  0 0
UUID=48BFA923C63314A4  /run/media/dean/软件  ntfs3  rw,nosuid,nodev,noatime,uid=1000,gid=1001,iocharset=utf8,nofail,x-systemd.device-timeout=10s,x-gvfs-show  0 0
```

**选项说明**：
- `nofail` + `x-systemd.device-timeout=10s`：Windows 快速启动导致 NTFS 休眠时不会卡住开机。
- **不加** `windows_names`：它会禁止 Wine prefix 需要的含 `: ? * "` 文件名。
- **不加** `noexec`：Proton 需要执行权限。

**验证**：
```bash
findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS -t ntfs3
bash scripts/steam-ntfs-automount.sh --status
```

**性能实测结论**：NTFS3 相对 ext4，顺序读写带宽无损耗，小文件创建慢约 11%。真正风险在 Wine prefix 语义和 Windows 快速启动休眠只读，不在速度。

---

## 10. 百度网盘：deb 解包安装 + 闪退修复

Arch 无 dpkg，且官方仓库已移除 GTK2 系列——百度网盘 8.9.7 的 `libbrowserengine.so` 依赖 10 个 GTK2/gtkmm-2.4 老 ABI，导致启动闪退。这是**本机最复杂的一项安装**，脚本已封装全部复杂度。

### 安装（脚本副本 `scripts/fix-baidunetdisk.sh`）

**第一步：解包 deb 到用户级**（源包 `~/下载/baidunetdisk_8.9.7_amd64.deb`，约 267MB）：

```bash
mkdir -p ~/.local/opt/baidunetdisk
ar p ~/下载/baidunetdisk_8.9.7_amd64.deb data.tar.bz2 | bsdtar -xm -C ~/.local/opt/baidunetdisk -f -
# 注意必须加 -m（不恢复时间戳），否则沙箱/文件系统会报 "Error exit delayed from previous errors"
```

装图标、启动器、mime：图标 `~/.local/share/icons/hicolor/scalable/apps/baidunetdisk.svg`，启动器 `~/.local/share/applications/baidunetdisk.desktop`（副本在 `configs/applications/`）。

**第二步：修复 GTK2 依赖闪退**：

```bash
bash scripts/fix-baidunetdisk.sh           # 自包含：内联 7 个 Debian 包 URL + SHA256，下载校验、解到应用私有 lib/
bash scripts/fix-baidunetdisk.sh --check    # 检查
bash scripts/fix-baidunetdisk.sh --rollback # 回滚
```

脚本做：从 Debian 12 bookworm 取 7 个运行时包（gtkmm2.4/atkmm1.6/pangomm/cairomm/glibmm2.4/libsigc++-2.0/gtk+2.0），逐个 SHA256 校验，只把 22 个 `.so` 解到 `~/.local/opt/baidunetdisk/lib/`；wrapper `~/.local/bin/baidunetdisk` 设 `LD_LIBRARY_PATH` 后 exec（保留 `--no-sandbox`——用户级解包丢了 chrome-sandbox 的 setuid 位）；desktop Exec 指向 wrapper；`kbuildsycoca6 --noincremental` 刷新。

wrapper 内容（本机现用）：
```sh
export LD_LIBRARY_PATH="/home/dean/.local/opt/baidunetdisk/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "/home/dean/.local/opt/baidunetdisk/baidunetdisk" --no-sandbox "$@"
```

**排查要点**：GTK2 库是 `dlopen` 依赖，`ldd` 主程序查不出来，必须 `ldd ~/.local/opt/baidunetdisk/libbrowserengine.so`。

**验证**：10 个 soname 齐全；带 `LD_LIBRARY_PATH` 的 `ldd` 全部私有库 0 未解析；启动无 `Failed to load shared library` / `Uncaught Exception`。

> **环境坑**（沙箱/低权限环境复用价值高）：`/tmp` 是 10MB tmpfs，大临时目录必须放 `/home` 下；解 deb 用 `tar -xmJ`（`-m`）；`cp -a` 因 utime 失败改用 `cp -d` / 普通 `cp`；EXIT trap 不能引用 `local` 变量（用全局 `WB_WORK`）；验证 Electron 存活用 sleep+kill 而非 `timeout`（后者产生 SIGTRAP coredump）。

---

## 11. 外观主题与拟物笔记 App

### 主题（本机现状）

- 桌面主题：`MacVentura-Light`（`~/.local/share/plasma/desktoptheme/`，`plasmarc` 里 `name=MacVentura-Light`）
- 光标：`WhiteSur-cursors`（见第 6 节）
- 图标：`WhiteSur` 系

> 主题文件是第三方资源（可从pling/store.kde.org 获取），本仓库不含主题本体。重装时装好同名主题、按上述 `plasmarc` 指回即可。

### 拟物笔记 App（调研结论，未安装）

用户想要"像 iOS 备忘录那样拟物 + 专门学 Linux"。调研结论：
- Apple Notes 无 Linux 版。
- 推荐 **Obsidian + Apple Notes / Lick 社区主题**（暖白纸/黄色勾选，Markdown 纯文本、代码块，适合 Linux 学习）。装法：`yay -S obsidian` 或 AppImage。
- 备选：Xournal++（C++ 轻量、手写纸质、官方仓库）、AppFlowy（Rust、Notion 式卡片、AUR）。

> 这一项是选型建议，本机未安装——重装时按需决定。

---

## 12. DSH / WorkBuddy 原生桌面小组件

这是独立于本手册的项目，源码与安装说明在：

**https://github.com/huanyingbeyond-ux/plasma-ai-plasmoids**

### 现状摘要（本机已装）

四个互相独立的 Plasmoid（`~/.local/share/plasma/plasmoids/`）：

| 组件 ID | 显示 |
|---|---|
| `org.dean.dsh.usage.widget` | DSH 余额、累计用量、调用次数、余额曲线 |
| `org.dean.dsh.chat.widget` | DSH 会话切换 + 对话/思考/回答三栏 + 强度/模型 + 输入直达 |
| `org.dean.workbuddy.usage.widget` | WorkBuddy 累计积分、模型倍率、上下文用量 |
| `org.dean.workbuddy.chat.widget` | WorkBuddy 会话切换 + 三栏 + 模型列表 + 深链入口 |

另有：
- **数据 helper**：`~/.local/opt/dsh-widget/` 下 `dsh-summary`、`dsh-usage.py`、`wb-summary.py`、`wb-usage.py`（配套 `configs/systemd-user/dsh-summary.service` / `wb-summary.service` + 各自 timer，30/60 秒刷新）。
- **D-Bus 桥**：`org.dsh.widget`（路径 `/org/dsh/widget`），已注入 `dsh-window.py`（`Ping` / `SubmitQuestion`），实现小组件输入直达 DSH 输入框（只填不发送）。`dsh-native` 还修了"假叫醒"（D-Bus 激活成功但窗口未映射）的 bug。
- **旧整合包** `org.dean.dsh.widget` / `org.dean.workbuddy.widget` 保留为"插件依赖（勿删）"——四个拆分包通过相对路径复用它们目录里的 `.so` 桥接插件。

> **经验**：桌面 Plasmoid 不要玩 compact/full 切换，也不要拆成"小态/大态"多个独立包来模拟缩放——KDE 桌面外框由 containment 管理，QML 改不动。最终方案是**宽度阈值 + 单一视图自适应 + 布局配置**（横三框/上下三框/对话+回答两框），最稳。

---

## 13. GitHub CLI：命令行上传仓库一劳永逸

**背景**：系统无 `gh`；`pacman` 因 `/var/lib/pacman` 属主异常用不了；`/tmp` 只有 10MB。最终下载官方二进制到用户目录。

### 安装（一次性）

```bash
# 下载 gh 二进制（版本以实际为准，本机 v2.105.0），解到用户 bin
mkdir -p ~/.local/bin
# 把 gh 二进制放到 ~/.local/bin/gh 并 chmod +x
~/.local/bin/gh --version
```

> `~/.local/bin` 需在 PATH 里（本机已在 PATH）。

### 授权（网页登录 ≠ 命令行授权）

```bash
~/.local/bin/gh auth login --hostname github.com --git-protocol https --web
```

会打印一次性验证码和 `https://github.com/login/device`。在**已登录 GitHub 的浏览器**打开该网址、输入验证码、点 Authorize 即可。

> **本机没装剪贴板工具**（xsel/xclip/wl-clipboard 都没有），gh 提示 "Failed to copy one-time code"，所以验证码要**手动输入**——这是正常的，不是故障。可用 `xdg-open https://github.com/login/device` 拉起默认浏览器（本机是 microsoft-edge-stable）。
>
> 验证码有时效，过期就重新跑一次命令生成新的。

验证：
```bash
~/.local/bin/gh auth status        # 应显示 Logged in to github.com account ...
```

### 以后每次上传代码（三行）

```bash
cd ~/WorkBuddy/2026-11-09-14-03-20/<仓库目录>
git add -A && git commit -m "说明本次改动" && git push
```

授权信息存在系统钥匙串，后续 push **不用再登录**。建新公开仓库并推送：

```bash
~/.local/bin/gh repo create <仓库名> --public --source=. --remote=origin --push \
  --description "仓库说明"
```

---

## 14. Steam / Proton 注意事项

（本机已核实、无需改动，重装后照此认知使用）

- 库 `SteamLibrary`（约 10G）已装 Proton Experimental + SteamLinuxRuntime，3 个 `compatdata` prefix 完整 → Windows 游戏正常运行。
- 几个老游戏的原生替代建议：`devilutionx.exe` → 原生 Linux `devilutionX`；`Heroes2w-BK.exe` → `fheroes2`（或 WINED3D）；HOMM3 HotA 别用 HD_Launcher。
- Vulkan：Intel HD4400 1.2 未认证 / AMD R5 M230 RADV 1.3；amdgpu 初始化成功无 lockup。
- 未装 wine / lutris / bottles / gamemode（如需可后装）。
- 基线性能：i5-4210U schedutil 2.39GHz，15G 内存可用 9.8G，zram 7.8G，mq-deadline，开机约 23.6s。**这些都是默认值，不要动**。

---

## 15. 磁盘空间：字体与缓存占用真相

用户曾感到"分区满了"，只读扫描结论（**未删除任何文件**）：

- 实际没满：`/` 与 `/home` 约 62–63%，NTFS 17–18%。
- 空间大头：① 字体/主题收集约 3.3G+（SF Pro 全家桶、PingFangSC 210M、`下载/Fonts` 575M）；② `.cache/yay` 2.6G（AUR 编译缓存，**安全可清**）；③ 装完的安装包 deb/zst 约 1.2G；④ 排障备份约 430M。
- 可净回收约 **4.5G 纯垃圾**（yay 缓存 + 旧安装包），不碰字体/应用/Steam。

> 清理个人目录属于高风险操作——本机原则是**先只读扫描出清单、用户逐项确认后再动**。重装时不必急于清理，先确认空间是否真的紧张。

---

## 16. 文件路径速查表

换机/改用户名时，下表所有 `/home/dean` / `dean` 需替换；标注"机器特定"的值需按新机确认。

| 用途 | 路径 | 副本位置 |
|---|---|---|
| 输入法会话钩子 | `~/.config/plasma-workspace/env/ime.sh` | `configs/plasma-workspace/env/ime.sh` |
| 天气 env 钩子 | `~/.config/plasma-workspace/env/weather-direct.sh` | `configs/plasma-workspace/env/weather-direct.sh` |
| fcitx5 禁用双实例 | `~/.config/autostart/org.fcitx.Fcitx5.desktop` | `configs/autostart/` |
| QML 本地读权限 | `~/.config/environment.d/wb-weather.conf` | `configs/environment.d/` |
| WorkBuddy 启动器 | `~/.local/share/applications/workbuddy.desktop` | `configs/applications/` |
| 百度网盘启动器 | `~/.local/share/applications/baidunetdisk.desktop` | `configs/applications/` |
| 百度网盘 wrapper | `~/.local/bin/baidunetdisk` | 第 10 节内联 |
| 天气抓取脚本 | `~/.local/bin/wb-weather-fetch.sh` | `scripts/wb-weather-fetch.sh` |
| Quick Look 脚本 | `~/.local/bin/dolphin-quicklook.sh` | `scripts/dolphin-quicklook.sh` |
| Quick Look 右键菜单 | `~/.local/share/kio/servicemenus/gloobus-preview.desktop` | `configs/kio/servicemenus/` |
| 会话恢复配置 | `~/.config/ksmserverrc` | `configs/plasma/ksmserverrc` |
| 桌面主题配置 | `~/.config/plasmarc` | `configs/plasma/plasmarc` |
| 面板布局 | `~/.config/plasma-org.kde.plasma.desktop-appletsrc` | 不手改！用运行时接口 |
| fcitx5 配置 | `~/.config/fcitx5/conf/{pinyin,classicui}.conf` | `configs/fcitx5/conf/` |
| systemd 服务 | `~/.config/systemd/user/*.service|timer` | `configs/systemd-user/` |
| AI 组件 helper | `~/.local/opt/dsh-widget/` | 见 plasma-ai-plasmoids 仓库 |
| 一键桌面修复 | `~/apply-desktop-fixes.sh` | `scripts/apply-desktop-fixes.sh` |
| NTFS 自动挂载 | `/etc/fstab`（root） | `scripts/steam-ntfs-automount.sh` |
| 光标主题 | `~/.icons/WhiteSur-cursors/cursors/` | 第 6 节命令 |
| gh 二进制 | `~/.local/bin/gh` | 第 13 节 |

**机器特定的值**：NTFS 分区 UUID（第 9 节）、Wayland socket `wayland-1`、天气坐标 `41.80/123.43`（第 4 节，换城市要改）、用户名 `dean` 和 uid/gid `1000/1001`。

---

## 17. 一键校验脚本

重装/恢复后跑这段，快速确认各项是否到位（只读、不改）：

```bash
echo "== 会话 =="; echo "$XDG_SESSION_TYPE / $WAYLAND_DISPLAY"
echo "== 驱动 =="; lspci -k | grep -A2 'R5 M230' | tail -2
echo "== 输入法 =="; grep '^SwitchInputMethodBehavior' ~/.config/fcitx5/conf/pinyin.conf; pgrep -c fcitx5
grep -m1 '^Exec' ~/.local/share/applications/workbuddy.desktop
echo "== 会话恢复 =="; kreadconfig6 --file ~/.config/ksmserverrc --group General --key loginMode
echo "== 天气 =="; systemctl --user is-active wb-weather.timer; ls -lh ~/.cache/wb-weather/weather.json
echo "== 光标 =="; md5sum ~/.icons/WhiteSur-cursors/cursors/{progress,wait}
echo "== 挂载 =="; findmnt -o TARGET,FSTYPE -t ntfs3
echo "== 工具 =="; which icns2png gloobus-preview kdotool gh
echo "== AI 组件 =="; kpackagetool6 --type Plasma/Applet --list | grep org.dean
echo "== 主题 =="; grep '^name=' ~/.config/plasmarc
echo "== GitHub =="; gh auth status 2>&1 | head -3
```

期望值见各章节"验证"小节。

---

## 18. 踩过的坑与经验教训

按主题沉淀，避免重装时重踩：

**KDE / Plasma**
- 面板布局不能手改 `plasma-org.kde.plasma.desktop-appletsrc`——plasmashell 退出会写回覆盖；用 `addWidget` 运行时添加。
- 桌面 Plasmoid 外框归 containment 管理，QML 改不动 `root.width/height`；不要靠切换 representation 做大小态。
- Plasmoid 加载报错 `module "org.dean.xxx" is not installed`：基于名称的 import 在 Plasma 里不可靠，要用**相对路径 import**（`import "org/dean/dsh" as Dsh`）。
- `metadata.json` 必须含 `KPackageStructure` / `X-Plasma-API` / `X-Plasma-MainScript` / `ServiceTypes`，缺一 KDE 不识别。
- Plasma 6 移除了 KHotKeys 自定义快捷键页，`.khotkeys` 文件无效；KCM 只能建全局快捷键，无窗口条件。
- `kwriteconfig6` 必须显式给 value；`kbuildsycoca6 --noincremental` 改完 desktop/元数据后要刷缓存。

**输入法**
- Wayland 下 `GTK_IM_MODULE` / `QT_IM_MODULE` 与 compositor 转发二选一，别同时开。
- 改 desktop 文件后必须**完全退出应用重开**（应用内重启继承旧环境）；判断实际加载的模块看 `/proc/<pid>/maps`。

**环境 / 沙箱**
- 工具容器常见 PID/D-Bus 隔离：`pgrep`、`/proc/maps`、`systemctl --user` 可能连的是假环境；判断真机状态用 `DISPLAY=:0 xprop`、`gdbus` 直连 session bus，或在桌面终端执行。
- 沙箱把宿主 uid 1000 显示成 root:root，`chown` 报 EINVAL——文件属主不可信。
- `/tmp` 可能只有 10MB tmpfs，大文件下载/解包放 `/home`。
- 解 deb 用 `tar -xm`（`-m` 不恢复时间戳）；`cp -a` 失败改 `cp -d`/普通 `cp`。

**GitHub**
- 浏览器网页登录和 `gh auth login` 是两回事，必须单独授权。
- 无剪贴板工具时设备码要手输（正常现象）；验证码有时效。
- `gh repo create ... --source=. --push` 一条命令完成建仓+推送。

**其他**
- Xwayland + 全局菜单（appmenu-gtk-module）与 Wayland layer-shell 协议冲突，单进程不可兼得——做桌面底层小组件和带全局菜单的窗口需要两个协作进程 + D-Bus。
- "打不开 DSH" 可能是"假叫醒"：D-Bus 名还在但窗口没映射，用 X 的 `_NET_CLIENT_LIST` + `WM_CLASS` 判断比信任 `Activate` 返回值可靠。

---

## 19. macOS 风格通用顶栏：global-menu-KDE + 中文翻译

macOS 的桌面本身是 Finder 的一部分，所以即使在桌面也有 `File / Edit / View / Window / Help` 顶端菜单。KDE Plasma 自带的全局菜单 applet（`org.kde.plasma.appmenu`）只在有兼容应用窗口时显示菜单，**无窗口的桌面状态下没有通用菜单**。本节用 `global-menu-KDE` 补上这一块，并附完整简体中文翻译。

### 目标效果

| Plasma 状态 | 顶栏显示 |
|---|---|
| 桌面 / 无窗口 | `文件 / 编辑 / 查看 / 前往 / 工具 / 设置 / 帮助` 通用菜单 |
| Dolphin、Kate 等兼容应用激活 | 自动切到该应用真实菜单 |
| 应用关闭 | 自动切回桌面通用菜单 |

它**不新建第二条面板**，而是作为一个普通 Plasmoid 放进你现有的顶栏。

### 与其他 appmenu 的关系（不互斥）

| 组件 | 说明 |
|---|---|
| `org.kde.plasma.appmenu` | KDE 原生全局菜单，你面板上已有一个（Containment 339 / Applet 343） |
| `com.github.uselessfire.application-title-bar-appmenu` | 第三方标题栏 appmenu，已装未启用 |
| `org.chathuranga.globalmenu` | 本节新装的插件 |

三者都是 D-Bus `com.canonical.AppMenu.Registrar` 的**消费者**，不抢服务、不冲突。但功能重叠，**面板上只放一个**——确认新菜单可用后，把原生 appmenu 从面板移除即可，随时可换回。

### 环境与前置条件（已在本机核实）

- Plasma ≥ 6.5（本机 6.8.2）、Qt ≥ 6.6、KF6 ≥ 6.0、`LibTaskManager` 开发文件齐全。
- 构建工具：`git cmake ninja c++ ctest msgfmt ldd`；依赖包 `qt6-base qt6-declarative kconfig ki18n kwindowsystem libplasma plasma-workspace dbus extra-cmake-modules gettext base-devel`。
- 本机缺 `ninja` 和 `extra-cmake-modules`——**不要直接跑官方 `install.sh`**，它默认执行 `pacman -Syu` 会触发全系统升级。

### 安装（一键，规避四个坑）

```bash
cd ~/WorkBuddy/2026-11-09-14-03-20/arch-macos-setup
bash scripts/install-global-menu-kde.sh
```

脚本做了四件事：
1. `sudo -v` 激活缓存，**只需输一次密码**；
2. `pacman -S --needed` **不带 `-y`**，只补缺失依赖，不全系统升级；
3. 把 `TMPDIR` 指到源码目录——本机 `/tmp` 只有 10MB，直接编译会失败；
4. 调用官方 `install-system.sh` 编译 + CTest + 装到 `/usr`，最后自动装中文翻译。

如只想单独装中文翻译（比如上游已装、或重装系统后恢复）：

```bash
bash scripts/install-global-menu-zh.sh
```

### 验证

```bash
# 插件是否就位
ls -l /usr/lib/qt6/plugins/plasma/applets/org.chathuranga.globalmenu.so

# 中文翻译是否就位
ls -l ~/.local/share/locale/zh_CN/LC_MESSAGES/plasma_applet_org.chathuranga.globalmenu.mo
msgunfmt ~/.local/share/locale/zh_CN/LC_MESSAGES/plasma_applet_org.chathuranga.globalmenu.mo | grep -A1 '&File'

# 系统语言环境
locale | grep LANG
```

插件安装脚本**不自动改面板配置**，桌面上的四个 AI 小组件、系统托盘、天气组件全部原样保留。装完需**退出并重新登录 Plasma 一次**，然后：编辑模式 → 添加小组件 → 搜索 `KDE Global Menu` → 拖入顶栏。

### 中文翻译

- 翻译源文件：`extras/global-menu-kde/po/zh_CN/plasma_applet_org.chathuranga.globalmenu.po`（92 条，含加速键 `文件(&F)` 形式）。
- 采用 KDE 标准 gettext 机制，**无需 sudo、无需重编译**——gettext 从 `~/.local/share/locale` 加载用户翻译。系统 locale 为 `zh_CN.UTF-8` 即可生效。
- 上游 PR：https://github.com/ChathurangaBW/global-menu-KDE/pull/19 （纯翻译，不改 C++/QML/CMake；合并后上游构建会自动用 `ki18n_install(po)` 打包中文 `.mo`）。
- 上游项目：https://github.com/ChathurangaBW/global-menu-KDE

### 回滚

```bash
global-menu-kde-uninstall       # 按 /var/lib/global-menu-kde/install_manifest.txt 精确删除
rm -f ~/.local/share/locale/zh_CN/LC_MESSAGES/plasma_applet_org.chathuranga.globalmenu.mo
# 然后退出重新登录 Plasma
```

原生 appmenu 是 KDE 自带组件，无需也不能卸载——把它从面板移除即可恢复原状。

---

*本手册由实际排障过程整理，所有改动均在本机验证生效。标注"未安装/未执行"的项为调研结论或按需选项。*
