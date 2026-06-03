---
description: Save session context for next session (interactive)
user_invocable: true
---

# /handoff

Interactive handoff command. Saves context before ending session or running `/clear`.

## Guiding principle: write for the NEXT context window

Optimize every handoff for what the next session needs to *act*, not for a record of what happened. The next window can recover completed work from git, the code, and commit messages — so spend the budget on what it *cannot* recover:

- **The forward-looking conversation.** When one or more parts of the work just finished, the highest-value content is the discussion about what comes next — decisions made, options weighed, the direction agreed on, and the user's stated intent in their own phrasing. Capture that conversation, not a summary of finished code.
- **Just enough history as a safety net.** A few lines on what was done and why, in case a decision needs revisiting. Keep it terse.
- **Empirical results that are expensive to reproduce** — especially for bugs: exact commands and their actual outputs.

When trimming to fit a size budget, cut historical narrative first; preserve next-step reasoning and un-reproducible results last.

## Instructions

### Step 0: Discover all relevant `.claude/` directories

**This step is non-negotiable.** Claude Code auto-loads `CLAUDE.md` from parent directories at session start, but during a handoff Claude is generating new content from memory and can miss parent-level state. Before writing anything, explicitly enumerate and read every `.claude/` in the tree.

1. **Resolve the write target** — the handoff writes to one canonical location:
   ```bash
   PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
   ```
   All `.claude/<file>` writes below resolve to `$PROJECT_ROOT/.claude/<file>`. Use absolute paths in tool calls; do not rely on cwd.

2. **Discover all `.claude/` directories from `$PROJECT_ROOT` up to `$HOME`** (inclusive):
   ```bash
   d="$PROJECT_ROOT"
   while true; do
     [ -d "$d/.claude" ] && echo "$d/.claude"
     if [ "$d" = "$HOME" ] || [ "$d" = "/" ]; then break; fi
     d="$(dirname "$d")"
   done
   ```
   Run this and capture the list. Most projects have one or two; cross-project setups (e.g., a parent dir hosting multiple repos with shared instructions) have more. Stop after checking `$HOME` — do not walk above the user's home directory.

3. **Read every relevant file at every level discovered.** For each `.claude/` directory found:
   - `CLAUDE.md` — instructions (parent levels often hold global preferences; project level holds project-specific rules)
   - `mode` — current mode (normal / task / bug / task.bug)
   - `context.md` — session context
   - `current-task.md` — active task details
   - `current-bug.md` — active bug details
   - `task-history.md` — historical task entries
   - `recent-prompts.md` — recent user prompts
   - `session-state.md` — live session state from proactive-handoff.sh
   - `tasks.md` — pending task list

   Read whatever exists; don't error on missing files. Read in **parallel** when possible (multiple `Read` tool calls in one message).

4. **Build the full picture before writing.** The new handoff content must reflect:
   - The user's intent across this session (from recent-prompts.md and conversation)
   - Active task / bug state (from current-task.md, current-bug.md at every level)
   - Session-state events (file edits, agent dispatches) from session-state.md
   - Any parent-level state that the next session must also check

   If parent-level `.claude/` directories contain task/bug/context state, **note them in the new context.md** with explicit paths so the next session knows to read them. Do not silently overwrite parent-level files unless the user explicitly asked.

5. **Write target = project-level `.claude/` only**, unless the user explicitly says otherwise. Cross-project state stays in parent `.claude/`. The handoff coordinates them by reference, not by overwriting.

### Step 1: Ask handoff type

Use AskUserQuestion with these options:

**Question:** "What type of handoff?"
**Header:** "Handoff"
**Options:**
1. **Context** (default) - "General context, clears task/bug state. Use when work is complete or switching focus."
2. **Task** - "Multi-session task. Preserves detailed task tracking files."
3. **Bug** - "Bug investigation. Creates bug-specific context (can layer on top of task)."
4. **Clean** - "Reset to clean state. Keeps only project-specific files (CLAUDE.md, settings), clears all session context."

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

## Mode: Task (a moving process — capture where it's heading, not just where it's been)

**Task:** [One-line description]
**Progress:** [X]% — [Current phase]
**Blocked:** [Yes/No - if yes, what's blocking]

See `.claude/current-task.md` for full details.

## Next Up — Decided Direction & Open Threads
The forward-looking conversation. This is the most valuable part of the handoff — especially if a part just finished. Capture in priority order:
1. **What we decided to do next and why** — the conclusion of the most recent discussion, in the user's framing/phrasing.
2. **Options still open / not yet decided** — anything under debate, with the trade-offs already surfaced so they aren't re-litigated next session.
3. **Immediate next action** — the single concrete thing to start with.

## Current Step
[What's being worked on RIGHT NOW - 2-3 lines]

## Done This Session (fallback context — keep brief)
[2-4 bullets of what changed and why; recoverable from git if needed]

## Key Files This Session
| File | Change |
|------|--------|
| file.c:123 | What changed |

## Build
\`\`\`bash
[Build command]
\`\`\`

## Recent Prompts
See `.claude/recent-prompts.md` for the user's last prompts before handoff.

## If Resuming Cold
[What someone needs to know to pick this up with NO other context - 5 lines max]
```

**Write `.claude/current-task.md` (max 100 lines):**

```markdown
# Task: [Title]

**Goal:** [One sentence]
**Acceptance:** [How we know it's done]

## Progress
[X]% complete. Phases: [list with checkmarks]. This is a moving target — rewrite it as it evolves, don't just append.

## Next Session Starts Here
- **Direction:** [What we decided to do next and why — the live plan, from the latest discussion, in the user's framing]
- **First action:** [The single concrete next step]
- **Open questions:** [Anything still undecided, plus the trade-offs already discussed so they aren't re-opened]

## Remaining (live plan — reorder/rewrite as it changes)
1. [Item]

## Architecture Decisions
| Decision | Choice | Why |
|----------|--------|-----|

## Key Code Locations
| File | Line | Description |
|------|------|-------------|

## Done This Session (brief fallback — recoverable from git)
| Item | Key Files |
|------|-----------|

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
4. Create/update `.claude/current-bug.md` (current state) and append to `.claude/bug-test-log.md` (empirical history — never overwrite it)

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

## Recent Prompts
See `.claude/recent-prompts.md` for the user's last prompts before handoff.

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

## Recent Prompts
See `.claude/recent-prompts.md` for the user's last prompts before handoff.

## Build
\`\`\`bash
[Build command]
\`\`\`
```

**Write `.claude/current-bug.md` (current state — keep lean, the long history lives in the test log):**

```markdown
# Bug: [Title]

## Symptom
[What user sees - 2 lines max]

## Reproduce
\`\`\`bash
[exact command(s) to reproduce — copy-pasteable]
\`\`\`

## Status
[Investigating / Root cause found / Fix in progress]

## Current Hypothesis
[Current theory - 2 lines]

## Confirmed Facts (established — do not re-investigate)
- [Fact] — established by [Tn] in bug-test-log.md

## Ruled Out (dead ends — do not retry)
- [Approach / hypothesis] — ruled out by [Tn], because [result]

## Key Locations
| File:Line | What |
|-----------|------|

## Next Step
[Single concrete action to take next]

## Test Log
Full command-by-command history in `.claude/bug-test-log.md`. Read it before running anything — it records what has already been tried and what it showed.
```

**Write/append `.claude/bug-test-log.md` (append-only — the empirical ledger):**

Purpose: so the next session never re-runs a settled test, and so there is a durable record of what went right and what went wrong. Record every meaningful test, command, build, or measurement run during the investigation.

```markdown
# Bug Test Log — [Title]

Append-only. Each entry is one test/experiment. Never delete or rewrite past entries — correct a wrong conclusion with a *later* entry that references the earlier one.

## Test History

### T1 — [what this test was checking] — [PASS / FAIL / INCONCLUSIVE]
- **Command:** \`exact command line, with flags and args\`
- **Result:** [actual output — the key lines, error text, exit code, or measured value]
- **Conclusion:** [what it established or eliminated]

### T2 — [...]
- **Command:** \`...\`
- **Result:** [...]
- **Conclusion:** [...]
```

**Test-log rules:**
- Record the **exact** command line — copy-pasteable, not paraphrased.
- Record the **actual** result (verbatim key lines / exit code / measured value), never just "it worked" or "failed".
- Tag every entry PASS / FAIL / INCONCLUSIVE so dead ends are obvious at a glance.
- When a test settles a question, also promote it to **Confirmed Facts** or **Ruled Out** in `current-bug.md`.
- Append across sessions — this log is the cumulative history of the whole investigation, not just this session.

---

## Option: Clean

**Purpose:** Reset to clean state between unrelated work sessions. Keeps project configuration, clears all session-specific context.

**Delete these files:**
- `.claude/context.md`
- `.claude/current-task.md`
- `.claude/task-history.md`
- `.claude/current-bug.md`
- `.claude/bug-test-log.md`
- `.claude/session-state.md`
- `.claude/recent-prompts.md`

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
- Deleted: context.md, current-task.md, task-history.md, current-bug.md, bug-test-log.md, session-state.md
- Cleaned: tasks.md (removed N completed tasks)
- Mode: normal

Ready for fresh start.
```

---

## User Prompt Capture (Task and Bug modes only)

When performing a **Task** or **Bug** handoff, save the last 5 user prompts to `.claude/recent-prompts.md`.

**Size gate:** Estimate the total size of the 5 prompts. If they exceed ~5% of the context window (~10K tokens / ~40KB of text), keep only the most recent prompts that fit within that budget. If even a single prompt exceeds the budget, truncate it to fit and note `[truncated]`.

**Write `.claude/recent-prompts.md`:**

```markdown
# Recent User Prompts

Captured at handoff for session continuity. Provides the next session with the user's recent intent and phrasing.

## Prompt 1 (most recent)
> [verbatim user prompt text]

## Prompt 2
> [verbatim user prompt text]

...
```

**Rules:**
- Include only user messages (not assistant responses, tool results, or system messages)
- Preserve the user's exact wording — do not paraphrase or summarize
- Use blockquote formatting for each prompt
- Number from most recent (1) to oldest (5)
- If fewer than 5 user prompts exist in the session, include all of them

**References from context.md:** Add this line to the Task and Bug context.md templates under the "Build" section:

```markdown
## Recent Prompts
See `.claude/recent-prompts.md` for the user's last prompts before handoff.
```

**Clean mode:** Delete `.claude/recent-prompts.md` along with other session files.

---

## Cleanup Rules (apply to all handoff types except Clean)

Before writing files, apply these cleanup rules:

1. **Filter `/tmp/*` paths** - Don't include temporary file paths in "Recent Changes" or "Key Files"
2. **Dedupe tasks** - If tasks.md has duplicate entries, merge them
3. **Compress history** - If task-history.md exceeds 30 entries, compress old ones
4. **Remove stale references** - Don't reference files that no longer exist
5. **Preserve the bug test log** - `.claude/bug-test-log.md` is append-only and exempt from trimming; never drop a test entry to save space. Only if it grows very large, collapse entries already promoted to "Confirmed Facts" / "Ruled Out" into a one-line reference — but keep their exact command and result.
