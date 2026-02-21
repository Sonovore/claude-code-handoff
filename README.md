# Claude Code Handoff

Interactive session handoff command for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Saves and restores context across sessions, surviving autocompaction and `/clear`.

## What It Does

When you're done working or need to switch context, run `/handoff` to save a structured summary of your session. Next time you start Claude Code, the hooks load that context automatically so you can pick up where you left off.

### Handoff Modes

| Mode | Use When | Output |
|------|----------|--------|
| **Context** | General work, switching focus | `.claude/context.md` (50 lines) |
| **Task** | Multi-session project work | `.claude/context.md` + `.claude/current-task.md` + `.claude/task-history.md` |
| **Bug** | Debugging investigation | `.claude/current-bug.md` (can layer on top of task) |
| **Recovery** | Autocompact degraded your context | Reconstructs handoff from full transcript |
| **Clean** | Starting fresh | Deletes all session files |

### How It Works

1. You run `/handoff` before ending a session
2. Claude writes structured context files to `.claude/`
3. Next session, the **SessionStart hook** outputs those files into Claude's context
4. During long sessions, the **PreCompact hook** re-injects context before autocompaction so nothing is lost

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

If `.claude/settings.json` already exists, merge the hooks from `settings-snippet.json` into your existing config. The relevant hooks are:

- **SessionStart** — runs `session-start.sh` to load handoff context
- **PreCompact** — runs `pre-compact.sh` to re-inject context before autocompaction

**7. Add to .gitignore**

```bash
# Handoff context files (session-specific, not for version control)
.claude/context.md
.claude/current-task.md
.claude/task-history.md
.claude/current-bug.md
.claude/mode
```

**8. Restart Claude Code**

The `/handoff` command and hooks will be active on next session start.

### Manual Install (no submodule)

1. Copy `handoff.md` → `.claude/commands/handoff.md`
2. Copy `hooks/session-start.sh` → `.claude/hooks/session-start.sh`
3. Copy `hooks/pre-compact.sh` → `.claude/hooks/pre-compact.sh`
4. Copy `extract-transcript.py` somewhere accessible (update the path in `handoff.md` line 250)
5. Follow steps 5-8 above

## Files

```
claude-code-handoff/
├── README.md                 # This file
├── LICENSE                   # MIT
├── handoff.md                # /handoff slash command
├── extract-transcript.py     # Transcript parser (Recovery mode)
├── settings-snippet.json     # Hook config to merge into .claude/settings.json
└── hooks/
    ├── session-start.sh      # SessionStart: loads context at session start
    └── pre-compact.sh        # PreCompact: re-injects context before autocompaction
```

## Usage

### Starting a session

If hooks are installed, context loads automatically. You'll see:

```
=== Session Context ===

--- context.md ---
# Session Context
...

=== Ready ===
```

### Ending a session

```
/handoff
```

Choose a mode when prompted. Files are written to `.claude/` and will be loaded next session.

### Recovery after autocompaction

If Claude starts losing context mid-session (forgetting what it was working on, re-reading files it already read), run:

```
/handoff
```

Select **Recovery**. This reads the full `.jsonl` transcript, extracts the useful content (user requests, test results, decisions), and regenerates the handoff files with full detail. Then `/clear` to free context — the recovered handoff will load on the next prompt.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `bash` (for hooks)
- Python 3 (for Recovery mode only)

## License

MIT — see [LICENSE](LICENSE)
