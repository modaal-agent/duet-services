#!/bin/bash
# The iOS lane: builds every target for the simulator and runs the suites that
# need a simulator host. CI runs this same file (the `ios` job in
# .github/workflows/ci.yml), so a green checkout and a green CI mean the same
# thing.
#
# Two steps, each covering something `swift test` on macOS cannot:
#
#   1. Build the whole package for a generic simulator destination. The host
#      lane compiles every `#if os(iOS)` file to nothing — the audio-session
#      port, FakeAudioSession, the APNS half of InboundAppServicesWorker, and
#      all of DuetTheming — so this is where they are type-checked.
#   2. Run ThemingTests on a booted simulator. Those tests mount real SwiftUI
#      trees under a `UIWindow` and assert on what a view resolved from the
#      environment, which needs UIKit at runtime. The other suites are
#      platform-neutral and run on the host lane; running them here again
#      would cover nothing further.
#
# Set TEST_DESTINATION to override the auto-picked simulator, e.g.
#   TEST_DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro' scripts/test-ios.sh
# Any further arguments are passed through to the `xcodebuild test` call.
set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="duet-services-Package"

DESTINATION="${TEST_DESTINATION:-}"

if [ -z "$DESTINATION" ]; then
  # Newest installed iOS runtime, first available iPhone on it. Picking by
  # UDID rather than by name keeps this working as Xcode's device set changes.
  UDID="$(xcrun simctl list devices available --json | python3 -c '
import json, sys

best = None
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if ".SimRuntime.iOS-" not in runtime:
        continue
    version = tuple(int(part) for part in runtime.rsplit("iOS-", 1)[1].split("-"))
    for device in devices:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            if best is None or version > best[0]:
                best = (version, device["udid"])
            break
print(best[1] if best else "")
')"

  if [ -z "$UDID" ]; then
    echo "No available iOS simulator. Install one from Xcode > Settings > Components." >&2
    exit 1
  fi

  DESTINATION="platform=iOS Simulator,id=$UDID"
fi

echo "==> Building every target for iOS Simulator"
xcodebuild build \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS Simulator' \
  -skipMacroValidation

echo "==> Test destination: $DESTINATION"
xcodebuild test \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:ThemingTests \
  -skipMacroValidation \
  "$@"
