---
name: document
version: 1.0.0
description: |
  Post-ship documentation update. Reads all project docs, cross-references the
  diff, updates README/ARCHITECTURE/CONTRIBUTING/CLAUDE.md to match what shipped,
  polishes CHANGELOG voice, cleans up TODOS, and optionally bumps VERSION.
  Reads project-init context for doc conventions.
  Use when asked to "update the docs", "sync documentation", or "document this".
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
---

# /document

Post-ship documentation update. Keeps docs accurate and user-forward after code ships.

## Preamble

```bash
source <(~/.jstack/bin/jstack-slug 2>/dev/null) || SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
_PROJECT_DOC=~/.jstack/projects/$SLUG.md
[ -f "$_PROJECT_DOC" ] && echo "PROJECT_DOC_FOUND" || echo "PROJECT_DOC_MISSING"
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "SLUG: $SLUG"
echo "BRANCH: $_BRANCH"
```

If `PROJECT_DOC_FOUND`: read `~/.jstack/projects/$SLUG.md`. Use the Conventions section to understand how docs are structured and what files matter most for this project.

---

## Step 0: Detect base branch

1. Check for existing PR: `gh pr view --json baseRefName -q .baseRefName`
2. If no PR: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`
3. Fallback: `main`

Use the detected branch as "the base branch" throughout.

---

## Operating Principles

Make obvious factual updates directly. Stop and ask only for risky or subjective decisions.

**Auto-update (no question needed):**
- Factual corrections clearly from the diff
- Adding items to tables/lists
- Updating paths, counts, version numbers
- Fixing stale cross-references
- Marking TODOS complete with evidence from diff
- Cross-doc factual inconsistencies (version number mismatch, etc.)

**Ask the user:**
- Narrative changes, philosophy, security model
- Large rewrites (>10 lines in one section)
- Section removal
- Ambiguous relevance

**Never:**
- Overwrite or regenerate CHANGELOG entries — polish wording only
- Bump VERSION without asking
- Use `Write` on CHANGELOG.md — always use `Edit` with exact `old_string`

---

## Step 1: Pre-flight & Diff Analysis

1. If on base branch, **abort**: "You're on the base branch. Run from a feature branch."

2. Gather context:
   ```bash
   git diff <base>...HEAD --stat
   git log <base>..HEAD --oneline
   git diff <base>...HEAD --name-only
   ```

3. Discover documentation files:
   ```bash
   find . -maxdepth 2 -name "*.md" -not -path "./.git/*" -not -path "./node_modules/*" | sort
   ```

4. Classify changes: new features, changed behaviour, removed functionality, infrastructure.

---

## Step 2: Per-File Audit

Read each doc file and cross-reference against the diff:

**README.md** — features, install instructions, examples, usage descriptions still valid?

**ARCHITECTURE.md** — diagrams and component descriptions match current code? Be conservative — only update things clearly contradicted by the diff.

**CONTRIBUTING.md** — walk through setup instructions as a new contributor. Are listed commands accurate?

**CLAUDE.md / project instructions** — project structure, commands, build/test instructions current?

**Other .md files** — read, determine purpose, check against diff.

Classify each needed update as **Auto-update** or **Ask user**.

---

## Step 3: Apply Auto-Updates

Make all clear, factual updates using the Edit tool.

For each file modified, output a one-line summary of exactly what changed.

---

## Step 4: Ask About Risky Changes

For each risky update, use AskUserQuestion with context, the specific decision, a recommendation, and options including "Skip — leave as-is".

---

## Step 5: CHANGELOG Voice Polish

**CRITICAL — NEVER CLOBBER CHANGELOG ENTRIES.**

Polish wording only. Do NOT rewrite, replace, or regenerate entries.

Rules:
1. Read the entire CHANGELOG.md first.
2. Only modify wording within existing entries. Never delete or reorder.
3. Never regenerate an entry from scratch.
4. Use Edit tool with exact `old_string` — never Write to overwrite CHANGELOG.md.

If CHANGELOG wasn't modified in this branch, skip.

Voice checks:
- Lead with what the user can now **do**, not implementation details
- "You can now..." not "Refactored the..."
- Would a user reading each bullet think "oh nice, I want to try that"?

---

## Step 6: Cross-Doc Consistency

1. README features match CLAUDE.md descriptions?
2. ARCHITECTURE component list match CONTRIBUTING project structure?
3. CHANGELOG latest version match VERSION file?
4. Every doc file reachable from README.md or CLAUDE.md?

Auto-fix factual inconsistencies. AskUserQuestion for narrative contradictions.

---

## Step 7: TODOS.md Cleanup

If TODOS.md doesn't exist, skip.

1. Cross-reference diff against open TODOs. Mark clearly completed items as done.
2. Check diff for `TODO`, `FIXME`, `HACK`, `XXX` comments. For meaningful deferred work, ask whether to add to TODOS.md.

---

## Step 8: VERSION Bump

**Never bump without asking.**

If VERSION doesn't exist: skip.

Check if already bumped:
```bash
git diff <base>...HEAD -- VERSION
```

If not bumped: ask (recommend Skip for docs-only changes):
- A) Bump PATCH
- B) Bump MINOR
- C) Skip

If already bumped: verify it covers the full scope of changes. If significant uncovered changes exist, ask whether to bump again.

---

## Step 9: Commit & Output

Run `git status`. If no doc files changed: "All documentation is up to date." and exit.

Otherwise:
1. Stage modified doc files by name
2. Commit:
   ```bash
   git commit -m "docs: update documentation"
   ```
3. Push:
   ```bash
   git push
   ```
4. Update PR body if one exists:
   ```bash
   gh pr view --json body -q .body > /tmp/jstack-pr-body-$$.md
   # Append or replace ## Documentation section
   gh pr edit --body-file /tmp/jstack-pr-body-$$.md
   rm -f /tmp/jstack-pr-body-$$.md
   ```

Output a doc health summary:
```
Documentation health:
  README.md       [Updated / Current / Skipped]
  ARCHITECTURE.md [...]
  CONTRIBUTING.md [...]
  CHANGELOG.md    [...]
  TODOS.md        [...]
  VERSION         [...]
```

---

## Completion Status

- **DONE** — All docs reviewed, updates applied, committed
- **DONE_WITH_CONCERNS** — Completed with skipped items or open questions
- **BLOCKED** — On base branch or no PR context
