#!/bin/bash
# PreCompact hook — re-injects handoff context before autocompaction.
#
# When Claude Code hits its context limit, it compacts the conversation.
# This hook outputs the handoff files so they get included in the
# compaction summary, preventing context loss.
#
# Install: symlink into .claude/hooks/ and add to .claude/settings.json
#   (see settings-snippet.json or the README for the full config)

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

echo ""
echo "=== Handoff Context (re-injecting for compaction) ==="

if [ -f ".claude/context.md" ]; then
    echo ""
    echo "--- context.md ---"
    cat ".claude/context.md"
fi

if [ -f ".claude/current-task.md" ]; then
    echo ""
    echo "--- current-task.md ---"
    cat ".claude/current-task.md"
fi

if [ -f ".claude/current-bug.md" ]; then
    echo ""
    echo "--- current-bug.md ---"
    cat ".claude/current-bug.md"
fi
