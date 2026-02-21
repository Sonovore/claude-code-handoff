---
description: Save session context for next session (interactive)
user_invocable: true
---

# /handoff

Interactive handoff command. Saves context before ending session or running `/clear`.

## Instructions

### Step 1: Ask handoff type

Use AskUserQuestion with these options:

**Question:** "What type of handoff?"
**Header:** "Handoff"
**Options:**
1. **Context** (default) - "General context, clears task/bug state. Use when work is complete or switching focus."
2. **Task** - "Multi-session task. Preserves detailed task tracking files."
3. **Bug** - "Bug investigation. Creates bug-specific context (can layer on top of task)."
4. **Recovery** - "Re-generate handoff from full transcript. Use after autocompact degraded context."

Note: **Clean** is also available if the user types it via "Other". See the Clean section below.

### Step 2: Execute based on selection

---

## Option: Context (Normal)

**Mode transition:**
1. Set `.claude/mode` to `normal`
2. Delete: `.claude/current-task.md`, `.claude/task-history.md`, `.claude/current-bug.md`

**Write `.claude/context.md` (max 50 lines):**

```markdown
# Session Context

## Current Work
[What was being worked on - 3-5 lines]

## Recent Changes
[Bullet list of files modified this session]

## Stable Features
[Bullet list of working features to avoid re-implementing]

## Build
\`\`\`bash
[Essential build commands]
\`\`\`

## Key Patterns
[Non-obvious patterns needed to continue work - max 5 lines]

## Next Steps
[What to do next - ordered list]
```

---

## Option: Task

**Mode transition:**
1. Set `.claude/mode` to `task`
2. Delete: `.claude/current-bug.md`
3. Preserve/create: `.claude/current-task.md`, `.claude/task-history.md`

**Write `.claude/context.md` (max 50 lines):**

```markdown
# Session Context

## Mode: Task

**Task:** [One-line description]
**Progress:** [X]% — [Current phase]
**Blocked:** [Yes/No - if yes, what's blocking]

See `.claude/current-task.md` for full details.

## Current Step
[What's being worked on RIGHT NOW - 2-3 lines]

## Key Files This Session
| File | Change |
|------|--------|
| file.c:123 | What changed |

## Build
\`\`\`bash
[Build command]
\`\`\`

## If Resuming Cold
[What someone needs to know to pick this up with NO other context - 5 lines max]
```

**Write `.claude/current-task.md` (max 100 lines):**

```markdown
# Task: [Title]

**Goal:** [One sentence]
**Acceptance:** [How we know it's done]

## Progress
[X]% complete. Phases: [list with checkmarks]

## Architecture Decisions
| Decision | Choice | Why |
|----------|--------|-----|

## Completed This Session
| Item | Key Files |
|------|-----------|

## Remaining
1. [Item]

## Key Code Locations
| File | Line | Description |
|------|------|-------------|

## Test Procedure
1. [Step]
```

**Append to `.claude/task-history.md` (2-4 lines):**

```markdown
Session N (YYYY-MM-DD): [What was accomplished]. Key: [most important file:line or decision].
```

---

## Option: Bug

**Mode transition:**
1. Read current mode from `.claude/mode`
2. If current mode is `task`: set mode to `task.bug` (PRESERVE task files)
3. Otherwise: set mode to `bug` (delete task files)
4. Create/update `.claude/current-bug.md`

**Write `.claude/context.md`:**

If standalone bug:
```markdown
# Session Context

## Mode: Bug

**Bug:** [One-line description]
**Symptom:** [What user sees]
**Status:** [Investigating / Root cause found / Fix in progress]

See `.claude/current-bug.md` for investigation details.

## Reproduce
1. [Step]

## Current Hypothesis
[What you think is wrong - 2 lines]

## Build
\`\`\`bash
[Build command]
\`\`\`
```

If bug within task (task.bug):
```markdown
# Session Context

## Mode: Task (blocked on bug)

**Task:** [Task name] — [X]% complete
**Blocker:** [Bug description]

### Bug Status
**Symptom:** [What's failing]
**Hypothesis:** [Current theory]

See `.claude/current-bug.md` for bug details.
See `.claude/current-task.md` for task details.

## Reproduce
1. [Step]

## Build
\`\`\`bash
[Build command]
\`\`\`
```

**Write `.claude/current-bug.md` (max 40 lines):**

```markdown
# Bug: [Title]

## Symptom
[What user sees - 2 lines max]

## Reproduce
1. [Step]

## Root Cause
[If known - 3 lines max. If unknown, write "Investigating"]

## Investigation
| What I tried | Result |
|--------------|--------|

## Hypothesis
[Current theory - 2 lines]

## Key Locations
| File:Line | What |
|-----------|------|

## Next Step
[Single action to take next]
```

---

## Option: Recovery

**Purpose:** Re-generate handoff files from the full conversation transcript after autocompact has degraded context. This recovers details that were lost during compaction (exact test results, per-file breakdowns, debugging sequences, specific parameter values, etc.).

**Important:** This option uses significant context. The user should `/clear` after recovery completes.

### Step R1: Locate and extract transcript

Find the current session's full transcript and extract the useful content:

```bash
# Find the most recent .jsonl transcript for this project
PROJECT_DIR="$HOME/.claude/projects/$(pwd | sed 's|/|-|g; s|^-||')"
TRANSCRIPT=$(ls -t "$PROJECT_DIR"/*.jsonl 2>/dev/null | head -1)
```

If no transcript is found, inform the user and abort.

Run the extraction script to pull out only meaningful content (user messages, assistant summaries, test results, diagnostics). This filters out file reads, build noise, task acks, and other tool noise:

```bash
python3 "$(git rev-parse --show-toplevel)/claude-code-handoff/extract-transcript.py" "$TRANSCRIPT"
```

The script outputs a chronological flow of USER requests, CLAUDE responses, and OUTPUT results. It automatically stops at the compaction boundary.

If the extraction script is not available, fall back to reading the `.jsonl` directly with the Read tool in chunks.

### Step R2: Read the extracted output

Read the extraction output directly into your context window using the Read tool. **Do NOT use a subagent** — the user will `/clear` or `/exit` after recovery, so using context space is fine and is the whole point.

As you read, note:
- Every user request and correction
- Test/build results with exact numbers
- Parameter tuning sequences (before → after)
- Diagnostic output (timing, per-component breakdowns)
- What worked vs. what didn't

### Step R3: Ask target handoff type

Use AskUserQuestion:

**Question:** "What type of handoff should I generate from the recovered context?"
**Header:** "Recovery"
**Options:**
1. **Task** (default) - "Multi-session task with full tracking files."
2. **Context** - "General context summary."
3. **Bug** - "Bug investigation context."

### Step R4: Generate handoff files

Using the recovered context (now in your main context window), generate the handoff files following the template for the selected type (Task, Context, or Bug) from the sections above.

**Key difference from normal handoff:** Since you have full recovered context, you can and SHOULD include more specific details than usual:
- Exact test result numbers per file, not just aggregates
- Specific parameter tuning history with rationale for each change
- Exact error messages and their fixes
- Detailed debugging timeline

The line limits on handoff files (50 for context.md, 100 for current-task.md) can be exceeded by up to 50% for recovery handoffs, since the extra detail is the whole point.

### Step R5: Report

Tell the user:
```
Recovery handoff complete:
- Source: [transcript path] ([N] lines)
- Generated: [list of files written]
- Type: [Context|Task|Bug]

You can now /clear to free context.
```

---

## Option: Clean

**Purpose:** Reset to clean state between unrelated work sessions. Keeps project configuration, clears all session-specific context.

**Delete these files:**
- `.claude/context.md`
- `.claude/current-task.md`
- `.claude/task-history.md`
- `.claude/current-bug.md`
- `.claude/session-state.md`

**Set `.claude/mode` to `normal`**

**Clean `.claude/tasks.md`:**
- Remove all completed tasks (lines with `~~strikethrough~~` or `✓ Done`)
- Keep pending tasks and backlog
- If file becomes empty, delete it

**Keep these files (don't touch):**
- `.claude/CLAUDE.md` (project instructions)
- `.claude/settings.json`, `.claude/settings.local.json`
- `.claude/docs/*`
- `.claude/commands/*`, `.claude/skills/*`, `.claude/hooks/*`

**Report to user:**
```
Cleaned session context:
- Deleted: context.md, current-task.md, task-history.md, current-bug.md, session-state.md
- Cleaned: tasks.md (removed N completed tasks)
- Mode: normal

Ready for fresh start.
```

---

## Cleanup Rules (apply to all handoff types except Clean)

Before writing files, apply these cleanup rules:

1. **Filter `/tmp/*` paths** - Don't include temporary file paths in "Recent Changes" or "Key Files"
2. **Dedupe tasks** - If tasks.md has duplicate entries, merge them
3. **Compress history** - If task-history.md exceeds 30 entries, compress old ones
4. **Remove stale references** - Don't reference files that no longer exist
