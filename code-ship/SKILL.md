---
name: code-ship
version: 1.0.0
description: |
  Ship workflow: create a feature branch, commit, push, and raise a PR.
  PR includes a list of TODOs addressed (from TODOS.md + inline comments)
  and a manual testing checklist. Updates the project-init doc after shipping.
  Use when asked to "ship", "create a PR", "push this", or "raise a PR".
benefits-from: [project-init, code-review]
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
---

# /code-ship

Create a branch, commit, push, and raise a PR with a TODO summary and manual
testing checklist. Updates your project context doc after shipping.

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
echo "$_MODEL" | grep -qi "sonnet" || echo "WRONG_MODEL: $_MODEL"
```

If `WRONG_MODEL` appears in the output: stop immediately and output:

> Wrong model: this skill requires Sonnet. Run `/model claude-sonnet-4-6` then re-run.

If `PROJECT_DOC_FOUND`: read `~/.jstack/projects/$SLUG.md`. Load conventions (branch strategy, PR conventions) and current state (for doc update in Step 6).

---

## Step 1: Detect TODOs addressed

Scan the working tree diff for resolved work:

```bash
git diff HEAD --unified=0
```

**From inline comments** — find removed `TODO` markers:
```bash
git diff HEAD | grep "^-.*\(TODO\|FIXME\|HACK\)" | sed 's/^-//'
```

**From TODOS.md** — cross-reference open items against the diff:
Read `TODOS.md` if it exists. For each open item, check whether the diff contains changes that plausibly address it (filename matches, keyword overlap in description vs. changed code).

Build a list: **Resolved TODOs** (from both sources, deduplicated).

---

## Step 2: Branch creation

Check current branch:
```bash
git branch --show-current
```

If already on a `feature/` branch: ask whether to continue on this branch or create a new one.

If on main/master/develop: ask the user:

> What is this shipping? (used for branch name)
> e.g. "user auth", "fix login bug", "add dashboard charts"

Create and checkout:
```bash
git checkout -b feature/<slugified-answer>
```

Slugify: lowercase, hyphens, no special chars, max 50 chars.

---

## Step 3: Stage and commit

Stage all modified tracked files:
```bash
git add -u
```

Also stage any new files that are clearly part of the feature (use judgment — don't stage `.env`, credentials, or unrelated scratch files).

Generate a commit message from the diff:
- First line: imperative summary, max 72 chars ("Add user authentication flow")
- Body (optional): brief explanation of why

```bash
git commit -m "<generated message>"
```

---

## Step 4: Push

```bash
git push -u origin feature/<branch-name>
```

---

## Step 5: Create PR

Generate the PR body:

```markdown
## What this ships
<1-3 sentence plain-English summary of the changes>

## TODOs addressed
<If none: "No open TODOs were addressed in this PR.">
- [ ] <todo item from TODOS.md or inline comment>
- [ ] <todo item>

## Testing checklist
- [ ] <plain-English manual step — e.g. "Open the login page and submit with a valid email/password — confirm you land on the dashboard">
- [ ] <plain-English manual step>
- [ ] <plain-English manual step for an edge case — e.g. "Submit the form with an empty password field — confirm error message appears">
```

<!-- CONTRACT: /testing depends on the "## Testing checklist" heading in the PR body template above. Do not rename it. -->

**Testing checklist generation rules:**
- One step per logical change in the diff
- Written as human-readable actions: "Open X and do Y — confirm Z"
- Cover the happy path first, then key edge cases
- Never write test code — these are manual verification steps for the user to tick off

Create the PR:
```bash
gh pr create \
  --title "<imperative summary matching commit>" \
  --body "$(cat <<'EOF'
<generated body>
EOF
)"
```

Output the PR URL.

---

## Step 6: Update project-init doc

If `PROJECT_DOC_MISSING`: skip this step silently.

If `PROJECT_DOC_FOUND`:

1. **Mark resolved TODOs as done** in the "Known TODOs" section of `~/.jstack/projects/$SLUG.md`:
   For each resolved TODO, add `*(resolved — PR #N, <date>)*` inline.

2. **Update "Current State"** if significant new capabilities shipped:
   Append a brief note describing what's new.

3. **Update "Last updated" line**:
   ```
   Last updated: <date> (code-ship — PR #N)
   ```

Use Edit tool with exact string matching — never overwrite the whole file.

---

## Completion Status

Output a summary:
```
Shipped:
  Branch:   feature/<name>
  PR:       <URL>
  TODOs:    N addressed
  Checklist: N manual steps
  Project doc: Updated / Skipped (no doc)
```

- **DONE** — Branch created, committed, pushed, PR raised, doc updated
- **DONE_WITH_CONCERNS** — PR raised but with warnings (e.g., large diff, no tests)
- **BLOCKED** — Git errors, gh auth issues, or user aborted
