#!/usr/bin/env python3
"""Frozen CURS-1 artifact and live delivery gate. Python standard library only.

Local packets are review deliverables. Only T5 checks actual Jira completion or
review with the current open PR; neither mode certifies handwriting education.
"""

import argparse
import copy
import datetime as dt
import hashlib
import html
import json
import re
import subprocess
import sys
import tempfile
import unittest
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


def lock_check():
    lock = read_json(LOCK)
    require(lock.get("schema") == "curs-1/check-lock.v1", "Invalid lock schema")
    hashes = lock.get("sha256", {})
    required_paths = {
        "scripts/check_curs_1_delivery.py", "scripts/prepare-curs-1-harness.py",
        "specs/harness/curs-1-manifest.json", "specs/harness/curs-1-plan.json",
        "docs/curs-1-harness.md", ".agent-harness/curs-1-manifest.json",
        ".agent-harness/curs-1-plan.json",
    }
    require(required_paths <= set(hashes), "Frozen lock omits a required check or plan")
    for relative, expected in hashes.items():
        path = Path(relative) if Path(relative).is_absolute() else ROOT / relative
        require(path.is_file() and digest(path) == expected,
                f"Frozen input changed or disappeared: {relative}")
    for name in ("controller", "governance_gate"):
        require(lock.get(name) in hashes, f"Frozen lock omits the plugin {name}")
    plan = read_json(PLAN)
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
    if STATE.exists():
        state = read_json(STATE)
        require(state.get("schema") == "agent-harness/state.v1", "Invalid controller state")
        require(state.get("max_loop_iterations") == 12, "Controller iteration budget changed")
        require([t.get("id") for t in state.get("tasks", [])] == list(TASKS),
                "Controller task scope changed")
        for task, original in zip(state["tasks"], plan["tasks"]):
            require(task.get("verification") == original["verification"]
                    and task.get("max_attempts") == 3,
                    f"Controller checks changed for {task['id']}")
    return lock, plan


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
    result = subprocess.run(["git", "diff", "--quiet", "HEAD", "--", *paths],
                            cwd=ROOT, capture_output=True, text=True, check=False)
    require(result.returncode == 0,
            "Local charter/review packets differ from committed HEAD; commit reviewed artifacts before T5")


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


def acceptance_receipts(evidence_dir, done_keys):
    if not done_keys:
        return {}
    data, _ = snapshot(evidence_dir, "acceptance-receipts.json")
    receipts = data.get("receipts", [])
    require(isinstance(receipts, list), "Acceptance receipts must be a list")
    by_key = {receipt.get("issue_key"): receipt for receipt in receipts}
    require(len(by_key) == len(receipts), "Duplicate acceptance receipt identities")
    for key in done_keys:
        receipt = by_key.get(key, {})
        require(receipt.get("human_reviewed") is True
                and receipt.get("accepted_by") == OWNER
                and receipt.get("decision") == "accepted",
                f"{key}: Done requires explicit human acceptance")
        require(utc_time(receipt.get("accepted_at")) <= dt.datetime.now(dt.timezone.utc),
                f"{key}: acceptance cannot be in the future")
        require(len(receipt.get("acceptance_text", "").strip()) >= 20
                and bool(receipt.get("criteria")), f"{key}: acceptance evidence is empty")
        require(receipt.get("source_kind") in ("user_message", "jira_comment", "confluence_page")
                and bool(receipt.get("source_reference")),
                f"{key}: acceptance lacks an attributable human source")
    return {key: by_key[key] for key in done_keys}


def final_delivery(evidence_dir):
    charter = validate_charter(evidence_dir)
    packets = [review_packet(task) for task in ("T2", "T3", "T4")]
    data, envelope = snapshot(evidence_dir, "children.json")
    children = validate_children(data, envelope)
    pr_evidence, _ = snapshot(evidence_dir, "pr.json")
    number = pr_evidence.get("number")
    require(isinstance(number, int) and number > 0, "PR evidence must name a positive PR number")
    committed_review_artifacts()
    pr = run_json(["gh", "pr", "view", str(number), "--json",
                   "number,state,isDraft,baseRefName,headRefOid,headRefName,url,body,files"])
    head = local_head()
    url = validate_pr(pr, head)
    for key in ISSUES:
        fields = children[key]["fields"]
        if fields["status"]["name"] == "In Review":
            require(url in description_text(fields.get("description")),
                    f"{key}: actual In Review item must link the current PR in its description")
    done_keys = [key for key in ISSUES if children[key]["fields"]["status"]["name"] == "Done"]
    receipts = acceptance_receipts(evidence_dir, done_keys)
    runs = run_json(["gh", "run", "list", "--branch", pr["headRefName"], "--limit", "100",
                     "--json", "workflowName,headSha,status,conclusion,url,databaseId,createdAt,event"])
    checks = validate_runs(runs, head)
    return {"charter": charter, "packets": packets, "head": head, "pr": url,
            "workflow_runs": checks,
            "jira_statuses": {key: children[key]["fields"]["status"]["name"] for key in ISSUES},
            "human_acceptance_receipts": receipts}


def governance_projection(output):
    _, plan = lock_check()
    state = read_json(STATE)
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
    require(output.resolve() not in (PLAN.resolve(), STATE.resolve(), LOCK.resolve()),
            "Governance output must be separate from locked inputs and controller state")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(projection, indent=2) + "\n", encoding="utf-8")
    return {"governance_output": str(output), "statuses": {t["id"]: t["status"] for t in projection["tasks"]}}


class FailureCases(unittest.TestCase):
    """Exercise rejection behavior before freeze, without live Jira or GitHub."""

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
