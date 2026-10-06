#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
repository_root="$PWD"
harness="$repository_root/.build/analyzer-tests"
mkdir -p "$harness/Tests/AnalyzerTests"
# Compile the exact app source with tests in the same file to access fileprivate helpers.
cat CursivePrototype.swiftpm/CursiveAnalyzer.swift CursivePrototype.swiftpm/EvaluationState.swift Tests/AnalyzerTests.swift > "$harness/Tests/AnalyzerTests/AnalyzerTests.swift"
cp Tests/Package.swift "$harness/Package.swift"
if [[ -z "${TEST_DESTINATION:-}" ]]; then
  device_id=$(xcrun simctl list devices available --json | python3 -c '
import json, sys
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if ".iOS-" in runtime:
        for device in devices:
            if device.get("isAvailable"):
                print(device["udid"])
                sys.exit(0)
sys.exit("No available iOS simulator; install a runtime in Xcode Settings")
')
  TEST_DESTINATION="platform=iOS Simulator,id=$device_id"
fi
cd "$harness"
# Each run gets a distinct bundle, so earlier results need not be deleted.
result_path="$repository_root/.build/Tests-$(date +%Y%m%d-%H%M%S)-$$.xcresult"
xcodebuild -scheme CursiveValidation-Package -destination "$TEST_DESTINATION" \
  -derivedDataPath "$repository_root/.build/test-derived" \
  -resultBundlePath "$result_path" CODE_SIGNING_ALLOWED=NO test
