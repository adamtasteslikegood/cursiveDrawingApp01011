#!/usr/bin/env python3
"""Initialize a reviewed CURS-1 plan while excluding failed-preparation cleanup.

The PLAN-file lock coordinates this supported initializer with preparation.
It does not protect initialization performed directly through the controller.
Existing state is always preserved; there is no force/reset option.
"""

import argparse
import contextlib
import fcntl
import importlib.util
import json
import os
import stat
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUN = ROOT / ".agent-harness"
PLAN = RUN / "curs-1-plan.json"


def binding(name, descriptor, parent_fd, directory=False):
    named = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
    pinned = os.fstat(descriptor)
    expected_type = stat.S_ISDIR if directory else stat.S_ISREG
    if not expected_type(named.st_mode) or (named.st_dev, named.st_ino) != (pinned.st_dev, pinned.st_ino):
        raise ValueError(f"Initialization input changed or is a symlink: {name}")


def require_no_state(runtime_fd):
    try:
        os.stat("curs-1-state.json", dir_fd=runtime_fd, follow_symlinks=False)
    except FileNotFoundError:
        return
    raise ValueError("Existing controller state preserved; initialization refused")


def main():
    argparse.ArgumentParser(description=__doc__).parse_args()
    try:
        with contextlib.ExitStack() as stack:
            def opened(name, flags, parent_fd=None):
                descriptor = os.open(name, flags | os.O_NOFOLLOW, dir_fd=parent_fd)
                stack.callback(os.close, descriptor)
                return descriptor

            root_fd = opened(ROOT, os.O_RDONLY | os.O_DIRECTORY)
            runtime_fd = opened(RUN.name, os.O_RDONLY | os.O_DIRECTORY, root_fd)
            plan_fd = opened(PLAN.name, os.O_RDONLY | os.O_NONBLOCK, runtime_fd)
            if not stat.S_ISREG(os.fstat(plan_fd).st_mode):
                raise ValueError("PLAN must be a regular file")
            fcntl.flock(plan_fd, fcntl.LOCK_EX)
            binding(RUN.name, runtime_fd, root_fd, directory=True)
            binding(PLAN.name, plan_fd, runtime_fd)
            require_no_state(runtime_fd)
            # Finish the production gate's context before init creates STATE.
            spec = importlib.util.spec_from_file_location("curs_1_delivery", ROOT / "scripts/check_curs_1_delivery.py")
            checker = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(checker)
            try:
                lock, _ = checker.lock_check()
            except checker.GateError as exc:
                raise ValueError(str(exc)) from exc
            evidence_fd = opened("curs-1-evidence", os.O_RDONLY | os.O_DIRECTORY, runtime_fd)
            binding(RUN.name, runtime_fd, root_fd, directory=True)
            binding(PLAN.name, plan_fd, runtime_fd)
            binding("curs-1-evidence", evidence_fd, runtime_fd, directory=True)
            require_no_state(runtime_fd)
            # The child retains this same flock if the wrapper is interrupted.
            result = subprocess.run(
                [sys.executable, lock["controller"], "init", "--plan",
                 ".agent-harness/curs-1-plan.json", "--state", ".agent-harness/curs-1-state.json"],
                cwd=ROOT, pass_fds=(plan_fd,), check=False)
            if result.returncode:
                raise ValueError(f"Controller initialization failed ({result.returncode}); existing outputs preserved")
            binding(RUN.name, runtime_fd, root_fd, directory=True)
            binding(PLAN.name, plan_fd, runtime_fd)
            binding("curs-1-evidence", evidence_fd, runtime_fd, directory=True)
            state = os.stat("curs-1-state.json", dir_fd=runtime_fd, follow_symlinks=False)
            if not stat.S_ISREG(state.st_mode):
                raise ValueError("Controller did not create a regular STATE file")
            print(json.dumps({"initialized": True, "state": ".agent-harness/curs-1-state.json"}))
            return 0
    except (OSError, ValueError, KeyError) as exc:
        print(json.dumps({"initialized": False, "reason": str(exc)}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
