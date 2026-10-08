#!/usr/bin/env python3
"""Supplemental Foundation-only tests; does not validate the Apple app integration."""
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
source = (ROOT / 'CursivePrototype.swiftpm/CursiveAnalyzer.swift').read_text()
# Copy exact declarations. Missing boundaries deliberately fail rather than silently skipping tests.
boundaries = [
    ('struct LetterReport', '/// Main analyzer entrypoint'),
    ('private struct Preprocessor', '// MARK: - Vision helpers'),
]
parts = ['import Foundation\n', (ROOT / 'CursivePrototype.swiftpm/HandwritingGuide.swift').read_text(), (ROOT / 'CursivePrototype.swiftpm/PracticeLesson.swift').read_text()]
for start, end in boundaries:
    first = source.index(start)
    last = source.index(end, first)
    parts.append(source[first:last])
harness = ROOT / '.build/portable-tests'
tests = harness / 'Tests/AnalyzerTests'
tests.mkdir(parents=True, exist_ok=True)
(tests / 'AnalyzerTests.swift').write_text(
    '\n'.join(parts) + (ROOT / 'CursivePrototype.swiftpm/EvaluationState.swift').read_text() + (ROOT / 'Tests/ScoringFixtures.swift').read_text() + (ROOT / 'Tests/AnalyzerTests.swift').read_text())
shutil.rmtree(tests / 'Guides', ignore_errors=True)
shutil.rmtree(tests / 'Fixtures', ignore_errors=True)
shutil.copytree(ROOT / 'CursivePrototype.swiftpm/Guides', tests / 'Guides', dirs_exist_ok=True)
shutil.copytree(ROOT / 'Tests/Fixtures', tests / 'Fixtures', dirs_exist_ok=True)
shutil.copy(ROOT / 'Tests/Package.swift', harness / 'Package.swift')
subprocess.run(['swift', 'test', '--package-path', str(harness)], check=True)
