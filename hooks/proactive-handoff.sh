#!/bin/bash
# Proactive Handoff — Track session state for context handoff
# Purpose: Maintain live session state that survives context compaction
# Usage: proactive-handoff.sh <event> [args...]
#
# Events:
#   init              - Initialize new session state
#   file <path>       - Track file modification
#   save              - Save state before compaction
#   load              - Load state at session start
#   cleanup           - Remove completed agents and old file entries
#
# Install: place in .claude/hooks/ — called by other hooks, not directly by settings.json

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE_FILE="$REPO_ROOT/.claude/session-state.md"
BACKUP_FILE="$REPO_ROOT/.claude/session-state.md.bak"

# Ensure .claude directory exists
mkdir -p "$REPO_ROOT/.claude"

# Get current timestamp
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Initialize empty state file
init_state() {
    local ts
    ts=$(timestamp)
    cat > "$STATE_FILE" << EOF
# Session State

Auto-updated during session. Read at session start for continuity.

## Active Work

### Current Focus
- None

### Modified Files
<!-- Files touched this session -->

### Next Steps
<!-- What to do next if interrupted -->

## Session Info

- **Started:** $ts
- **Last Updated:** $ts

## Notes

<!-- Manual notes can be added here -->
EOF
}

# Update the "Last Updated" timestamp
update_timestamp() {
    if [ -f "$STATE_FILE" ]; then
        sed -i '' "s/\*\*Last Updated:\*\* .*/\*\*Last Updated:\*\* $(timestamp)/" "$STATE_FILE" 2>/dev/null || \
        sed -i "s/\*\*Last Updated:\*\* .*/\*\*Last Updated:\*\* $(timestamp)/" "$STATE_FILE"
    fi
}

# Track a file modification
track_file() {
    local file_path="$1"
    if [ -f "$STATE_FILE" ]; then
        # Check if file already tracked
        if ! grep -q "^- \`$file_path\`" "$STATE_FILE" 2>/dev/null; then
            # Add file to Modified Files section (macOS and Linux compatible)
            if sed -i '' "/<!-- Files touched this session -->/a\\
- \`$file_path\` ($(timestamp))
" "$STATE_FILE" 2>/dev/null; then
                :
            else
                sed -i "/<!-- Files touched this session -->/a\\- \`$file_path\` ($(timestamp))" "$STATE_FILE"
            fi
        fi
        update_timestamp
    fi
}

# Save state before compaction
save_state() {
    if [ -f "$STATE_FILE" ]; then
        cp "$STATE_FILE" "$BACKUP_FILE"
        update_timestamp
    fi
}

# Load state at session start
load_state() {
    if [ -f "$STATE_FILE" ]; then
        echo "--- session-state.md (previous session) ---"
        cat "$STATE_FILE"
        echo ""
    elif [ -f "$BACKUP_FILE" ]; then
        echo "--- session-state.md (restored from backup) ---"
        cp "$BACKUP_FILE" "$STATE_FILE"
        cat "$STATE_FILE"
        echo ""
    fi
}

# Cleanup: trim old file entries
cleanup_state() {
    if [ ! -f "$STATE_FILE" ]; then
        return
    fi

    local keep_files="${1:-20}"
    local file_count
    file_count=$(grep -c '^- `.*` (' "$STATE_FILE" 2>/dev/null || echo "0")

    if [ "$file_count" -gt "$keep_files" ]; then
        local remove_count=$((file_count - keep_files))
        # Remove oldest entries (they appear first after the comment)
        local temp_file
        temp_file=$(mktemp)
        grep '^- `.*` (' "$STATE_FILE" | tail -n "$keep_files" > "$temp_file"

        if sed -i '' '/^- `.*` (/d' "$STATE_FILE" 2>/dev/null; then
            while IFS= read -r line; do
                sed -i '' "/<!-- Files touched this session -->/a\\
$line
" "$STATE_FILE"
            done < "$temp_file"
        else
            sed -i '/^- `.*` (/d' "$STATE_FILE"
            while IFS= read -r line; do
                sed -i "/<!-- Files touched this session -->/a\\$line" "$STATE_FILE"
            done < "$temp_file"
        fi
        rm -f "$temp_file"
    fi

    update_timestamp
}

# Main command dispatch
case "${1:-help}" in
    init)
        init_state
        echo "Session state initialized: $STATE_FILE"
        ;;
    file)
        if [ -n "${2:-}" ]; then
            track_file "$2"
        else
            echo "Usage: $0 file <path>" >&2
            exit 1
        fi
        ;;
    save)
        save_state
        ;;
    load)
        load_state
        ;;
    cleanup)
        cleanup_state "${2:-20}"
        ;;
    help|*)
        echo "Usage: $0 <event> [args...]"
        echo ""
        echo "Events:"
        echo "  init              - Initialize new session state"
        echo "  file <path>       - Track file modification"
        echo "  save              - Save state before compaction"
        echo "  load              - Load state at session start"
        echo "  cleanup [N]       - Keep last N file entries (default 20)"
        ;;
esac

exit 0
