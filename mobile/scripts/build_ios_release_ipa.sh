#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mobile_root="$(cd "$script_dir/.." && pwd)"
ios_root="$mobile_root/ios"
app_path="$mobile_root/build/ios/iphoneos/Immich.app"
ipa_dir="$mobile_root/build/ios/ipa"

expected_bundle_id=""
install_device=""
skip_build=0
dry_run=0

usage() {
  cat <<'USAGE'
Build a signed iOS Release IPA for local device installation.

Usage:
  mobile/scripts/build_ios_release_ipa.sh [options]

Options:
  --expected-bundle-id <id>  Verify the built app bundle id. Defaults to
                            IMMICH_BUNDLE_ID_PROD from ios/Signing.local.xcconfig,
                            then ios/Signing.xcconfig.
  --install <device-id>      Install the IPA after building. Use the CoreDevice
                            identifier shown by: xcrun devicectl list devices
  --skip-build               Package the existing build/ios/iphoneos/Immich.app.
  --dry-run                  Print the major commands without running the build.
  -h, --help                 Show this help.

Examples:
  mobile/scripts/build_ios_release_ipa.sh
  mobile/scripts/build_ios_release_ipa.sh --install 1510FDFC-2EB1-5E95-8076-B7295C8191B7

Notes:
  This IPA is development-signed for devices allowed by the provisioning profile.
  It is not an App Store or TestFlight distribution package.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

info() {
  echo "==> $*"
}

run() {
  if [[ "$dry_run" == "1" ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

read_xcconfig_value() {
  local key="$1"
  local file

  for file in "$ios_root/Signing.local.xcconfig" "$ios_root/Signing.xcconfig"; do
    [[ -f "$file" ]] || continue
    awk -v key="$key" '
      $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
        sub(/^[^=]*=[[:space:]]*/, "")
        sub(/[[:space:]]*\/\/.*$/, "")
        sub(/[[:space:]]+$/, "")
        print
        exit
      }
    ' "$file"
    return 0
  done
}

flutter_cmd=()
detect_flutter() {
  if command -v mise >/dev/null 2>&1 && [[ -f "$mobile_root/mise.toml" ]]; then
    local flutter_version
    flutter_version="$(
      awk -F'"' '$2 == "aqua:flutter/flutter" { print $4; exit }' "$mobile_root/mise.toml"
    )"
    if [[ -n "$flutter_version" ]]; then
      flutter_cmd=(mise x "aqua:flutter/flutter@$flutter_version" -- flutter)
    else
      flutter_cmd=(mise x -- flutter)
    fi
  elif command -v flutter >/dev/null 2>&1; then
    flutter_cmd=(flutter)
  else
    die "Flutter was not found. Install mise tools from mobile/mise.toml or put flutter on PATH."
  fi
}

print_install_help() {
  local ipa_path="$1"
  local bundle_id="$2"

  cat <<EOF

IPA created:
  $ipa_path

Install on a connected iPhone:
  xcrun devicectl list devices
  xcrun devicectl device install app --device <device-id> "$ipa_path"

Launch after install:
  xcrun devicectl device process launch --device <device-id> "$bundle_id"

If you use a free Personal Team and installation fails with the maximum app
limit, uninstall an older free-profile app first, for example:
  xcrun devicectl device uninstall app --device <device-id> com.ranpeng.immichdev.debug
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --expected-bundle-id)
      [[ $# -ge 2 ]] || die "--expected-bundle-id requires a value"
      expected_bundle_id="$2"
      shift 2
      ;;
    --install)
      [[ $# -ge 2 ]] || die "--install requires a device id"
      install_device="$2"
      shift 2
      ;;
    --skip-build)
      skip_build=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

if [[ -z "$expected_bundle_id" ]]; then
  expected_bundle_id="$(read_xcconfig_value IMMICH_BUNDLE_ID_PROD || true)"
fi

detect_flutter

info "Mobile root: $mobile_root"

if [[ "$skip_build" != "1" ]]; then
  info "Building iOS Release app"
  (
    cd "$mobile_root"
    run "${flutter_cmd[@]}" build ios --release
  )
else
  info "Skipping Flutter build; packaging existing app"
fi

if [[ "$dry_run" == "1" ]]; then
  info "Dry run finished before packaging."
  exit 0
fi

[[ -d "$app_path" ]] || die "missing built app: $app_path"

built_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist")"
[[ -n "$built_bundle_id" ]] || die "could not read CFBundleIdentifier from $app_path"

if [[ -n "$expected_bundle_id" && "$built_bundle_id" != "$expected_bundle_id" ]]; then
  die "built bundle id is '$built_bundle_id', expected '$expected_bundle_id'"
fi

timestamp="$(date +%Y%m%d%H%M%S)"
safe_bundle_id="${built_bundle_id//[^A-Za-z0-9._-]/_}"
ipa_path="$ipa_dir/Immich-release-$safe_bundle_id-$timestamp.ipa"
mkdir -p "$ipa_dir"
package_dir="$(mktemp -d "$ipa_dir/package.XXXXXX")"

cleanup() {
  rm -rf "$package_dir"
}
trap cleanup EXIT

info "Packaging IPA"
mkdir -p "$package_dir/Payload"
cp -R "$app_path" "$package_dir/Payload/Immich.app"
(
  cd "$package_dir"
  run /usr/bin/zip -qry "$ipa_path" Payload
)

codesign -dv --verbose=2 "$app_path" 2>&1 | sed -n 's/^TeamIdentifier=/TeamIdentifier: /p; s/^Authority=/Authority: /p'
echo "Bundle ID: $built_bundle_id"
ls -lh "$ipa_path"

if [[ -n "$install_device" ]]; then
  info "Installing IPA on device $install_device"
  run xcrun devicectl device install app --device "$install_device" "$ipa_path"
fi

print_install_help "$ipa_path" "$built_bundle_id"
