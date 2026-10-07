#!/usr/bin/env python3
"""Render the supported alphabet directly from active model points; no publisher assets."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true', help='Fail if the committed visual differs from the model')
args = parser.parse_args()
source = (ROOT / 'CursivePrototype.swiftpm/PracticeLesson.swift').read_text()
source += r'''
let symbols = Set(PracticeLesson.all.flatMap { Array($0.word) }).sorted()
let export = symbols.map { symbol -> [String: Any] in
  let model = PracticeLesson(word: String(symbol), focus: "Model export")
  return ["letter": model.word, "width": Double(model.width),
          "points": model.modelPoints.map { [Double($0.x), Double($0.y)] }]
}
print(String(data: try JSONSerialization.data(withJSONObject: export), encoding: .utf8)!)
'''
with tempfile.TemporaryDirectory(prefix='cursive-primer-') as temporary:
    path = Path(temporary) / 'main.swift'
    path.write_text(source)
    models = json.loads(subprocess.check_output(['swift', str(path)], text=True))
width = 150 * len(models) + 40
parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="235" viewBox="0 0 {width} 235">',
         '<rect width="100%" height="100%" fill="white"/>',
         '<text x="20" y="24" font-family="sans-serif" font-size="16">Prototype primer v1: supported lowercase models (educational review pending)</text>']
for index, model in enumerate(models):
    x, y = 30 + index*150, 65
    parts.append(f'<text x="{x}" y="50" font-family="sans-serif" font-size="20">{model["letter"]}</text>')
    parts.append(f'<rect x="{x}" y="{y+40}" width="125" height="40" fill="#eff6ff"/>')
    for line in [0,80]:
        parts.append(f'<path d="M{x} {y+line} h125" stroke="#3b82f6"/>')
    parts.append(f'<path d="M{x} {y+40} h125" stroke="#3b82f6" stroke-dasharray="7 5"/>')
    points = ' '.join(f'{x+px*80:.3f},{y+py*80:.3f}' for px,py in model['points'])
    parts.append(f'<polyline points="{points}" stroke="#2563eb" stroke-width="2.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
    parts.append(f'<circle cx="{x}" cy="{y+80}" r="3" fill="#16a34a"/>')
    parts.append(f'<circle cx="{x+model["width"]*80:.3f}" cy="{y+80}" r="3" fill="#475569"/>')
parts += ['<text x="20" y="211" font-family="sans-serif" font-size="12">Green: encoded entry. Gray: encoded exit. Paths show the project model, not accredited stroke instruction.</text>', '</svg>']
rendered = '\n'.join(parts)+'\n'
target = ROOT / 'docs/primer-reference.svg'
if args.check:
    if not target.exists() or target.read_text() != rendered:
        raise SystemExit('Primer visual differs from active models; run python3 scripts/export-primer.py')
    print('Primer visual matches the active model points.')
else:
    target.write_text(rendered)
    print(target)
