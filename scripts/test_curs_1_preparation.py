#!/usr/bin/env python3
"""Behavioral preparation regressions, isolated from real harness state.

Run the actual preparation CLI in disposable repositories. A small governance
CLI fixture records its serialized input and models documented plan acceptance;
the tests require no installed plugins. Failure injection remains at subprocess
boundaries while resolution, hashing and filesystem effects execute normally.
"""

import json
import signal
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="curs-1-preparation-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "repo"
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
        initializer = ROOT / "scripts/initialize-curs-1-harness.py"
        if initializer.exists():
            shutil.copyfile(initializer, self.root / initializer.relative_to(ROOT))
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
            "if (root / 'symlink-before-write').exists():\n"
            "    directory = root / '.agent-harness'\n"
            "    outside = root.parent / 'outside'\n"
            "    if (root / 'symlink-before-write').read_text() == 'run':\n"
            "        directory.symlink_to(outside, target_is_directory=True)\n"
            "    else:\n"
            "        directory.mkdir()\n"
            "        (directory / 'curs-1-evidence').symlink_to(outside, target_is_directory=True)\n"
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

    def prepare(self, script=None):
        script = script or self.root / "scripts/prepare-curs-1-harness.py"
        if (self.root / "swap-during-open").exists():
            # Simulate a replacement between the directory inspection and the
            # actual file open, regardless of Path.open versus os.open usage.
            wrapper = self.root / "race_open.py"
            wrapper.write_text(
                "import io, os, pathlib, runpy, sys\n"
                "root = pathlib.Path.cwd()\n"
                "run = root / '.agent-harness'\n"
                "original_io, original_os = io.open, os.open\n"
                "swapped = False\n"
                "def swap(path, writing, directory_fd=None):\n"
                "    global swapped\n"
                "    if swapped or not writing or not isinstance(path, (str, os.PathLike)):\n"
                "        return\n"
                "    path = pathlib.Path(path)\n"
                "    if path.name == 'curs-1-manifest.json' and (path.parent == run or directory_fd is not None):\n"
                "        run.rename(root / 'moved-run')\n"
                "        run.symlink_to(root.parent / 'outside', target_is_directory=True)\n"
                "        swapped = True\n"
                "def open_io(path, mode='r', *args, **kwargs):\n"
                "    swap(path, any(flag in mode for flag in 'wax'))\n"
                "    return original_io(path, mode, *args, **kwargs)\n"
                "def open_os(path, flags, *args, **kwargs):\n"
                "    swap(path, flags & os.O_CREAT, kwargs.get('dir_fd'))\n"
                "    return original_os(path, flags, *args, **kwargs)\n"
                "io.open, os.open = open_io, open_os\n"
                "runpy.run_path(str(root / 'scripts/prepare-curs-1-harness.py'), run_name='__main__')\n",
                encoding="utf-8")
            script = wrapper
        return subprocess.run(
            [sys.executable, str(script),
             "--agent-harness-dir", str(self.harness), "--pm-skills-dir", str(self.pm)],
            cwd=self.root, capture_output=True, text=True, timeout=20, check=False)

    def assert_exit(self, process, code):
        self.assertEqual(process.returncode, code, process.stdout + process.stderr)

    def rewrite(self, path, mutation):
        value = json.loads(path.read_text(encoding="utf-8"))
        mutation(value)
        path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")

    def outside_directory(self):
        outside = self.root.parent / "outside"
        outside.mkdir()
        (outside / "sentinel.json").write_bytes(b"original outside contents\n")
        return outside

    def assert_outside_untouched(self, outside):
        self.assertEqual(sorted(path.name for path in outside.iterdir()), ["sentinel.json"])
        self.assertEqual((outside / "sentinel.json").read_bytes(), b"original outside contents\n")

    def prepare_production_run(self, initialized=True):
        """Freeze the real checker; skip only its separately tested self-test command."""
        shutil.copyfile(ROOT / "scripts/check_curs_1_delivery.py",
                        self.root / "scripts/check_curs_1_delivery.py")
        launcher = self.root / "prepare_fixture.py"
        launcher.write_text(
            "import pathlib, runpy, subprocess\n"
            "original_run = subprocess.run\n"
            "def run(command, *args, **kwargs):\n"
            "    if len(command) == 3 and command[1:] == ['scripts/check_curs_1_delivery.py', '--self-test']:\n"
            "        return subprocess.CompletedProcess(command, 0)\n"
            "    return original_run(command, *args, **kwargs)\n"
            "subprocess.run = run\n"
            "runpy.run_path(str(pathlib.Path.cwd() / 'scripts/prepare-curs-1-harness.py'), run_name='__main__')\n",
            encoding="utf-8")
        self.assert_exit(self.prepare(launcher), 0)
        if not initialized:
            return
        plan = json.loads((self.run / "curs-1-plan.json").read_text())
        # The documented controller init contract; no installed plugin needed.
        state = {
            "schema": "agent-harness/state.v1", "goal": plan["goal"],
            "domain": plan["domain"], "plan_file": ".agent-harness/curs-1-plan.json",
            "created_at": "2026-10-09T00:00:00Z", "iteration": 0,
            "max_loop_iterations": 12, "status": "open",
            "tasks": [{"id": task["id"], "skill": task["skill"],
                       "objective": task["objective"], "verification": task["verification"],
                       "max_attempts": 3, "attempts": 0, "status": "pending", "evidence": []}
                      for task in plan["tasks"]],
        }
        (self.run / "curs-1-state.json").write_text(json.dumps(state), encoding="utf-8")

    def check(self):
        return subprocess.run(
            [sys.executable, str(self.root / "scripts/prepare-curs-1-harness.py"), "--check"],
            cwd=self.root, capture_output=True, text=True, timeout=20, check=False)

    def start_process(self, command):
        process = subprocess.Popen(command, cwd=self.root, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True)
        def stop():
            if process.poll() is None:
                process.kill()
            process.communicate(timeout=5)
        self.addCleanup(stop)
        return process

    def finish_process(self, process, code):
        stdout, stderr = process.communicate(timeout=10)
        self.assertEqual(process.returncode, code, stdout + stderr)
        return stdout, stderr

    def wait_for(self, name, process=None):
        marker = self.root / name
        deadline = time.monotonic() + 5
        while not marker.exists() and time.monotonic() < deadline:
            if process is not None and process.poll() is not None:
                stdout, stderr = process.communicate(timeout=5)
                self.fail(f"Process exited before {name}: {stdout}{stderr}")
            time.sleep(0.01)
        self.assertTrue(marker.exists(), f"Timed out waiting for {name}")

    def paused_preparation(self, pause_cleanup=False, production=False):
        if production:
            shutil.copyfile(ROOT / "scripts/check_curs_1_delivery.py",
                            self.root / "scripts/check_curs_1_delivery.py")
        launcher = self.root / "paused_prepare.py"
        launcher.write_text(
            "import importlib.util, pathlib, sys, time\n"
            "root = pathlib.Path.cwd()\n"
            "spec = importlib.util.spec_from_file_location('prepare', root / 'scripts/prepare-curs-1-harness.py')\n"
            "module = importlib.util.module_from_spec(spec)\n"
            "spec.loader.exec_module(module)\n"
            "def wait(name):\n"
            "    deadline = time.monotonic() + 8\n"
            "    while not (root / name).exists():\n"
            "        if time.monotonic() > deadline: raise RuntimeError('barrier timeout: ' + name)\n"
            "        time.sleep(0.01)\n"
            "original_command = module.checked_command\n"
            "def command(args):\n"
            "    if args[1:] == ['scripts/check_curs_1_delivery.py', '--self-test']: return\n"
            "    if args[1:] == ['scripts/check_curs_1_delivery.py', '--check-lock']:\n"
            "        (root / 'preparation-ready').touch()\n"
            "        wait('fail-preparation')\n"
            "        raise ValueError('injected final preflight failure')\n"
            "    original_command(args)\n"
            "module.checked_command = command\n"
            + ("original_cleanup, original_state = module.cleanup_failed_attempt, module.state_entry_exists\n"
               "inside_cleanup = False\n"
               "def cleanup(*args):\n"
               "    global inside_cleanup\n"
               "    inside_cleanup = True\n"
               "    return original_cleanup(*args)\n"
               "def state(fd):\n"
               "    if inside_cleanup and not (root / 'cleanup-entered').exists():\n"
               "        (root / 'cleanup-entered').touch()\n"
               "        wait('release-cleanup')\n"
               "    return original_state(fd)\n"
               "module.cleanup_failed_attempt, module.state_entry_exists = cleanup, state\n"
               if pause_cleanup else "")
            + "sys.exit(module.main())\n", encoding="utf-8")
        process = self.start_process([sys.executable, str(launcher),
                                      "--agent-harness-dir", str(self.harness),
                                      "--pm-skills-dir", str(self.pm)])
        self.wait_for("preparation-ready", process)
        return process

    def assert_plan_is_locked(self):
        # A distinct process/open-file description must see the held lock.
        probe = subprocess.run(
            [sys.executable, "-c", "import fcntl, pathlib; "
             "stream = pathlib.Path('.agent-harness/curs-1-plan.json').open(); "
             "fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)"],
            cwd=self.root, capture_output=True, text=True, timeout=5, check=False)
        self.assertNotEqual(probe.returncode, 0, "PLAN was unlocked at the synchronization barrier")

    def install_initializer_controller(self):
        # The installed-controller boundary uses its documented init state shape.
        # Parent interruption is tested separately to prove lock inheritance.
        (self.harness / "scripts/loop_controller.py").write_text(
            "import fcntl, json, pathlib, sys, time\n"
            "root = pathlib.Path.cwd()\n"
            "assert sys.argv[1:] == ['init', '--plan', '.agent-harness/curs-1-plan.json', '--state', '.agent-harness/curs-1-state.json']\n"
            "with (root / '.agent-harness/curs-1-plan.json').open() as probe:\n"
            "    try: fcntl.flock(probe, fcntl.LOCK_EX | fcntl.LOCK_NB)\n"
            "    except BlockingIOError: (root / 'controller-inherited-lock').touch()\n"
            "(root / 'controller-entered').touch()\n"
            "if (root / 'pause-controller').exists():\n"
            "    deadline = time.monotonic() + 8\n"
            "    while not (root / 'release-controller').exists():\n"
            "        if time.monotonic() > deadline: raise RuntimeError('controller barrier timeout')\n"
            "        time.sleep(0.01)\n"
            "plan = json.loads((root / '.agent-harness/curs-1-plan.json').read_text())\n"
            "state = {'schema':'agent-harness/state.v1', 'goal':plan['goal'], 'domain':plan['domain'],\n"
            "         'plan_file':'.agent-harness/curs-1-plan.json', 'created_at':'2026-10-09T00:00:00Z',\n"
            "         'iteration':0, 'max_loop_iterations':12, 'status':'open',\n"
            "         'tasks':[dict(id=t['id'], skill=t['skill'], objective=t['objective'],\n"
            "                       verification=t['verification'], max_attempts=3, attempts=0,\n"
            "                       status='pending', evidence=[]) for t in plan['tasks']]}\n"
            "with (root / '.agent-harness/curs-1-state.json').open('x') as stream: json.dump(state, stream)\n",
            encoding="utf-8")

    def start_initializer(self):
        launcher = self.root / "initialize_fixture.py"
        launcher.write_text(
            "import fcntl, pathlib, runpy\n"
            "root = pathlib.Path.cwd()\n"
            "original = fcntl.flock\n"
            "def flock(fd, operation):\n"
            "    if operation == fcntl.LOCK_EX: (root / 'initializer-lock-attempt').touch()\n"
            "    return original(fd, operation)\n"
            "fcntl.flock = flock\n"
            "runpy.run_path(str(root / 'scripts/initialize-curs-1-harness.py'), run_name='__main__')\n",
            encoding="utf-8")
        process = self.start_process([sys.executable, str(launcher)])
        # Release a paused child before killing its wrapper during test cleanup.
        self.addCleanup((self.root / "release-controller").touch)
        return process

    def test_failed_cleanup_waits_for_an_existing_plan_lock(self):
        preparation = self.paused_preparation()
        holder = self.start_process([
            sys.executable, "-c",
            "import fcntl, pathlib, time; root=pathlib.Path.cwd(); "
            "stream=(root/'.agent-harness/curs-1-plan.json').open(); "
            "fcntl.flock(stream, fcntl.LOCK_EX); (root/'holder-entered').touch(); "
            "\nwhile not (root/'release-holder').exists(): time.sleep(0.01)\n"
            "(root/'.agent-harness/curs-1-state.json').write_text('initialized')\n"])
        self.wait_for("holder-entered", holder)
        self.assert_plan_is_locked()
        (self.root / "fail-preparation").touch()
        try:
            preparation.wait(timeout=0.2)
        except subprocess.TimeoutExpired:
            pass
        else:
            self.fail("Cleanup deleted a run while another process held its PLAN lock")
        (self.root / "release-holder").touch()
        self.finish_process(holder, 0)
        self.finish_process(preparation, 1)
        for name in ("manifest", "plan", "lock", "state"):
            self.assertTrue((self.run / f"curs-1-{name}.json").is_file())

    def test_initializer_wins_and_failed_cleanup_preserves_initialized_run(self):
        self.install_initializer_controller()
        (self.root / "pause-controller").touch()
        preparation = self.paused_preparation(production=True)
        before = {name: (self.run / name).read_bytes() for name in
                  ("curs-1-manifest.json", "curs-1-plan.json", "curs-1-lock.json")}
        initializer = self.start_initializer()
        self.wait_for("controller-entered", initializer)
        self.assert_plan_is_locked()
        self.assertTrue((self.root / "controller-inherited-lock").exists())
        (self.root / "fail-preparation").touch()
        with self.assertRaises(subprocess.TimeoutExpired):
            preparation.wait(timeout=0.2)
        (self.root / "release-controller").touch()
        self.finish_process(initializer, 0)
        self.finish_process(preparation, 1)
        self.assertEqual(before, {name: (self.run / name).read_bytes() for name in before})
        self.assertTrue((self.run / "curs-1-state.json").is_file())
        self.assertTrue((self.run / "curs-1-evidence").is_dir())
        self.assert_exit(self.check(), 0)

    def test_cleanup_wins_and_waiting_initializer_rejects_removed_inputs(self):
        self.install_initializer_controller()
        preparation = self.paused_preparation(pause_cleanup=True, production=True)
        (self.root / "fail-preparation").touch()
        self.wait_for("cleanup-entered", preparation)
        self.assert_plan_is_locked()
        initializer = self.start_initializer()
        self.wait_for("initializer-lock-attempt", initializer)
        self.assertFalse((self.root / "controller-entered").exists())
        with self.assertRaises(subprocess.TimeoutExpired):
            initializer.wait(timeout=0.2)
        (self.root / "release-cleanup").touch()
        self.finish_process(preparation, 1)
        self.finish_process(initializer, 1)
        self.assertFalse(self.run.exists())
        self.assertFalse((self.root / "controller-entered").exists())

    def test_controller_retains_plan_lock_when_initializer_is_interrupted(self):
        self.install_initializer_controller()
        (self.root / "pause-controller").touch()
        preparation = self.paused_preparation(production=True)
        initializer = self.start_initializer()
        self.wait_for("controller-entered", initializer)
        initializer.terminate()
        initializer.wait(timeout=5)
        self.assert_plan_is_locked()
        (self.root / "fail-preparation").touch()
        with self.assertRaises(subprocess.TimeoutExpired):
            preparation.wait(timeout=0.2)
        (self.root / "release-controller").touch()
        self.finish_process(initializer, -signal.SIGTERM)
        self.finish_process(preparation, 1)
        self.assert_exit(self.check(), 0)

    def test_preparation_freezes_and_prints_the_supported_initializer(self):
        process = self.prepare()
        self.assert_exit(process, 0)
        result = json.loads(process.stdout[process.stdout.index('{\n  "prepared"'):])
        self.assertEqual(result["commands"]["init_after_setup_review"],
                         "python3 scripts/initialize-curs-1-harness.py")
        lock = json.loads((self.run / "curs-1-lock.json").read_text())
        self.assertIn("scripts/initialize-curs-1-harness.py", lock["sha256"])

    def test_initializer_rejects_redirected_inputs_and_existing_state(self):
        self.install_initializer_controller()
        self.prepare_production_run(initialized=False)
        outside = self.outside_directory()
        for name in ("run", "plan", "lock", "manifest", "evidence", "dangling-state"):
            with self.subTest(input=name):
                target = (self.run if name == "run" else self.run / "curs-1-evidence"
                          if name == "evidence" else self.run / f"curs-1-{'state' if name == 'dangling-state' else name}.json")
                preserved = outside / target.name
                if name != "dangling-state":
                    target.rename(preserved)
                target.symlink_to(outside / "missing-state" if name == "dangling-state" else preserved,
                                  target_is_directory=name in ("run", "evidence"))
                before = {str(path.relative_to(outside)): path.read_bytes()
                          for path in outside.rglob("*") if path.is_file()}
                try:
                    self.finish_process(self.start_initializer(), 1)
                    self.assertFalse((self.root / "controller-entered").exists())
                    self.assertTrue(target.is_symlink())
                    self.assertEqual(before, {str(path.relative_to(outside)): path.read_bytes()
                                             for path in outside.rglob("*") if path.is_file()})
                finally:
                    target.unlink()
                    if name != "dangling-state":
                        preserved.rename(target)
        state = self.run / "curs-1-state.json"
        state.write_bytes(b"previous state\n")
        self.finish_process(self.start_initializer(), 1)
        self.assertEqual(state.read_bytes(), b"previous state\n")
        self.assertFalse((self.root / "controller-entered").exists())
        self.assert_outside_untouched(outside)

    def test_initializer_requires_fresh_frozen_gate_and_evidence_directory(self):
        self.install_initializer_controller()
        self.prepare_production_run(initialized=False)
        before = {name: (self.run / name).read_bytes() for name in
                  ("curs-1-manifest.json", "curs-1-plan.json", "curs-1-lock.json")}
        original = self.plan.read_bytes()
        self.plan.write_bytes(original + b"\n")
        self.finish_process(self.start_initializer(), 1)
        self.assertFalse((self.root / "controller-entered").exists())
        self.plan.write_bytes(original)
        (self.run / "curs-1-evidence").rmdir()
        self.finish_process(self.start_initializer(), 1)
        self.assertFalse((self.root / "controller-entered").exists())
        self.assertFalse((self.run / "curs-1-state.json").exists())
        self.assertEqual(before, {name: (self.run / name).read_bytes() for name in before})

    def test_check_cli_accepts_an_honest_prepared_initialized_run(self):
        # Control case: real production lock_check accepts the producer's output.
        self.prepare_production_run()
        self.assert_exit(self.check(), 0)

    def test_check_cli_rejects_post_init_directory_and_reserved_file_links(self):
        # Path-following reads must not accept byte-identical redirected files.
        self.prepare_production_run()
        outside = self.outside_directory()
        for name in ("run", "manifest", "plan", "lock", "state", "dangling-state"):
            with self.subTest(link=name):
                self.assert_exit(self.check(), 0)
                target = self.run if name == "run" else self.run / f"curs-1-{'state' if name == 'dangling-state' else name}.json"
                preserved = outside / target.name
                target.rename(preserved)
                target.symlink_to(outside / "missing-state" if name == "dangling-state" else preserved,
                                  target_is_directory=name == "run")
                before = {str(path.relative_to(outside)): path.read_bytes()
                          for path in outside.rglob("*") if path.is_file()}
                try:
                    self.assert_exit(self.check(), 1)
                    self.assertTrue(target.is_symlink())
                    after = {str(path.relative_to(outside)): path.read_bytes()
                             for path in outside.rglob("*") if path.is_file()}
                    self.assertEqual(after, before)
                finally:
                    target.unlink()
                    preserved.rename(target)
        self.assert_exit(self.check(), 0)
        self.assert_outside_untouched(outside)

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

    def test_runtime_symlink_is_rejected_and_preserved(self):
        # Following the runtime directory would publish the run outside checkout.
        outside = self.outside_directory()
        self.run.symlink_to(outside, target_is_directory=True)
        self.assert_exit(self.prepare(), 1)
        self.assertTrue(self.run.is_symlink())
        self.assert_outside_untouched(outside)
        self.run.unlink()
        self.assert_exit(self.prepare(), 0)
        self.assert_outside_untouched(outside)

    def test_evidence_symlink_is_rejected_without_publishing_files(self):
        # An evidence link must fail before creating any manifest/plan/lock.
        outside = self.outside_directory()
        self.run.mkdir()
        (self.run / "history.json").write_bytes(b"previous run\n")
        evidence = self.run / "curs-1-evidence"
        evidence.symlink_to(outside, target_is_directory=True)
        self.assert_exit(self.prepare(), 1)
        self.assertEqual(sorted(path.name for path in self.run.iterdir()),
                         ["curs-1-evidence", "history.json"])
        self.assertEqual((self.run / "history.json").read_bytes(), b"previous run\n")
        self.assertTrue(evidence.is_symlink())
        self.assert_outside_untouched(outside)
        evidence.unlink()
        self.assert_exit(self.prepare(), 0)
        self.assert_outside_untouched(outside)

    def test_runtime_symlink_raced_after_preflight_is_rejected(self):
        outside = self.outside_directory()
        (self.root / "symlink-before-write").write_text("run")
        self.assert_exit(self.prepare(), 1)
        self.assertTrue(self.run.is_symlink())
        self.assert_outside_untouched(outside)

    def test_evidence_symlink_raced_after_preflight_is_rejected(self):
        outside = self.outside_directory()
        (self.root / "symlink-before-write").write_text("evidence")
        self.assert_exit(self.prepare(), 1)
        self.assertTrue((self.run / "curs-1-evidence").is_symlink())
        self.assertEqual(sorted(path.name for path in self.run.iterdir()), ["curs-1-evidence"])
        self.assert_outside_untouched(outside)

    def test_runtime_swap_during_exclusive_open_cannot_redirect_writes(self):
        outside = self.outside_directory()
        (self.root / "swap-during-open").write_text("race")
        self.assert_exit(self.prepare(), 1)
        self.assertTrue(self.run.is_symlink())
        self.assert_outside_untouched(outside)
        # Cleanup must use the pinned original directory, not the replacement.
        self.assertEqual(list((self.root / "moved-run").iterdir()), [])

    def test_dangling_directory_links_are_rejected_without_replacing_them(self):
        for directory in (self.run, self.run / "curs-1-evidence"):
            with self.subTest(directory=directory.name):
                if directory != self.run:
                    self.run.mkdir()
                directory.symlink_to(self.root.parent / "missing", target_is_directory=True)
                self.assert_exit(self.prepare(), 1)
                self.assertTrue(directory.is_symlink())
                directory.unlink()
                if directory != self.run:
                    self.run.rmdir()

    def test_dangling_reserved_state_link_blocks_preparation(self):
        # exists() alone misses the state entry; it must still block a new run.
        self.run.mkdir()
        state = self.run / "curs-1-state.json"
        state.symlink_to(self.root.parent / "missing-state")
        self.assert_exit(self.prepare(), 1)
        self.assertEqual(list(self.run.iterdir()), [state])
        self.assertTrue(state.is_symlink())


if __name__ == "__main__":
    unittest.main(verbosity=2)
