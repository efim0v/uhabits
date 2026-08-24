#!/usr/bin/env bash
# Runs the iOS widget extension's own XCTest cases.
#
# `flutter test` cannot run Swift, so for a long time the widget extension was
# guarded only by Dart tests that read its source as text — which can see that
# a field is declared or that a pattern is absent, and cannot see an off-by-one.
# Eight audit findings came out of that gap, the last two of them logic errors.
#
# The widget sources are compiled into the RunnerTests bundle (see
# ios/Runner.xcodeproj/project.pbxproj), so these cases execute the real code.
# It needs a booted simulator, which is why it is a separate script rather than
# part of close_features.sh.
set -euo pipefail

cd "$(dirname "$0")/../app/ios"

# A booted device if there is one, otherwise any available iPhone: xcodebuild
# boots a clone of whatever it is pointed at.
DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  DEVICE=$(xcrun simctl list devices -j | python3 -c '
import json, sys
devices = [d for v in json.load(sys.stdin)["devices"].values() for d in v]
booted = [d for d in devices if d.get("state") == "Booted"]
usable = [d for d in devices if d.get("isAvailable") and "iPhone" in d.get("name", "")]
pick = booted or usable
print(pick[0]["udid"] if pick else "")')
fi
if [ -z "$DEVICE" ]; then
  echo "no iOS simulator available; install one or pass a udid" >&2
  exit 2
fi

xcodebuild test \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -quiet 2>&1 | grep -E "Test case|Testing failed|\*\* TEST" || true

# xcodebuild's exit status is what decides.
xcodebuild test \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -quiet > /dev/null 2>&1
