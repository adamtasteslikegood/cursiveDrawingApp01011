# Cursive Prototype

An iOS Swift Playgrounds prototype for practicing cursive handwriting with PencilKit and receiving experimental feedback from Vision and stroke geometry.

The current lesson asks the learner to write **“loop”** on lined paper. The canvas supports PencilKit tools, Clear, and Evaluate. Evaluation displays recognized text, an overall score, and per-segment feedback.

Scores are exploratory heuristics, not validated handwriting assessments. Recognized characters are aligned with `targetText`; missing and extra characters affect the score. Timing is a fixed placeholder and shape comparison needs registered teacher templates. Character segmentation remains approximate and assumes a single left-to-right writing line. The full conversation describes future behavior beyond this prototype.

Start with [QUICKSTART.md](QUICKSTART.md). Contribution and verification instructions are in [CONTRIBUTING.md](CONTRIBUTING.md).

## Repository layout

| Path | Purpose |
| --- | --- |
| `CursivePrototype.swiftpm/` | Active, standalone Swift Playgrounds app package, one level below root |
| `docs/` | Unique historical conversation and troubleshooting documents, indexed by content hash |
| `specs/` | Reserved for future plan, roadmap, and design documents |
| `Tests/` | Analyzer regression tests, compiled with the actual app analyzer source |
| `scripts/` | Build, test, lint, and repository validation entry points |
| `.github/` | CI, CodeQL, Dependabot, and contribution templates |
| `backups/legacy/` | Preserved original sources, scripts, documents, and duplicate packages |

The confirmed prototype review bugs and their regression coverage are documented in [docs/review-fixes.md](docs/review-fixes.md).

## Development checks

On a Mac with full Xcode selected:

```sh
./scripts/lint.sh
./scripts/build.sh
./scripts/test.sh
python3 scripts/check_repository.py
```

CI builds the iOS package, tests analyzer behavior in an iOS simulator, checks Swift formatting and repository integrity, and uploads the playground package. CodeQL uses a manual iOS build and a separate GitHub Actions scan. Dependabot updates GitHub Actions weekly; the app currently has no external Swift package dependencies.

Linux can run repository checks and Swift formatting but cannot build the UIKit/PencilKit app. A passing workflow does not replace the iPad checks in [docs/device-validation.md](docs/device-validation.md).

## Project history

The working prototype originated in [PR #1](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/pull/1). Housekeeping is based on that branch so its prototype changes are included. See [docs/README.md](docs/README.md) for the original design conversation and provenance. Legacy files are reference material and are excluded from active lint/build/test inputs.

## License

[MIT](LICENSE), copyright 2026 Cursive Prototype contributors.

Foundation-only analyzer tests can also run on Linux with `python3 scripts/test-portable.py`. This copies the exact math/model declarations from the active analyzer; it does not exercise Vision, PencilKit, or the iOS UI and does not replace the simulator suite.
