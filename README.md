# Claude Code Handoff

Interactive session handoff command for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Saves and restores context across sessions, surviving autocompaction and `/clear`.

## What It Does

When you're done working or need to switch context, run `/handoff` to save a structured summary of your session. Next time you start Claude Code, the context is loaded automatically so you can pick up where you left off.

### Handoff Modes

| Mode | Use When | Output |
|------|----------|--------|
| **Context** | General work, switching focus | `.claude/context.md` (50 lines) |
| **Task** | Multi-session project work | `.claude/context.md` + `.claude/current-task.md` + `.claude/task-history.md` |
| **Bug** | Debugging investigation | `.claude/current-bug.md` (can layer on top of task) |
| **Recovery** | Autocompact degraded your context | Reconstructs handoff from full transcript |
| **Clean** | Starting fresh | Deletes all session files |

## Install

### As a git submodule (recommended)

```bash
# Add to your project
git submodule add https://github.com/Sonovore/claude-code-handoff.git claude-code-handoff

# Symlink the command so Claude Code sees it
mkdir -p .claude/commands
cd .claude/commands
ln -sf ../../claude-code-handoff/handoff.md .
cd ../..
```

### Manual install

Copy `handoff.md` to `.claude/commands/handoff.md` in your project.

Copy `extract-transcript.py` somewhere accessible (only needed for Recovery mode).

## Usage

In Claude Code, type:

```
/handoff
```

You'll be prompted to choose a mode. The command writes structured markdown files to `.claude/` that Claude Code reads at the start of your next session.

### Task Mode Example

After running `/handoff` → Task, you get:

- `.claude/context.md` — Quick summary with current step, key files, build commands
- `.claude/current-task.md` — Full task details: goal, progress, architecture decisions, remaining work, test procedure
- `.claude/task-history.md` — Append-only log of what was accomplished each session

### Recovery Mode

If autocompaction has degraded your context mid-session (Claude starts forgetting things), Recovery mode reads the full `.jsonl` transcript and regenerates handoff files with specific details: exact test numbers, parameter values, debugging timelines.

Requires `extract-transcript.py` to be accessible at the path in `handoff.md`. The script filters out noise (file reads, build output, task acks) and extracts meaningful content (user requests, test results, diagnostics).

## Files

| File | Description |
|------|-------------|
| `handoff.md` | The `/handoff` slash command (Claude Code reads this as instructions) |
| `extract-transcript.py` | Transcript parser for Recovery mode |

## Gitignore

Add to your `.gitignore`:

```
.claude/context.md
.claude/current-task.md
.claude/task-history.md
.claude/current-bug.md
.claude/mode
```

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Python 3 (for Recovery mode only)

## License

MIT — see [LICENSE](LICENSE)
