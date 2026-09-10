#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mobile_dir="$(cd "$script_dir/.." && pwd)"

# Key source precedence: env var > mobile/.env.local (git-ignored, never committed)
amap_web_key="${IMMICH_AMAP_WEB_KEY:-${PC_AMAP_KEY:-}}"
if [[ -z "$amap_web_key" && -f "$mobile_dir/.env.local" ]]; then
  while IFS='=' read -r key value; do
    [[ -z "${key// /}" || "${key:0:1}" == "#" ]] && continue
    if [[ "$key" == "IMMICH_AMAP_WEB_KEY" && -n "$value" ]]; then
      amap_web_key="$value"
      break
    fi
  done < "$mobile_dir/.env.local"
fi
if [[ -z "$amap_web_key" ]]; then
  echo "Set IMMICH_AMAP_WEB_KEY (or put it in mobile/.env.local) before building the China Android release APK." >&2
  exit 2
fi

cd "$mobile_dir"
flutter_cmd=(flutter)
if ! command -v flutter >/dev/null 2>&1; then
  if ! command -v mise >/dev/null 2>&1; then
    echo "flutter is not on PATH and mise is unavailable." >&2
    exit 2
  fi
  flutter_cmd=(mise exec -- flutter)
fi

"${flutter_cmd[@]}" build apk \
  --release \
  --target-platform android-arm64 \
  --split-per-abi \
  --dart-define=IMMICH_AMAP_WEB_KEY="$amap_web_key"
