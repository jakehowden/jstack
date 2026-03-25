---
name: bug
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

# /bug

File a bug as a structured GitHub issue. Gathers repro steps, expected vs actual
behavior, checks for duplicates, and creates the issue.

## Preamble

```bash
source <(~/.jstack/bin/jstack-slug 2>/dev/null) || SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
_PROJECT_DOC=~/.jstack/projects/$SLUG.md
[ -f "$_PROJECT_DOC" ] && echo "PROJECT_DOC_FOUND" || echo "PROJECT_DOC_MISSING"
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "SLUG: $SLUG"
echo "BRANCH: $_BRANCH"
```

If `PROJECT_DOC_FOUND`: read `~/.jstack/projects/$SLUG.md`. Use the tech stack section to add context to the issue.

If `PROJECT_DOC_MISSING`: continue without it — the skill works standalone.

---

## AskUserQuestion Format

For every AskUserQuestion:
1. **Re-ground:** State the project and what we're deciding. (1-2 sentences)
2. **Plain English:** Explain what information is needed and why.
3. **Options:** Lettered A) B) C)

---

## Phase 1: Context Gathering

1. Read `TODOS.md` if it exists.
2. Run `git log --oneline -10` to understand recent context.
3. Check existing open issues:
   ```bash
   gh issue list --state open --limit 10 --json number,title --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null
   ```
   Hold this list for the duplicate check in Phase 3.

---

## Phase 2: Bug Description

Ask these **one at a time** via AskUserQuestion. Stop after each — wait for the answer.

**Q1 — What's the bug?**
> What's going wrong? Describe the bug you've found.

**Q2 — Reproduction steps**
> What steps trigger this? Walk me through what you did.

**Q3 — Expected vs actual**
> What did you expect to happen, and what actually happened? Include any error messages.

**Q4 — Severity**
> How severe is this?
>
> A) Blocker — can't work around it, blocks progress
> B) Major — significant impact but has a workaround
> C) Minor — cosmetic or low-impact

**Smart-skip:** If the user's initial prompt already answers a question clearly, skip it. Only ask questions whose answers aren't yet known.

---

## Phase 3: Duplicate Check

Extract keywords from the bug description and search existing issues:
```bash
gh issue list --state open --search "<keywords>" --json number,title,url --jq '.[] | "#\(.number) \(.title) — \(.url)"' 2>/dev/null
```

**If potential duplicates found:** present them via AskUserQuestion:

> These open issues look related:
>
> 1. #42 — Login redirect loop
> 2. #38 — Dashboard crash on empty data
>
> Is your bug the same as any of these?
>
> A) Yes — tell me which number (I'll add a comment instead)
> B) No — file a new issue

**On "Yes":** Add a comment to the existing issue with the new reproduction details:
```bash
gh issue comment <number> --body "<repro details from Phase 2>"
```
Output the issue URL. Skip to Phase 5.

**On "No":** Continue to Phase 4.

**If no duplicates found:** Continue to Phase 4 silently.

---

## Phase 4: Issue Creation

Generate the issue body:

```markdown
## Bug Report

**Description**
{user's bug description from Q1}

**Reproduction Steps**
1. {step from Q2}
2. {step}

**Expected Behavior**
{expected from Q3}

**Actual Behavior**
{actual from Q3}

**Severity**
{Blocker / Major / Minor from Q4}

**Context**
- Branch: {current branch}
- Recent commits: {last 3 commit summaries from git log}
```

Create the issue:
```bash
gh issue create \
  --title "Bug: {concise summary}" \
  --body "$(cat <<'EOF'
<generated body>
EOF
)" \
  --label bug 2>/dev/null || \
gh issue create \
  --title "Bug: {concise summary}" \
  --body "$(cat <<'EOF'
<generated body>
EOF
)"
```

The first attempt includes `--label bug`. If it fails (label doesn't exist), the fallback creates the issue without a label.

Output the issue URL.

---

## Phase 5: Next Steps

Ask via AskUserQuestion:

> Issue filed. What next?
>
> A) Start debugging now — I'll run /debug to investigate the root cause
> B) Done for now

**On "Start debugging":** Tell the user: "Run **/debug** to start investigating."

---

## Completion Status

- **DONE** — Issue created (or comment added to existing issue)
- **BLOCKED** — `gh` auth issues, no git repo, or user aborted
