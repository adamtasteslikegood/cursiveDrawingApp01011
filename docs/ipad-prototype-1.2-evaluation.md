# Prototype 1.2 iPad evaluation — 2026-10-06

## Reported setup and iteration

The user reports testing prototype 1.2 on the same 13-inch iPad Pro M4 and Apple Pencil Pro. The earlier setup was 512 GB Wi-Fi, reported iPadOS 27.2, Swift Playgrounds 4.7 (2088). OS and Playgrounds versions were not separately reconfirmed in this report.

Reference delivery: `dist/lessons-1.2/CursivePrototype.zip`, with all seven Swift files verified against `8d486df8a557ec74b1e4cedfd3444747a78ce711` when delivered. The device's exact file/commit was not independently rechecked; the user identifies the tested iteration as 1.2.

## User observations

- All three sets of three words appear and animate.
- Per-letter feedback is present. This confirms display, not its numerical or educational accuracy.
- After several attempts, scribbling, gibberish, and unrelated words (including profanity) appeared to receive around **70%**.
- Even careful tracing of the displayed guide did not exceed approximately **85%** in the reported trials.

These are reported observations, not a controlled reproduction or established score ceiling. No drawings, component-score breakdowns, or per-attempt state traces were supplied. Do not attribute the behavior to caching, a particular formula, OCR, or state retention without reproducing it. Profanity is relevant as unrelated target content; this finding does not request content filtering.

## Acceptance assessment

Lesson presentation, animation, and feedback display work in the reported trial. **Scoring remains unresolved:** unrelated ink receives misleadingly high matches and careful tracing appears under-rewarded. Do not mark all 1.2 systems accepted or interpret its percentage as writing correctness/mastery. The previously accepted 1.1 report remains historical evidence, not a rebuttal of this trial.

## User-directed next work

Create or locate a technical style-guide model, starting with the selected Zaner-Bloser reference. The app must consume interchangeable guides rather than hardcoding one style. Guides should support different writing styles, skill levels, languages, and glyph sets. Future capabilities include learning a user's style to personalize teaching and capturing penmanship for custom fonts. These capabilities are requirements to design for, not existing implementation.

Record the scoring findings in regression work and compare exact reference paths, guided tracing, unrelated words, dense scribbles, repeated attempts, and input reset behavior. Establish expected outcomes from reviewed samples before choosing numeric thresholds. Build guide-specific instruction and evaluation from a consistent, versioned source. See [design](../specs/design.md) and [plan](../specs/plan.md).

## Sprint 119 acceptance follow-up — 2026-10-07

PR #5 was merged with this report preserved. CURS-17 records the available 1.2 evidence; it does not certify every device-checklist item. Exact device artifact, current OS/Playgrounds, partial erasure, join accuracy, local distortion and detailed reset/repeated-attempt sequences remain unreported. The prior 1.1 replay/toggle success is not automatically a new 1.2 result.

Synthetic scoring reproduction is now documented in [the 1.3 investigation](scoring-evidence-1.3.md). It corroborates false positives under controlled inputs without explaining the device's apparent tracing ceiling. A fresh [1.3 device trial](device-validation.md#guide-foundation-13--new-device-evidence-required) must identify the new guide/revision/profile.
