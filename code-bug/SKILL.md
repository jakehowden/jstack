---
name: code-bug
version: 1.0.0
description: |
  Raise a bug and create a GitHub issue. Gathers reproduction steps,
  expected vs actual behavior, and files a structured issue via gh.
  Use when asked to "file a bug", "raise an issue", "report a bug",
  or "create a GitHub issue".
benefits-from: [project-init]
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - AskUserQuestion
---

# /code-bug

File a bug as a structured GitHub issue. Gathers repro steps, expected vs actual, checks for duplicates, and creates the issue.

## Preamble

```bash
~/.jstack/bin/jstack-preamble any
```

If `PROJECT_DOC_FOUND`: read `~/.jstack/projects/$SLUG.md` tech stack section — add context to the issue.

---

## AskUserQuestion Format

For every AskUserQuestion: re-ground in project/decision, explain what information is needed and why, provide lettered choices A) B) C).

---

## Phase 1: Context Gathering

1. Read `TODOS.md` if it exists.
2. `git log --oneline -10`
3. `gh issue list --state open --limit 10 --json number,title --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null` — save for duplicate check in Phase 3.

---

## Phase 2: Bug Description (one at a time)

**Q1** — What's the bug? What's going wrong?
**Q2** — Reproduction steps: what steps trigger this?
**Q3** — Expected vs actual: what did you expect, and what happened? Include error messages.
**Q4** — Severity: A) Blocker (can't work around it) | B) Major (workaround exists) | C) Minor (cosmetic/low-impact)

Smart-skip any question the user's initial prompt already answers.

---

## Phase 3: Duplicate Check

`gh issue list --state open --search "<keywords>" --json number,title,url --jq '.[] | "#\(.number) \(.title) — \(.url)"' 2>/dev/null`

If potential duplicates found, ask via AskUserQuestion: "These open issues look related: [list]. Is your bug the same as any? A) Yes — tell me which number (I'll add a comment) | B) No — file a new issue"

On "Yes": `gh issue comment <number> --body "<repro details from Phase 2>"` — output URL, skip to Phase 5.
On "No" or no duplicates: continue to Phase 4.

---

## Phase 4: Issue Creation

```bash
gh issue create \
  --title "Bug: {concise summary}" \
  --body "$(cat <<'EOF'
## Bug Report
**Description:** {Q1}
**Reproduction Steps:** {Q2 as numbered list}
**Expected:** {Q3 expected} | **Actual:** {Q3 actual}
**Severity:** {Q4}
**Context:** Branch: {branch} | Recent commits: {last 3 from git log}
EOF
)" \
  --label bug 2>/dev/null || \
gh issue create --title "Bug: {concise summary}" --body "<same body without --label>"
```

Output the issue URL.

---

## Phase 5: Next Steps

Ask via AskUserQuestion: "Issue filed. What next? A) Start debugging now — run /debug | B) Done for now"

On "Start debugging": "Run **/debug** to start investigating."

**DONE** — Issue created or comment added | **BLOCKED** — gh auth issues, no git repo, or user aborted
