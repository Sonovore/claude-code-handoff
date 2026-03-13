# Claude Code Handoff

Session context preservation for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Keeps Claude aware of what it's working on across autocompaction and session boundaries.

## Two Systems

### 1. Automated Live Handoff (recommended)

Claude continuously maintains a `.claude/session-state.md` file as you work. No manual intervention needed.

| Hook | Event | What It Does |
|------|-------|--------------|
| `live-handoff.sh` | **UserPromptSubmit** | Injects a directive on every message telling Claude to update `session-state.md` |
| `post-edit-hook.sh` | **PostToolUse** (Edit/Write) | Tracks which files were modified |
| `proactive-handoff.sh` | (utility) | State file management — init, file tracking, save/load |
| `pre-compact-handoff.sh` | **PreCompact** | Emergency state dump before autocompaction — asks the user how to save if task/bug state is detected |

**How it works:**
- Every time you send a message, Claude sees a `<live-handoff>` directive telling it to check if anything important happened and update `session-state.md`
- When `session-state.md` grows too large (60-120 lines depending on mode), the directive switches to "rewrite" mode, telling Claude to keep only critical information
- Before autocompaction, a `<pre-compact-handoff>` directive forces a complete state dump
- On session start, the previous `session-state.md` is loaded into context

### 2. Manual `/handoff` Command

Run `/handoff` before ending a session to write structured context files. Good for deliberate handoffs where you want to control exactly what's saved.

| Mode | Use When | Output |
|------|----------|--------|
| **Context** | General work, switching focus | `.claude/context.md` (50 lines) |
| **Task** | Multi-session project work | `.claude/context.md` + `.claude/current-task.md` + `.claude/task-history.md` |
| **Bug** | Debugging investigation | `.claude/current-bug.md` (can layer on top of task) |
| **Recovery** | Autocompact degraded your context | Reconstructs handoff from full transcript |
| **Clean** | Starting fresh | Deletes all session files |

Both systems work together — the automated system maintains live state, while `/handoff` creates deliberate checkpoints.

## Install

### Quick Setup (have Claude do it)

Add the submodule to your project, then tell Claude:

> Install claude-code-handoff following the instructions in claude-code-handoff/README.md

Claude will create the symlinks and settings for you.

### Step-by-Step

**1. Add the submodule**

```bash
git submodule add https://github.com/Sonovore/claude-code-handoff.git claude-code-handoff
```

**2. Create directories**

```bash
mkdir -p .claude/commands .claude/hooks
```

**3. Symlink the command**

```bash
cd .claude/commands
ln -sf ../../claude-code-handoff/handoff.md .
cd ../..
```

**4. Symlink the hooks**

```bash
cd .claude/hooks
ln -sf ../../claude-code-handoff/hooks/session-start.sh .
ln -sf ../../claude-code-handoff/hooks/pre-compact.sh .
ln -sf ../../claude-code-handoff/hooks/live-handoff.sh .
ln -sf ../../claude-code-handoff/hooks/post-edit-hook.sh .
ln -sf ../../claude-code-handoff/hooks/proactive-handoff.sh .
ln -sf ../../claude-code-handoff/hooks/pre-compact-handoff.sh .
cd ../..
```

**5. Make hooks executable**

```bash
chmod +x claude-code-handoff/hooks/*.sh
```

**6. Configure settings**

If `.claude/settings.json` doesn't exist yet, copy the snippet:

```bash
cp claude-code-handoff/settings-snippet.json .claude/settings.json
```

If `.claude/settings.json` already exists, merge the hooks from `settings-snippet.json` into your existing config. The hooks are:

- **SessionStart** — loads handoff context and previous session state
- **UserPromptSubmit** — injects live-handoff directive on every message
- **PostToolUse** (Edit/Write/NotebookEdit) — tracks file modifications
- **PreCompact** — re-injects context, saves state backup, and forces state dump before autocompaction

**7. Add to .gitignore**

```bash
# Handoff context files (session-specific, not for version control)
.claude/context.md
.claude/current-task.md
.claude/task-history.md
.claude/current-bug.md
.claude/session-state.md
.claude/session-state.md.bak
.claude/mode
```

**8. Restart Claude Code**

The hooks will be active on next session start. The automated system begins tracking immediately — no `/handoff` needed.

### Manual Install (no submodule)

1. Copy all files from `hooks/` → `.claude/hooks/`
2. Copy `handoff.md` → `.claude/commands/handoff.md`
3. Copy `extract-transcript.py` somewhere accessible (update the path in `handoff.md` line 250)
4. Follow steps 5-8 above

### Minimal Install (automated only, no `/handoff` command)

If you only want the automated live handoff system without the manual `/handoff` command:

1. Copy `hooks/live-handoff.sh`, `hooks/post-edit-hook.sh`, `hooks/proactive-handoff.sh`, `hooks/pre-compact-handoff.sh` → `.claude/hooks/`
2. Add the `UserPromptSubmit`, `PostToolUse`, and `PreCompact` hooks from `settings-snippet.json` to `.claude/settings.json`
3. Optionally add the `SessionStart` hook to load previous session state on startup
4. Follow steps 5, 7, 8 above

## Files

```
claude-code-handoff/
├── README.md                          # This file
├── LICENSE                            # MIT
├── handoff.md                         # /handoff slash command
├── extract-transcript.py              # Transcript parser (Recovery mode)
├── settings-snippet.json              # Hook config to merge into .claude/settings.json
└── hooks/
    ├── session-start.sh               # SessionStart: loads context + session state
    ├── live-handoff.sh                # UserPromptSubmit: continuous state maintenance
    ├── post-edit-hook.sh              # PostToolUse: tracks file modifications
    ├── proactive-handoff.sh           # Utility: state file management
    ├── pre-compact.sh                 # PreCompact: re-injects handoff context
    └── pre-compact-handoff.sh         # PreCompact: emergency state dump
```

## Usage

### Starting a session

If hooks are installed, context loads automatically. You'll see:

```
=== Session Context ===

--- session-state.md (previous session) ---
# Session State
...

--- context.md ---
# Session Context
...

=== Ready ===
```

### During a session

With the automated system, Claude maintains `.claude/session-state.md` continuously. You don't need to do anything — context is preserved through autocompaction automatically.

### Ending a session

**Automated:** Just stop working. The session state is already saved.

**Manual:** Run `/handoff` and choose a mode for a more structured handoff.

### Recovery after autocompaction

If Claude starts losing context mid-session (forgetting what it was working on, re-reading files it already read), run:

```
/handoff
```

Select **Recovery**. This reads the full `.jsonl` transcript, extracts the useful content (user requests, test results, decisions), and regenerates the handoff files with full detail. Then `/clear` to free context — the recovered handoff will load on the next prompt.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `bash` (for hooks)
- `jq` (for file tracking via post-edit-hook)
- Python 3 (for Recovery mode only)

## License

MIT — see [LICENSE](LICENSE)
