#!/usr/bin/env python3
"""Behavioral preparation regressions, isolated from real harness state.

Run the actual preparation CLI in disposable repositories. A small governance
CLI fixture records its serialized input and models documented plan acceptance;
the tests require no installed plugins. Failure injection remains at subprocess
boundaries while resolution, hashing and filesystem effects execute normally.
"""

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="curs-1-preparation-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.run = self.root / ".agent-harness"
        self.pm = self.root / "plugins/pm skills"
        self.harness = self.root / "plugins/agent-harness"
        self.manifest = self.root / "specs/harness/curs-1-manifest.json"
        self.plan = self.root / "specs/harness/curs-1-plan.json"
        for relative in (
            "scripts/prepare-curs-1-harness.py", "scripts/check_repository.py",
            "scripts/lint.sh", "scripts/test-portable.py", "docs/curs-1-harness.md",
            "specs/harness/curs-1-manifest.json", "specs/harness/curs-1-plan.json",
        ):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        for name in ("pm-skills", "confluence-expert", "jira-expert"):
            directory = self.pm / name
            directory.mkdir(parents=True)
            (directory / "SKILL.md").write_text(f"# {name}\n", encoding="utf-8")
        (self.pm / "pm-skills/scripts").mkdir()
        self.harness.mkdir(parents=True)
        (self.harness / "SKILL.md").write_text("# Agent harness\n", encoding="utf-8")
        (self.harness / "scripts").mkdir()
        (self.harness / "scripts/loop_controller.py").write_text("# Not initialized by these tests\n", encoding="utf-8")
        # The external gate records its input and models its ownership/reviewer/
        # executable acceptance contract. It does not do production resolution.
        (self.pm / "pm-skills/scripts/delivery_loop_gate.py").write_text(
            "import json, pathlib, sys\n"
            "root = pathlib.Path.cwd()\n"
            "plan = pathlib.Path(sys.argv[sys.argv.index('--plan') + 1])\n"
            "raw = plan.read_text(encoding='utf-8')\n"
            "value = json.loads(raw)\n"
            "runtime = [p.name for p in (root / '.agent-harness').glob('curs-1-*')]\n"
            "(root / 'governance-observed.json').write_text(json.dumps({'raw':raw, 'runtime':runtime}))\n"
            "if (root / 'race-before-write').exists():\n"
            "    directory = root / '.agent-harness'\n"
            "    directory.mkdir(exist_ok=True)\n"
            "    (directory / 'curs-1-manifest.json').write_text('other attempt')\n"
            "tasks = value.get('tasks', [])\n"
            "invalid = not tasks or any(not t.get('owner') or not t.get('reviewer') or not t.get('acceptance', {}).get('cmd') for t in tasks)\n"
            "print(json.dumps({'verdict':'PLAN-BLOCKED' if invalid else 'PLAN-OK'}))\n"
            "sys.exit(2 if invalid else 0)\n",
            encoding="utf-8")
        # The local verifier's full suite runs separately in CI. At this slow
        # subprocess boundary the fixture checks actual frozen file hashes,
        # with selected final failures after preparation has written files.
        (self.root / "scripts/check_curs_1_delivery.py").write_text(
            "import hashlib, json, pathlib, sys\n"
            "root = pathlib.Path(__file__).resolve().parent.parent\n"
            "fault = root / 'lock-check-fault'\n"
            "if '--check-lock' in sys.argv and fault.exists():\n"
            "    directory = root / '.agent-harness'\n"
            "    mode = fault.read_text()\n"
            "    if mode == 'initialized':\n"
            "        (directory / 'curs-1-state.json').write_text('{\"status\":\"open\"}')\n"
            "    if mode == 'replaced':\n"
            "        replacement = directory / 'replacement.json'\n"
            "        replacement.write_text('other attempt')\n"
            "        replacement.replace(directory / 'curs-1-manifest.json')\n"
            "    sys.exit(1)\n"
            "if sys.argv[1:] == ['--check-lock']:\n"
            "    lock = json.loads((root / '.agent-harness/curs-1-lock.json').read_text())\n"
            "    for name, expected in lock['sha256'].items():\n"
            "        path = pathlib.Path(name) if pathlib.Path(name).is_absolute() else root / name\n"
            "        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:\n"
            "            sys.exit(1)\n"
            "elif sys.argv[1:] != ['--self-test']:\n"
            "    sys.exit(2)\n"
            "print(json.dumps({'verdict':'PASS'}))\n",
            encoding="utf-8")

    def prepare(self):
        return subprocess.run(
            [sys.executable, str(self.root / "scripts/prepare-curs-1-harness.py"),
             "--agent-harness-dir", str(self.harness), "--pm-skills-dir", str(self.pm)],
            cwd=self.root, capture_output=True, text=True, timeout=20, check=False)

    def assert_exit(self, process, code):
        self.assertEqual(process.returncode, code, process.stdout + process.stderr)

    def rewrite(self, path, mutation):
        value = json.loads(path.read_text(encoding="utf-8"))
        mutation(value)
        path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")

    def test_governance_validates_exact_resolved_bytes_before_runtime_writes(self):
        # Catches validating the unresolved template or validating after publish.
        process = self.prepare()
        self.assert_exit(process, 0)
        observed = json.loads((self.root / "governance-observed.json").read_text())
        validated = json.loads(observed["raw"])
        self.assertEqual(validated["tasks"][0]["skill_path"], str(self.pm / "confluence-expert"))
        self.assertEqual(observed["raw"], (self.run / "curs-1-plan.json").read_text())
        self.assertEqual(observed["runtime"], [])
        self.assertFalse((self.run / "curs-1-state.json").exists())

    def test_resolved_manifest_registers_every_routed_skill(self):
        # Catches a shipped inventory that cannot describe its own task routes.
        process = self.prepare()
        self.assert_exit(process, 0)
        manifest = json.loads((self.run / "curs-1-manifest.json").read_text())
        inventory = {skill["name"]: skill["path"] for skill in manifest["skills"]}
        self.assertEqual(inventory, {
            "confluence-expert": str(self.pm / "confluence-expert"),
            "jira-expert": str(self.pm / "jira-expert"),
            "pm-skills": str(self.pm / "pm-skills"),
        })

    def test_missing_manifest_skill_is_rejected_before_runtime_writes(self):
        # Catches accepting a task whose skill has no manifest registration.
        self.rewrite(self.manifest, lambda value: value.update(skills=[
            skill for skill in value["skills"] if skill["name"] != "confluence-expert"]))
        process = self.prepare()
        self.assert_exit(process, 1)
        self.assertFalse(self.run.exists())

    def test_mismatched_manifest_path_is_rejected_before_runtime_writes(self):
        # A registered name must not silently point at another installed skill.
        self.rewrite(self.manifest, lambda value: next(
            skill for skill in value["skills"] if skill["name"] == "pm-skills").update(
                path="${PM_SKILLS_DIR}/jira-expert"))
        process = self.prepare()
        self.assert_exit(process, 1)
        self.assertFalse(self.run.exists())

    def test_unregistered_check_is_rejected_before_runtime_writes(self):
        # Catches a task invoking a check that its inventory never authorized.
        self.rewrite(self.plan, lambda value: value["tasks"][1]["verification"][0].update(
            cmd="python3 scripts/unregistered.py"))
        process = self.prepare()
        self.assert_exit(process, 1)
        self.assertFalse(self.run.exists())

    def test_hashing_failure_cleans_new_artifacts_and_preserves_history(self):
        # Catches a late failure stranding outputs and blocking the next attempt.
        self.run.mkdir()
        previous = self.run / "previous-run.json"
        previous.write_text("previous evidence")
        source = self.root / "scripts/test-portable.py"
        backup = source.read_bytes()
        source.unlink()
        self.assert_exit(self.prepare(), 1)
        self.assertEqual(previous.read_text(), "previous evidence")
        self.assertEqual(sorted(path.name for path in self.run.iterdir()), ["previous-run.json"])
        source.write_bytes(backup)
        self.assert_exit(self.prepare(), 0)

    def test_final_gate_failure_preserves_existing_evidence_and_allows_retry(self):
        # Cleanup must remove the three new JSON files, not old evidence.
        evidence = self.run / "curs-1-evidence"
        evidence.mkdir(parents=True)
        previous = evidence / "receipt.json"
        previous.write_text("previous evidence")
        fault = self.root / "lock-check-fault"
        fault.write_text("fail")
        self.assert_exit(self.prepare(), 1)
        self.assertEqual(previous.read_text(), "previous evidence")
        self.assertEqual(sorted(path.name for path in self.run.iterdir()), ["curs-1-evidence"])
        fault.unlink()
        self.assert_exit(self.prepare(), 0)

    def test_failed_attempt_preserves_racing_initialized_state(self):
        # Cleanup of an uninitialized failure must stop when a state appears.
        (self.root / "lock-check-fault").write_text("initialized")
        self.assert_exit(self.prepare(), 1)
        self.assertEqual((self.run / "curs-1-state.json").read_text(), '{"status":"open"}')
        for name in ("manifest", "plan", "lock"):
            self.assertTrue((self.run / f"curs-1-{name}.json").is_file())

    def test_final_gate_failure_removes_a_new_empty_runtime_directory(self):
        # Files must be removed before newly created parent directories.
        (self.root / "lock-check-fault").write_text("fail")
        self.assert_exit(self.prepare(), 1)
        self.assertFalse(self.run.exists())

    def test_failed_attempt_preserves_a_replaced_artifact(self):
        # Deleting by path alone would destroy a different attempt's replacement.
        (self.root / "lock-check-fault").write_text("replaced")
        self.assert_exit(self.prepare(), 1)
        self.assertEqual((self.run / "curs-1-manifest.json").read_text(), "other attempt")
        self.assertFalse((self.run / "curs-1-plan.json").exists())
        self.assertFalse((self.run / "curs-1-lock.json").exists())

    def test_exclusive_write_preserves_a_racing_existing_artifact(self):
        # Existing outputs can appear after the initial no-overwrite inspection.
        (self.root / "race-before-write").write_text("race")
        self.assert_exit(self.prepare(), 1)
        self.assertEqual((self.run / "curs-1-manifest.json").read_text(), "other attempt")
        self.assertEqual(sorted(path.name for path in self.run.iterdir()), ["curs-1-manifest.json"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
