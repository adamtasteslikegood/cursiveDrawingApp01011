#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../CursivePrototype.swiftpm"
xcodebuild -scheme CursivePrototype -configuration Debug -destination 'generic/platform=iOS' \
  -derivedDataPath ../.build/app CODE_SIGNING_ALLOWED=NO build
# App playgrounds use Bundle.main, unlike the standalone SwiftPM test bundle.
python3 - <<'PYTHON'
from pathlib import Path
source = Path('Guides')
bundled = Path('../.build/app/Build/Products/Debug-iphoneos/CursivePrototype.app/Guides')
assert bundled.is_dir(), 'Guide resources are missing from the built app'
assert {p.name for p in bundled.glob('*.json')} == {p.name for p in source.glob('*.json')}, 'Bundled guide inventory differs'
for guide in source.glob('*.json'):
    assert guide.read_bytes() == (bundled / guide.name).read_bytes(), f'Bundled guide differs: {guide.name}'
print('Built app contains the exact guide JSON resources.')
PYTHON
