# Plasma Wayland：fcitx5 由 KWin 独占启动，GTK/Qt 原生应用走
# Wayland text-input-v3 协议（Arch Wiki: Fcitx5 > Integration > Wayland）。
# 若同时设置 GTK_IM_MODULE / QT_IM_MODULE，应用会走 IM 模块路径，
# 与 compositor 的输入转发并存，导致按键与候选词时序错乱（打串字、错别字）。
# 因此这里只保留 XMODIFIERS，供 Xwayland / 传统 X11 应用使用 XIM。
export XMODIFIERS="@im=fcitx"
