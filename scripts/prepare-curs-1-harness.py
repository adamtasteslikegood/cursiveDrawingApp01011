#!/usr/bin/env python3
"""Resolve portable CURS-1 templates and freeze gates; never initialize a loop.

Use --check after controller initialization. Existing run artifacts are preserved:
preparation refuses to overwrite any CURS-1 plan, manifest, lock or state file.
"""

import argparse
import datetime as dt
import hashlib
import json
import os
import shlex
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUN = ROOT / ".agent-harness"
TEMPLATES = ROOT / "specs/harness"


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, value, created=None, directory_fd=None):
    # Exclusive creation protects previous runs from accidental resets.
    if directory_fd is None:  # Private staged plan in TemporaryDirectory.
        stream = path.open("x", encoding="utf-8")
    else:
        descriptor = os.open(path.name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                             0o600, dir_fd=directory_fd)
        stream = os.fdopen(descriptor, "w", encoding="utf-8")
    with stream:
        if created is not None:
            info = os.fstat(stream.fileno())
            created.append((path, (info.st_dev, info.st_ino), directory_fd))
        json.dump(value, stream, indent=2)
        stream.write("\n")


def resolve(value, pm_directory):
    if isinstance(value, str):
        result = value.replace("${PM_SKILLS_DIR}", str(pm_directory))
        if "${" in result:
            raise ValueError(f"Unresolved template token: {result}")
        return result
    if isinstance(value, list):
        return [resolve(item, pm_directory) for item in value]
    if isinstance(value, dict):
        return {key: resolve(item, pm_directory) for key, item in value.items()}
    return value


def checked_command(command):
    result = subprocess.run(command, cwd=ROOT, check=False)
    if result.returncode:
        raise ValueError(f"Preflight command failed ({result.returncode}): {shlex.join(command)}")


def validate_inventory(plan, manifest):
    inventory = {}
    for skill in manifest["skills"]:
        name = skill["name"]
        if name in inventory:
            raise ValueError(f"Duplicate manifest skill: {name}")
        if not (Path(skill["path"]) / "SKILL.md").is_file():
            raise ValueError(f"Missing installed manifest skill: {skill['path']}")
        checks = []
        for tool in skill.get("tools", []):
            script = Path(tool["script"])
            if not (script if script.is_absolute() else ROOT / script).is_file():
                raise ValueError(f"Missing manifest tool: {script}")
            checks.extend(tool.get("verification", []))
        inventory[name] = (skill["path"], checks)
    for task in plan["tasks"]:
        entry = inventory.get(task["skill"])
        if entry is None or task["skill_path"] != entry[0]:
            raise ValueError(f"Task {task['id']} skill/path is not registered in the manifest")
        if any(check not in entry[1] for check in task.get("verification", [])):
            raise ValueError(f"Task {task['id']} verification is not registered in the manifest")
        if task.get("acceptance", {}).get("cmd") not in {check.get("cmd") for check in entry[1]}:
            raise ValueError(f"Task {task['id']} acceptance is not registered in the manifest")


def create_directory(path, created, parent_fd):
    new_directory = False
    try:
        os.mkdir(path.name, dir_fd=parent_fd)
    except FileExistsError:
        pass
    else:
        new_directory = True
    # Pin the real directory. O_NOFOLLOW also rejects a symlink raced into mkdir.
    descriptor = os.open(path.name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                         dir_fd=parent_fd)
    if new_directory:
        info = os.fstat(descriptor)
        created.append((path, (info.st_dev, info.st_ino), parent_fd))
    return descriptor


def validate_directory_binding(path, descriptor, parent_fd):
    named = os.stat(path.name, dir_fd=parent_fd, follow_symlinks=False)
    pinned = os.fstat(descriptor)
    if not stat.S_ISDIR(named.st_mode) or (named.st_dev, named.st_ino) != (pinned.st_dev, pinned.st_ino):
        raise ValueError(f"Runtime directory changed or is a symlink: {path}")


def state_entry_exists(runtime_fd):
    if runtime_fd is None:
        return False
    try:
        os.stat("curs-1-state.json", dir_fd=runtime_fd, follow_symlinks=False)
    except FileNotFoundError:
        return False
    return True


def runtime_digest(path, runtime_fd):
    descriptor = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=runtime_fd)
    with os.fdopen(descriptor, "rb") as stream:
        return hashlib.sha256(stream.read()).hexdigest()


def cleanup_failed_attempt(files, directories, runtime_fd):
    """Remove this attempt's own files/empty directories unless a state appears."""
    warnings = []
    for path, identity, parent_fd in [*reversed(files), *reversed(directories)]:
        if state_entry_exists(runtime_fd):
            break
        try:
            info = os.stat(path.name, dir_fd=parent_fd, follow_symlinks=False)
            if (info.st_dev, info.st_ino) != identity:
                continue  # Another attempt replaced this path; preserve it.
            if stat.S_ISDIR(info.st_mode):
                # Preserve a directory to which another process added evidence.
                descriptor = os.open(path.name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                                     dir_fd=parent_fd)
                try:
                    if os.listdir(descriptor):
                        continue
                    os.rmdir(path.name, dir_fd=parent_fd)
                finally:
                    os.close(descriptor)
            else:
                os.unlink(path.name, dir_fd=parent_fd)
        except FileNotFoundError:
            continue
        except OSError as exc:
            warnings.append(f"Preserved {path}: {exc}")
    return warnings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--agent-harness-dir", type=Path,
                        help="Installed agent-harness skill directory containing SKILL.md and scripts/.")
    parser.add_argument("--pm-skills-dir", type=Path,
                        help="Installed PM skill root containing pm-skills/, jira-expert/ and confluence-expert/.")
    parser.add_argument("--check", action="store_true", help="Check existing frozen inputs without writing.")
    args = parser.parse_args()
    created_files, created_directories = [], []
    directory_descriptors = []
    runtime_fd = None
    try:
        if args.check:
            checked_command([sys.executable, "scripts/check_curs_1_delivery.py", "--check-lock"])
            return 0
        if args.agent_harness_dir is None or args.pm_skills_dir is None:
            parser.error("preparation requires --agent-harness-dir and --pm-skills-dir")
        harness = args.agent_harness_dir.expanduser().resolve()
        pm = args.pm_skills_dir.expanduser().resolve()
        controller = harness / "scripts/loop_controller.py"
        governance = pm / "pm-skills/scripts/delivery_loop_gate.py"
        for path in (harness / "SKILL.md", controller, governance,
                     pm / "pm-skills/SKILL.md", pm / "jira-expert/SKILL.md",
                     pm / "confluence-expert/SKILL.md"):
            if not path.is_file():
                raise ValueError(f"Missing installed plugin file: {path}")
        destinations = [RUN / f"curs-1-{name}.json" for name in ("manifest", "plan", "lock", "state")]
        for directory in (RUN, RUN / "curs-1-evidence"):
            if directory.is_symlink():
                raise ValueError(f"Runtime directory must not be a symlink: {directory}")
        for path in destinations:
            if path.exists() or path.is_symlink():
                raise ValueError(f"Existing run preserved; refusing to overwrite {path.relative_to(ROOT)}")
        plan = resolve(read_json(TEMPLATES / "curs-1-plan.json"), pm)
        manifest = resolve(read_json(TEMPLATES / "curs-1-manifest.json"), pm)
        validate_inventory(plan, manifest)
        # Failures are tested before creating the frozen input set. Controller
        # initialization is intentionally a separate, reviewed command.
        checked_command([sys.executable, "scripts/check_curs_1_delivery.py", "--self-test"])
        with tempfile.TemporaryDirectory(prefix="curs-1-preparation-") as directory:
            staged_plan = Path(directory) / "plan.json"
            write_json(staged_plan, plan)
            checked_command([sys.executable, str(governance), "--plan",
                             str(staged_plan), "--mode", "plan"])
        root_fd = os.open(ROOT, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        directory_descriptors.append(root_fd)
        runtime_fd = create_directory(RUN, created_directories, root_fd)
        directory_descriptors.append(runtime_fd)
        evidence_fd = create_directory(RUN / "curs-1-evidence", created_directories, runtime_fd)
        directory_descriptors.append(evidence_fd)
        validate_directory_binding(RUN, runtime_fd, root_fd)
        validate_directory_binding(RUN / "curs-1-evidence", evidence_fd, runtime_fd)
        if state_entry_exists(runtime_fd):
            raise ValueError("A controller state appeared during preparation; preserving the run")
        write_json(destinations[0], manifest, created_files, runtime_fd)
        write_json(destinations[1], plan, created_files, runtime_fd)
        frozen = [
            "specs/harness/curs-1-manifest.json", "specs/harness/curs-1-plan.json",
            "scripts/check_curs_1_delivery.py", "scripts/prepare-curs-1-harness.py",
            "docs/curs-1-harness.md", ".agent-harness/curs-1-manifest.json",
            ".agent-harness/curs-1-plan.json", "scripts/check_repository.py",
            "scripts/lint.sh", "scripts/test-portable.py", str(controller), str(governance),
        ]
        validate_directory_binding(RUN, runtime_fd, root_fd)
        validate_directory_binding(RUN / "curs-1-evidence", evidence_fd, runtime_fd)
        hashes = {}
        for name in frozen:
            path = Path(name) if Path(name).is_absolute() else ROOT / name
            hashes[name] = runtime_digest(path, runtime_fd) if path.parent == RUN else hashlib.sha256(path.read_bytes()).hexdigest()
        lock = {"schema": "curs-1/check-lock.v1",
                "created_at": dt.datetime.now(dt.timezone.utc).isoformat(),
                "controller": str(controller), "governance_gate": str(governance),
                "plugin_versions": manifest["plugin_versions"], "sha256": hashes}
        write_json(destinations[2], lock, created_files, runtime_fd)
        validate_directory_binding(RUN, runtime_fd, root_fd)
        validate_directory_binding(RUN / "curs-1-evidence", evidence_fd, runtime_fd)
        checked_command([sys.executable, "scripts/check_curs_1_delivery.py", "--check-lock"])
        validate_directory_binding(RUN, runtime_fd, root_fd)
        validate_directory_binding(RUN / "curs-1-evidence", evidence_fd, runtime_fd)
        commands = {
            "init_after_setup_review": shlex.join(["python3", str(controller), "init", "--plan",
                                                  ".agent-harness/curs-1-plan.json", "--state",
                                                  ".agent-harness/curs-1-state.json"]),
            "check_after_init": "python3 scripts/prepare-curs-1-harness.py --check",
            "next": shlex.join(["python3", str(controller), "next", "--state",
                                ".agent-harness/curs-1-state.json"]),
            "governance_projection": "python3 scripts/check_curs_1_delivery.py --governance-output .agent-harness/curs-1-governance.json",
            "governance_close": shlex.join(["python3", str(governance), "--plan",
                                            ".agent-harness/curs-1-governance.json", "--mode", "close"]),
            "controller_close": shlex.join(["python3", str(controller), "close", "--state",
                                            ".agent-harness/curs-1-state.json"]),
        }
        print(json.dumps({"prepared": True, "initialized": False,
                          "controller": str(controller), "governance_gate": str(governance),
                          "commands": commands}, indent=2))
        return 0
    except (OSError, ValueError, KeyError) as exc:
        result = {"prepared": False, "reason": str(exc)}
        warnings = cleanup_failed_attempt(created_files, created_directories, runtime_fd)
        if warnings:
            result["cleanup_warnings"] = warnings
        print(json.dumps(result, indent=2), file=sys.stderr)
        return 1
    finally:
        for descriptor in reversed(directory_descriptors):
            os.close(descriptor)


if __name__ == "__main__":
    sys.exit(main())
