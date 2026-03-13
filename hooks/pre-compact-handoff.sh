#!/bin/bash
# Pre-Compact Handoff Failsafe
# Fires before context compaction — tells Claude to dump full state to session-state.md
# Detects active task/bug state and tailors the handoff format accordingly.
#
# This is the last-resort mechanism. live-handoff.sh handles the ongoing updates;
# this hook ensures nothing is lost when autocompaction hits.
#
# Install: place in .claude/hooks/ and add to PreCompact in .claude/settings.json

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

mkdir -p "$REPO_ROOT/.claude"

# Detect current work mode
HAS_TASK=false
HAS_BUG=false
[ -f "$REPO_ROOT/.claude/current-task.md" ] && HAS_TASK=true
[ -f "$REPO_ROOT/.claude/current-bug.md" ] && HAS_BUG=true

# Determine handoff type directive based on detected state
if [ "$HAS_BUG" = true ] && [ "$HAS_TASK" = true ]; then
    MODE_DIRECTIVE="
DETECTED STATE: Active task AND active bug (task.bug mode).
Before writing session-state.md, use AskUserQuestion to confirm with the user:
  Question: \"Context compaction is imminent. You have an active task and bug. How should I save state?\"
  Options:
  1. Task+Bug — preserve both task and bug investigation details
  2. Task only — bug is resolved, keep task context
  3. General — both are resolved, save general context only

Then write session-state.md accordingly:
- Task+Bug: include task progress, acceptance criteria, bug symptom, hypothesis, investigation table, reproduce steps
- Task only: include task progress, acceptance criteria, completed/remaining items
- General: standard context dump"
elif [ "$HAS_BUG" = true ]; then
    MODE_DIRECTIVE="
DETECTED STATE: Active bug investigation.
Before writing session-state.md, use AskUserQuestion to confirm with the user:
  Question: \"Context compaction is imminent. You have an active bug investigation. Is the bug still open?\"
  Options:
  1. Bug still open — preserve investigation state (symptom, hypothesis, what was tried, reproduce steps)
  2. Bug is fixed — save general context only

Then write session-state.md accordingly:
- Bug open: include symptom, current hypothesis, investigation table (what tried / result), reproduce steps, key file:line locations
- Bug fixed: note the fix, standard context dump"
elif [ "$HAS_TASK" = true ]; then
    MODE_DIRECTIVE="
DETECTED STATE: Active multi-session task.
Before writing session-state.md, use AskUserQuestion to confirm with the user:
  Question: \"Context compaction is imminent. You have an active task. Is it still in progress?\"
  Options:
  1. Task in progress — preserve task tracking state
  2. Task complete — save general context only

Then write session-state.md accordingly:
- In progress: include goal, acceptance criteria, progress %, architecture decisions, completed items, remaining items, key code locations
- Complete: note completion, standard context dump. Delete .claude/current-task.md"
else
    MODE_DIRECTIVE=""
fi

cat << DIRECTIVE
<pre-compact-handoff>
CRITICAL: Context compaction is about to happen. You MUST update .claude/session-state.md NOW.
${MODE_DIRECTIVE}

REQUIRED content for session-state.md (adapt format based on mode above):
1. Read the current session-state.md
2. REWRITE it completely with everything needed to continue this work after compaction:
   - What are we working on and why
   - All decisions made and their rationale
   - Key discoveries, gotchas, blockers
   - Important file:line references
   - What was just completed
   - What needs to happen next
3. This file will be your ONLY memory after compaction. Line targets: general 60-80, task 80-100, bug 100-120 (if needed).
4. After compaction, you MUST read .claude/session-state.md before doing anything else.
</pre-compact-handoff>
DIRECTIVE

exit 0
