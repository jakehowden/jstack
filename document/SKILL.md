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
~/.jstack/bin/jstack-preamble any
```

If `PROJECT_DOC_FOUND`: read `~/.jstack/projects/$SLUG.md` Conventions section for doc structure and priorities.

---

## Step 0: Detect base branch

1. `gh pr view --json baseRefName -q .baseRefName`
2. `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`
3. Fallback: `main`

---

## Operating Principles

**Auto-update (no question):** factual corrections from the diff, adding to tables/lists, updating paths/counts/versions, fixing stale cross-references, marking TODOs complete, cross-doc factual inconsistencies.

**Ask the user:** narrative changes, philosophy, security model, large rewrites (>10 lines in one section), section removal, ambiguous relevance.

**Never:** overwrite or regenerate CHANGELOG entries (polish wording only); bump VERSION without asking; use `Write` on CHANGELOG.md (always use `Edit` with exact `old_string`).

---

## Step 1: Pre-flight & Diff Analysis

If on base branch: abort — "Run from a feature branch."

```bash
git diff <base>...HEAD --stat
git log <base>..HEAD --oneline
git diff <base>...HEAD --name-only
find . -maxdepth 2 -name "*.md" -not -path "./.git/*" -not -path "./node_modules/*" | sort
```

Classify changes: new features, changed behaviour, removed functionality, infrastructure.

---

## Step 2: Per-File Audit

Read each doc and cross-reference against the diff:

- **README.md** — features, install, examples, usage still valid?
- **ARCHITECTURE.md** — diagrams and component descriptions match? Be conservative — only update things clearly contradicted by the diff.
- **CONTRIBUTING.md** — walk through setup as a new contributor. Are commands accurate?
- **CLAUDE.md / project instructions** — project structure, commands, build/test instructions current?
- **Other .md files** — read, determine purpose, check against diff.

Classify each needed update as Auto-update or Ask user.

---

## Step 3: Apply Auto-Updates

Make all clear factual updates using Edit. For each file modified, output a one-line summary of what changed.

---

## Step 4: Ask About Risky Changes

For each risky update, use AskUserQuestion with context, the specific decision, a recommendation, and a "Skip — leave as-is" option.

---

## Step 5: CHANGELOG Voice Polish

**CRITICAL — NEVER CLOBBER CHANGELOG ENTRIES.**

1. Read the entire CHANGELOG.md first.
2. Polish wording only — never delete, reorder, or regenerate entries.
3. Use Edit with exact `old_string` only.
4. If CHANGELOG wasn't modified in this branch, skip.

Voice: lead with what the user can now **do** ("You can now..."), not implementation details.

---

## Step 6: Cross-Doc Consistency

- README features match CLAUDE.md descriptions?
- ARCHITECTURE component list match CONTRIBUTING project structure?
- CHANGELOG latest version match VERSION file?
- Every doc reachable from README or CLAUDE.md?

Auto-fix factual inconsistencies. AskUserQuestion for narrative contradictions.

---

## Step 7: TODOS.md Cleanup

If TODOS.md doesn't exist, skip. Cross-reference diff against open TODOs — mark completed items. Check diff for `TODO`/`FIXME`/`HACK`/`XXX` comments; ask whether to add meaningful deferred work to TODOS.md.

---

## Step 8: VERSION Bump

Never bump without asking. If VERSION doesn't exist, skip. Check `git diff <base>...HEAD -- VERSION`. If not bumped, ask (recommend Skip for docs-only changes): A) Bump PATCH | B) Bump MINOR | C) Skip.

---

## Step 9: Commit & Output

`git status` — if no doc files changed: "All documentation is up to date." Exit.

Otherwise:
1. Stage modified doc files by name.
2. `git commit -m "docs: update documentation"`
3. `git push`
4. Update PR body if one exists: `gh pr view --json body -q .body > /tmp/jstack-pr-body-$$.md` then append/replace `## Documentation` section and `gh pr edit --body-file /tmp/jstack-pr-body-$$.md && rm -f /tmp/jstack-pr-body-$$.md`

Output doc health summary:
```
Documentation health:
  README.md       [Updated / Current / Skipped]
  ARCHITECTURE.md [...]
  CONTRIBUTING.md [...]
  CHANGELOG.md    [...]
  TODOS.md        [...]
  VERSION         [...]
```

**DONE** — All docs reviewed, updates applied, committed | **DONE_WITH_CONCERNS** — Completed with skipped items | **BLOCKED** — On base branch or no PR context
