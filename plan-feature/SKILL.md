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

Brainstorm and produce a design doc for a feature.

## Preamble

```bash
~/.jstack/bin/jstack-preamble opus
```

If `WRONG_MODEL` in output: stop — tell user to run `/model claude-opus-4-6` then re-run.
If `PROJECT_DOC_FOUND`: read `~/.jstack/projects/$SLUG.md` — use tech stack, TODOs, conventions throughout.
If `PROJECT_DOC_MISSING`: tell user "Tip: run /project-init for better suggestions." Continue.

---

## AskUserQuestion Format

For every AskUserQuestion: (1) re-ground in project/branch/decision, (2) explain the tradeoff plainly, (3) `RECOMMENDATION: Choose [X] because [reason]`, (4) lettered options A) B) C).

---

## Phase 1: Context Gathering

1. Read `CLAUDE.md`, `TODOS.md` if they exist.
2. Run `git log --oneline -20`.
3. `ls -t ~/.jstack/projects/$SLUG/*-design-*.md 2>/dev/null | head -5` — list prior designs.
4. Check bugs: `gh issue list --state open --label bug --limit 10 --json number,title,createdAt --jq '.[] | "#\(.number) \(.title) (\(.createdAt | split("T")[0]))"' 2>/dev/null`
   Fallback if empty: `gh issue list --state open --limit 10 --search "bug OR fix OR broken" --json number,title,createdAt --jq '.[] | "#\(.number) \(.title) (\(.createdAt | split("T")[0]))"' 2>/dev/null`

   If bugs found: ask via AskUserQuestion — list them, offer A) pick a bug or B) build something new. RECOMMENDATION: fix bugs first.
   If user picks a bug: `gh issue view <number> --json title,body,comments`. Skip Phase 2, use bug context for Phase 3 premises.
   If no bugs: continue silently.

5. Ask "What are you thinking about building?" via AskUserQuestion. After answer, check for keyword overlap: `grep -li "<keyword>" ~/.jstack/projects/$SLUG/*-design-*.md 2>/dev/null`. If related prior design found: ask whether to build on it or start fresh.

---

## Phase 2: Builder Questions (one at a time)

**Q1** — What's the coolest version? What would make it genuinely impressive?
**Q2** — Who would you show this to? What would make them say "whoa"?
**Q3** — What's the fastest path to something usable? Smallest version worth shipping?
**Q4** — What already exists that's closest? How is yours different?

Smart-skip any question the user's initial prompt already answers.
Escape hatch: if user says "just do it" or seems impatient → skip to Phase 4. Still run Phase 3.

---

## Phase 3: Premise Challenge

Before proposing solutions, challenge:
1. Is this the right problem? Could a different framing be simpler or more impactful?
2. What happens if we do nothing? Real pain or hypothetical?
3. What existing code partially solves this?

State as `PREMISES:\n1. [statement] — agree/disagree?` via AskUserQuestion. If user disagrees, revise and re-ask.

---

## Phase 4: Alternatives Generation (MANDATORY)

Produce 2-3 approaches in this format:
```
APPROACH A: [Name]
  Summary: [1-2 sentences] | Effort: S/M/L/XL | Risk: Low/Med/High
  Pros: [2-3 bullets] | Cons: [2-3 bullets] | Reuses: [existing code]
```
Rules: at least 2 approaches; one minimal viable, one ideal architecture.
`RECOMMENDATION: Choose [X] because [reason].`
Present via AskUserQuestion. Do not proceed without approval.

---

## Phase 5: Design Doc

```bash
source <(~/.jstack/bin/jstack-slug 2>/dev/null) || SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
USER=$(whoami); DATETIME=$(date +%Y%m%d-%H%M%S); mkdir -p ~/.jstack/projects/$SLUG
PRIOR=$(ls -t ~/.jstack/projects/$SLUG/*-$BRANCH-design-*.md 2>/dev/null | head -1)
```

Write to `~/.jstack/projects/{slug}/{user}-{branch}-design-{datetime}.md` with these sections:
- Header: `# Design: {title}`, Generated/Branch/Repo/Status: DRAFT, Supersedes (if PRIOR exists)
- **Problem Statement** — what we're building and why
- **What Makes This Good** — the core "whoa" factor
- **Constraints** — tech stack constraints from project-init doc
- **Premises** — from Phase 3
- **Approaches Considered** — from Phase 4 (A, B, optional C)
- **Recommended Approach** — chosen approach with rationale
- **Testing Strategy** — see rules below
- **Open Questions** — unresolved questions
- **Success Criteria** — measurable definition of done
- **Next Steps** — concrete ordered build tasks

### Testing Strategy Rules

1. Check `~/.jstack/projects/$SLUG.md` for `## Testing` section, framework keywords (npm test, pytest, go test, make test), test directory patterns.
2. If found: use detected framework, test directory, naming conventions explicitly.
3. If not found: describe tests in terms of inputs/outputs/edge cases; no framework assumed.
4. **What to Test**: 3-6 bullets (happy path + key edge cases + error cases).
5. **Where Tests Go**: 1-2 lines (directory + naming pattern).
6. **Coverage Notes**: 2-4 bullets (highest-risk areas and why they need coverage).
7. If multiple suites (unit/integration/e2e): organize "What to Test" by suite, 3-5 items each.

---

## Phase 5.5: Spec Review

Dispatch a reviewer subagent with the file path. Review on: Completeness, Consistency, Clarity, Scope (YAGNI), Feasibility, Testability. Get quality score (1-10) + issues list. Fix issues and re-dispatch up to 3 iterations. If same issues recur, add "Reviewer Concerns" section.

Tell user: "Your doc survived N rounds of review. M issues caught and fixed. Quality score: X/10."

---

## Phase 6: Approval

Ask via AskUserQuestion: A) Approve (mark Status: APPROVED, ready for /plan-review) | B) Revise (specify sections, loop back) | C) Start over (return to Phase 2).

Once APPROVED: "Design doc saved. Run **/plan-review** to lock in the engineering approach before building."

**DONE** — APPROVED | **DONE_WITH_CONCERNS** — Approved with open questions | **NEEDS_CONTEXT** — User left questions unanswered
