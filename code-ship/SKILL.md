---
name: code-ship
version: 1.0.0
description: |
  Ship workflow: create a feature branch, commit, push, and raise a PR.
  PR includes a list of TODOs addressed (from TODOS.md + inline comments)
  and a manual testing checklist. Updates the project-init doc after shipping.
  Use when asked to "ship", "create a PR", "push this", or "raise a PR".
benefits-from: [project-init, code-review]
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
---

# /code-ship

Create a branch, commit, push, and raise a PR with a TODO summary and manual testing checklist. Updates your project context doc after shipping.

## Preamble

```bash
~/.jstack/bin/jstack-preamble sonnet
```

If `WRONG_MODEL` in output: stop — tell user to run `/model claude-sonnet-4-6` then re-run.
If `PROJECT_DOC_FOUND`: read `~/.jstack/projects/$SLUG.md` for branch strategy, PR conventions, and current state (for Step 6 update).

---

## Step 1: Detect TODOs addressed

```bash
git diff HEAD --unified=0
git diff HEAD | grep "^-.*\(TODO\|FIXME\|HACK\)" | sed 's/^-//'
```

Read `TODOS.md` if it exists. Cross-reference open items against the diff (filename + keyword overlap). Build a deduplicated **Resolved TODOs** list.

---

## Step 2: Branch creation

`git branch --show-current` — if on a `feature/` branch, ask whether to continue or create a new one.

If on main/master/develop: ask "What is this shipping?" (used for branch name). Create: `git checkout -b feature/<slugified-answer>` (lowercase, hyphens, no special chars, max 50 chars).

---

## Step 3: Stage and commit

```bash
git add -u
```

Also stage new files clearly part of the feature (not `.env`, credentials, or unrelated scratch files).

Commit message: imperative summary ≤72 chars, optional body explaining why.

```bash
git commit -m "<generated message>"
```

---

## Step 4: Push

```bash
git push -u origin feature/<branch-name>
```

---

## Step 5: Create PR

```bash
gh pr create \
  --title "<imperative summary matching commit>" \
  --body "$(cat <<'EOF'
## What this ships
<1-3 sentence plain-English summary>

## TODOs addressed
<If none: "No open TODOs were addressed in this PR.">
- [ ] <todo item>

## Testing checklist
- [ ] <plain-English step: "Open X and do Y — confirm Z">
- [ ] <edge case step>
EOF
)"
```

<!-- CONTRACT: /testing depends on the "## Testing checklist" heading above. Do not rename it. -->

Testing checklist rules: one step per logical change, "Open X and do Y — confirm Z" format, happy path first then edge cases, manual steps only (no test code).

Output the PR URL.

---

## Step 6: Update project-init doc

If `PROJECT_DOC_MISSING`: skip.
If `PROJECT_DOC_FOUND`:
1. Mark resolved TODOs: add `*(resolved — PR #N, <date>)*` inline in the "Known TODOs" section.
2. Append a note to "Current State" if significant new capabilities shipped.
3. Update `Last updated: <date> (code-ship — PR #N)`.

Use Edit with exact string matching — never overwrite the whole file.

---

## Completion Status

```
Shipped:
  Branch:   feature/<name> | PR: <URL>
  TODOs:    N addressed | Checklist: N manual steps
  Project doc: Updated / Skipped (no doc)
```

**DONE** — Branch, commit, push, PR, doc update all complete | **DONE_WITH_CONCERNS** — PR raised with warnings | **BLOCKED** — Git errors, auth issues, or user aborted
