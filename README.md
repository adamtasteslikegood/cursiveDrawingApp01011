# Cursive Prototype

An iOS Swift Playgrounds prototype for practicing cursive handwriting with PencilKit and receiving experimental feedback from Vision and stroke geometry.

Version **1.3** adds interchangeable JSON handwriting guides. **Prototype Cursive** preserves the nine words in three sets: **loop/pool/hello**, **hope/help/peel**, and **heel/hole/pole**. **Stroke Lab** demonstrates a different glyph inventory, separate strokes, guide lines and profiles. Import a guide JSON file for the current session. Examples, replay, thumbnails and geometric comparison consume the selected guide revision; changing guide/profile/lesson clears ink and results. See the [guide contract and examples](docs/guide-format.md).

Version **1.5** grades independent practice without multiplying by trace coverage. Shape, position and height feedback remain, with an excessive-ink check to discourage scribbles. **Replay example** clears ink and previous feedback before replaying. Bundled guides use revision **3**, `geometry-v3`; the original glyph curves are preserved. See [the scoring evidence and limitations](docs/scoring-evidence-1.5.md).

The [1.4-final iPad trial](docs/ipad-prototype-1.4-evaluation.md) confirms improved false-positive behavior and comfortable writing-area positioning, but reports totals below 20% despite useful individual feedback. It motivates 1.5; the new scoring and Replay behavior await another device trial.

The primary **Practice score** compares the selected guide's letter forms without requiring ink to cover the overlay. Showing or hiding the guide never changes the scoring policy. OCR remains a separate recognition check. These are provisional geometric estimates, not validated educational grades, spelling checks or stroke-order judgments. The five-letter model remains provisional; [source research and alignment findings](docs/model-source-assessment.md) describe the selected Zaner-Bloser reference and remaining work.

The user confirmed the refreshed **1.0 baseline** runs and evaluates handwriting on an iPad, while reporting low scores and missing tutorial cues; see [the baseline evaluation](docs/ipad-baseline-evaluation.md). The user subsequently accepted the core 1.1 UI and scoring consistency on the same iPad; the [1.2 trial](docs/ipad-prototype-1.2-evaluation.md) confirms lesson animations and feedback display but reports misleading scores for unrelated ink and careful tracing; scoring remains unresolved; [the 1.1 evaluation](docs/ipad-lesson-1.1-evaluation.md) records the evidence and the still-experimental per-letter analysis.

Sprint scope and acceptance gaps are tracked in [the sprint 119 record](docs/sprint-119.md).

Start with [QUICKSTART.md](QUICKSTART.md). Contribution and verification instructions are in [CONTRIBUTING.md](CONTRIBUTING.md).

## Repository layout

| Path | Purpose |
| --- | --- |
| `CursivePrototype.swiftpm/` | Active, standalone Swift Playgrounds app package, one level below root |
| `CursivePrototype.swiftpm/Guides/` | Bundled versioned guide JSON, including an importable e/ee example |
| `docs/` | Current model/validation reports and historical documents indexed by content hash |
| `specs/` | Plan, roadmap, and design drafts reflecting the user’s next direction and remaining primer alignment work |
| `Tests/` | Analyzer regression tests, compiled with the actual app analyzer source |
| `scripts/` | Build, test, lint, and repository validation entry points |
| `.github/` | CI, CodeQL, Dependabot, and contribution templates |
| `backups/legacy/` | Preserved original sources, scripts, documents, and duplicate packages |

The [primer comparison](docs/primer-decisions.md) and [source-derived letter visual](docs/primer-reference.svg) describe the current model and the user-selected Zaner-Bloser instructional reference. The runtime curves remain provisional pending alignment. The confirmed prototype review bugs and their regression coverage are documented in [docs/review-fixes.md](docs/review-fixes.md).

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

Foundation-only analyzer tests can also run on Linux with `python3 scripts/test-portable.py`. This copies the exact guide loader, lesson models/resources and math/model declarations from the active analyzer; it does not exercise Vision, PencilKit, or the iOS UI and does not replace the simulator suite.
