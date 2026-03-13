#!/bin/bash
# PostToolUse hook for Edit/Write/NotebookEdit
# Extracts the file path from hook input and tracks it in session-state.md
#
# Hook receives JSON via stdin with structure:
# { "tool_input": { "file_path": "/path/to/file" }, ... }
#
# Install: place in .claude/hooks/ and add PostToolUse matcher to .claude/settings.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Read JSON input from stdin
INPUT=$(cat)

# Extract file path using jq
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null || true)

# Only proceed if we got a file path
if [ -n "$FILE_PATH" ]; then
    "$SCRIPT_DIR/proactive-handoff.sh" file "$FILE_PATH" 2>/dev/null || true
fi

exit 0
