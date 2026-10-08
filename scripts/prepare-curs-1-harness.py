#!/usr/bin/env python3
"""Resolve portable CURS-1 templates and freeze gates; never initialize a loop.

Use --check after controller initialization. Existing run artifacts are preserved:
preparation refuses to overwrite any CURS-1 plan, manifest, lock or state file.
"""

import argparse
import datetime as dt
import hashlib
import json
import shlex
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUN = ROOT / ".agent-harness"
TEMPLATES = ROOT / "specs/harness"


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, value):
    # Exclusive creation protects previous runs from accidental resets.
    with path.open("x", encoding="utf-8") as stream:
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--agent-harness-dir", type=Path,
                        help="Installed agent-harness skill directory containing SKILL.md and scripts/.")
    parser.add_argument("--pm-skills-dir", type=Path,
                        help="Installed PM skill root containing pm-skills/, jira-expert/ and confluence-expert/.")
    parser.add_argument("--check", action="store_true", help="Check existing frozen inputs without writing.")
    args = parser.parse_args()
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
        for path in destinations:
            if path.exists():
                raise ValueError(f"Existing run preserved; refusing to overwrite {path.relative_to(ROOT)}")
        plan = resolve(read_json(TEMPLATES / "curs-1-plan.json"), pm)
        manifest = resolve(read_json(TEMPLATES / "curs-1-manifest.json"), pm)
        # Failures are tested before creating the frozen input set. Controller
        # initialization is intentionally a separate, reviewed command.
        checked_command([sys.executable, "scripts/check_curs_1_delivery.py", "--self-test"])
        checked_command([sys.executable, str(governance), "--plan",
                         "specs/harness/curs-1-plan.json", "--mode", "plan"])
        RUN.mkdir(exist_ok=True)
        (RUN / "curs-1-evidence").mkdir(exist_ok=True)
        write_json(destinations[0], manifest)
        write_json(destinations[1], plan)
        frozen = [
            "specs/harness/curs-1-manifest.json", "specs/harness/curs-1-plan.json",
            "scripts/check_curs_1_delivery.py", "scripts/prepare-curs-1-harness.py",
            "docs/curs-1-harness.md", ".agent-harness/curs-1-manifest.json",
            ".agent-harness/curs-1-plan.json", "scripts/check_repository.py",
            "scripts/lint.sh", "scripts/test-portable.py", str(controller), str(governance),
        ]
        hashes = {}
        for name in frozen:
            path = Path(name) if Path(name).is_absolute() else ROOT / name
            hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
        lock = {"schema": "curs-1/check-lock.v1",
                "created_at": dt.datetime.now(dt.timezone.utc).isoformat(),
                "controller": str(controller), "governance_gate": str(governance),
                "plugin_versions": manifest["plugin_versions"], "sha256": hashes}
        write_json(destinations[2], lock)
        checked_command([sys.executable, "scripts/check_curs_1_delivery.py", "--check-lock"])
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
        print(json.dumps({"prepared": False, "reason": str(exc)}, indent=2), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
