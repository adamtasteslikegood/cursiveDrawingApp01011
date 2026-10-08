# Quick start

## Run on iPad

1. Clone or download this repository.
2. Transfer the entire `CursivePrototype.swiftpm` folder to your iPad (Files or AirDrop).
3. Open the package in Swift Playgrounds and run it. The manifest targets iOS 16 or later; use a current Playgrounds version compatible with your iPad.
4. Confirm the on-screen label reads **Lesson prototype 1.3.1 · 2026-10-07**. Select Prototype Cursive and choose a word from Set 1, 2, or 3; changing guide, profile or lesson clears the drawing. Scroll the page to position the paper comfortably; space below it remains available before evaluation and after clearing results.
5. Use the thumbnail and Replay example. Small-letter bodies sit in the highlighted band between the dashed middle line and solid baseline; tall letters reach the top solid line, and p descends below the baseline.
6. Trace the optional blue guide with Apple Pencil or touch, tap Evaluate, and inspect shape/position/height feedback, expanded experimental letter/join rows, and OCR separately. Clear resets the drawing and results. Try again with Trace guide off.

To exercise the new engine, select **Stroke Lab**, which contains a two-stroke x and lifted connections. Its models are technical demonstrations, not reviewed handwriting instruction. Compare Explore and Precise geometry profiles. Import `CursivePrototype.swiftpm/Guides/e-and-ee.example.json` to try the complete one-letter/two-letter schema example. Imports last for the session; invalid files preserve the current lesson. See [guide authoring](docs/guide-format.md).

Scoring remains unresolved: unrelated ink can receive a high geometry score. Record component scores and actual letter quality separately in the [device checklist](docs/device-validation.md).

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
- Package fails to open: preserve the complete `.swiftpm` directory and its `Package.swift` and `Guides/` resources, not just individual Swift files.

CI produces a downloadable playground ZIP; device validation is still required before calling a prototype ready.

Foundation-only analyzer tests can also run on Linux with `python3 scripts/test-portable.py`. This copies the exact guide loader, lesson models/resources and math/model declarations from the active analyzer; it does not exercise Vision, PencilKit, or the iOS UI and does not replace the simulator suite.

The five supported model letters can be viewed in [the primer visual](docs/primer-reference.svg); see [primer decisions](docs/primer-decisions.md) for educational-source comparison. To regenerate/check that visual, run `python3 scripts/export-primer.py` / `python3 scripts/export-primer.py --check`.
