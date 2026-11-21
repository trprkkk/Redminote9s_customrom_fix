#!/usr/bin/env bash
# Rebuild a patched miui-wifi-service.jar from the original jar.
#
# Requirements: bash, java, unzip, zip, patch, baksmali.jar, smali.jar
#
# Usage:
#   bash tools/apply-patch.sh \
#     --orig miui-wifi-service.jar \
#     --baksmali baksmali-2.5.2.jar \
#     --smali smali-2.5.2.jar \
#     --out miui-wifi-service-patched.jar
#
# baksmali/smali: https://github.com/JesusFreke/smali/releases/tag/v2.5.2

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH="${SCRIPT_DIR}/../patches/softap-5ghz-jp.patch"

ORIG=""
BAKSMALI=""
SMALI=""
OUT=""

usage() {
  echo "usage: $0 --orig <jar> --baksmali <jar> --smali <jar> --out <jar> [--patch <file>]" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --orig) ORIG="${2:-}"; shift 2 ;;
    --baksmali) BAKSMALI="${2:-}"; shift 2 ;;
    --smali) SMALI="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --patch) PATCH="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
done

[ -n "$ORIG" ] && [ -n "$BAKSMALI" ] && [ -n "$SMALI" ] && [ -n "$OUT" ] || usage
[ -f "$ORIG" ] || { echo "not found: $ORIG" >&2; exit 1; }
[ -f "$PATCH" ] || { echo "not found: $PATCH" >&2; exit 1; }

for cmd in java unzip zip patch; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "missing command: $cmd" >&2; exit 1; }
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/orig" "$WORK/out"
unzip -q -o "$ORIG" classes.dex META-INF/MANIFEST.MF -d "$WORK/orig"

java -jar "$BAKSMALI" d "$WORK/orig/classes.dex" -o "$WORK/smali"
patch -p1 -d "$WORK/smali" < "$PATCH"
java -jar "$SMALI" a "$WORK/smali" -o "$WORK/classes.dex"

mkdir -p "$WORK/out/META-INF"
cp "$WORK/orig/META-INF/MANIFEST.MF" "$WORK/out/META-INF/MANIFEST.MF"
cp "$WORK/classes.dex" "$WORK/out/classes.dex"

rm -f "$OUT"
( cd "$WORK/out" && zip -X -q "$OUT" classes.dex META-INF/MANIFEST.MF )

echo "patched: $OUT"
