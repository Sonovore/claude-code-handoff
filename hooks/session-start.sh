#!/bin/bash
# SessionStart hook — loads handoff context at the start of each session.
#
# Outputs the contents of .claude/context.md (and related files) so Claude
# sees them in the session-start system reminder.  This is how the handoff
# documents written by /handoff get loaded automatically.
#
# Install: symlink into .claude/hooks/ and add to .claude/settings.json
#   (see settings-snippet.json or the README for the full config)

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

echo "=== Session Context ==="
echo ""

# Primary context file (written by all handoff modes)
if [ -f ".claude/context.md" ]; then
    echo "--- context.md ---"
    cat ".claude/context.md"
    echo ""
fi

# Task details (written by Task mode)
if [ -f ".claude/current-task.md" ]; then
    echo "--- current-task.md ---"
    cat ".claude/current-task.md"
    echo ""
fi

# Bug details (written by Bug mode)
if [ -f ".claude/current-bug.md" ]; then
    echo "--- current-bug.md ---"
    cat ".claude/current-bug.md"
    echo ""
fi

# Task history (written by Task mode, append-only)
if [ -f ".claude/task-history.md" ]; then
    echo "--- task-history.md (last 10 entries) ---"
    tail -20 ".claude/task-history.md"
    echo ""
fi

if [ ! -f ".claude/context.md" ] && [ ! -f ".claude/current-task.md" ] && [ ! -f ".claude/current-bug.md" ]; then
    echo "No handoff context found. Run /handoff before ending a session to save context."
fi

echo "=== Ready ==="
