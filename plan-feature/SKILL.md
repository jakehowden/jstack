---
name: plan-feature
version: 1.0.0
description: |
  Brainstorm and design a feature. Produces a design doc at
  ~/.jstack/projects/<slug>/design-<datetime>.md. Reads the project-init
  context doc to ground the session. Feeds into /plan-review.
  Use when asked to "plan a feature", "brainstorm", "design this", or "office hours".
benefits-from: [project-init]
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
  - Agent
---

# /plan-feature

Brainstorm and produce a design doc for a feature. Reads your project context
so the session starts grounded in your stack, goals, and constraints.

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

If `PROJECT_DOC_MISSING`: tell the user "Tip: run /project-init to set up project context — it helps plan-feature give better suggestions." Then continue without it.

If `PROJECT_DOC_FOUND`: read `~/.jstack/projects/$SLUG.md` and load it as session context. Reference it throughout the session — tech stack constraints, existing TODOs, conventions.

---

## AskUserQuestion Format

For every AskUserQuestion:
1. **Re-ground:** State the project, current branch, and what we're deciding. (1-2 sentences)
2. **Plain English:** Explain the tradeoff clearly. No jargon.
3. **Recommend:** `RECOMMENDATION: Choose [X] because [one-line reason]`
4. **Options:** Lettered A) B) C)

---

## Phase 1: Context Gathering

1. Read `CLAUDE.md`, `TODOS.md` if they exist.
2. Run `git log --oneline -20` to understand recent context.
3. Search for existing design docs for this project:
   ```bash
   ls -t ~/.jstack/projects/$SLUG/*-design-*.md 2>/dev/null | head -5
   ```
   If prior designs exist, list them: "Prior designs for this project: [titles + dates]"

4. Check for open bugs on this repo:
   ```bash
   gh issue list --state open --label bug --limit 10 --json number,title,createdAt --jq '.[] | "#\(.number) \(.title) (\(.createdAt | split("T")[0]))"' 2>/dev/null
   ```
   If no issues found with the `bug` label, try a keyword search as fallback:
   ```bash
   gh issue list --state open --limit 10 --search "bug OR fix OR broken" --json number,title,createdAt --jq '.[] | "#\(.number) \(.title) (\(.createdAt | split("T")[0]))"' 2>/dev/null
   ```

   **If bugs found:** present them before the open-ended question. Ask via AskUserQuestion:

   > I found some open bugs on this repo:
   >
   > 1. #42 — Fix login redirect loop (2026-03-20)
   > 2. #38 — Dashboard chart crashes on empty data (2026-03-18)
   >
   > Would you like to work on one of these, or build something new?
   >
   > RECOMMENDATION: Squash bugs before building new features — less tech debt.
   >
   > A) Pick a bug (tell me which number)
   > B) Build something new

   **If user picks a bug:** Run `gh issue view <number> --json title,body,comments` to load
   full context. Use the bug's title, description, and comments as the feature context for
   all subsequent phases. The "feature" becomes "fix for #N". Skip Phase 2 builder questions —
   the bug report already provides the problem statement. Proceed directly to Phase 3
   (Premise Challenge) with premises derived from the bug report.

   **If user picks "build something new":** Continue to step 5 as normal.

   **If no bugs found:** Skip this step silently. Continue to step 5.

5. Ask what the user wants to build:

   > What are you thinking about building or exploring? What's the idea?

   Ask via AskUserQuestion. After they answer, check for keyword overlap with prior designs:
   ```bash
   grep -li "<keyword>" ~/.jstack/projects/$SLUG/*-design-*.md 2>/dev/null
   ```
   If a related prior design is found: "Related prior design found — [title]. Should we build on it or start fresh?"

---

## Phase 2: Builder Questions (one at a time)

Ask these **one at a time** via AskUserQuestion. Stop after each — wait for the answer.

**Q1 — What's the coolest version of this?**
What would make it genuinely delightful or impressive?

**Q2 — Who would you show this to?**
What would make them say "whoa"?

**Q3 — What's the fastest path to something usable?**
What's the smallest version that's still worth shipping?

**Q4 — What's closest to this that already exists?**
How is yours different or better?

**Smart-skip:** If the user's initial prompt already answers a question clearly, skip it. Only ask questions whose answers aren't yet known.

**Escape hatch:** If the user says "just do it", provides a fully formed plan, or seems impatient → fast-track to Phase 4 (Alternatives). Still run Phase 3 (Premise Challenge).

---

## Phase 3: Premise Challenge

Before proposing solutions, challenge the premises:

1. **Is this the right problem?** Could a different framing yield a simpler or more impactful solution?
2. **What happens if we do nothing?** Real pain point or hypothetical?
3. **What existing code already partially solves this?** Map existing patterns that could be reused.

Output as clear statements the user must agree with before proceeding:
```
PREMISES:
1. [statement] — agree/disagree?
2. [statement] — agree/disagree?
```

Use AskUserQuestion to confirm. If the user disagrees with a premise, revise and loop back.

---

## Phase 4: Alternatives Generation (MANDATORY)

Produce 2-3 distinct implementation approaches:

```
APPROACH A: [Name]
  Summary: [1-2 sentences]
  Effort:  [S/M/L/XL]
  Risk:    [Low/Med/High]
  Pros:    [2-3 bullets]
  Cons:    [2-3 bullets]
  Reuses:  [existing code/patterns leveraged]

APPROACH B: [Name]
  ...

APPROACH C: [Name] (optional)
  ...
```

Rules:
- At least 2 approaches required
- One must be the **minimal viable** (fewest files, ships fastest)
- One must be the **ideal architecture** (best long-term)

`RECOMMENDATION: Choose [X] because [one-line reason].`

Present via AskUserQuestion. Do not proceed without approval.

---

## Phase 5: Design Doc

Write the design document:

```bash
source <(~/.jstack/bin/jstack-slug 2>/dev/null)
USER=$(whoami)
DATETIME=$(date +%Y%m%d-%H%M%S)
mkdir -p ~/.jstack/projects/$SLUG
```

Check for prior design on this branch:
```bash
PRIOR=$(ls -t ~/.jstack/projects/$SLUG/*-$BRANCH-design-*.md 2>/dev/null | head -1)
```

Write to `~/.jstack/projects/{slug}/{user}-{branch}-design-{datetime}.md`:

```markdown
# Design: {title}

Generated by /plan-feature on {date}
Branch: {branch}
Repo: {slug}
Status: DRAFT
Supersedes: {prior filename — omit if first design on this branch}

## Problem Statement
{what we're building and why}

## What Makes This Good
{the core value or "whoa" factor}

## Constraints
{tech stack constraints, conventions from project-init doc}

## Premises
{from Phase 3}

## Approaches Considered
### Approach A: {name}
{from Phase 4}
### Approach B: {name}
{from Phase 4}

## Recommended Approach
{chosen approach with rationale}

## Testing Strategy
{auto-generated from project context — framework, test location, naming conventions}

### What to Test
{key behaviors and edge cases derived from the feature design}

### Where Tests Go
{test directory and file naming pattern, inferred from project conventions}

### Coverage Notes
{which parts of the recommended approach need test coverage and why}

## Open Questions
{unresolved questions}

## Success Criteria
{what "done" looks like — measurable}

## Next Steps
{concrete build tasks — what to implement first, second, third}
```

**Testing Strategy generation rules:**

1. **Read project context.** Check the project-init doc (`~/.jstack/projects/$SLUG.md`)
   for any of these headings or keywords: `## Testing`, `## Test`, `test framework`,
   `test runner`, `test directory`, `testing conventions`. Also check for tool/script
   references like `npm test`, `pytest`, `go test`, `make test`.

2. **If testing info found:** populate the Testing Strategy section using the detected
   framework, test directory, and naming conventions. Reference them explicitly
   (e.g., "Tests use Vitest, live in `src/__tests__/`, named `*.test.ts`").
   If multiple frameworks are mentioned, reference all of them and organize
   the testing section by suite/framework.

3. **If no testing info found:** generate a framework-agnostic testing section based on
   the feature design alone. Focus on what the key testable behaviors are. Do not
   assume a specific framework — describe tests in terms of inputs, expected outputs,
   and edge cases.

4. **Scope guidance:**
   - "What to Test": 3-6 bullet points covering happy path, key edge cases, and error cases.
   - "Where Tests Go": 1-2 lines naming the directory and file naming pattern.
   - "Coverage Notes": 2-4 bullets identifying which parts of the chosen approach carry
     the most risk and why they need test coverage.

5. **Complex setups:** If the project has multiple test suites (unit, integration, e2e),
   organize "What to Test" by suite. Keep each suite's list to 3-5 items.

---

## Phase 5.5: Spec Review

Dispatch an independent reviewer subagent. Provide the file path and ask it to review on 6 dimensions:
1. **Completeness** — All requirements addressed?
2. **Consistency** — Any contradictions?
3. **Clarity** — Could an engineer implement this without questions?
4. **Scope** — Any YAGNI violations?
5. **Feasibility** — Can this actually be built as described?
6. **Testability** — Does the testing strategy cover the key behaviors from the recommended approach? Are there untested risk areas?

Ask for a quality score (1-10) and list of issues.

Fix each issue and re-dispatch up to 3 iterations. If same issues recur, add a "Reviewer Concerns" section to the doc.

Tell the user: "Your doc survived N rounds of review. M issues caught and fixed. Quality score: X/10."

---

## Phase 6: Approval

Present via AskUserQuestion:
- A) Approve — mark Status: APPROVED, ready for /plan-review
- B) Revise — specify which sections to change (loop back)
- C) Start over — return to Phase 2

---

## Handoff

Once APPROVED, tell the user:
"Design doc saved. Run **/plan-review** to lock in the engineering approach before building."

---

## Completion Status

- **DONE** — Design doc APPROVED
- **DONE_WITH_CONCERNS** — Approved but with open questions listed
- **NEEDS_CONTEXT** — User left questions unanswered
