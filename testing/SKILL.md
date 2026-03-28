---
name: testing
version: 1.0.0
description: |
  Post-ship manual testing session. Walks through the testing checklist
  from /code-ship's PR, with an AI-assisted fix loop when tests fail.
  Reads project-init context for tech stack clues during debugging.
  Use when asked to "test this", "run testing", "walk through tests",
  or "QA this PR".
benefits-from: [project-init, code-ship]
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
---

# /testing

Post-ship manual testing session. Walk through the checklist, fix what breaks, ship clean.

## Preamble

```bash
~/.jstack/bin/jstack-preamble opus
```

If `WRONG_MODEL` in output: stop — tell user to run `/model claude-opus-4-6` then re-run.
If `PROJECT_DOC_FOUND`: read `~/.jstack/projects/$SLUG.md` tech stack section — use during fix loop debugging.

---

## AskUserQuestion Format

For every AskUserQuestion: re-ground in PR/test item/decision, recommend an action when applicable, provide lettered choices A) B) C).

---

## Phase 1: Load Checklist

1. `gh pr view --json number,title,body -q '{number: .number, title: .title, body: .body}'`
2. Extract the `## Testing checklist` section (also matches: `## Test plan`, `## Testing`, `## Manual testing`). Collect all `- [ ]` and `- [x]` lines until next `##` or end of body.
3. If no PR: "No open PR found. Run /code-ship first, or paste your testing steps below." Accept freeform input.
4. If PR found but no checklist: "PR #N found but no testing checklist. Paste your testing steps below." Accept freeform input.
5. Display full checklist and confirm via AskUserQuestion: "PR #N — 'title'. Ready to start. I'll walk you through each item one at a time. A) Let's go  B) Skip to a specific item  C) Abort"

---

## Phase 2: Walk-Through Loop

For each item, ask via AskUserQuestion:
```
Testing PR #N — "<title>". Item X of Y.
Test: "<the test step>"
Try this now and tell me the result.
```
Options: A) Pass | B) Fail | C) Skip | D) Add a new test item | E) Done — show report

- **Pass:** record, move on.
- **Fail:** enter Phase 3 (Fix Loop). Return here when resolved.
- **Skip:** record as skipped, move on.
- **Add item:** accept step from user, append to checklist, continue with current item.
- **Done:** exit to Phase 4.

---

## Phase 3: Fix Loop

**Track fix metadata:** for each fix, record `{file, line, description, related_item}` for the Phase 4 report.

**Track issues, not items:** each distinct problem gets its own attempt counter (max 3 per issue). An issue is "distinct" when error message, failure behavior, or root cause is clearly different.

1. Ask user to describe what went wrong (or paste error) via AskUserQuestion.
2. Read relevant code, Grep for references. Identify root cause before proposing anything.
3. Propose a minimal fix: state the cause first, then the fix. One change at a time.
4. Apply fix using Edit (or Write for new files).
5. Ask user to retest:
   ```
   PR #N — "<title>". Testing: "<item>". Fix applied (attempt N of 3).
   Retest: "<what to try>"
   ```
   Options: A) Now passes | B) Same issue, still failing | C) Different issue now | D) Unrelated issue found

   - **B:** increment attempt counter. At attempt 3, go to step 6.
   - **C:** prior issue is resolved (record metadata). Reset counter, loop back to step 2 with new failure.
   - **D:** pause current item (preserve attempt count). Enter nested fix loop (same 3-attempt limit). When resolved or abandoned, resume original item — re-present step 5.

6. After 3 failed cycles: "Couldn't resolve this issue after 3 attempts." Ask:
   Options: A) Move on (record as unresolved, return to Phase 2) | B) Different problem — reset counter for new issue, loop back to step 1.

---

## Phase 4: Test Report

```
TEST REPORT
════════════════════════════════════════
PR:       #N — <title>
Branch:   <branch> | Date: <date>

Results:
  ✓ Passed: N | ✗ Failed: N (M fixed) | ○ Skipped: N | + Ad-hoc: N

Fixes Applied:
  - [file:line] <what was fixed>

Unresolved:
  - <item> — could not fix after 3 attempts

Status: DONE | DONE_WITH_CONCERNS | BLOCKED
════════════════════════════════════════
```

Status: DONE if all passed/fixed; DONE_WITH_CONCERNS if unresolved items; BLOCKED if aborted before starting.

Proceed to Phase 5 only if fixes were applied. Otherwise stop.

---

## Phase 5: Commit Fixes

Only runs if at least one fix was applied.

1. `git diff` — show the diff.
2. Ask via AskUserQuestion: "N fix(es) applied. Commit and push to PR #N?"
   Options: A) Commit and push | B) Review changes first | C) Discard all fixes

3. **On Commit:** `git add -u` + stage any new files from fix metadata explicitly. Generate commit message (imperative, ≤72 chars; if multiple fixes, add body with one bullet per fix). `git push`.

4. **On Discard:** `git checkout -- <file1> <file2> ...` for each file in the fix metadata only. For new files created during fixes: `rm <file>`. **Do NOT use `git checkout -- .`** — that discards unrelated changes.

**DONE** — All items passed/fixed, fixes committed | **DONE_WITH_CONCERNS** — Unresolved items remain | **BLOCKED** — Could not load checklist or user aborted
