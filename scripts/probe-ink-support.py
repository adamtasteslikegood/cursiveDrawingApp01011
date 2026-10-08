#!/usr/bin/env python3
"""Explore current guide/profile ink support with synthetic paths, never personal drawings."""
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
source = '\n'.join((ROOT / name).read_text() for name in [
    'CursivePrototype.swiftpm/HandwritingGuide.swift',
    'CursivePrototype.swiftpm/PracticeLesson.swift',
    'Tests/ScoringFixtures.swift', 'Tests/InkSupportFixtures.swift',
])
source += r'''
var records: [[String: Any]] = []
for model in GuideLibrary.all {
  for profile in model.profiles {
    for lesson in PracticeLesson.lessons(in: model, profile: profile) {
      let guide = WritingGuide(size: CGSize(width: 700, height: 320), wordWidth: lesson.width, lines: model.lines)
      for (name, strokes) in InkSupportFixtures.cases(lesson: lesson, guide: guide) {
        let result = LessonScorer.evaluate(strokes: strokes, lesson: lesson, guide: guide)
        records.append(["guide": model.id, "revision": model.revision, "profile": profile.id,
          "algorithm": profile.assessment.algorithm, "word": lesson.word, "probe": name,
          "score": result.score, "shape": result.shape, "placement": result.placement,
          "height": result.size, "inkNearModel": result.inkNearModel.map { $0 as Any } ?? NSNull(),
          "modelCoverage": result.modelCoverage.map { $0 as Any } ?? NSNull()])
      }
    }
  }
}
print(String(data: try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
'''
with tempfile.TemporaryDirectory(prefix='cursive-ink-support-') as directory:
    path = Path(directory) / 'main.swift'
    path.write_text(source)
    records = json.loads(subprocess.check_output(['swift', str(path)], cwd=ROOT, text=True))
print(json.dumps({
    'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
    'tracked_changes': bool(subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=ROOT, text=True)),
    'canvas': {'width': 700, 'height': 320}, 'synthetic_only': True, 'records': records,
}, indent=2, sort_keys=True))
