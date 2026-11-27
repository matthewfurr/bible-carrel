#!/bin/zsh
# Builds the Release configuration, signed with the team, and installs it as
# "/Applications/Bible Carrel.app", the copy you read in. The build keeps the
# file name ReadingThroughScripture.app (paths and scripts depend on it); only the
# installed copy takes the app's name, which the Dock and Finder show.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
built="$repo/Build/DerivedData/Build/Products/Release/ReadingThroughScripture.app"
installed="/Applications/Bible Carrel.app"
# The name the installed copy had before 2026-11-20; removed once the new copy is in place.
former="/Applications/ReadingThroughScripture.app"

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" xcodebuild \
    -workspace "$repo/ReadingThroughScripture.xcworkspace" \
    -scheme ReadingThroughScripture \
    -configuration Release \
    -derivedDataPath "$repo/Build/DerivedData" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    build

# Never remove the installed copy without a built one to put in its place.
if [[ ! -d "$built" ]]; then
    echo "No built app at $built; the installed copy is unchanged." >&2
    exit 1
fi

# True while an installed copy (under either name) is running.
running() {
    pgrep -f "^$installed/Contents/MacOS/" > /dev/null || pgrep -f "^$former/Contents/MacOS/" > /dev/null
}

# Quit the installed copy if it is running, and wait for it to go (30 seconds at most).
if running; then
    osascript -e 'with timeout of 30 seconds' -e 'tell application id "com.matthewfurr.ReadingThroughScripture" to quit' -e 'end timeout' || true
    waited=0
    while running; do
        if (( waited >= 60 )); then
            echo "The installed app did not quit within 30 seconds; the installed copy is unchanged." >&2
            exit 1
        fi
        sleep 0.5
        (( waited += 1 ))
    done
fi

rm -rf "$installed"
ditto "$built" "$installed"
echo "Installed $installed"

if [[ -d "$former" ]]; then
    rm -rf "$former"
    echo "Removed $former (the same app under its former name)"
fi
