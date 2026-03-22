# jstack

Jake's personal dev workflow skill system for Claude Code.

## Pipeline

```
project-init → plan-feature → plan-review → code-review → code-ship → testing
                                                ↑
                                             debug
                                           document
```

Start a new project with `/project-init`. Plan features with `/plan-feature`.
Lock in the approach with `/plan-review`. Review your diff with `/code-review`.
Ship with `/code-ship`. Test what you shipped with `/testing`. Debug bugs with `/debug`.
Keep docs current with `/document`.

## Skills

| Skill | What it does |
|---|---|
| `/project-init` | One-time project setup — captures tech stack, goals, TODOs, conventions into a context doc all other skills read |
| `/plan-feature` | Brainstorm and design a feature — produces a design doc via iterative questioning and adversarial spec review |
| `/plan-review` | Engineering review of a plan — architecture, edge cases, test coverage, performance, one issue at a time |
| `/debug` | Systematic debugging — root cause first, Iron Law: no fixes without root cause |
| `/document` | Post-ship doc update — keeps README, CHANGELOG, TODOS accurate after code ships |
| `/code-review` | Pre-landing review — SQL safety, race conditions, LLM trust boundaries, style/convention check |
| `/code-ship` | Ship workflow — creates `feature/<name>` branch, commits, pushes, raises PR with TODO list and manual testing checklist |
| `/testing` | Post-ship testing session — walks through the PR checklist with an AI-assisted fix loop when tests fail |

## Install

```bash
git clone <this-repo> ~/Documents/Github/jstack
cd ~/Documents/Github/jstack
./setup
```

## Update

```bash
cd ~/Documents/Github/jstack
git pull
./setup
```

## Project context

Each project gets a context doc at `~/.jstack/projects/<slug>.md`. Run `/project-init`
once per project — every skill reads it automatically. `/code-ship` keeps it up to date
after each PR by marking resolved TODOs and updating the current state.
