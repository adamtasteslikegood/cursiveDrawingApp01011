# Cursive Prototype

An iOS Swift Playgrounds prototype for practicing cursive handwriting with PencilKit and receiving experimental feedback from Vision and stroke geometry.

Version **1.1** offers **loop**, **pool**, and **hello**, with a centered writing band, labeled solid/dashed guides, a target thumbnail, an optional trace guide, and a replay demonstration. The canvas supports PencilKit tools, Clear, and Evaluate. The visible version/date label identifies this lesson iteration on the iPad.

The primary **Practice match** compares actual ink with the displayed model's geometry and reports shape, vertical position, and height separately. OCR is shown as a separate recognition check. Models, weights, and feedback are experimental and do not establish educational mastery, timing, joins, or stroke-order accuracy. See [the lesson guide](docs/lesson-prototype.md) for scoring details and limitations.

The user confirmed the refreshed **1.0 baseline** runs and evaluates handwriting on an iPad, while reporting low scores and missing tutorial cues; see [the baseline evaluation](docs/ipad-baseline-evaluation.md). The user subsequently accepted the core 1.1 UI and scoring consistency on the same iPad; [the 1.1 evaluation](docs/ipad-lesson-1.1-evaluation.md) records the evidence and the still-experimental per-letter analysis.

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

The working prototype originated in [PR #1](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/pull/1). PRs #1–#3 merged the prototype, repository foundation, review fixes, and the user’s baseline evaluation. See [docs/README.md](docs/README.md) for the original design conversation and provenance. Legacy files are reference material and are excluded from active lint/build/test inputs.

## License

[MIT](LICENSE), copyright 2026 Cursive Prototype contributors.

Foundation-only analyzer tests can also run on Linux with `python3 scripts/test-portable.py`. This copies the exact lesson models and math/model declarations from the active analyzer; it does not exercise Vision, PencilKit, or the iOS UI and does not replace the simulator suite.
