# Prototype 1.4-final iPad evaluation

Owner report received 2026-10-08, for the `ink-support-1.4-final` delivery. Source: `ab42d59ccba215bc3129131c82c678fc90bc836c`; visible label `Lesson prototype 1.4 · 2026-10-07`; guide revision 2, `geometry-v2`. Delivered ZIP SHA-256: `b17b5e12f0f03ab09a14505ce5f0a400f6fa7e3292288c27471334b8ffb35b3c`. The on-device file hash was not independently checked.

## Device

13-inch iPad Pro M4, 512 GB, **iPadOS 27.3**, Apple Pencil Pro. Swift Playgrounds version was not reconfirmed (previously 4.7, build 2088). The OS version differs from the earlier 27.2 reports.

## Owner observations

- False positives are no longer a problem in this trial.
- In Stroke Lab, **Precise geometry** feels like the more realistic evaluator.
- Individual analyzer feedback seems right, but the overall score is consistently **below 20%**.
- Grading appears to emphasize covering the traceable example. The owner wants learners to practice and test without the overlay, with no trace-coverage component in the grade.
- The writing area can now be centered comfortably; otherwise the UI works well.
- **Replay example should clear the testing area.** The follow-up also resets previous feedback so it cannot describe erased ink.

The report does not specify target words, per-attempt profile, exact component values, orientation, or whether each low score occurred during tracing or independent writing. No personal drawings were supplied. Do not infer a complete device-checklist pass, or verified recognition, curriculum alignment, educational calibration, or timing/stroke-order grading.

## Engineering interpretation and follow-up

Source inspection confirms that overlay visibility does not enter scoring. In 1.4, however, the shape/position/height composite is multiplied by both near-exact ink support and model coverage. Smooth synthetic variations reproduce low totals despite high shape components; this is evidence of formula sensitivity, not a reconstruction of the owner's drawing.

[CURS-25](https://tasteslikegood.atlassian.net/browse/CURS-25) tracks independent practice scoring while retaining scribble regressions. [CURS-26](https://tasteslikegood.atlassian.net/browse/CURS-26) tracks Replay clearing. The positive false-positive and centering observations are recorded on CURS-20 and CURS-24; CURS-21's earlier tracing complaint remains distinct. The preference for Precise geometry is recorded without changing all guides to that profile.

See [the 1.5 implementation and validation](scoring-evidence-1.5.md). New scoring and Replay behavior still require a new device trial; this report accepts only the behavior observed in 1.4-final.
