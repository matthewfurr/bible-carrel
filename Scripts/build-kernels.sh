#!/bin/bash
# Compiles the Core Image kernels in Packages/ScriptureKit/KernelSources into the metallibs
# ScriptureUI bundles (Sources/ScriptureUI/Kernels), one per platform. Needs Xcode's Metal
# Toolchain (xcodebuild -downloadComponent MetalToolchain). Run after changing a kernel and
# commit the libraries: SwiftPM cannot pass Core Image's -fcikernel / -cikernel flags.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Packages/ScriptureKit/KernelSources"
OUT="$ROOT/Packages/ScriptureKit/Sources/ScriptureUI/Kernels"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
for kernel in "$SRC"/*.ci.metal; do
    name="$(basename "$kernel" .ci.metal)"
    for pair in "macosx:macos:-mmacosx-version-min=26.0" "iphoneos:ios:-mios-version-min=26.0" "iphonesimulator:iossimulator:-mios-simulator-version-min=26.0"; do
        IFS=: read -r sdk suffix min <<<"$pair"
        xcrun -sdk "$sdk" metal -c -fcikernel "$min" "$kernel" -o "$TMP/$name-$suffix.air"
        xcrun -sdk "$sdk" metallib -cikernel "$TMP/$name-$suffix.air" -o "$OUT/$name-$suffix.metallib"
        echo "built $name-$suffix.metallib"
    done
done
