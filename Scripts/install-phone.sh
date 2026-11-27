#!/bin/bash
# Builds the iPhone app for a connected iPhone, signed with the team, and
# installs it there.
#
#   Scripts/install-phone.sh debug [device]              the Debug build (.dev identity)
#   Scripts/install-phone.sh release --go-live [device]  the Release build, your real notes
#
# With no device given it uses the one paired physical iPhone that
# `xcrun devicectl list devices` reports.
set -euo pipefail

usage() {
    echo "Usage: $0 debug|release [--go-live] [device-identifier]" >&2
    exit 64
}

configuration=""
device=""
go_live=0
for argument in "$@"; do
    case "$argument" in
        debug|release)
            [[ -z "$configuration" ]] || usage
            configuration="$argument"
            ;;
        --go-live)
            go_live=1
            ;;
        -*)
            usage
            ;;
        *)
            [[ -z "$device" ]] || usage
            device="$argument"
            ;;
    esac
done
[[ -n "$configuration" ]] || usage

# The Release build holds the real notes: refuse it before anything is built or installed.
if [[ "$configuration" == "release" && "$go_live" -ne 1 ]]; then
    echo "Refusing to build or install Release without --go-live. Release is the identity that holds your real notes." >&2
    exit 1
fi

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

repo="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$configuration" == "release" ]]; then
    build_configuration="Release"
    bundle_id="com.matthewfurr.ReadingThroughScripture"
else
    build_configuration="Debug"
    bundle_id="com.matthewfurr.ReadingThroughScripture.dev"
fi
built="$repo/Build/DerivedData/Build/Products/$build_configuration-iphoneos/ReadingThroughScripture.app"

# With no device given, find the one paired physical iPhone.
if [[ -z "$device" ]]; then
    devices_json="$(mktemp "${TMPDIR:-/tmp}/install-phone-devices.XXXXXX")"
    trap 'rm -f "$devices_json"' EXIT
    xcrun devicectl list devices --quiet --json-output "$devices_json"
    phones="$(/usr/bin/python3 -I -c '
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
for d in devices:
    hw = d.get("hardwareProperties", {})
    pairing = d.get("connectionProperties", {}).get("pairingState")
    if hw.get("reality") == "physical" and hw.get("deviceType") == "iPhone" and pairing == "paired":
        print(hw.get("udid") or d["identifier"])
' "$devices_json")"
    count="$(printf '%s' "$phones" | grep -c . || true)"
    if [[ "$count" -eq 0 ]]; then
        echo "No paired iPhone found. Connect and pair the phone, or name it: $0 $configuration <device-identifier>" >&2
        exit 1
    fi
    if [[ "$count" -gt 1 ]]; then
        echo "More than one paired iPhone found; name the one to install on:" >&2
        echo "$phones" >&2
        exit 1
    fi
    device="$phones"
fi

echo "Building $build_configuration ($bundle_id) for device $device"

xcodebuild \
    -workspace "$repo/ReadingThroughScripture.xcworkspace" \
    -scheme ReadingThroughScripture-iOS \
    -configuration "$build_configuration" \
    -destination "id=$device" \
    -derivedDataPath "$repo/Build/DerivedData" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    build

if [[ ! -d "$built" ]]; then
    echo "No built app at $built; nothing was installed." >&2
    exit 1
fi

echo "Installing $built on device $device"
xcrun devicectl device install app --device "$device" "$built"
echo "Installed $bundle_id on device $device"
