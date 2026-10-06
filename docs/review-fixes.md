# Prototype review fixes

The eight findings on PR #1 were confirmed in the original source. The fixes apply to the active root-level package. Original duplicate sources are preserved unchanged under `backups/legacy/`, excluded from app builds, and checked by their SHA-256 manifest.

| Finding | Corrected behavior | Regression evidence |
| --- | --- | --- |
| Recognition scored against itself | Minimum-edit alignment compares recognized characters with `targetText`, chooses templates by the expected character, and includes missing/extra characters in the overall score | `testTargetAlignmentScoresSubstitutionAgainstExpectedCharacter`, `testTargetAlignmentRetainsMissingAndExtraCharacters`, `testTemplateLookupUsesExpectedCharacter` |
| Cropped image boxes mixed with drawing coordinates | A single conversion applies crop offsets and the Vision bottom-left to drawing top-left Y flip. Public report boxes are crop-relative normalized rectangles | `testVisionBoxConvertsCropOffsetAndFlippedYAxis`, `testContinuousStrokeIsSplitAcrossFourCharactersAwayFromOrigin` |
| Whole words reported as letters | Vision character-range boxes generate individual anchors. Line clipping partitions continuous strokes, including crossings with no sampled points inside a character box | `testFastVisionRecognitionProducesPerCharacterAnchors`, `testContinuousStrokeIsSplitAcrossFourCharactersAwayFromOrigin`, `testStrokeClippingPreservesUnknownInkAndAvoidsDuplicateAssignment` |
| Duplicate SwiftUI row identifiers | Feedback rows use occurrence indices rather than letter text | `testRepeatedLettersAndUnknownRowsHaveDistinctOccurrenceIDs` |
| Old reports hide empty-input and analysis errors | Evaluation resets old results before the empty-input guard; failure also clears report and recognized text | `testEvaluationClearsSuccessfulReportBeforeEmptyGuardAndFailure` |
| Normalization distorts physical slant | Slant is measured on drawing-space points; shape comparison still uses normalized points | `testPhysicalSlantIsNotMeasuredAfterAnisotropicNormalization` |
| Proportions mix normalized and drawing units | Letter height and baseline metrics both use drawing coordinates | `testProportionsUseDrawingUnitsAndAreTranslationInvariant` |
| Stroke transforms ignored | Stroke extraction applies each PencilKit stroke's affine transform | `testStrokeExtractionAppliesTranslationScalingAndRotation` |

## Vision precision and remaining limits

Apple documents that `.accurate` recognition returns word-level boxes even for individual character ranges, while `.fast` provides character-level boxes. The prototype now uses `.fast` and asks for each non-whitespace character's range. Missing character boxes use an explicitly heuristic equal-width fallback. [Apple: boundingBox(for:)](https://developer.apple.com/documentation/vision/vnrecognizedtext/boundingbox(for:))

These fixes do not validate cursive OCR, educational scores, or exact letter boundaries. Character boxes are approximate; unknown ink remains explicit, overlapping boxes assign each path interval once, and this lesson assumes a single left-to-right writing line. Timing remains a fixed placeholder and teacher templates still need registration. PencilKit masks and handwritten multi-line reading order need separate work.

## Checks

`python3 scripts/test-portable.py` runs 17 Foundation-only tests. `./scripts/test.sh` runs those tests plus two Apple-framework integration tests on an iOS simulator. App compilation and the simulator suite must pass in CI before merging. Actual iPad/Apple Pencil checks remain separate in `device-validation.md`.
