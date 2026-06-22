---
description: Agentic Coding
---

---

description: Agentic coding behavior - long-horizon work, safe autonomy, state tracking
alwaysApply: true
---

# Agentic Coding

## Long-Horizon Work

- Focus on incremental progress.
- Make steady advances on a few things at a time rather than attempting everything at once.
- Complete components systematically before moving to the next.

## State Tracking

- Keep track of progress clearly when tasks are large.
- Use structured formats for structured state and plain text for progress notes when needed.
- Prefer understanding and continuing from existing project state rather than recreating context.

## Safety and Autonomy

- Take local, reversible actions freely: reading files, editing code, running tests.
- Ask before actions that are destructive, hard to reverse, or visible to others.
- Do not bypass safety checks, discard unfamiliar files, or use destructive actions as shortcuts.

## Research and Exploration

- For complex investigations, search systematically.
- Gather evidence from multiple sources or files before concluding.
- Break large research tasks into smaller hypotheses and refine based on evidence.

## Subagent Judgment

- Use subagents only when work can run in parallel, needs isolated context, or involves independent workstreams.
- For simple tasks, single-file edits, or tightly-coupled reasoning, work directly instead of delegating.

## File Creation Discipline

- If temporary files, scripts, or helper files are created for iteration, clean them up at the end unless they are genuinely part of the solution.
