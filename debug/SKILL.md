---
name: debug
version: 1.0.0
description: |
  Systematic debugging with root cause investigation. Four phases: investigate,
  analyze, hypothesize, implement. Iron Law: no fixes without root cause.
  Reads project-init context for tech stack clues.
  Use when asked to "debug this", "fix this bug", "why is this broken",
  or "root cause analysis".
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
---

# /debug

Systematic root cause debugging. No fixes without evidence.

## Preamble

```bash
~/.jstack/bin/jstack-preamble opus
```

If `WRONG_MODEL` in output: stop — tell user to run `/model claude-opus-4-6` then re-run.
If `PROJECT_DOC_FOUND`: read `~/.jstack/projects/$SLUG.md` tech stack section — use it to narrow hypotheses and identify likely failure modes.

---

## Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.** Fixing symptoms creates whack-a-mole debugging. Find the root cause, then fix it.

---

## Phase 1: Root Cause Investigation

1. Collect symptoms: error messages, stack traces, reproduction steps. If insufficient, ask ONE question at a time via AskUserQuestion.
2. Read the code: trace the codepath from symptom back to causes. Grep for all references.
3. Check recent changes: `git log --oneline -20 -- <affected-files>` — regressions are in the diff.
4. Reproduce: can you trigger the bug deterministically? If not, gather more evidence first.

Output: **"Root cause hypothesis: ..."** — a specific, testable claim.

---

## Scope Lock

After forming a hypothesis, identify the narrowest directory containing the affected files:
```bash
mkdir -p ~/.jstack
echo "<detected-directory>/" > ~/.jstack/debug-scope.txt
echo "Debug scope locked to: <detected-directory>/"
```

Tell the user the scope. If the bug spans the whole repo, skip and note why.

---

## Phase 2: Pattern Analysis

Check if the bug matches a known pattern:

| Pattern | Signature | Where to look |
|---------|-----------|---------------|
| Race condition | Intermittent, timing-dependent | Concurrent access to shared state |
| Nil/null propagation | NoMethodError, TypeError | Missing guards on optional values |
| State corruption | Inconsistent data, partial updates | Transactions, callbacks, hooks |
| Integration failure | Timeout, unexpected response | External API calls, service boundaries |
| Configuration drift | Works locally, fails in staging | Env vars, feature flags, DB state |
| Stale cache | Shows old data, fixes on cache clear | Redis, CDN, browser cache |

Also check `TODOS.md` for related known issues; `git log` for prior fixes in the same area (recurring bugs = architectural smell).

---

## Phase 3: Hypothesis Testing

Before writing ANY fix, verify the hypothesis.

1. Add a temporary log/assertion at the suspected root cause. Does the evidence match?
2. If wrong: return to Phase 1. Do not guess.
3. **3-strike rule:** if 3 hypotheses fail, STOP and ask via AskUserQuestion:
   ```
   3 hypotheses tested, none confirmed.
   A) Continue — I have a new hypothesis: [describe]
   B) Escalate — needs deeper system knowledge
   C) Add logging — instrument and catch it next time
   ```

Red flags: proposing a fix before tracing data flow; "quick fix for now"; each fix reveals a new problem elsewhere.

---

## Phase 4: Implementation

Once root cause confirmed:
1. Fix the root cause, not the symptom. Smallest change that eliminates the actual problem.
2. Minimal diff: fewest files, fewest lines.
3. Write a regression test that **fails** without the fix and **passes** with it.
4. Run the full test suite. No regressions allowed.
5. If fix touches >5 files, ask via AskUserQuestion:
   ```
   Fix touches N files — large blast radius.
   A) Proceed — root cause spans these files
   B) Split — fix critical path now, defer rest
   C) Rethink — is there a more targeted approach?
   ```

---

## Phase 5: Verification & Report

Reproduce the original bug scenario and confirm it's fixed. Not optional. Run the test suite and paste output.

```
DEBUG REPORT
════════════════════════════════════════
Symptom:         [what the user observed]
Root cause:      [what was actually wrong]
Fix:             [what was changed, file:line]
Evidence:        [test output confirming fix]
Regression test: [file:line of new test]
Related:         [TODOS.md items, prior bugs in same area]
Status:          DONE | DONE_WITH_CONCERNS | BLOCKED
════════════════════════════════════════
```

---

## Important Rules

- **3+ failed fix attempts → STOP** and question the architecture
- **Never apply a fix you cannot verify**
- **Never say "this should fix it"** — prove it
- **If fix touches >5 files → AskUserQuestion** about blast radius
- **Never `git push`** — committing locally is fine, pushing waits for `/code-ship`

**DONE** — Root cause found, fix applied, regression test written, all tests pass | **DONE_WITH_CONCERNS** — Fixed but cannot fully verify | **BLOCKED** — Root cause unclear, escalated
