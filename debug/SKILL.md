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

If `PROJECT_DOC_FOUND`: read `~/.jstack/projects/$SLUG.md`. Use the tech stack section to narrow hypotheses — knowing the framework, database, and infra helps identify likely failure modes faster.

---

## Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

Fixing symptoms creates whack-a-mole debugging. Every fix that doesn't address root cause makes the next bug harder to find. Find the root cause, then fix it.

---

## Phase 1: Root Cause Investigation

Gather context before forming any hypothesis.

1. **Collect symptoms:** Read the error messages, stack traces, and reproduction steps. If the user hasn't provided enough context, ask ONE question at a time via AskUserQuestion.

2. **Read the code:** Trace the code path from the symptom back to potential causes. Use Grep to find all references, Read to understand the logic.

3. **Check recent changes:**
   ```bash
   git log --oneline -20 -- <affected-files>
   ```
   Was this working before? What changed? A regression means the root cause is in the diff.

4. **Reproduce:** Can you trigger the bug deterministically? If not, gather more evidence before proceeding.

Output: **"Root cause hypothesis: ..."** — a specific, testable claim about what is wrong and why.

---

## Scope Lock

After forming your root cause hypothesis, lock edits to the affected module to prevent scope creep.

Identify the narrowest directory containing the affected files. Tell the user: "Restricting edits to `<dir>/` for this debug session to prevent changes to unrelated code."

Write the scope to a state file:
```bash
mkdir -p ~/.jstack
echo "<detected-directory>/" > ~/.jstack/debug-scope.txt
echo "Debug scope locked to: <detected-directory>/"
```

If the bug spans the entire repo, skip the lock and note why.

---

## Phase 2: Pattern Analysis

Check if this bug matches a known pattern:

| Pattern | Signature | Where to look |
|---------|-----------|---------------|
| Race condition | Intermittent, timing-dependent | Concurrent access to shared state |
| Nil/null propagation | NoMethodError, TypeError | Missing guards on optional values |
| State corruption | Inconsistent data, partial updates | Transactions, callbacks, hooks |
| Integration failure | Timeout, unexpected response | External API calls, service boundaries |
| Configuration drift | Works locally, fails in staging/prod | Env vars, feature flags, DB state |
| Stale cache | Shows old data, fixes on cache clear | Redis, CDN, browser cache |

Also check:
- `TODOS.md` for related known issues
- `git log` for prior fixes in the same area — recurring bugs in the same files are an architectural smell

---

## Phase 3: Hypothesis Testing

Before writing ANY fix, verify your hypothesis.

1. **Confirm the hypothesis:** Add a temporary log statement, assertion, or debug output at the suspected root cause. Does the evidence match?

2. **If wrong:** Return to Phase 1. Gather more evidence. Do not guess.

3. **3-strike rule:** If 3 hypotheses fail, **STOP** and use AskUserQuestion:
   ```
   3 hypotheses tested, none confirmed.

   A) Continue — I have a new hypothesis: [describe]
   B) Escalate — this needs deeper knowledge of the system
   C) Add logging — instrument the area and catch it next time
   ```

**Red flags:**
- Proposing a fix before tracing data flow — you're guessing
- "Quick fix for now" — there is no "for now"
- Each fix reveals a new problem elsewhere — wrong layer, not wrong code

---

## Phase 4: Implementation

Once root cause is confirmed:

1. **Fix the root cause, not the symptom.** Smallest change that eliminates the actual problem.
2. **Minimal diff:** Fewest files touched, fewest lines changed.
3. **Write a regression test** that:
   - **Fails** without the fix (proves the test is meaningful)
   - **Passes** with the fix (proves the fix works)
4. **Run the full test suite.** No regressions allowed.
5. **If fix touches >5 files:** Use AskUserQuestion to flag the blast radius:
   ```
   This fix touches N files — large blast radius for a bug fix.
   A) Proceed — root cause genuinely spans these files
   B) Split — fix the critical path now, defer the rest
   C) Rethink — is there a more targeted approach?
   ```

---

## Phase 5: Verification & Report

Reproduce the original bug scenario and confirm it's fixed. Not optional.

Run the test suite and paste the output.

```
DEBUG REPORT
════════════════════════════════════════
Symptom:         [what the user observed]
Root cause:      [what was actually wrong]
Fix:             [what was changed, with file:line references]
Evidence:        [test output, reproduction attempt showing fix works]
Regression test: [file:line of the new test]
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

## Completion Status

- **DONE** — Root cause found, fix applied, regression test written, all tests pass
- **DONE_WITH_CONCERNS** — Fixed but cannot fully verify (intermittent, requires staging)
- **BLOCKED** — Root cause unclear after investigation, escalated
