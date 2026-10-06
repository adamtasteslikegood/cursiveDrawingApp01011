# Guided lesson 1.1 iPad evaluation — 2026-10-06

## Evaluated iteration

The delivered `CursivePrototype.zip` came from CI run 37421366639, artifact `CursivePrototype-412cfa2cf9907284dfea2a0f900e3d8078e1dfeb`. All seven Swift sources were verified against PR #4 head `0a77e7984570048eb3112644b015f906595ee347`. The visible lesson revision is `Lesson prototype 1.1 · 2026-10-05`.

The user confirms the same 13-inch iPad Pro M4 (512 GB Wi-Fi), reported iPadOS 27.2, and Apple Pencil Pro as the baseline trial. Swift Playgrounds 4.7 (2088) was reported for the baseline; its version was not separately reconfirmed for this trial.

## User report

- Ghost animation works.
- Scores reflect proximity to the example. Tracing produces approximately 92% or higher without effort, and scoring is consistent across trials.
- Other UI features work as expected. Trace guide toggles the ghost overlay on/off.
- Replay works regardless of the toggle's previous state and correctly turns the toggle on before animating; the user considers this useful behavior.
- Experimental per-letter feedback renders one row for each letter in all three lessons, but advanced per-letter analysis remains work in progress.

The user accepts the current prototype's systems as working, with advanced per-letter analysis explicitly excepted. This is device evidence for the reported behaviors and scoring consistency, not validation of educational accuracy or every unreported checklist case.

## Requested next direction

Frame the primary primer/style decision and preserve the possibility of multiple primers. Prototype advanced per-letter analysis and expand to a second and third set of single-word lessons. Later lesson types should include phrases, sentences, single letters, and two-or-more-letter linking combinations offered as sub-lessons of words containing those combinations.

The current hand-authored examples are illustrative. No accredited educational source, validated stroke order, or calibrated per-letter scoring is implied by this successful UI evaluation.
