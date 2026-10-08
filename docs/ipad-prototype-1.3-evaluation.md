# Prototype 1.3 iPad evaluation

Owner report received 2026-10-07. Recorded on [PR #6 before its merge](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/pull/6#issuecomment-6052107557). This report is separate from the [1.2 trial](ipad-prototype-1.2-evaluation.md).

## Device and delivery

- 13-inch iPad Pro M4, 512 GB; iPadOS 27.2; Apple Pencil Pro.
- Owner identifies the delivered `guide-foundation-1.3` CursivePrototype package.
- Delivery source: `a2a46acef78c8985597f39654b3c8abb421eb98b`; visible revision supplied with that delivery: `Lesson prototype 1.3 · 2026-10-07`.
- Delivered ZIP SHA-256: `dc5aebf17ec8832a4f6d80550fc4312b4ed4c9f6297aa8459b4155651b0e5bfe`.
- Swift Playgrounds version was not reconfirmed in this report; previously reported as 4.7 (2088). Exact on-device file hash and label were not independently checked.

## Reported results

| Observation | Interpretation |
| --- | --- |
| Tracing the example reaches approximately 98% and other high scores | Positive tracing evidence for 1.3; the earlier ceiling was not reproduced in this trial |
| Scribbling across the test area still scores approximately 75% | False-positive defect remains; [CURS-20](https://tasteslikegood.atlassian.net/browse/CURS-20) is unresolved |
| Stroke Lab works with two modes | Partial acceptance of the second guide/profile experience; no detailed stroke-by-stroke checklist was supplied |
| Writing area is constrained near the bottom before evaluation | Owner reports discomfort and insufficient scroll range |
| Expanded feedback permits centering, but the next lesson clears it and removes the extra scroll range | Scroll availability depends on feedback content; track as [CURS-24](https://tasteslikegood.atlassian.net/browse/CURS-24) |

The owner recalls the writing area being easier to position in 1.1 and 1.2, even if that flexibility was an unintended consequence of earlier UI behavior. The owner authorizes merging 1.3, then fixing positioning and continuing stroke/model development.

No exact word, guide/profile, orientation, component scores, OCR transcript, personal drawing, import cases or full checklist results were supplied. Do not infer that those checks passed. The reported high tracing score does not establish the cause of [CURS-21](https://tasteslikegood.atlassian.net/browse/CURS-21), validate the scoring formula, or establish Zaner-Bloser model alignment.

## Positioning follow-up: 1.3.1

The outer lesson page now reserves bottom space equal to half the difference between viewport height and paper height, clamped at zero. This gives the paper enough travel to reach the viewport center without needing an evaluation. Clear and lesson/guide/profile changes can still remove stale results without removing that minimum scroll space. The space adapts when the viewport changes size.

The PencilKit canvas retains its size and fixed drawing coordinates; the whole page scrolls. The patch keeps scoring formulas, guide data and original model curves unchanged. Physical comfort, gesture behavior and rotation/Split View still require the [1.3.1 device checks](device-validation.md#writing-area-positioning-131).

For the next analysis/model iteration, use paired tracing and unrelated-ink probes against the same guide/profile before changing score weights. Keep the current synthetic baseline as historical characterization. Develop any replacement scoring method under a new version with separate tests for positive traces, extra ink, incomplete strokes and separate paths; keep model alignment and stroke-order claims tied to explicit guide data and reviewed evidence.
