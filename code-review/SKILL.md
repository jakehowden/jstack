---
name: code-review
version: 1.0.0
description: |
  Pre-landing PR review. Analyzes diff for SQL safety, race conditions, LLM trust
  boundaries, conditional side effects, structural issues, and style/convention
  consistency. Reads project-init context for coding conventions.
  Use when asked to "review this", "code review", or "check my diff".
  Feeds into /code-ship.
benefits-from: [project-init, plan-review]
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - AskUserQuestion
---

# /code-review

Pre-landing review. Catches structural issues and style drift before the PR ships.

## Preamble

```bash
~/.jstack/bin/jstack-preamble opus
```

If `WRONG_MODEL` in output: stop — tell user to run `/model claude-opus-4-6` then re-run.
If `PROJECT_DOC_FOUND`: read `~/.jstack/projects/$SLUG.md` Conventions section for naming/style/patterns to enforce.

---

## Step 0: Detect base branch

1. `gh pr view --json baseRefName -q .baseRefName`
2. `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`
3. Fallback: `main`

---

## Step 1: Check branch

```bash
git branch --show-current
git fetch origin <base> --quiet && git diff origin/<base> --stat
```

If on base branch or no diff: "Nothing to review." Stop.

---

## Step 1.5: Scope Drift Detection

1. Read `TODOS.md`, `gh pr view --json body --jq .body 2>/dev/null`, `git log origin/<base>..HEAD --oneline` — identify stated intent.
2. Compare `git diff origin/<base> --stat` against stated intent.

Output:
```
Scope Check: [CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING]
Intent: <1-line summary>
Delivered: <1-line summary>
[If drift: list out-of-scope changes] [If missing: list unaddressed requirements]
```

Informational only — does not block the review.

---

## Step 2: Get the diff

```bash
git fetch origin <base> --quiet
git diff origin/<base>
```

---

## Step 3: Two-pass review

### Pass 1 — CRITICAL

**SQL & Data Safety:** raw SQL with user input, missing transactions on multi-step writes, DELETE/UPDATE without WHERE, schema migrations without rollback.

**Race Conditions:** missing locks on shared state read-then-write, optimistic locking without conflict handling, async operations with implicit ordering assumptions.

**LLM Output Trust Boundary:** LLM output used directly in SQL/shell/file paths, no validation before DB write, user input concatenated into prompts.

**Enum & Value Completeness:** new enum/status/type not handled in all switch/match statements. Use Grep to find sibling values, Read those files to check coverage.

### Pass 2 — INFORMATIONAL

**Conditional Side Effects:** side effects (emails, charges, webhooks) inside conditionals that could be skipped silently; missing logging around external calls.

**Magic Numbers & String Coupling:** hardcoded values that should be constants; strings appearing in multiple places that will drift.

**Dead Code & Consistency:** unused imports/variables/functions in the diff; inconsistent patterns vs. existing codebase.

**Test Gaps:** new code paths without tests; modified behaviour without updated assertions.

**Style & Convention:** naming conventions (read 2-3 similar files to calibrate); mixed indentation or formatting; structural patterns inconsistent with adjacent code. Reference Conventions section of project-init doc if available.

---

## Step 4: Fix-First Review

Output: `Pre-Landing Review: N issues (X critical, Y informational)`

**AUTO-FIX** anything mechanical and low-risk (formatting, unused imports, obvious naming). For each: `[AUTO-FIXED] [file:line] Problem → what was done`

**ASK** about anything requiring judgment. Present all ASK items in one AskUserQuestion (or individually if ≤3):
```
I auto-fixed N issues. M need your input:
1. [CRITICAL] file:42 — Race condition in status transition
   Fix: Add WHERE status = 'pending' to the UPDATE → A) Fix  B) Skip
RECOMMENDATION: Fix both — #1 is a real race condition.
```

Apply approved fixes immediately.

---

## Step 5: TODOS cross-reference

Read `TODOS.md` if it exists. Note which TODOs this PR closes; flag any new work that should become a TODO.

---

## Step 6: Documentation staleness check

For each `.md` doc in the repo root: if the code it describes changed in this branch but the doc wasn't updated, flag as informational: "Documentation may be stale: [file]. Consider running /document."

---

## Important Rules

- **Never `git push`** — committing locally is fine, pushing waits for `/code-ship`

---

## Completion Status

```
Pre-Landing Review complete.
  Auto-fixed: N | User-approved fixes: N | Skipped: N
  Scope drift: CLEAN / DETECTED | TODOs addressed: N | Stale docs: N
```

**DONE** — Review complete, all findings actioned | **DONE_WITH_CONCERNS** — Skipped critical items | **BLOCKED** — On base branch or no diff
