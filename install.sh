#!/system/bin/sh
# install.sh — 从 GitHub Release 拉取 ohos-riscv64-sdk 并安装到设备
# 用法（K3 pico / OpenHarmony 6.1 riscv64，已配好网络）:  sh install.sh
# 离线：先把完整 tar.gz 放到 /data/stage/（或放 part0..part6 分卷）再执行本脚本
#
# 注：资产以 7 个分卷发布（每卷 16M，短连接规避长流限速），下载后 cat 合并。
set -e

GH=https://github.com/shihuan1999/ohos-riscv64-sdk/releases/download/v6.1.0.32-api23
TGZ=oh-sdk-23-riscv64-6.1.0.32.tar.gz
SIZE=109896037
PARTS="0 1 2 3 4 5 6"
DEST=/data/hap-dev/sdk/oh-sdk/23
STAGE=/data/stage

mkdir -p "$STAGE" "$DEST"

CACERT=""
for c in /etc/ssl/certs/cacert.pem /system/etc/ssl/cacert.pem; do
  [ -f "$c" ] && CACERT="--cacert $c" && break
done

# 1. 获取（整包已存在则跳过分卷）
if [ ! -f "$STAGE/$TGZ" ]; then
  for p in $PARTS; do
    if [ ! -f "$STAGE/part-$p" ] || [ ! -s "$STAGE/part-$p" ]; then
      echo "[install] downloading part$p ..."
      curl -fL $CACERT --retry 3 --retry-delay 3 --connect-timeout 20 \
        -o "$STAGE/part-$p" "$GH/$TGZ.part$p"
    fi
  done
  cat $(for p in $PARTS; do echo "$STAGE/part-$p"; done) > "$STAGE/$TGZ"
  rm -f "$STAGE"/part-*
fi

# 2. 完整性（设备 toybox 无 sha256sum，用字节数 + tar 目录校验）
set -- $(wc -c < "$STAGE/$TGZ"); GOT=$1
if [ "$GOT" != "$SIZE" ]; then
  echo "[install] size mismatch: $GOT != $SIZE (expect). Remove $STAGE/$TGZ and retry." >&2
  exit 1
fi
tar tzf "$STAGE/$TGZ" > /dev/null && echo "[install] tar integrity OK ($GOT bytes)"

# 3. 安装（清旧组件，解压新组件）
for c in ets js toolchains native previewer; do rm -rf "$DEST/$c"; done
tar xzf "$STAGE/$TGZ" -C "$DEST"
chmod 755 "$DEST/toolchains/es2abc.real" "$DEST/toolchains/syscap_tool" "$DEST/toolchains/restool" \
          "$DEST/ets/build-tools/ets-loader/bin/ark/build/bin/es2abc" \
          "$DEST/ets/build-tools/ets-loader/bin/ark/build/bin/es2abc.real" \
          "$DEST/js/build-tools/ace-loader/bin/ark/build/bin/es2abc" \
          "$DEST/js/build-tools/ace-loader/bin/ark/build/bin/es2abc.real" 2>/dev/null || true

# 4. 自检
for f in ets/oh-uni-package.json toolchains/oh-uni-package.json toolchains/syscap_tool \
         ets/build-tools/ets-loader/bin/ark/build/bin/es2abc.real; do
  [ -e "$DEST/$f" ] || { echo "[install] MISSING: $f" >&2; exit 2; }
done
grep -q '"apiVersion": "23"' "$DEST/ets/oh-uni-package.json" || { echo "[install] apiVersion not 23!" >&2; exit 3; }

echo "[install] DONE -> $DEST"
echo "[install] 验证: . /data/hap-dev/env.sh && hapdev run"
