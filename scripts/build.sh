#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../CursivePrototype.swiftpm"
xcodebuild -scheme CursivePrototype -destination 'generic/platform=iOS' \
  -derivedDataPath ../.build/app CODE_SIGNING_ALLOWED=NO build
