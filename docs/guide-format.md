# Handwriting guide contract — schema 1

Implemented in prototype 1.3 for CURS-7/CURS-16. The canonical decoder and validator are `HandwritingGuide.swift`. The app reads local JSON resources and session-only imports; it does not download models, train on drawings, or persist imported files.

## Records and coordinates

| Field | Meaning |
| --- | --- |
| `schemaVersion` | Exactly `1`; unsupported versions and unknown fields are rejected |
| `id`, `revision`, `name` | Stable model identity, immutable content revision, display name |
| `style`, `language`, `script`, `direction` | Descriptive identity plus supported direction (`leftToRight` only) |
| `reviewStatus`, `provenance` | Author, license declaration, origin, instructional reference and review notes; declarations are not verified permissions or accreditation |
| `lines` | Top = 0, baseline = 1; `midline` lies between them; `descender` is 1–2; three display labels |
| `profiles` | IDs, names, instructions and assessment parameters; teaching goals/calibration require later review |
| `glyphs` | One Unicode grapheme per symbol, advance, ordered strokes, entry/exit points, instruction |
| `joins` | Explicit ordered pairs of glyph symbols with `continuous` or `lift` mode |
| `lessons` | Stable ID, text, positive set number and instruction |

Each stroke has a `start` point and cubic `curves` with `control1`, `control2`, `end`. Points have finite `x` and `y` numbers. Curves are sampled at 24 intervals, matching the original prototype. Stroke ordering controls replay; the scorer does **not** grade order, speed or correctness of lifts.

All sampled geometry must remain inside its glyph advance and the top/descender lines, allowing only numerical roundoff. Controls may extend 0.5 units beyond those limits. Entry/exit must be the first/last actual endpoints. A continuous connection requires the translated endpoints to coincide. The composer joins only those paths; it leaves internal strokes and lifted connections separate. Missing join rules are rejected. Join observations use the model's entry height, not a universal baseline.

Schema 1 intentionally cannot represent contextual glyph variants, bridging connector curves, deferred marks across a word, overhanging glyphs, right-to-left shaping, vertical writing or multiple lines. Do not encode these as silently ignored extra fields. They require a new supported contract and composer. `language` and `script` identify data; they do not configure Vision recognition or establish language-specific instruction. Phrase/sentence and parent-linked combination lesson kinds remain future work. The small `e`/`ee` example demonstrates geometry composition, not those lesson families.

## Examples and loading

- [Prototype Cursive](../CursivePrototype.swiftpm/Guides/prototype-cursive.json): the original five glyphs and nine words, revision 2; assessment changed, glyph geometry did not.
- [E and EE example](../CursivePrototype.swiftpm/Guides/e-and-ee.example.json): complete importable guide with one existing letter and a two-letter connection.
- [Stroke Lab](../CursivePrototype.swiftpm/Guides/stroke-lab.json): independent project-owned technical model with `x` and `l`, multiple strokes, lifted joins, different lines and two assessment profiles. It is not a curriculum alternative.

Select **Handwriting guide** and **Practice profile** in the app. **Import guide JSON** accepts a complete schema-1 file and selects it only after validation succeeds. Failed imports preserve the current guide, ink and results. Duplicate loaded guide IDs are rejected; use a distinct ID for a comparison draft. Changing guide/profile/lesson clears ink and results. Imports last for the running session. No credentials, network access or publisher assets are needed.

Bundled files live inside `CursivePrototype.swiftpm/Guides/` and are copied as SwiftPM resources. Preserve that folder when transferring the package. `Bundle.main` loads the AppleProductTypes app resources; `Bundle.module` loads standard SwiftPM test resources under the `CURSIVE_TESTS` compilation flag. The iOS build checks the copied files byte-for-byte; the source-derived visual exporter runs the same decoder from the repository root.

## Assessment and identity

`geometry-v1` keeps the baseline formula: 60% symmetric nearest-path shape, 20% vertical placement, 20% height. Profiles supply shape/position/size tolerances and falloffs plus the per-letter falloff. Whole-word fitting preserves aspect ratio; letter windows remain guided estimates, not recognition. Shape/position tolerances use writing-band height units; size uses absolute log height ratio. A narrower profile does not constitute a validated skill level.

`geometry-v2` adds `matchTolerance` (required, finite, 0.005–0.2 writing-band heights; bundled value 0.05). It uses a uniform least-squares extent fit, conservative translation refinement and arc-length support against actual separate polyline edges. Weighted ink support and model coverage multiply the shape/position/height composite. Support is full up to half `matchTolerance`, falls linearly to zero at the full tolerance, and stays zero beyond it. Results add optional `inkNearModel` and `modelCoverage` percentages. See [the 1.4 algorithm and evidence](scoring-evidence-1.4.md). V1 rejects `matchTolerance` rather than ignoring it. Original v1 guides remain importable; older apps reject v2 as unsupported. Schema 1's geometry and shaping capabilities are unchanged.

The lesson holds the guide and profile by value for each analysis. Results serialize model ID/revision, profile ID, algorithm, style and language. These fields remain optional when reading historical reports. A guide editor must bump `revision` when geometry, instructions or assessment settings change; the importer cannot verify an author's revision history.

No profile repairs the known false positives in `geometry-v1`. See [historical scoring evidence](scoring-evidence-1.3.md). V2 reduces the tested synthetic failures; iPad calibration remains open. Learned models and font capture need separate consent, provenance, revision and export designs before implementation.

## Validation limits and checks

Imports read at most 1 MB plus one overflow byte. Limits are 256 glyphs, 8 strokes per glyph, 64 curves per stroke, 16 profiles, 4,096 joins, 128 lessons, 32 graphemes per lesson, 65,536 sampled points per guide and 16,384 per lesson. Positive advances, visible stroke length, lesson vertical extent, unique IDs/symbols, supported algorithms, bounded tolerances, required fields, nonblank guide labels/profile names/instructions and complete lesson coverage are checked before use.

Run `python3 scripts/test-portable.py` for malformed models, new glyph inventory, lifted and raised connections, profile identity, serialization and baseline comparison. `./scripts/test.sh` additionally covers Apple frameworks. `python3 scripts/export-primer.py --check` verifies the five-letter visual against the loaded model. UI import, selection, replay and device scoring still require the [iPad checklist](device-validation.md).
