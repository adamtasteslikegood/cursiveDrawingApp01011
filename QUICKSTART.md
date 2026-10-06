# Quick start

## Run on iPad

1. Clone or download this repository.
2. Transfer the entire `CursivePrototype.swiftpm` folder to your iPad (Files or AirDrop).
3. Open the package in Swift Playgrounds and run it. The manifest targets iOS 16 or later; use a current Playgrounds version compatible with your iPad.
4. Write “loop” using Apple Pencil or touch, tap Evaluate, and inspect feedback. Clear resets the drawing and results.

Use only the root-level package; packages under `backups/legacy/` are historical copies.

## Develop on Mac

Install full Xcode, open it once to finish setup, and select it:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
xcodebuild -version
open CursivePrototype.swiftpm
```

From the repository root:

```sh
./scripts/build.sh
./scripts/test.sh
./scripts/lint.sh
python3 scripts/check_repository.py
```

Tests automatically select an available iOS simulator. Override it with `TEST_DESTINATION='platform=iOS Simulator,id=<device-UUID>'`. Use `xcrun simctl list devices available` to inspect devices.

To apply formatting, run `swift format format --in-place --recursive CursivePrototype.swiftpm Tests`, then rerun lint. A current Swift toolchain with `swift format` is required.

## Troubleshooting

- `AppleProductTypes`, UIKit, or PencilKit missing: use full Xcode on macOS or Swift Playgrounds on iPad. Plain host `swift build` is not the app build command.
- No simulator: install an iOS simulator runtime in Xcode Settings, then retry.
- Signing errors: the CI build uses `CODE_SIGNING_ALLOWED=NO`; installing from Xcode on a physical device requires your own signing setup.
- Package fails to open: preserve the complete `.swiftpm` directory and its `Package.swift`, not just individual Swift files.

CI produces a downloadable playground ZIP; device validation is still required before calling a prototype ready.

Foundation-only analyzer tests can also run on Linux with `python3 scripts/test-portable.py`. This copies the exact math/model declarations from the active analyzer; it does not exercise Vision, PencilKit, or the iOS UI and does not replace the simulator suite.
