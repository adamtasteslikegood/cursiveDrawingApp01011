# Contributing

Create a focused branch from current `main`; the prototype and repository setup are merged. State any new PR dependency explicitly.

The active app is `CursivePrototype.swiftpm`. Preserve the standalone Playgrounds package and iOS 16 minimum unless a change explicitly calls for updating them. Keep historical files under `backups/legacy/` unchanged. Put unique reference documents in `docs/`; future accepted plans belong in `specs/`.

## Before submitting

```sh
./scripts/lint.sh
./scripts/build.sh
./scripts/test.sh
python3 scripts/check_repository.py
```

Swift's formatter is the enforced lint tool. Lint also checks the source-derived primer SVG; regenerate it with `python3 scripts/export-primer.py` if model paths change. Format only active Swift sources and tests. Add regression coverage when changing analyzer behavior. Tests append the unmodified guide, lesson-model, analyzer, and evaluation-state sources and test code into a temporary test target, allowing coverage of its file-private helpers without changing the app's public API or introducing app dependencies. The harness copies the same bundled guide resources and baseline fixtures. This is an initial harness; move to a shared core when architecture work warrants it.

Use the PR template, explain the user-visible change, and report exactly which checks ran. Include screenshots and the [device checklist](docs/device-validation.md) for UI changes. Linux checks do not establish iOS build or iPad acceptance.

## Workflows

- **CI / repository**: checks preserved-file hashes and repository structure.
- **CI / iOS**: checks formatting, builds the app, runs simulator regression tests, and uploads a standalone playground ZIP and test results.
- **CodeQL / Swift**: analyzes the active app using a manual generic-iOS build.
- **CodeQL / Actions**: analyzes automation configuration.
- Dependabot opens weekly action-version updates. Add a Swift dependency update entry if external package dependencies are introduced.

CodeQL uses advanced setup. GitHub default setup must remain disabled because it rejects uploads from the custom workflow.

Maintainers should configure required checks after their first successful runs. Workflow files do not enforce branch protection themselves. Never commit credentials, personal drawings, or generated Xcode/Playgrounds state.

The project is MIT licensed. Submit only code and documents you have permission to contribute.

For the CURS-1 delivery loop, use the [charter](specs/curs-1-charter.md), tracked templates in `specs/harness/` and [harness instructions](docs/curs-1-harness.md). Prepare a fresh run with `scripts/prepare-curs-1-harness.py`; generated state and Jira/Confluence snapshots belong in ignored `.agent-harness/`. Freeze verifier checks before initialization, resume from the controller state, and require actual Jira In Review plus an open PR or evidenced Done. This delivery endpoint does not accept unresolved device or curriculum requirements.

Foundation-only analyzer tests can also run on Linux with `python3 scripts/test-portable.py`. This copies the exact lesson models and math/model declarations from the active analyzer; it does not exercise Vision, PencilKit, or the iOS UI and does not replace the simulator suite.

Keep primer identity/revision, guides, rendering, and comparison models consistent. The current five-letter primer is provisional; consult `docs/primer-decisions.md` and the drafts in `specs/` when aligning models with the user-selected Zaner-Bloser reference or adding lesson kinds.

Guide changes must pass `HandwritingGuide.decode` validation and retain source/review provenance. Bump a model revision for changed content; do not relabel the provisional curves as a publisher model. Keep `Guides/` in the standalone package. See [schema and examples](docs/guide-format.md). Run `python3 scripts/probe-scoring.py` for component-level synthetic diagnostics. Baseline regression fixtures deliberately record the known false positives; they preserve migration behavior and are not calibration targets.

Run `python3 scripts/probe-ink-support.py` for current positives and negatives across both bundled guides and all profiles. `Tests/InkSupportFixtures.swift` is shared by that probe and both test harnesses. Use `--algorithm geometry-v2` to compare the retained 1.4 behavior on the same cases. Preserve `geometry-v1` fixture values and v2 behavioral compatibility tests when changing newer algorithms. Include independently varied shapes alongside exact traces. Matching tolerances and synthetic thresholds are engineering choices awaiting physical/educational review; include paired trace and unrelated-ink evidence for scoring changes.
