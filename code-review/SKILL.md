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
source <(~/.jstack/bin/jstack-slug 2>/dev/null) || SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
_PROJECT_DOC=~/.jstack/projects/$SLUG.md
[ -f "$_PROJECT_DOC" ] && echo "PROJECT_DOC_FOUND" || echo "PROJECT_DOC_MISSING"
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "SLUG: $SLUG"
echo "BRANCH: $_BRANCH"
_MODEL=$(python3 -c "
import json, os
for path in [os.path.expanduser('~/.claude/settings.local.json'), os.path.expanduser('~/.claude/settings.json')]:
    try:
        with open(path) as f:
            m = json.load(f).get('model', '')
            if m: print(m); break
    except: pass
else: print('unknown')
" 2>/dev/null)
echo "$_MODEL" | grep -qi "opus" || echo "WRONG_MODEL: $_MODEL"
```

If `WRONG_MODEL` appears in the output: stop immediately and output:

> Wrong model: this skill requires Opus. Run `/model claude-opus-4-6` then re-run.

If `PROJECT_DOC_FOUND`: read `~/.jstack/projects/$SLUG.md`. Load the Conventions & Preferences section — it defines naming conventions, code style, and patterns to enforce in the Style & Convention dimension.

---

## Step 0: Detect base branch

1. `gh pr view --json baseRefName -q .baseRefName` — use if succeeds
2. `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` — fallback
3. `main` — final fallback

---

## Step 1: Check branch

```bash
git branch --show-current
git fetch origin <base> --quiet && git diff origin/<base> --stat
```

If on base branch or no diff: "Nothing to review — you're on the base branch or have no changes." Stop.

---

## Step 1.5: Scope Drift Detection

Did you build what was requested — nothing more, nothing less?

1. Read `TODOS.md`, PR description (`gh pr view --json body --jq .body 2>/dev/null || true`), and commit messages (`git log origin/<base>..HEAD --oneline`).
2. Identify **stated intent**.
3. Compare `git diff origin/<base> --stat` against stated intent.

Output:
```
Scope Check: [CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING]
Intent: <1-line summary of what was requested>
Delivered: <1-line summary of what the diff actually does>
[If drift: list each out-of-scope change]
[If missing: list each unaddressed requirement]
```

This is **informational** — does not block the review.

---

## Step 2: Get the diff

```bash
git fetch origin <base> --quiet
git diff origin/<base>
```

---

## Step 3: Two-pass review

### Pass 1 — CRITICAL

**SQL & Data Safety**
- Raw SQL with user input without parameterisation
- Missing transactions on multi-step writes
- DELETE/UPDATE without WHERE clauses
- Schema migrations without rollback strategy

**Race Conditions & Concurrency**
- Missing locks on shared state reads-then-writes
- Optimistic locking patterns without conflict handling
- Async operations with implicit ordering assumptions

**LLM Output Trust Boundary**
- LLM output used directly in SQL, shell commands, or file paths
- No validation before writing LLM output to the database
- Prompt injection vectors (user input concatenated into prompts)

**Enum & Value Completeness**
- New enum value added but not handled in all switch/match statements
- New status/tier/type constant not covered in downstream logic
- Use Grep to find sibling values, Read those files to check coverage

### Pass 2 — INFORMATIONAL

**Conditional Side Effects**
- Side effects (emails, charges, webhooks) inside conditionals that could be skipped silently
- Missing logging around external service calls

**Magic Numbers & String Coupling**
- Hardcoded values that should be constants or config
- Strings that appear in multiple places and will drift

**Dead Code & Consistency**
- Unused imports, variables, or functions introduced in the diff
- Inconsistent patterns vs. the existing codebase

**Test Gaps**
- New code paths introduced without corresponding tests
- Modified behaviour without updated test assertions

**Style & Convention** *(jstack addition)*
- **Naming conventions:** Does naming match the patterns established in this codebase? (Read 2-3 similar files to calibrate — e.g., if existing files use `camelCase` for variables, flag `snake_case` in the diff.) Reference the Conventions section of the project-init doc if available.
- **Formatting:** Mixed indentation, trailing whitespace, inconsistent brace/bracket style vs. surrounding code.
- **Code style consistency:** Does the diff follow the same structural patterns as adjacent code? (e.g., if similar functions use early returns, does the new function do the same?)

---

## Step 4: Fix-First Review

Output: `Pre-Landing Review: N issues (X critical, Y informational)`

### Classify each finding

- **AUTO-FIX:** Mechanical, low-risk, no meaningful alternatives (formatting, unused imports, obvious naming fixes, clear style inconsistencies)
- **ASK:** Requires judgment, has real tradeoffs, or could change behaviour

### Auto-fix all AUTO-FIX items

For each: `[AUTO-FIXED] [file:line] Problem → what was done`

### Batch-ask about ASK items

Present all ASK items in one AskUserQuestion (or individually if ≤3):

```
I auto-fixed N issues. M need your input:

1. [CRITICAL] file.rb:42 — Race condition in status transition
   Fix: Add WHERE status = 'pending' to the UPDATE
   → A) Fix  B) Skip

2. [INFORMATIONAL] service.js:88 — LLM output written to DB without validation
   Fix: Add schema validation before write
   → A) Fix  B) Skip

RECOMMENDATION: Fix both — #1 is a real race condition, #2 prevents silent corruption.
```

Apply user-approved fixes immediately.

---

## Step 5: TODOS cross-reference

Read `TODOS.md` if it exists.
- Does this PR close any open TODOs? Note which.
- Does this PR create work that should become a TODO? Flag as informational.

---

## Step 6: Documentation staleness check

For each `.md` doc in the repo root: if code it describes changed in this branch but the doc wasn't updated, flag as informational:
"Documentation may be stale: [file] describes [feature] but code changed. Consider running /document."

---

## Important Rules

- **Never `git push`** — committing locally is fine, but pushing must wait until the user runs `/code-ship`

---

## Completion Status

Output a summary:
```
Pre-Landing Review complete.
  Auto-fixed: N
  User-approved fixes: N
  Skipped: N
  Scope drift: CLEAN / DETECTED
  TODOs addressed: N
  Stale docs: N
```

- **DONE** — Review complete, all findings actioned
- **DONE_WITH_CONCERNS** — Completed with skipped critical items
- **BLOCKED** — On base branch or no diff
