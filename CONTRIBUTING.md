# Contributing

Create a focused branch from current `main`. Until prototype PR #1 and the repository setup land, changes that depend on the prototype must include that branch or be stacked on it; state the dependency in the PR.

The active app is `CursivePrototype.swiftpm`. Preserve the standalone Playgrounds package and iOS 16 minimum unless a change explicitly calls for updating them. Keep historical files under `backups/legacy/` unchanged. Put unique reference documents in `docs/`; future accepted plans belong in `specs/`.

## Before submitting

```sh
./scripts/lint.sh
./scripts/build.sh
./scripts/test.sh
python3 scripts/check_repository.py
```

Swift's formatter is the enforced lint tool. Format only active Swift sources and tests. Add regression coverage when changing analyzer behavior. Tests append the unmodified analyzer source and test code into a temporary test target, allowing coverage of its file-private helpers without changing the app's public API or introducing app dependencies. This is an initial harness; move to a shared core when architecture work warrants it.

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

Foundation-only analyzer tests can also run on Linux with `python3 scripts/test-portable.py`. This copies the exact math/model declarations from the active analyzer; it does not exercise Vision, PencilKit, or the iOS UI and does not replace the simulator suite.
