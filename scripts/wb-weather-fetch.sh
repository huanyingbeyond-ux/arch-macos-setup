#!/bin/sh
# 直连 Open-Meteo 拉取沈阳天气，写入本地缓存供 Plasma 小组件读取。
# --noproxy '*' 强制绕开系统/KDE 代理，保证「不翻墙」也能取到数据。
set -eu

OUT_DIR="$HOME/.cache/wb-weather"
OUT="$OUT_DIR/weather.json"
TMP="$OUT_DIR/.weather.json.$$"
URL='https://api.open-meteo.com/v1/forecast?latitude=41.80&longitude=123.43&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=Asia%2FShanghai&forecast_days=2'

mkdir -p "$OUT_DIR"

if curl --noproxy '*' -fsS --max-time 20 --retry 2 --retry-delay 2 "$URL" -o "$TMP"; then
    if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert "current" in d and "daily" in d' "$TMP" 2>/dev/null; then
        mv -f "$TMP" "$OUT"
        exit 0
    fi
fi
rm -f "$TMP"
exit 1
