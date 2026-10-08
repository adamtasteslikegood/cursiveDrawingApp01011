# Prototype 1.5 iPad evaluation

Owner report received 2026-10-08. The owner confirms that **1.5 runs**, is **a better grader than 1.4**, and that **Replay clears the testing area**. The owner explicitly requests recording this evaluation and merging the open PRs.

## Device and delivered version

- Same hardware/software setup as the previous evaluations: 13-inch iPad Pro M4, 512 GB, Apple Pencil Pro. The most recently stated OS is **iPadOS 27.3**, from the 1.4-final report.
- Swift Playgrounds was previously reported as **4.7 (2088)**. This report says the setup is unchanged; it does not independently restate each version number.
- Delivered package: `dist/independent-practice-1.5/CursivePrototype.zip`.
- Source: `be4f74e6261a2c9cb630631a37cb32bab667e5af`; delivery label: **Lesson prototype 1.5 · 2026-10-08**; bundle version 7; bundled guide revision 3, `geometry-v3`.
- Delivered ZIP SHA-256: `65235f227be140806f0be4b3a994e3e6b14cf1c5b4badbbf7e9c2cd23b1f34b8`. The package was checked against all 11 committed app/resource files before delivery; the on-device file hash was not independently checked.

## Acceptance and limits

| Owner observation | Recorded outcome |
| --- | --- |
| 1.5 runs on the same setup | Positive physical-device execution evidence |
| Grading is better than 1.4 | Qualitative acceptance of the independent-practice scoring improvement, tracked in CURS-25 |
| Replay clears the testing area | Physical confirmation of the requested ink-clearing behavior, tracked in CURS-26 |
| Add the evaluation and merge open PRs | Approval to merge PR #7 and PR #8 after checking their current automated results and review state |

No exact scores, per-attempt target/profile, orientation, timing measurements, or fresh paired tracing/freehand/scribble results were supplied. The earlier 1.4-final report separately confirmed improved false positives and comfortable centering. Do not convert this qualitative 1.5 report into a full device-checklist pass, numerical calibration claim, or evidence of independent recognition, stroke-order grading or Zaner-Bloser model alignment.

## Engineering evidence for the evaluated app

- [CI 37757735744](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/actions/runs/37757735744): macOS iOS build, bundled resources, and **66 simulator tests** passed.
- [CodeQL 37757735791](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/actions/runs/37757735791): Swift and Actions passed with zero findings on merge commit `0e9542170c904969fca2a73425620f571a4ca0f3`.
- Repository integrity, Swift lint and **61 portable tests** passed before delivery. Linux checks do not replace the Apple build or this owner evaluation.
- This acceptance update changes documentation only; the evaluated app, tests, scripts and guide geometry are preserved. PR checks for the documentation commit are reviewed separately before merging.

See [the 1.5 scoring formula and synthetic evidence](scoring-evidence-1.5.md), [the preceding 1.4-final evaluation](ipad-prototype-1.4-evaluation.md), and [remaining device checks](device-validation.md#independent-practice-and-replay-15).
