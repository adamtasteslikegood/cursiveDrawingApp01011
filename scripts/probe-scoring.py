#!/usr/bin/env python3
"""Reproduce synthetic scoring counterexamples with exact app math (not device ink)."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline', help='Local Git revision of the 1.2 PracticeLesson.swift for comparison')
args = parser.parse_args()
model = ROOT / 'CursivePrototype.swiftpm/PracticeLesson.swift'
if args.baseline:
    source = subprocess.check_output(['git', 'show', f'{args.baseline}:CursivePrototype.swiftpm/PracticeLesson.swift'], cwd=ROOT, text=True)
else:
    source = (ROOT / 'CursivePrototype.swiftpm/HandwritingGuide.swift').read_text() + '\n' + model.read_text()
source += '\n' + (ROOT / 'Tests/ScoringFixtures.swift').read_text()
source += r'''
var records: [[String: Any]] = []
for lesson in PracticeLesson.all {
  let guide = WritingGuide(size: CGSize(width: 700, height: 320), wordWidth: lesson.width)
  for (name, strokes) in ScoringFixtures.cases(lesson: lesson, guide: guide) {
    let score = LessonScorer.evaluate(strokes: strokes, lesson: lesson, guide: guide)
    records.append(["word": lesson.word, "probe": name, "score": score.score,
      "shape": score.shape, "placement": score.placement, "height": score.size])
  }
}
print(String(data: try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
'''
with tempfile.TemporaryDirectory(prefix='cursive-score-') as temporary:
    path = Path(temporary) / 'main.swift'
    path.write_text(source)
    records = json.loads(subprocess.check_output(['swift', str(path)], cwd=ROOT, text=True))
print(json.dumps(records, indent=2, sort_keys=True))
