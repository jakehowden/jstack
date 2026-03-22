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

Post-ship manual testing session. Walk through the checklist, fix what breaks,
ship clean.

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

If `PROJECT_DOC_FOUND`: read `~/.jstack/projects/$SLUG.md`. Use the tech stack section to inform debugging during the fix loop.

If `PROJECT_DOC_MISSING`: continue without it — the skill works standalone.

---

## AskUserQuestion Format

For every AskUserQuestion:
1. **Re-ground:** State the PR, current test item, and what we're deciding. (1-2 sentences)
2. **Plain English:** Explain what to test and what to look for.
3. **Recommend:** `RECOMMENDATION: [action] because [one-line reason]` (only when applicable)
4. **Options:** Lettered A) B) C)

---

## Phase 1: Load Checklist

1. Find the open PR on the current branch:
   ```bash
   gh pr view --json number,title,body -q '{number: .number, title: .title, body: .body}'
   ```

2. Extract the `## Testing checklist` section from the PR body:
   - Find any of these headings (case-insensitive): `## Testing checklist`, `## Test plan`, `## Testing`, `## Manual testing`
   - Collect all `- [ ]` and `- [x]` lines until the next `##` heading or end of body
   - Strip the `- [ ]` / `- [x]` prefix; treat each line as one test item

3. **If no PR found:** Output: "No open PR found on this branch. Run /code-ship first, or paste your testing steps below." Accept freeform input — each line is one test item.

4. **If PR found but no checklist section:** Output: "PR #N found but no testing checklist in the body. Paste your testing steps below." Accept freeform input.

5. Display the full checklist and confirm via AskUserQuestion:

   > PR #N — "title". Ready to start testing. I'll walk you through each item one at a time.
   >
   > A) Let's go  B) Skip to a specific item  C) Abort

---

## Phase 2: Walk-Through Loop

For each checklist item, present via AskUserQuestion:

```
Testing PR #N — "<title>". Item X of Y.

Test: "<the test step>"

Try this now and tell me the result.
```

Options:
- A) Pass
- B) Fail — something went wrong
- C) Skip
- D) Add a new test item
- E) Done — stop here and show the report

**On Pass:** Record as passed. Move to next item.

**On Fail:** Enter Phase 3 (Fix Loop) for this item. Return here when resolved.

**On Skip:** Record as skipped with no reason. Move to next item.

**On Add new item:** Accept a test step from the user. Append to the checklist. Continue with the current item (do not skip it).

**On Done:** Exit to Phase 4 immediately.

When all items are complete, proceed to Phase 4.

---

## Phase 3: Fix Loop

Entered from Phase 2 when a test fails.

**Track fix metadata throughout:** for each fix applied, record `{file, line, description}` for use in the Phase 4 report.

**Fix Loop Rules:**
- Minimal diffs only — this is a testing session, not a refactor
- Understand the cause before proposing any fix
- Each cycle of propose → apply → retest → fail = 1 attempt
- After 3 failed cycles: flag the item as unresolved and return to Phase 2

### Loop steps

1. Ask the user to describe what went wrong (or paste the error output) via AskUserQuestion.

2. Read the relevant code files to understand the issue. Use Grep to find references. Identify the root cause before proposing anything.

3. Propose a minimal fix. State the cause first, then the fix. One change at a time.

4. Apply the fix using Edit (or Write for new files) with user approval.

5. Ask the user to retest:
   ```
   PR #N — "<title>". Testing: "<item>". Fix applied.

   Retest: "<what to try>"
   ```
   Options:
   - A) Now passes — record fix metadata, return to Phase 2
   - B) Still failing — propose a new fix (attempt N of 3)
   - C) New issue found — record this item as passed (the original problem is fixed), append the new issue as an ad-hoc test item, return to Phase 2

6. After 3 failed cycles: output "Couldn't resolve this one after 3 attempts. Moving on." Record as unresolved. Return to Phase 2.

---

## Phase 4: Test Report

Output the report:

```
TEST REPORT
════════════════════════════════════════
PR:       #N — <title>
Branch:   <branch>
Date:     <date>

Results:
  ✓ Passed:  N
  ✗ Failed:  N (M fixed during session)
  ○ Skipped: N
  + Ad-hoc:  N (items added during session)

Fixes Applied:
  - [file:line] <what was fixed>

Unresolved:
  - <item> — could not fix after 3 attempts

Status: DONE | DONE_WITH_CONCERNS | BLOCKED
════════════════════════════════════════
```

If no fixes were applied and no unresolved items: `Status: DONE`
If unresolved items exist: `Status: DONE_WITH_CONCERNS`
If testing was aborted before starting: `Status: BLOCKED`

Proceed to Phase 5 if any fixes were applied. Otherwise, stop here.

---

## Phase 5: Commit Fixes

Only runs if at least one fix was applied during the session.

1. Show the diff:
   ```bash
   git diff
   ```

2. Ask via AskUserQuestion:
   ```
   N fix(es) applied during this session. Commit and push to PR #N?
   ```
   Options:
   - A) Commit and push
   - B) Review changes first — show me the diff again
   - C) Discard all fixes

3. **On Commit:**
   - Stage modified files: `git add -u`
   - Stage any new files created during fixes explicitly: `git add <file>` for each file in the fix metadata that wasn't already tracked
   - Generate a commit message from the fixes applied: imperative summary, max 72 chars (e.g., "Fix login redirect and validate email input")
   - If multiple distinct fixes: add a body with one bullet per fix
   - Commit and push:
     ```bash
     git push
     ```

4. **On Discard:** Revert only the files modified during the testing session using the fix metadata: `git checkout -- <file1> <file2> ...` for each file in the tracked fix list. For any new files created during fixes, remove them with `rm <file>`. Do NOT use `git checkout -- .` — that would discard all unstaged changes, including work unrelated to this testing session.

---

## Completion Status

- **DONE** — All checklist items passed (or were fixed during the session), fixes committed
- **DONE_WITH_CONCERNS** — Testing complete but unresolved items remain (flagged after 3 fix attempts)
- **BLOCKED** — Could not load checklist, no PR found, or user aborted
