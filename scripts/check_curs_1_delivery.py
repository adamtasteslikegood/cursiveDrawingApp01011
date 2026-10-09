#!/usr/bin/env python3
"""Frozen CURS-1 artifact and live delivery gate. Python standard library only.

Local packets are review deliverables. Only T5 checks actual Jira completion or
review with the current open PR; neither mode certifies handwriting education.
"""

import argparse
import copy
import contextlib
import datetime as dt
import hashlib
import html
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUN = ROOT / ".agent-harness"
LOCK = RUN / "curs-1-lock.json"
PLAN = RUN / "curs-1-plan.json"
STATE = RUN / "curs-1-state.json"
CLOUD = "029decc8-e09a-4d55-92f8-20d9ca64ca13"
OWNER = "Adam Schoen"
ISSUES = ("CURS-6", "CURS-7", "CURS-8")
PRESERVED = ("CURS-9", "CURS-22", "CURS-23")
TASKS = ("T1", "T2", "T3", "T4", "T5")
MAX_AGE = dt.timedelta(minutes=30)
ATLASSIAN = "https://tasteslikegood.atlassian.net"
GITHUB_REPOSITORY = "adamtasteslikegood/cursiveDrawingApp01011"
GITHUB_OWNER = "adamtasteslikegood"


class GateError(Exception):
    """An unmet acceptance condition, rather than a successful partial check."""


def require(condition, message):
    if not condition:
        raise GateError(message)


def read_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise GateError(f"Cannot read {path}: {exc}") from exc


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def utc_time(value):
    require(isinstance(value, str), "Evidence timestamp is missing")
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise GateError(f"Invalid UTC timestamp: {value}") from exc
    require(parsed.tzinfo is not None and parsed.utcoffset() == dt.timedelta(0),
            "Evidence timestamp must explicitly use UTC")
    return parsed


def snapshot(evidence_dir, name, now=None):
    envelope = read_json(evidence_dir / name)
    require(isinstance(envelope, dict), f"{name}: envelope must be an object")
    require(envelope.get("cloud_id") == CLOUD, f"{name}: wrong Atlassian cloud")
    require(bool(envelope.get("query")), f"{name}: query provenance is missing")
    captured = utc_time(envelope.get("captured_at"))
    age = (now or dt.datetime.now(dt.timezone.utc)) - captured
    require(dt.timedelta(minutes=-2) <= age <= MAX_AGE,
            f"{name}: snapshot is stale or from the future (limit 30 minutes)")
    response = envelope.get("response")
    require(isinstance(response, dict), f"{name}: raw response must be an object")
    require(not response.get("isError") and not response.get("error")
            and not response.get("errors"), f"{name}: API error or denied access")
    data = response.get("data")
    require(isinstance(data, dict), f"{name}: expected raw response.data object")
    require(not data.get("error") and not data.get("errors")
            and not data.get("isError"), f"{name}: API error or denied access")
    return data, envelope


@contextlib.contextmanager
def frozen_runtime_entries():
    """Pin regular runtime metadata before reading; reject links, even dangling state."""
    require(RUN == ROOT / ".agent-harness" and LOCK == RUN / "curs-1-lock.json"
            and PLAN == RUN / "curs-1-plan.json" and STATE == RUN / "curs-1-state.json",
            "Runtime metadata paths must use this repository's reserved identities")
    try:
        with contextlib.ExitStack() as opened:
            directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
            root_fd = os.open(ROOT, directory_flags)
            opened.callback(os.close, root_fd)
            runtime_fd = os.open(".agent-harness", directory_flags, dir_fd=root_fd)
            opened.callback(os.close, runtime_fd)
            streams = {}
            for name in ("lock", "manifest", "plan", "state"):
                filename = f"curs-1-{name}.json"
                try:
                    descriptor = os.open(filename, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                                         dir_fd=runtime_fd)
                except FileNotFoundError:
                    if name == "state":
                        continue  # Only genuine absence is allowed before initialization.
                    raise
                opened.callback(os.close, descriptor)
                require(stat.S_ISREG(os.fstat(descriptor).st_mode),
                        f"Reserved runtime metadata must be a regular file: {filename}")
                stream = opened.enter_context(os.fdopen(descriptor, "rb", closefd=False))
                streams[name] = stream
            # All reserved entries have been pinned without following links before
            # any JSON is read or any frozen digest is checked.
            yield {name: stream.read() for name, stream in streams.items()}
            named = os.stat(".agent-harness", dir_fd=root_fd, follow_symlinks=False)
            pinned = os.fstat(runtime_fd)
            require(stat.S_ISDIR(named.st_mode)
                    and (named.st_dev, named.st_ino) == (pinned.st_dev, pinned.st_ino),
                    "Runtime directory identity changed during lock validation")
            for name, stream in streams.items():
                named = os.stat(f"curs-1-{name}.json", dir_fd=runtime_fd, follow_symlinks=False)
                pinned = os.fstat(stream.fileno())
                require(stat.S_ISREG(named.st_mode)
                        and (named.st_dev, named.st_ino) == (pinned.st_dev, pinned.st_ino),
                        f"Reserved runtime metadata identity changed: curs-1-{name}.json")
            if "state" not in streams:
                try:
                    os.stat("curs-1-state.json", dir_fd=runtime_fd, follow_symlinks=False)
                except FileNotFoundError:
                    pass
                else:
                    raise GateError("Controller state appeared during lock validation; recheck the run")
    except OSError as exc:
        raise GateError(f"Cannot read reserved runtime metadata without following links: {exc}") from exc


def runtime_json(entries, name):
    try:
        return json.loads(entries[name].decode("utf-8"))
    except (UnicodeError, ValueError) as exc:
        raise GateError(f"Invalid reserved runtime JSON: curs-1-{name}.json: {exc}") from exc


def validate_plugin_roles(lock, manifest, hashes):
    paths = {}
    for name in ("controller", "governance_gate"):
        value = lock.get(name)
        require(isinstance(value, str), f"Frozen lock omits the plugin {name}")
        path = Path(value)
        require(path.is_absolute() and str(path.resolve()) == value,
                f"Frozen plugin {name} reference must be an absolute canonical path")
        require(value in hashes, f"Frozen lock omits the plugin {name}")
        paths[name] = path
    controller = paths["controller"]
    require(controller.name == "loop_controller.py" and controller.parent.name == "scripts"
            and (controller.parent.parent / "SKILL.md").is_file(),
            "Frozen controller must identify an installed skill's scripts/loop_controller.py")
    require(isinstance(manifest, dict) and manifest.get("schema") == "agent-harness/manifest.v1",
            "Invalid resolved manifest schema")
    skills = manifest.get("skills")
    require(isinstance(skills, list) and all(isinstance(skill, dict) for skill in skills),
            "Resolved manifest skill inventory is missing")
    matches = [skill for skill in skills if skill.get("name") == "pm-skills"]
    require(len(matches) == 1 and isinstance(matches[0].get("path"), str),
            "Resolved manifest must identify one pm-skills installation")
    pm_root = Path(matches[0]["path"])
    require(pm_root.is_absolute() and str(pm_root.resolve()) == matches[0]["path"],
            "Resolved pm-skills installation must have an absolute canonical path")
    require(paths["governance_gate"] == pm_root / "scripts/delivery_loop_gate.py",
            "Frozen governance gate differs from the resolved pm-skills installation")


def validate_locked_inputs(entries):
    lock = runtime_json(entries, "lock")
    require(isinstance(lock, dict) and lock.get("schema") == "curs-1/check-lock.v1", "Invalid lock schema")
    hashes = lock.get("sha256", {})
    require(isinstance(hashes, dict), "Frozen digests must be a path/hash object")
    required_paths = {
        "scripts/check_curs_1_delivery.py", "scripts/prepare-curs-1-harness.py",
        "specs/harness/curs-1-manifest.json", "specs/harness/curs-1-plan.json",
        "docs/curs-1-harness.md", ".agent-harness/curs-1-manifest.json",
        ".agent-harness/curs-1-plan.json", "scripts/check_repository.py",
        "scripts/lint.sh", "scripts/test-portable.py",
    }
    require(required_paths <= set(hashes), "Frozen lock omits a required check or plan")
    runtime_paths = {RUN / "curs-1-manifest.json": entries["manifest"], PLAN: entries["plan"]}
    for relative, expected in hashes.items():
        path = Path(relative) if Path(relative).is_absolute() else ROOT / relative
        actual = hashlib.sha256(runtime_paths[path]).hexdigest() if path in runtime_paths else (
            digest(path) if path.is_file() else None)
        require(actual is not None and actual == expected,
                f"Frozen input changed or disappeared: {relative}")
    validate_plugin_roles(lock, runtime_json(entries, "manifest"), hashes)
    plan = runtime_json(entries, "plan")
    require([t.get("id") for t in plan.get("tasks", [])] == list(TASKS),
            "Resolved plan must have exactly T1 through T5 in order")
    require(plan.get("scope", {}).get("issue_keys") == list(ISSUES), "Plan scope changed")
    require(plan.get("budgets") == {"max_attempts_per_task": 3, "max_loop_iterations": 12},
            "Plan budgets changed")
    for task in plan["tasks"]:
        require(task.get("owner") == OWNER and task.get("reviewer") == OWNER
                and task.get("executor") == "agent", "Human accountability changed")
        command = f"python3 scripts/check_curs_1_delivery.py --task {task['id']}"
        expected_commands = [command]
        if task["id"] == "T1":
            expected_commands += ["python3 scripts/check_repository.py", "./scripts/lint.sh"]
        elif task["id"] == "T3":
            expected_commands += ["python3 scripts/test-portable.py"]
        checks = task.get("verification", [])
        require(task.get("max_attempts") == 3
                and [check.get("cmd") for check in checks] == expected_commands
                and all(check.get("expect_exit") == 0 and check.get("kind") != "manual-evidence"
                        for check in checks),
                f"Unexpected executable verification contract for {task['id']}")
        require(task.get("acceptance", {}).get("cmd") == command,
                f"Acceptance command changed for {task['id']}")
    if "state" in entries:
        state = runtime_json(entries, "state")
        require(state.get("schema") == "agent-harness/state.v1", "Invalid controller state")
        require(state.get("max_loop_iterations") == 12, "Controller iteration budget changed")
        require([t.get("id") for t in state.get("tasks", [])] == list(TASKS),
                "Controller task scope changed")
        for task, original in zip(state["tasks"], plan["tasks"]):
            require(task.get("verification") == original["verification"]
                    and task.get("max_attempts") == 3,
                    f"Controller checks changed for {task['id']}")
    return lock, plan


def lock_check():
    with frozen_runtime_entries() as entries:
        return validate_locked_inputs(entries)


def section_bodies(text, required):
    headings = list(re.finditer(r"^#{1,6}\s+(.+)$", text, flags=re.M))
    for section in required:
        matching = [i for i, heading in enumerate(headings)
                    if re.search(rf"\b{re.escape(section)}\b", heading.group(1), re.I)]
        require(bool(matching), f"Need a '{section}' heading")
        bodies = []
        for index in matching:
            end = headings[index + 1].start() if index + 1 < len(headings) else len(text)
            bodies.append(text[headings[index].end():end].strip())
        require(any(len(body) >= 30 for body in bodies),
                f"'{section}' section lacks substantive content")


def validate_epic(epic):
    require(epic.get("key") == "CURS-1" and str(epic.get("id")) == "31025",
            "Wrong epic identity")
    fields = epic.get("fields", {})
    require(fields.get("issuetype", {}).get("name") == "Epic", "CURS-1 is not the epic")
    require(fields.get("status", {}).get("name") == "In Progress",
            "CURS-1 must actually be In Progress while review acceptance remains open")
    require(fields.get("assignee", {}).get("displayName") == OWNER,
            "CURS-1 lacks its named human owner")


def validate_sprint(data):
    require(data.get("isLast") is True and not data.get("nextPageToken"),
            "Sprint listing pagination is incomplete")
    values = data.get("values")
    require(isinstance(values, list), "Sprint values are missing")
    require(len(values) == data.get("total", len(values)), "Sprint listing is partial")
    selected = [s for s in values if s.get("id") == 119]
    require(len(selected) == 1, "Sprint 119 identity is missing or duplicated")
    sprint = selected[0]
    require(sprint.get("originBoardId") == 204
            and sprint.get("name") == "Cursivly 01 - Model foundation", "Wrong sprint/board")
    require(sprint.get("state") == "future", "The existing time-box must remain future")


def semantic_markdown(value):
    """Ignore Confluence formatting normalization, retaining words and link targets."""
    links = re.findall(r"\[[^\]]*\]\(([^\s)]+)(?:\s+[^)]*)?\)", value)
    visible = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", value)
    visible = re.sub(r"(?m)^\s*(?:[-+*]|\d+[.)])\s+", "", visible)
    words = re.findall(r"\w+", html.unescape(visible))
    return words, sorted(set(html.unescape(link) for link in links))


def validate_charter(evidence_dir):
    path = ROOT / "specs/curs-1-charter.md"
    require(path.is_file(), "Missing canonical specs/curs-1-charter.md")
    text = path.read_text(encoding="utf-8")
    section_bodies(text, ("Goal", "Scope", "Review", "Acceptance", "Risks", "Budgets"))
    for identity in ("CURS-1", *ISSUES, OWNER, "119", "204", "3", "12"):
        require(identity in text, f"Charter lacks {identity}")
    epic, _ = snapshot(evidence_dir, "epic.json")
    validate_epic(epic)
    sprint, _ = snapshot(evidence_dir, "sprint.json")
    validate_sprint(sprint)
    space, _ = snapshot(evidence_dir, "confluence-space.json")
    require(space.get("key") == "CURS" and space.get("status") == "current"
            and str(space.get("id", "")).isdigit(), "Wrong or inaccessible CURS space")
    require(space.get("webUrl") == f"{ATLASSIAN}/wiki/spaces/CURS", "Wrong Confluence site")
    page, _ = snapshot(evidence_dir, "confluence-charter.json")
    require(page.get("type") == "page" and page.get("status") == "current"
            and str(page.get("id", "")).isdigit(), "Charter is not a published page")
    require(str(page.get("spaceId")) == str(space["id"]), "Charter is in another space")
    require(page.get("title") == "CURS-1 model foundation charter", "Wrong charter page")
    body = page.get("body", {})
    require(body.get("format") == "markdown" and isinstance(body.get("value"), str),
            "Charter readback must include its full markdown body")
    require(semantic_markdown(body["value"]) == semantic_markdown(text),
            "Published Confluence charter differs from the canonical charter")
    page_url = f"{ATLASSIAN}/wiki/spaces/CURS/pages/{page['id']}"
    epic_urls = re.findall(r"https?://[^\s<>\"'()]+", description_text(
        epic.get("fields", {}).get("description")))
    require(any(url == page_url or url.startswith(page_url + "/") for url in epic_urls),
            "CURS-1 must link its published CURS charter page in its description")
    return {"space_id": str(space["id"]), "page_id": str(page["id"])}


def review_packet(task):
    issue = {"T2": "CURS-6", "T3": "CURS-7", "T4": "CURS-8"}[task]
    path = ROOT / f"docs/reviews/{issue}.md"
    require(path.is_file(), f"Missing {path.relative_to(ROOT)}")
    text = path.read_text(encoding="utf-8")
    require(len(re.findall(r"\S+", text)) >= 180, f"{issue}: review is too thin")
    require(issue in text and OWNER in text, f"{issue}: issue/reviewer identity is missing")
    section_bodies(text, ("Acceptance evidence", "Findings", "Decision requested",
                          "Remaining acceptance"))
    references = {
        "T2": ("model-source-assessment.md", "primer-decisions.md"),
        "T3": ("guide-format.md", "HandwritingGuide.swift"),
        "T4": ("primer-reference.svg", "zaner-bloser.com"),
    }
    for reference in references[task]:
        require(reference in text, f"{issue}: lacks source reference {reference}")
    require(not re.search(r"\b(?:TODO|TBD|lorem ipsum)\b", text, re.I),
            f"{issue}: packet contains unfinished placeholders")
    return {"issue": issue, "file": str(path.relative_to(ROOT)), "sha256": digest(path)}


def validate_children(data, envelope):
    query = envelope.get("query")
    require(isinstance(query, str) and re.fullmatch(
        r"\s*project\s*=\s*CURS\s+AND\s+parent\s*=\s*CURS-1\s+ORDER\s+BY\s+key\s+ASC\s*",
        query, re.I) is not None,
        "Children evidence must use exactly: project = CURS AND parent = CURS-1 ORDER BY key ASC")
    require(data.get("isLast") is True and not data.get("nextPageToken"),
            "Epic children pagination is incomplete")
    issues = data.get("issues")
    require(isinstance(issues, list), "Epic children list is missing")
    require(len(issues) == data.get("total", len(issues)), "Epic children listing is partial")
    by_key = {issue.get("key"): issue for issue in issues}
    require(len(by_key) == len(issues), "Duplicate epic child identities")
    require(set(ISSUES) | set(PRESERVED) <= set(by_key), "Expected epic children are missing")
    for key, issue in by_key.items():
        require(re.fullmatch(r"CURS-\d+", key or "") is not None, "Wrong child project")
        fields = issue.get("fields", {})
        require(fields.get("parent", {}).get("key") == "CURS-1", f"{key}: wrong parent")
        status = fields.get("status", {}).get("name")
        require(isinstance(status, str), f"{key}: missing actual workflow status")
        if key in PRESERVED:
            require(status == "To Do", f"{key}: out-of-scope status changed")
        elif key not in ISSUES:
            require(status in ("To Do", "Done"), f"Unexpected active epic child {key}: {status}")
        else:
            require(fields.get("assignee", {}).get("displayName") == OWNER,
                    f"{key}: named human owner is missing")
            sprint_field = fields.get("customFields", {}).get("Sprint", {})
            memberships = sprint_field.get("value", [])
            require(any(s.get("id") == 119 and s.get("boardId") == 204 for s in memberships),
                    f"{key}: missing sprint 119/board 204 membership")
            require(status in ("In Review", "Done"),
                    f"{key}: actual status is {status!r}; labels and prose cannot substitute")
    return by_key


def validate_preserved_sprint_item(issue):
    require(issue.get("key") == "CURS-17" and str(issue.get("id")) == "31041",
            "Wrong preserved sprint item identity")
    fields = issue.get("fields", {})
    parent = fields.get("parent", {})
    require(parent.get("key") == "CURS-4" and str(parent.get("id")) == "31028",
            "CURS-17: preserved parent changed")
    require(fields.get("status", {}).get("name") == "In Progress",
            "CURS-17: preserved actual status changed")
    assignee = fields.get("assignee", {})
    require(assignee.get("displayName") == OWNER
            and assignee.get("accountId") == "712020:b8ee911e-5c1a-43e6-bcd7-ab242663a8b6",
            "CURS-17: preserved human owner changed")
    memberships = fields.get("customFields", {}).get("Sprint", {}).get("value", [])
    require(isinstance(memberships, list) and len(memberships) == 1
            and isinstance(memberships[0], dict)
            and memberships[0].get("id") == 119 and memberships[0].get("boardId") == 204
            and memberships[0].get("state") == "future",
            "CURS-17: preserved sprint 119/board 204 membership changed")
    return {"issue": "CURS-17", "parent": "CURS-4", "status": "In Progress",
            "sprint_id": 119, "board_id": 204}


def run_json(command):
    try:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                check=False, timeout=45)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise GateError(f"Live command could not complete: {command[0]}: {exc}") from exc
    require(result.returncode == 0, f"Live command failed: {' '.join(command)}: {result.stderr.strip()}")
    try:
        return json.loads(result.stdout)
    except ValueError as exc:
        raise GateError(f"Live command returned invalid JSON: {command[0]}") from exc


def local_head():
    result = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True,
                            text=True, check=False)
    require(result.returncode == 0, "Cannot determine local git HEAD")
    return result.stdout.strip()


def committed_review_artifacts():
    paths = ["specs/curs-1-charter.md", *(f"docs/reviews/{key}.md" for key in ISSUES)]
    for relative in paths:
        result = subprocess.run(["git", "show", f"HEAD:{relative}"],
                                cwd=ROOT, capture_output=True, check=False)
        require(result.returncode == 0,
                f"Review artifact is absent from committed HEAD: {relative}")
        path = ROOT / relative
        require(path.is_file() and path.read_bytes() == result.stdout,
                f"Review artifact differs from committed HEAD: {relative}; commit reviewed artifacts before T5")


def validate_pr(pr, head):
    require(pr.get("state") == "OPEN" and pr.get("isDraft") is False,
            "Review PR must actually be OPEN and non-draft")
    require(pr.get("baseRefName") == "main", "Review PR must target main")
    require(pr.get("headRefOid") == head, "PR head differs from current local git HEAD")
    url = pr.get("url", "")
    require(re.fullmatch(r"https://github\.com/[\w.-]+/[\w.-]+/pull/\d+", url) is not None,
            "PR URL is not canonical")
    require(url.endswith(f"/pull/{pr.get('number')}"), "PR number/URL mismatch")
    body = pr.get("body", "")
    files = {entry.get("path") for entry in pr.get("files", [])}
    for issue in ISSUES:
        path = f"docs/reviews/{issue}.md"
        require(issue in body and path in body and path in files,
                f"PR must name {issue} and include/link its specific review packet")
    require("specs/curs-1-charter.md" in files, "PR omits the canonical charter")
    return url


def validate_runs(runs, head):
    require(isinstance(runs, list), "Workflow run listing is invalid")
    selected = {}
    for workflow in ("CI", "CodeQL"):
        candidates = [run for run in runs if run.get("headSha") == head
                      and run.get("workflowName") == workflow]
        require(bool(candidates), f"No {workflow} workflow run at current PR head")
        # A duplicate dispatch/push is independent of the PR event. Require the
        # latest PR-event run when present, otherwise its latest fallback event.
        preferred = [run for run in candidates if run.get("event") == "pull_request"]
        latest = max(preferred or candidates, key=lambda run: (run.get("createdAt", ""),
                                                              run.get("databaseId", 0)))
        require(latest.get("status") == "completed" and latest.get("conclusion") == "success",
                f"Current {workflow} run is not successful: {latest.get('url', '')}")
        selected[workflow] = latest.get("url")
    return selected


def description_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return " ".join(description_text(item) for item in value.values())
    if isinstance(value, list):
        return " ".join(description_text(item) for item in value)
    return ""


def verified_acceptance_source(key, receipt):
    require(receipt.get("source_kind") == "github_comment",
            f"{key}: acceptance requires a live verifiable GitHub comment source")
    reference = receipt.get("source_reference")
    require(isinstance(reference, str), f"{key}: acceptance source URL is missing")
    match = re.fullmatch(rf"https://github\.com/{re.escape(GITHUB_REPOSITORY)}/"
                         r"(?:issues|pull)/[1-9]\d*#issuecomment-([1-9]\d*)", reference)
    require(match is not None, f"{key}: acceptance source must be a canonical repository comment URL")
    comment_id = int(match.group(1))
    source = run_json(["gh", "api", "--hostname", "github.com", "--method", "GET",
                       f"repos/{GITHUB_REPOSITORY}/issues/comments/{comment_id}"])
    require(isinstance(source, dict) and source.get("id") == comment_id
            and source.get("html_url") == reference,
            f"{key}: live acceptance comment identity differs from the receipt")
    author = source.get("user", {})
    require(isinstance(author, dict) and author.get("login") == GITHUB_OWNER
            and author.get("type") == "User"
            and source.get("performed_via_github_app", "missing") is None,
            f"{key}: acceptance comment must be authored by the owner's user account without an app")
    require(isinstance(source.get("body"), str), f"{key}: acceptance comment body is missing")
    try:
        body = json.loads(source["body"])
    except ValueError as exc:
        raise GateError(f"{key}: acceptance comment must contain a plain JSON acceptance object") from exc
    require(isinstance(body, dict) and body.get("schema") == "curs-1/human-acceptance.v1"
            and body.get("issue_key") == key and body.get("human_reviewed") is True
            and body.get("decision") == "accepted",
            f"{key}: live comment does not record current issue-specific human acceptance")
    for field in ("issue_key", "human_reviewed", "decision", "acceptance_text", "criteria"):
        require(body.get(field) == receipt.get(field),
                f"{key}: local acceptance {field} differs from the live comment")
    require(utc_time(source.get("updated_at")) == utc_time(receipt.get("accepted_at")),
            f"{key}: acceptance timestamp differs from the live comment's current revision")
    return {"comment_id": comment_id, "url": source["html_url"],
            "author": author["login"], "updated_at": source["updated_at"]}


def acceptance_receipts(evidence_dir, done_keys):
    if not done_keys:
        return {}
    data, _ = snapshot(evidence_dir, "acceptance-receipts.json")
    receipts = data.get("receipts", [])
    require(isinstance(receipts, list) and all(isinstance(receipt, dict) for receipt in receipts),
            "Acceptance receipts must be a list of objects")
    by_key = {receipt.get("issue_key"): receipt for receipt in receipts}
    require(len(by_key) == len(receipts), "Duplicate acceptance receipt identities")
    verified = {}
    for key in done_keys:
        receipt = by_key.get(key, {})
        require(receipt.get("human_reviewed") is True
                and receipt.get("accepted_by") == OWNER
                and receipt.get("decision") == "accepted",
                f"{key}: Done requires explicit human acceptance")
        require(utc_time(receipt.get("accepted_at")) <= dt.datetime.now(dt.timezone.utc),
                f"{key}: acceptance cannot be in the future")
        text, criteria = receipt.get("acceptance_text"), receipt.get("criteria")
        require(isinstance(text, str) and len(text.strip()) >= 20
                and isinstance(criteria, list) and bool(criteria)
                and all(isinstance(item, str) and bool(item.strip()) for item in criteria),
                f"{key}: acceptance evidence is empty or malformed")
        verified[key] = receipt | {"verified_source": verified_acceptance_source(key, receipt)}
    return verified


def final_delivery(evidence_dir):
    charter = validate_charter(evidence_dir)
    packets = [review_packet(task) for task in ("T2", "T3", "T4")]
    data, envelope = snapshot(evidence_dir, "children.json")
    children = validate_children(data, envelope)
    preserved, _ = snapshot(evidence_dir, "preserved-sprint-item.json")
    preserved_item = validate_preserved_sprint_item(preserved)
    committed_review_artifacts()
    head = local_head()
    done_keys = [key for key in ISSUES if children[key]["fields"]["status"]["name"] == "Done"]
    receipts = acceptance_receipts(evidence_dir, done_keys)
    review_keys = [key for key in ISSUES if children[key]["fields"]["status"]["name"] == "In Review"]
    url, checks = None, {}
    if review_keys:
        pr_evidence, _ = snapshot(evidence_dir, "pr.json")
        number = pr_evidence.get("number")
        require(isinstance(number, int) and number > 0, "PR evidence must name a positive PR number")
        pr = run_json(["gh", "pr", "view", str(number), "--json",
                       "number,state,isDraft,baseRefName,headRefOid,headRefName,url,body,files"])
        url = validate_pr(pr, head)
        for key in review_keys:
            require(url in description_text(children[key]["fields"].get("description")),
                    f"{key}: actual In Review item must link the current PR in its description")
        runs = run_json(["gh", "run", "list", "--branch", pr["headRefName"], "--limit", "100",
                         "--json", "workflowName,headSha,status,conclusion,url,databaseId,createdAt,event"])
        checks = validate_runs(runs, head)
    return {"charter": charter, "packets": packets, "head": head, "pr": url,
            "workflow_runs": checks,
            "preserved_sprint_item": preserved_item,
            "jira_statuses": {key: children[key]["fields"]["status"]["name"] for key in ISSUES},
            "human_acceptance_receipts": receipts}


def governance_projection(output):
    with frozen_runtime_entries() as entries:
        _, plan = validate_locked_inputs(entries)
        require("state" in entries, "Governance projection requires an initialized controller state")
        state = runtime_json(entries, "state")
    projection = copy.deepcopy(plan)
    projection["iteration"] = state["iteration"]
    projection["controller_state"] = str(STATE.relative_to(ROOT))
    projection["controller_status"] = state["status"]
    status_map = {"pending": "todo", "in_progress": "in_progress", "verifying": "in_progress",
                  "verified": "done", "escalated": "blocked", "waived": "waived"}
    for task, controller in zip(projection["tasks"], state["tasks"]):
        status = controller.get("status")
        require(status in status_map, f"Unknown controller state {status}")
        if status == "verified":
            checks = [entry for entry in controller.get("evidence", [])
                      if entry.get("phase") == "verify-run"]
            require(bool(checks), f"{task['id']}: no controller-run verification evidence")
            last = checks[-1].get("checks", [])
            require([check.get("cmd") for check in last] == [check["cmd"] for check in task["verification"]]
                    and all(check.get("passed") is True and check.get("exit") == 0 for check in last),
                    f"{task['id']}: verified state lacks successful frozen check receipts")
        task["status"] = status_map[status]
        task["attempts"] = controller.get("attempts", 0)
        task["controller_evidence"] = controller.get("evidence", [])
        task["evidence"] = json.dumps(controller.get("evidence", []), sort_keys=True) if controller.get("evidence") else ""
        if "waive_reason" in controller:
            task["waive_reason"] = controller["waive_reason"]
    output = Path(output)
    require(".." not in output.parts, "Governance output must not contain path traversal")
    if not output.is_absolute():
        output = ROOT / output
    require(RUN == ROOT / ".agent-harness" and output.parent == RUN,
            "Governance output must be a fresh direct child of this repository's .agent-harness directory")
    require(output not in (PLAN, STATE, LOCK),
            "Governance output must be separate from locked inputs and controller state")
    require(not output.exists() and not output.is_symlink(),
            "Governance output already exists; preserve it and choose a fresh path")
    payload = json.dumps(projection, indent=2) + "\n"
    try:
        # Anchor exclusive creation to the actual RUN directory, without following
        # a directory symlink or any existing file, including a raced-in symlink.
        directory = os.open(RUN, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            descriptor = os.open(output.name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                                 mode=0o600, dir_fd=directory)
            with os.fdopen(descriptor, "w", encoding="utf-8") as destination:
                destination.write(payload)
        finally:
            os.close(directory)
    except OSError as exc:
        raise GateError(f"Cannot create fresh governance output inside .agent-harness: {exc}") from exc
    return {"governance_output": str(output), "statuses": {t["id"]: t["status"] for t in projection["tasks"]}}


class FailureCases(unittest.TestCase):
    """Exercise rejection behavior before freeze, without live Jira or GitHub."""

    @contextlib.contextmanager
    def lock_fixture(self):
        """Prepare honest frozen inputs and initialized state in a disposable root."""
        source = ROOT
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            run = root / ".agent-harness"
            run.mkdir()
            frozen = ["scripts/check_curs_1_delivery.py", "scripts/prepare-curs-1-harness.py",
                      "specs/harness/curs-1-manifest.json", "specs/harness/curs-1-plan.json",
                      "docs/curs-1-harness.md", "scripts/check_repository.py", "scripts/lint.sh",
                      "scripts/test-portable.py"]
            for relative in frozen:
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((source / relative).read_bytes())
            harness = root / "custom controller skill"
            pm = root / "custom PM skills"
            for skill in (harness, pm / "pm-skills", pm / "jira-expert", pm / "confluence-expert"):
                skill.mkdir(parents=True)
                (skill / "SKILL.md").write_text("# Installed fixture skill\n", encoding="utf-8")
            controller = harness / "scripts/loop_controller.py"
            governance = pm / "pm-skills/scripts/delivery_loop_gate.py"
            for path in (controller, governance):
                path.parent.mkdir()
                path.write_text("# Frozen fixture plugin\n", encoding="utf-8")
            for name in ("manifest", "plan"):
                raw = (source / f"specs/harness/curs-1-{name}.json").read_text(encoding="utf-8")
                (run / f"curs-1-{name}.json").write_text(raw.replace("${PM_SKILLS_DIR}", str(pm)), encoding="utf-8")
                frozen.append(f".agent-harness/curs-1-{name}.json")
            frozen += [str(controller), str(governance)]
            hashes = {name: hashlib.sha256((Path(name) if Path(name).is_absolute()
                                           else root / name).read_bytes()).hexdigest() for name in frozen}
            lock = {"schema": "curs-1/check-lock.v1", "controller": str(controller),
                    "governance_gate": str(governance), "sha256": hashes}
            (run / "curs-1-lock.json").write_text(json.dumps(lock), encoding="utf-8")
            plan = read_json(run / "curs-1-plan.json")
            state = {"schema": "agent-harness/state.v1", "max_loop_iterations": 12,
                     "tasks": [{"id": task["id"], "verification": task["verification"], "max_attempts": 3}
                               for task in plan["tasks"]]}
            (run / "curs-1-state.json").write_text(json.dumps(state), encoding="utf-8")
            with mock.patch.multiple(__name__, ROOT=root, RUN=run, LOCK=run / "curs-1-lock.json",
                                     PLAN=run / "curs-1-plan.json", STATE=run / "curs-1-state.json"):
                yield root, run

    def test_lock_accepts_honest_initialized_inputs_and_preinit_state_absence(self):
        with self.lock_fixture() as (_, _):
            self.assertEqual([task["id"] for task in lock_check()[1]["tasks"]], ["T1", "T2", "T3", "T4", "T5"])
            STATE.unlink()
            self.assertEqual(lock_check()[1]["scope"]["issue_keys"], ["CURS-6", "CURS-7", "CURS-8"])

    def test_lock_rejects_reserved_file_symlinks_after_initialization(self):
        for name in ("manifest", "plan", "lock", "state"):
            with self.subTest(name=name), self.lock_fixture() as (root, run):
                original = run / f"curs-1-{name}.json"
                redirected = root / f"redirected-{name}.json"
                original.rename(redirected)
                original.symlink_to(redirected)
                with self.assertRaises(GateError):
                    lock_check()

    def test_lock_rejects_runtime_directory_and_dangling_state_symlinks(self):
        for kind in ("runtime", "dangling state"):
            with self.subTest(kind=kind), self.lock_fixture() as (root, run):
                if kind == "runtime":
                    redirected = root / "redirected-runtime"
                    run.rename(redirected)
                    run.symlink_to(redirected, target_is_directory=True)
                else:
                    STATE.unlink()
                    STATE.symlink_to(root / "missing-state.json")
                with self.assertRaises(GateError):
                    lock_check()

    def test_lock_rejects_unrelated_or_swapped_plugin_role_references(self):
        with self.lock_fixture() as (_, _):
            original = read_json(LOCK)
            for changes in ({"controller": "scripts/lint.sh", "governance_gate": "scripts/check_repository.py"},
                            {"controller": original["governance_gate"]},
                            {"governance_gate": original["controller"]}):
                LOCK.write_text(json.dumps(original | changes), encoding="utf-8")
                with self.subTest(changes=changes), self.assertRaises(GateError):
                    lock_check()

    def test_lock_requires_installed_controller_skill_identity(self):
        with self.lock_fixture() as (_, _):
            controller = Path(read_json(LOCK)["controller"])
            (controller.parent.parent / "SKILL.md").unlink()
            with self.assertRaises(GateError):
                lock_check()

    def test_lock_rejects_missing_frozen_input_with_invalid_digest(self):
        with self.lock_fixture() as (root, _):
            (root / "docs/curs-1-harness.md").unlink()
            lock = read_json(LOCK)
            lock["sha256"]["docs/curs-1-harness.md"] = None
            LOCK.write_text(json.dumps(lock), encoding="utf-8")
            with self.assertRaises(GateError):
                lock_check()

    def test_lock_rejects_state_appearing_during_validation(self):
        for kind in ("regular state", "dangling symlink"):
            with self.subTest(kind=kind), self.lock_fixture() as (root, _):
                original = STATE.read_bytes()
                STATE.unlink()
                with self.assertRaises(GateError):
                    with frozen_runtime_entries() as entries:
                        validate_locked_inputs(entries)
                        if kind == "regular state":
                            STATE.write_bytes(original)
                        else:
                            STATE.symlink_to(root / "missing-state.json")

    def test_lock_rejects_nonregular_metadata_without_leaking_descriptor(self):
        with self.lock_fixture() as (_, _):
            STATE.unlink()
            STATE.mkdir()
            before = len(list(Path("/dev/fd").iterdir()))
            with self.assertRaises(GateError):
                lock_check()
            self.assertEqual(len(list(Path("/dev/fd").iterdir())), before)

    def test_lock_requires_all_canonical_executable_digests(self):
        with self.lock_fixture() as (_, _):
            original = read_json(LOCK)
            for relative in ("scripts/check_repository.py", "scripts/lint.sh", "scripts/test-portable.py"):
                lock = copy.deepcopy(original)
                del lock["sha256"][relative]
                LOCK.write_text(json.dumps(lock), encoding="utf-8")
                with self.subTest(relative=relative), self.assertRaises(GateError):
                    lock_check()

    @contextlib.contextmanager
    def governance_fixture(self):
        """Use honest locked inputs, real controller receipts and filesystem writes."""
        with self.lock_fixture() as (root, run):
            plan = read_json(PLAN)
            state = {"schema": "agent-harness/state.v1", "max_loop_iterations": 12,
                "iteration": 10, "status": "closed", "tasks": [
                {"id": task["id"], "status": "verified", "attempts": 1,
                 "max_attempts": 3, "verification": task["verification"],
                 "evidence": [{"phase": "verify-run", "checks": [
                     {"cmd": check["cmd"], "exit": 0, "passed": True}
                     for check in task["verification"]]}]} for task in plan["tasks"]]}
            STATE.write_text(json.dumps(state), encoding="utf-8")
            yield root, run

    def test_governance_projection_uses_the_validated_state_snapshot(self):
        with self.governance_fixture() as (root, run):
            replacement = root / "unvalidated-state.json"
            state = read_json(STATE)
            state["iteration"] = 11
            replacement.write_text(json.dumps(state), encoding="utf-8")
            reader = frozen_runtime_entries

            @contextlib.contextmanager
            def replace_state_after_validation():
                with reader() as entries:
                    yield entries
                STATE.rename(root / "validated-state.json")
                STATE.symlink_to(replacement)

            output = run / "curs-1-governance-pinned-state.json"
            with mock.patch(__name__ + ".frozen_runtime_entries", replace_state_after_validation):
                governance_projection(output)
            self.assertTrue(STATE.is_symlink())
            self.assertEqual(read_json(output)["iteration"], 10)

    def test_governance_output_cannot_overwrite_repository_files(self):
        with self.governance_fixture() as (root, _):
            charter = root / "specs/curs-1-charter.md"
            charter.parent.mkdir(exist_ok=True)
            original = b"Existing canonical charter must remain unchanged.\n"
            charter.write_bytes(original)
            error = None
            try:
                governance_projection(charter)
            except GateError as exc:
                error = exc
            self.assertEqual(charter.read_bytes(), original)
            self.assertIsInstance(error, GateError)

    def test_governance_output_cannot_overwrite_history_or_reserved_paths(self):
        with self.governance_fixture() as (_, run):
            old = run / "curs-1-governance.json"
            old.write_bytes(b"Historical governance projection\n")
            for output in (old, PLAN, STATE, LOCK):
                original = output.read_bytes()
                error = None
                try:
                    governance_projection(output)
                except GateError as exc:
                    error = exc
                with self.subTest(path=output.name):
                    self.assertEqual(output.read_bytes(), original)
                    self.assertIsInstance(error, GateError)

    def test_governance_output_rejects_traversal_and_symlink_escape(self):
        with self.governance_fixture() as (root, run):
            outside = root / "outside"
            outside.mkdir()
            (run / "escape").symlink_to(outside, target_is_directory=True)
            for output in (run / "../outside/traversal.json", run / "escape/symlink.json"):
                with self.subTest(output=output), self.assertRaises(GateError):
                    governance_projection(output)
            self.assertEqual(list(outside.iterdir()), [])

    def test_governance_output_creates_fresh_projection_inside_run(self):
        with self.governance_fixture() as (_, run):
            before = {path: path.read_bytes() for path in (PLAN, STATE, LOCK)}
            output = run / "curs-1-governance-review-2.json"
            result = governance_projection(output)
            self.assertEqual(result["statuses"], {
                "T1": "done", "T2": "done", "T3": "done", "T4": "done", "T5": "done"})
            projection = read_json(output)
            self.assertEqual(projection["iteration"], 10)
            self.assertEqual(projection["controller_status"], "closed")
            self.assertEqual(projection["controller_state"], ".agent-harness/curs-1-state.json")
            self.assertEqual({path: path.read_bytes() for path in before}, before)

    def test_governance_output_requires_direct_run_child(self):
        with self.governance_fixture() as (_, run):
            with self.assertRaises(GateError):
                governance_projection(run / "history/new-governance.json")
            self.assertFalse((run / "history").exists())

    def test_governance_output_accepts_relative_run_path(self):
        with self.governance_fixture() as (root, run):
            previous = Path.cwd()
            try:
                os.chdir(root)
                governance_projection(Path(".agent-harness/curs-1-governance-next.json"))
            finally:
                os.chdir(previous)
            projection = read_json(run / "curs-1-governance-next.json")
            self.assertEqual(projection["controller_status"], "closed")
            self.assertEqual(projection["iteration"], 10)

    def test_governance_output_rejects_symlink_file_or_run_directory(self):
        with self.governance_fixture() as (root, run):
            outside = root / "outside"
            outside.mkdir()
            existing = outside / "existing.json"
            existing.write_bytes(b"Outside content\n")
            alias = run / "symlink-governance.json"
            alias.symlink_to(existing)
            with self.assertRaises(GateError):
                governance_projection(alias)
            self.assertEqual(existing.read_bytes(), b"Outside content\n")
            original_state = STATE.read_bytes()
            run.rename(root / "original-run")
            run.symlink_to(outside, target_is_directory=True)
            (outside / "curs-1-state.json").write_bytes(original_state)
            with self.assertRaises(GateError):
                governance_projection(run / "new-governance.json")
            self.assertFalse((outside / "new-governance.json").exists())

    @contextlib.contextmanager
    def delivery_fixture(self, statuses=("Done", "Done", "Done")):
        """Use real publication/artifact checks and replace only external APIs."""
        source_root = ROOT
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = ["specs/curs-1-charter.md", *(f"docs/reviews/{key}.md" for key in ISSUES)]
            for relative in paths:
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((source_root / relative).read_bytes())
            for command in (["git", "init", "-q"],
                            ["git", "config", "user.name", "Gate Test"],
                            ["git", "config", "user.email", "gate@example.invalid"],
                            ["git", "add", "--", *paths],
                            ["git", "commit", "-qm", "Synthetic delivery fixture"]):
                subprocess.run(command, cwd=root, check=True, capture_output=True)
            head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root,
                                           text=True).strip()
            evidence = root / "evidence"
            evidence.mkdir()
            now = dt.datetime.now(dt.timezone.utc).isoformat()

            def write_snapshot(name, data, query="synthetic test fixture"):
                (evidence / name).write_text(json.dumps({
                    "captured_at": now, "cloud_id": CLOUD, "query": query,
                    "response": {"data": data}}), encoding="utf-8")

            url = "https://github.com/example/project/pull/10"
            write_snapshot("epic.json", {"id": "31025", "key": "CURS-1", "fields": {
                "issuetype": {"name": "Epic"}, "status": {"name": "In Progress"},
                "assignee": {"displayName": "Adam Schoen"},
                "description": "https://tasteslikegood.atlassian.net/wiki/spaces/CURS/pages/87916545/CURS-1+model+foundation+charter"}})
            write_snapshot("sprint.json", {"isLast": True, "total": 1, "values": [{
                "id": 119, "originBoardId": 204, "name": "Cursivly 01 - Model foundation",
                "state": "future"}]})
            write_snapshot("confluence-space.json", {"key": "CURS", "status": "current",
                "id": "87785474", "webUrl": "https://tasteslikegood.atlassian.net/wiki/spaces/CURS"})
            write_snapshot("confluence-charter.json", {"type": "page", "status": "current",
                "id": "87916545", "spaceId": "87785474",
                "title": "CURS-1 model foundation charter", "body": {"format": "markdown",
                "value": (root / "specs/curs-1-charter.md").read_text(encoding="utf-8")}})
            children = []
            for key, status in zip((*ISSUES, *PRESERVED), (*statuses, "To Do", "To Do", "To Do")):
                children.append({"key": key, "fields": {"parent": {"key": "CURS-1"},
                    "status": {"name": status}, "assignee": {"displayName": "Adam Schoen"},
                    "description": url,
                    "customFields": {"Sprint": {"value": [{"id": 119, "boardId": 204}]}}}})
            write_snapshot("children.json", {"isLast": True, "total": 6, "issues": children},
                           "project = CURS AND parent = CURS-1 ORDER BY key ASC")
            write_snapshot("preserved-sprint-item.json", {"key": "CURS-17", "id": "31041", "fields": {
                "parent": {"key": "CURS-4", "id": "31028"}, "status": {"name": "In Progress"},
                "assignee": {"displayName": "Adam Schoen", "accountId": "712020:b8ee911e-5c1a-43e6-bcd7-ab242663a8b6"}, "customFields": {"Sprint": {
                "value": [{"id": 119, "boardId": 204, "state": "future"}]}}}})
            receipts = [{"issue_key": key, "human_reviewed": True, "accepted_by": "Adam Schoen",
                "decision": "accepted", "accepted_at": now,
                "acceptance_text": "Synthetic owner acceptance of the issue-specific criteria.",
                "criteria": ["Synthetic criterion reviewed"], "source_kind": "github_comment",
                "source_reference": f"https://github.com/adamtasteslikegood/cursiveDrawingApp01011/pull/10#issuecomment-{100001 + index}"}
                for index, (key, status) in enumerate(zip(ISSUES, statuses)) if status == "Done"]
            write_snapshot("acceptance-receipts.json", {"receipts": receipts})
            if "In Review" in statuses:
                write_snapshot("pr.json", {"number": 10})
            pr = {"number": 10, "state": "OPEN", "isDraft": False, "baseRefName": "main",
                "headRefOid": head, "headRefName": "review-fixture", "url": url,
                "body": "CURS-6 docs/reviews/CURS-6.md CURS-7 docs/reviews/CURS-7.md CURS-8 docs/reviews/CURS-8.md",
                "files": [{"path": relative} for relative in paths]}
            runs = [{"workflowName": name, "headSha": head, "event": "pull_request",
                "createdAt": now, "databaseId": index, "status": "completed",
                "conclusion": "success", "url": f"https://example.invalid/run/{index}"}
                for index, name in enumerate(("CI", "CodeQL"), 1)]
            comments = {}
            for receipt in receipts:
                comment_id = int(receipt["source_reference"].split("#issuecomment-")[1])
                body = {name: receipt[name] for name in (
                    "issue_key", "human_reviewed", "decision", "acceptance_text", "criteria")}
                body["schema"] = "curs-1/human-acceptance.v1"
                comments[str(comment_id)] = {"id": comment_id, "html_url": receipt["source_reference"],
                    "url": f"https://api.github.com/repos/adamtasteslikegood/cursiveDrawingApp01011/issues/comments/{comment_id}",
                    "issue_url": "https://api.github.com/repos/adamtasteslikegood/cursiveDrawingApp01011/issues/10",
                    "user": {"login": "adamtasteslikegood", "type": "User", "id": 1},
                    "created_at": now, "updated_at": now, "body": json.dumps(body),
                    "author_association": "OWNER", "performed_via_github_app": None}
            (root / "api.json").write_text(json.dumps({"pr": pr, "runs": runs, "comments": comments}), encoding="utf-8")
            bindir = root / "bin"
            bindir.mkdir()
            gh = bindir / "gh"
            gh.write_text(f"#!{sys.executable}\nimport json, sys\nfrom pathlib import Path\n"
                          f"data = json.loads(Path({str(root / 'api.json')!r}).read_text())\n"
                          "args = sys.argv[1:]\n"
                          "if data.get('forbid_review_queries') and args[0] in ('pr', 'run'):\n    sys.exit(99)\n"
                          "if len(args) == 6 and args[:5] == ['api', '--hostname', 'github.com', '--method', 'GET']:\n"
                          "    prefix = 'repos/adamtasteslikegood/cursiveDrawingApp01011/issues/comments/'\n"
                          "    if not args[5].startswith(prefix):\n        sys.exit(98)\n"
                          "    comment_id = args[5][len(prefix):]\n"
                          "    if comment_id in data.get('api_errors', {}) or comment_id not in data['comments']:\n"
                          "        print('HTTP denied or not found', file=sys.stderr)\n        sys.exit(1)\n"
                          "    print(json.dumps(data['comments'][comment_id]))\n"
                          "elif args[:3] == ['pr', 'view', '10']:\n    print(json.dumps(data['pr']))\n"
                          "elif args[:2] == ['run', 'list']:\n    print(json.dumps(data['runs']))\n"
                          "else:\n    sys.exit(98)\n", encoding="utf-8")
            gh.chmod(0o755)
            with mock.patch(__name__ + ".ROOT", root), mock.patch.dict(
                    os.environ, {"PATH": str(bindir) + os.pathsep + os.environ.get("PATH", "")}):
                yield root, evidence, head

    def test_done_only_requires_receipts_without_review_pr(self):
        with self.delivery_fixture() as (root, evidence, head):
            # Done-only still reads its acceptance source, without PR/workflow queries.
            path = root / "api.json"
            api = read_json(path)
            api["forbid_review_queries"] = True
            path.write_text(json.dumps(api), encoding="utf-8")
            try:
                result = final_delivery(evidence)
            except GateError as exc:
                self.fail(f"Valid Done-only acceptance was rejected: {exc}")
            self.assertEqual(result["jira_statuses"], {
                "CURS-6": "Done", "CURS-7": "Done", "CURS-8": "Done"})
            self.assertEqual(set(result["human_acceptance_receipts"]), {"CURS-6", "CURS-7", "CURS-8"})
            self.assertIsNone(result["pr"])
            self.assertEqual(result["workflow_runs"], {})
            self.assertEqual(result["head"], head)

    def test_done_only_rejects_missing_or_invalid_human_receipts(self):
        with self.delivery_fixture() as (_, evidence, _):
            path = evidence / "acceptance-receipts.json"
            valid = read_json(path)
            for changes in ({"human_reviewed": False}, {"accepted_by": "Agent"},
                            {"criteria": []}, {"source_reference": ""}):
                broken = copy.deepcopy(valid)
                broken["response"]["data"]["receipts"][0].update(changes)
                path.write_text(json.dumps(broken), encoding="utf-8")
                with self.subTest(changes=changes), self.assertRaises(GateError):
                    final_delivery(evidence)
            path.unlink()
            with self.assertRaisesRegex(GateError, "acceptance-receipts.json"):
                final_delivery(evidence)

    def test_done_rejects_receipts_without_live_verified_source(self):
        with self.delivery_fixture() as (_, evidence, _):
            path = evidence / "acceptance-receipts.json"
            valid = read_json(path)
            for kind in ("user_message", "jira_comment", "confluence_page"):
                broken = copy.deepcopy(valid)
                broken["response"]["data"]["receipts"][0].update({
                    "source_kind": kind, "source_reference": "locally-invented-human-acceptance"})
                path.write_text(json.dumps(broken), encoding="utf-8")
                with self.subTest(kind=kind), self.assertRaises(GateError):
                    acceptance_receipts(evidence, ["CURS-6"])

    def test_live_acceptance_source_requires_owner_and_current_acceptance(self):
        with self.delivery_fixture() as (root, evidence, _):
            path = root / "api.json"
            valid = read_json(path)
            source = valid["comments"]["100001"]
            body = json.loads(source["body"])
            changes = [
                {"id": 100002}, {"html_url": "https://github.com/other/project/issues/1#issuecomment-100001"},
                {"user": {"login": "another-person", "type": "User"}},
                {"user": {"login": "adamtasteslikegood", "type": "Bot"}},
                {"performed_via_github_app": {"id": 1}}, {"body": "No JSON acceptance object"},
                {"body": "[]"},
                {"updated_at": (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=1)).isoformat()},
            ]
            changes.extend({"body": json.dumps(body | replacement)} for replacement in (
                {"schema": "another-schema"}, {"issue_key": "CURS-7"}, {"human_reviewed": False},
                {"decision": "revoked"}, {"acceptance_text": "Owner edited this acceptance after the local receipt."},
                {"criteria": ["A different criterion"]}))
            for change in changes:
                broken = copy.deepcopy(valid)
                broken["comments"]["100001"].update(change)
                path.write_text(json.dumps(broken), encoding="utf-8")
                with self.subTest(change=change), self.assertRaises(GateError):
                    acceptance_receipts(evidence, ["CURS-6"])
            path.write_text(json.dumps(valid), encoding="utf-8")
            result = acceptance_receipts(evidence, ["CURS-6"])
            self.assertEqual(result["CURS-6"].get("verified_source"), {
                "comment_id": 100001, "url": source["html_url"],
                "author": "adamtasteslikegood", "updated_at": source["updated_at"]})

    def test_live_acceptance_source_missing_or_denied_blocks_done(self):
        with self.delivery_fixture() as (root, evidence, _):
            path = root / "api.json"
            valid = read_json(path)
            missing = copy.deepcopy(valid)
            missing["comments"].pop("100001")
            denied = copy.deepcopy(valid) | {"api_errors": {"100001": 403}}
            for api in (missing, denied):
                path.write_text(json.dumps(api), encoding="utf-8")
                with self.subTest(api=api.get("api_errors", "missing")), self.assertRaises(GateError):
                    acceptance_receipts(evidence, ["CURS-6"])

    def test_local_receipt_must_match_verified_comment(self):
        with self.delivery_fixture() as (_, evidence, _):
            path = evidence / "acceptance-receipts.json"
            valid = read_json(path)
            for change in (
                {"source_reference": "https://github.com/other/project/pull/10#issuecomment-100001"},
                {"source_reference": "https://github.example/adamtasteslikegood/cursiveDrawingApp01011/pull/10#issuecomment-100001"},
                {"source_reference": "https://github.com/adamtasteslikegood/cursiveDrawingApp01011/pull/10#discussion_r100001"},
                {"accepted_at": (dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=1)).isoformat()},
                {"acceptance_text": "Locally fabricated acceptance text differs from the source."},
                {"criteria": ["Locally fabricated accepted criterion"]},
            ):
                broken = copy.deepcopy(valid)
                broken["response"]["data"]["receipts"][0].update(change)
                path.write_text(json.dumps(broken), encoding="utf-8")
                with self.subTest(change=change), self.assertRaises(GateError):
                    acceptance_receipts(evidence, ["CURS-6"])

    def test_acceptance_requires_substantive_text_and_string_criteria(self):
        with self.delivery_fixture() as (root, evidence, _):
            local_path, api_path = evidence / "acceptance-receipts.json", root / "api.json"
            local, api = read_json(local_path), read_json(api_path)
            for change in ({"criteria": [""]}, {"criteria": [42]}, {"criteria": "criterion"},
                           {"criteria": []}, {"acceptance_text": "accepted"}):
                receipt, source = copy.deepcopy(local), copy.deepcopy(api)
                receipt["response"]["data"]["receipts"][0].update(change)
                comment = source["comments"]["100001"]
                comment["body"] = json.dumps(json.loads(comment["body"]) | change)
                local_path.write_text(json.dumps(receipt), encoding="utf-8")
                api_path.write_text(json.dumps(source), encoding="utf-8")
                with self.subTest(change=change), self.assertRaises(GateError):
                    acceptance_receipts(evidence, ["CURS-6"])

    def test_mixed_delivery_keeps_review_pr_ci_and_done_receipts(self):
        with self.delivery_fixture(("Done", "In Review", "In Review")) as (root, evidence, head):
            result = final_delivery(evidence)
            self.assertEqual(result["pr"], "https://github.com/example/project/pull/10")
            self.assertEqual(result["head"], head)
            self.assertEqual(result["workflow_runs"], {
                "CI": "https://example.invalid/run/1", "CodeQL": "https://example.invalid/run/2"})
            self.assertEqual(set(result["human_acceptance_receipts"]), {"CURS-6"})
            path = root / "api.json"
            valid = read_json(path)
            for changes in ({"state": "MERGED"}, {"state": "CLOSED"},
                            {"isDraft": True}, {"headRefOid": "old"}):
                broken = copy.deepcopy(valid)
                broken["pr"].update(changes)
                path.write_text(json.dumps(broken), encoding="utf-8")
                with self.subTest(changes=changes), self.assertRaises(GateError):
                    final_delivery(evidence)
            broken = copy.deepcopy(valid)
            broken["runs"][0]["conclusion"] = "failure"
            path.write_text(json.dumps(broken), encoding="utf-8")
            with self.assertRaisesRegex(GateError, "CI run is not successful"):
                final_delivery(evidence)
            path.write_text(json.dumps(valid), encoding="utf-8")
            (evidence / "acceptance-receipts.json").unlink()
            with self.assertRaisesRegex(GateError, "acceptance-receipts.json"):
                final_delivery(evidence)

    def test_review_only_does_not_require_done_acceptance_receipts(self):
        with self.delivery_fixture(("In Review", "In Review", "In Review")) as (_, evidence, _):
            (evidence / "acceptance-receipts.json").unlink()
            result = final_delivery(evidence)
            self.assertEqual(result["human_acceptance_receipts"], {})
            self.assertEqual(result["pr"], "https://github.com/example/project/pull/10")

    def test_review_artifacts_must_exist_in_committed_head(self):
        with self.delivery_fixture() as (root, _, _):
            committed_review_artifacts()
            charter = root / "specs/curs-1-charter.md"
            original = charter.read_bytes()
            charter.write_bytes(original + b"\nLocal uncommitted change\n")
            with self.assertRaises(GateError):
                committed_review_artifacts()
            charter.write_bytes(original)
            subprocess.run(["git", "rm", "--cached", "--", "docs/reviews/CURS-7.md"],
                           cwd=root, check=True, capture_output=True)
            subprocess.run(["git", "commit", "-qm", "Remove tracked review packet"],
                           cwd=root, check=True, capture_output=True)
            # The review is present locally, but cannot be fetched from this HEAD.
            with self.assertRaises(GateError):
                committed_review_artifacts()

    def test_epic_must_link_its_published_charter_page(self):
        with self.delivery_fixture() as (_, evidence, _):
            path = evidence / "epic.json"
            envelope = read_json(path)
            for description in ("No publication link", "https://tasteslikegood.atlassian.net/wiki/spaces/CURS/pages/879165450",
                                "https://tasteslikegood.atlassian.net/wiki/spaces/OTHER/pages/87916545"):
                envelope["response"]["data"]["fields"]["description"] = description
                path.write_text(json.dumps(envelope), encoding="utf-8")
                with self.subTest(description=description), self.assertRaises(GateError):
                    validate_charter(evidence)
            for description in (
                "https://tasteslikegood.atlassian.net/wiki/spaces/CURS/pages/87916545",
                {"type": "doc", "content": [{"type": "paragraph", "content": [{"type": "text",
                    "text": "Charter", "marks": [{"type": "link", "attrs": {"href":
                    "https://tasteslikegood.atlassian.net/wiki/spaces/CURS/pages/87916545/CURS-1+model+foundation+charter"}}]}]}]},
            ):
                envelope["response"]["data"]["fields"]["description"] = description
                path.write_text(json.dumps(envelope), encoding="utf-8")
                with self.subTest(description=description):
                    self.assertEqual(validate_charter(evidence)["page_id"], "87916545")

    def test_preserved_sprint_item_cannot_be_changed(self):
        with self.delivery_fixture() as (_, evidence, _):
            path = evidence / "preserved-sprint-item.json"
            valid = read_json(path)
            mutations = (
                (("key",), "CURS-99"), (("id",), "99999"),
                (("fields", "parent", "key"), "CURS-1"),
                (("fields", "parent", "id"), "31025"),
                (("fields", "status", "name"), "Done"),
                (("fields", "assignee", "displayName"), "Agent"),
                (("fields", "assignee", "accountId"), "another-human"),
                (("fields", "customFields", "Sprint", "value"), []),
                (("fields", "customFields", "Sprint", "value"), [None]),
                (("fields", "customFields", "Sprint", "value"), [{"id": 118, "boardId": 204, "state": "future"}]),
                (("fields", "customFields", "Sprint", "value"), [{"id": 119, "boardId": 205, "state": "future"}]),
                (("fields", "customFields", "Sprint", "value"), [{"id": 119, "boardId": 204, "state": "active"}]),
                (("fields", "customFields", "Sprint", "value"), [{"id": 119, "boardId": 204, "state": "future"},
                                                                      {"id": 118, "boardId": 204, "state": "future"}]),
            )
            for keys, value in mutations:
                broken = copy.deepcopy(valid)
                cursor = broken["response"]["data"]
                for key in keys[:-1]:
                    cursor = cursor[key]
                cursor[keys[-1]] = value
                path.write_text(json.dumps(broken), encoding="utf-8")
                with self.subTest(field=keys, value=value):
                    try:
                        final_delivery(evidence)
                    except Exception as exc:
                        self.assertIsInstance(exc, GateError)
                    else:
                        self.fail("Changed preserved sprint item was accepted")
            path.write_text(json.dumps(valid), encoding="utf-8")
            result = final_delivery(evidence)
            self.assertEqual(result.get("preserved_sprint_item"), {
                "issue": "CURS-17", "parent": "CURS-4", "status": "In Progress",
                "sprint_id": 119, "board_id": 204})
            self.assertNotIn("CURS-17", result["jira_statuses"])
            self.assertNotIn("CURS-17", result["human_acceptance_receipts"])

    def test_preserved_sprint_item_requires_fresh_readback(self):
        with self.delivery_fixture() as (_, evidence, _):
            path = evidence / "preserved-sprint-item.json"
            valid = read_json(path)
            path.unlink()
            with self.assertRaisesRegex(GateError, "preserved-sprint-item.json"):
                final_delivery(evidence)
            valid["captured_at"] = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=1)).isoformat()
            path.write_text(json.dumps(valid), encoding="utf-8")
            with self.assertRaisesRegex(GateError, "preserved-sprint-item.json.*stale"):
                final_delivery(evidence)

    def test_snapshot_stale_denied_wrong_cloud(self):
        now = dt.datetime.now(dt.timezone.utc)
        base = {"captured_at": now.isoformat(), "cloud_id": CLOUD, "query": "test",
                "response": {"data": {"key": "CURS-1"}}}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.json"
            path.write_text(json.dumps(base))
            self.assertEqual(snapshot(Path(directory), "test.json", now)[0]["key"], "CURS-1")
            for changes in ({"captured_at": (now - dt.timedelta(hours=1)).isoformat()},
                            {"cloud_id": "another-cloud"},
                            {"response": {"error": "Permission denied"}},
                            {"response": {"data": {"errors": ["unauthorized"]}}}):
                path.write_text(json.dumps(base | changes))
                with self.assertRaises(GateError):
                    snapshot(Path(directory), "test.json", now)

    def test_semantic_publication_retains_content_and_links(self):
        source = "## Scope\n\n1. **Adam** reviews [CURS-6](https://example/CURS-6).\n| Item | Result |\n| --- | --- |\n| CURS-7 | Review |"
        normalized = "# Scope\n\n- Adam reviews [CURS-6](https://example/CURS-6).\nItem | Result\nCURS-7 | Review"
        self.assertEqual(semantic_markdown(source), semantic_markdown(normalized))
        self.assertNotEqual(semantic_markdown(source), semantic_markdown(normalized.replace("CURS-7", "CURS-8")))
        self.assertNotEqual(semantic_markdown(source), semantic_markdown(normalized.replace("https://example", "https://other")))

    def test_actual_jira_status_and_complete_scope(self):
        issues = []
        for key in (*ISSUES, *PRESERVED):
            issues.append({"key": key, "fields": {"parent": {"key": "CURS-1"},
                "status": {"name": "In Review" if key in ISSUES else "To Do"},
                "assignee": {"displayName": OWNER},
                "customFields": {"Sprint": {"value": [{"id": 119, "boardId": 204}]}}}})
        data = {"isLast": True, "issues": issues}
        envelope = {"query": "project = CURS AND parent = CURS-1 ORDER BY key ASC"}
        self.assertEqual(len(validate_children(data, envelope)), 6)
        self.assertEqual(len(validate_children(data, {"query":
            "\n project=CURS\tand parent = curs-1\norder BY key asc\n"})), 6)
        for query in (
            "project = CURS AND parent = CURS-1 AND key IN (CURS-6, CURS-7, CURS-8) ORDER BY key ASC",
            "project = CURS AND parent = CURS-1 AND status = 'In Review' ORDER BY key ASC",
            "project = CURS AND parent = CURS-1 ORDER BY key DESC",
            "project = CURS AND parent = CURS-1 ORDER BY key ASC; other query",
        ):
            with self.subTest(narrowed_query=query), self.assertRaises(GateError):
                validate_children(data, {"query": query})
        for mutation in ("partial", "label", "unexpected", "preserved", "missing"):
            broken = copy.deepcopy(data)
            if mutation == "partial":
                broken["isLast"] = False
            elif mutation == "label":
                broken["issues"][0]["fields"]["status"]["name"] = "In Progress"
                broken["issues"][0]["fields"]["labels"] = ["In Review"]
            elif mutation == "unexpected":
                broken["issues"].append({"key": "CURS-99", "fields": {
                    "parent": {"key": "CURS-1"}, "status": {"name": "In Progress"}}})
            elif mutation == "preserved":
                broken["issues"][-1]["fields"]["status"]["name"] = "Done"
            else:
                broken["issues"].pop()
            with self.subTest(mutation=mutation), self.assertRaises(GateError):
                validate_children(broken, envelope)

    def test_unknown_inactive_children_are_outside_active_delivery_scope(self):
        with self.delivery_fixture() as (_, evidence, _):
            envelope = read_json(evidence / "children.json")
            for status, allowed in (("To Do", True), ("Done", True), ("In Progress", False),
                                    ("In Review", False), ("Blocked", False)):
                data = copy.deepcopy(envelope["response"]["data"])
                data["issues"].append({"key": "CURS-99", "fields": {
                    "parent": {"key": "CURS-1"}, "status": {"name": status}}})
                data["total"] = 7
                with self.subTest(status=status):
                    if allowed:
                        self.assertIn("CURS-99", validate_children(data, envelope))
                    else:
                        with self.assertRaisesRegex(GateError, "Unexpected active epic child CURS-99"):
                            validate_children(data, envelope)

    def test_pr_identity_and_review_artifacts(self):
        paths = [f"docs/reviews/{key}.md" for key in ISSUES]
        pr = {"number": 9, "state": "OPEN", "isDraft": False, "baseRefName": "main",
              "headRefOid": "abc", "url": "https://github.com/example/project/pull/9",
              "body": " ".join(ISSUES + tuple(paths)),
              "files": [{"path": path} for path in paths + ["specs/curs-1-charter.md"]]}
        self.assertTrue(validate_pr(pr, "abc"))
        for changes in ({"state": "MERGED"}, {"isDraft": True}, {"headRefOid": "old"},
                        {"baseRefName": "dev"}, {"files": []}, {"body": "all work reviewed"}):
            with self.subTest(changes=changes), self.assertRaises(GateError):
                validate_pr(pr | changes, "abc")

    def test_workflows_require_current_success(self):
        runs = [{"workflowName": name, "headSha": "abc", "event": "pull_request",
                 "createdAt": "2026-10-08T10:00:00Z", "databaseId": index,
                 "status": "completed", "conclusion": "success", "url": f"https://example/{index}"}
                for index, name in enumerate(("CI", "CodeQL"), 1)]
        self.assertEqual(set(validate_runs(runs, "abc")), {"CI", "CodeQL"})
        duplicate = runs + [runs[0] | {"event": "workflow_dispatch", "status": "in_progress",
                                      "createdAt": "2026-10-08T11:00:00Z", "databaseId": 3}]
        self.assertEqual(set(validate_runs(duplicate, "abc")), {"CI", "CodeQL"})
        for broken in (runs[:1], [runs[0] | {"conclusion": "failure"}, runs[1]],
                       [run | {"headSha": "old"} for run in runs]):
            with self.assertRaises(GateError):
                validate_runs(broken, "abc")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--task", choices=TASKS)
    mode.add_argument("--check-lock", action="store_true")
    mode.add_argument("--self-test", action="store_true")
    mode.add_argument("--governance-output", type=Path)
    parser.add_argument("--evidence-dir", type=Path, default=RUN / "curs-1-evidence")
    args = parser.parse_args()
    if args.self_test:
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(FailureCases)
        result = unittest.TextTestRunner(verbosity=2).run(suite)
        return 0 if result.wasSuccessful() else 1
    try:
        if args.governance_output:
            detail = governance_projection(args.governance_output)
        else:
            lock_check()
            if args.check_lock:
                detail = {"lock": str(LOCK.relative_to(ROOT)), "frozen_inputs": "unchanged"}
            elif args.task == "T1":
                detail = validate_charter(args.evidence_dir)
            elif args.task == "T5":
                detail = final_delivery(args.evidence_dir)
            else:
                detail = review_packet(args.task)
        print(json.dumps({"verdict": "PASS", "task": args.task, "evidence": detail}, indent=2))
        return 0
    except (GateError, OSError, KeyError, TypeError) as exc:
        print(json.dumps({"verdict": "FAIL", "task": args.task, "reason": str(exc)}, indent=2))
        return 1


if __name__ == "__main__":
    sys.exit(main())
