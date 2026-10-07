#!/usr/bin/env python3
"""Validate package layout and byte-for-byte historical document preservation."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    required = [
        'README.md', 'QUICKSTART.md', 'CONTRIBUTING.md', 'LICENSE', 'AGENTS.md',
        'specs/README.md', 'specs/plan.md', 'specs/roadmap.md', 'specs/design.md',
        'docs/primer-reference.svg', 'docs/primer-decisions.md', 'scripts/export-primer.py', 'CursivePrototype.swiftpm/Package.swift',
        'CursivePrototype.swiftpm/MyApp.swift', 'CursivePrototype.swiftpm/ContentView.swift',
        'CursivePrototype.swiftpm/CursiveAnalyzer.swift', 'CursivePrototype.swiftpm/LinedPaper.swift',
        'CursivePrototype.swiftpm/EvaluationState.swift', 'CursivePrototype.swiftpm/PracticeLesson.swift',
        '.github/workflows/ci.yml', '.github/workflows/codeql.yml', '.github/dependabot.yml',
    ]
    for relative in required:
        assert (ROOT / relative).is_file(), f'Missing {relative}'
    for old in ['OtherFiles', 'SwiftPlaygroundALPHA011', 'swfitopplaygrtoundppp', 'Skip to content.md']:
        assert not (ROOT / old).exists(), f'Legacy path still at root: {old}'
    for entry in json.loads((ROOT / 'backups/legacy/file-manifest.json').read_text()):
        assert digest(ROOT / entry['archived']) == entry['sha256'], f'Archive changed: {entry["archived"]}'
    documents = json.loads((ROOT / 'docs/document-index.json').read_text())
    seen = set()
    for entry in documents:
        assert entry['sha256'] not in seen, f'Duplicate canonical document: {entry["canonical"]}'
        seen.add(entry['sha256'])
        for relative in [entry['canonical'], *entry['originals']]:
            assert digest(ROOT / relative) == entry['sha256'], f'Document changed: {relative}'
    assert 'MIT License' in (ROOT / 'LICENSE').read_text(), 'Missing MIT license'
    assert '.iOSApplication(' in (ROOT / 'CursivePrototype.swiftpm/Package.swift').read_text()
    print(f'Repository integrity passed: {len(documents)} unique documents and preserved legacy files.')


if __name__ == '__main__':
    main()
