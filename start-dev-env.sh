#!/system/bin/sh
# start-dev-env.sh — K3 pico 开发环境开机自恢复（重启后跑一次）
# 网络路由/DNS 重启即丢；vscode-server 不随系统自启（官方镜像 /system 只读，
# 无法加 init cfg）。本脚本把三件事一次做完：
#   1) 默认路由 + DNS bind mount   2) vscode-server(:3000)   3) 自检
DHCP_GW=$(ip route 2>/dev/null | grep -m1 'eth0.*via' | sed 's/.*via \([0-9.]*\).*/\1/')
GW=${DHCP_GW:-10.0.90.254}
route -n 2>/dev/null | grep -q '^0.0.0.0' || route add default gw $GW dev eth0
mkdir -p /data/local/tmp/resolv
printf 'nameserver 10.0.26.18\nnameserver 10.0.26.19\n' > /data/local/tmp/resolv/resolv.conf
# 守卫必须查内网 DNS IP 而非泛 nameserver：原版 resolv.conf 自带
# 114.114.114.114/8.8.8.8（公司网 UDP DNS 被拦，getaddrinfo 全挂），
# 查 nameserver 会误判"已配置"而跳过 bind mount（2026-09-10 deveco 排查实测）。
grep -q 10.0.26.18 /etc/resolv.conf 2>/dev/null || \
  mount --bind /data/local/tmp/resolv/resolv.conf /etc/resolv.conf
# vscode-server（已监听则跳过）
if ! cat /proc/net/tcp 2>/dev/null | grep -qi ':0BB8'; then
  cd /data/vscode/server && HOME=/data/vscode/home setsid nohup ./start.sh \
    > /data/vscode/vscode.log 2>&1 < /dev/null &
fi
sleep 2
cat /proc/net/tcp | grep -qi ':0BB8' && echo "[dev-env] vscode-server :3000 LISTEN  http://$(ifconfig eth0 | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p' | head -1):3000"
ping -c 1 -W 3 ohpm.openharmony.cn > /dev/null 2>&1 && echo "[dev-env] network OK" || echo "[dev-env] WARN: DNS/外网未通"
echo "[dev-env] hap-dev: . /data/hap-dev/env.sh && hapdev run"
echo "[dev-env] deveco : /data/deveco/bin/deveco-chat（apiKey 在 /data/deveco/home/.config/deveco/deveco.json）"
