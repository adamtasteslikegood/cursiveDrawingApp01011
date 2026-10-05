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
    ('private struct BaselineInfo', 'private struct BaselineDetector'),
    ('private struct Segment {', 'private struct Segmenter {'),
    ('private struct DTW', '// MARK: - Vision helpers'),
]
parts = ['import Foundation\n']
for start, end in boundaries:
    first = source.index(start)
    last = source.index(end, first)
    parts.append(source[first:last])
harness = ROOT / '.build/portable-tests'
tests = harness / 'Tests/AnalyzerTests'
tests.mkdir(parents=True, exist_ok=True)
(tests / 'AnalyzerTests.swift').write_text(
    '\n'.join(parts) + (ROOT / 'Tests/AnalyzerTests.swift').read_text())
shutil.copy(ROOT / 'Tests/Package.swift', harness / 'Package.swift')
subprocess.run(['swift', 'test', '--package-path', str(harness)], check=True)
