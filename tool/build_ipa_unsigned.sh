#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS IPA 必须在 macOS 上构建；当前系统不是 macOS。" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
APP_PATH="$ROOT/build/ios/iphoneos/Runner.app"
OUT_DIR="$ROOT/build/ios/ipa"
VERSION="$(sed -n 's/^version:[[:space:]]*//p' "$ROOT/pubspec.yaml" | cut -d+ -f1)"
IPA_NAME="Guomu-${VERSION}-unsigned.ipa"

if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  echo "找不到 Flutter：$FLUTTER_BIN" >&2
  exit 1
fi
if ! command -v zip >/dev/null 2>&1; then
  echo "找不到 zip；请先安装 Xcode Command Line Tools。" >&2
  exit 1
fi

cd "$ROOT"
"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build ios --release --no-codesign

if [[ ! -d "$APP_PATH" ]]; then
  echo "没有找到 iOS 构建产物：$APP_PATH" >&2
  exit 1
fi

rm -rf "$OUT_DIR/Payload"
mkdir -p "$OUT_DIR"
cp -R "$APP_PATH" "$OUT_DIR/Payload"
rm -f "$OUT_DIR/$IPA_NAME"
(
  cd "$OUT_DIR"
  /usr/bin/zip -qry "$IPA_NAME" Payload
  rm -rf Payload
)

printf '\n未签名 IPA：%s\n' "$OUT_DIR/$IPA_NAME"
printf '请使用 Sideloadly、AltStore、TrollStore 或你的签名证书完成签名安装。\n'
