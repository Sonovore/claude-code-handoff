#!/usr/bin/env python3
"""Extract key information from a Claude Code .jsonl transcript for recovery handoff.

Reads the pre-compaction portion of a transcript and outputs a structured summary
containing: user requests, assistant summaries, test/build results, and diagnostics.
Skips: file reads (still on disk), write confirmations, search results, build
line-by-line compilation output, task create/update acks, and progress events.

Usage:
    python3 extract-transcript.py <transcript.jsonl> [--max-chars 60000]
"""

import json
import re
import sys
import os
from collections import Counter


def find_compaction_boundary(lines):
    """Find the line where autocompact summary was injected."""
    for i, line in enumerate(lines):
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("type") != "user":
            continue
        msg = obj.get("message", {})
        c = msg.get("content", "")
        if isinstance(c, str) and "continued from a previous conversation" in c:
            return i
    return len(lines)  # No compaction found


def is_file_read(text):
    """Detect file read output (line-numbered content with arrow separator)."""
    # Pattern: "     1→" at start, or multiple lines with this pattern
    if "\u2192" in text[:200]:
        # Count lines starting with number→
        lines = text.split("\n")
        numbered = sum(1 for l in lines[:5] if re.match(r"\s+\d+\u2192", l))
        return numbered >= 2
    return False


def is_build_noise(text):
    """Detect line-by-line build output that isn't useful."""
    # Full cmake rebuild output: [  2%] Building CXX object...
    if re.search(r"\[\s*\d+%\]\s+(Building|Linking|Built target)", text):
        lines = text.strip().split("\n")
        build_lines = sum(1 for l in lines if re.search(r"\[\s*\d+%\]", l))
        # If mostly build progress lines, it's noise
        if build_lines > 3 and build_lines / max(len(lines), 1) > 0.5:
            return True
    return False


def is_task_ack(text):
    """Detect task create/update acknowledgments."""
    return bool(re.match(r"(Task #\d+ created|Updated task #\d+)", text))


def is_search_result(text):
    """Detect glob/grep search results (file path lists)."""
    lines = text.strip().split("\n")
    if len(lines) < 2:
        return False
    path_lines = sum(1 for l in lines if l.strip().startswith("/"))
    return path_lines / max(len(lines), 1) > 0.7


def classify_tool_result(text):
    """Classify a tool result for filtering. Returns 'KEEP' or 'SKIP'."""
    if not text or len(text) < 30:
        return "SKIP"

    # Skip file write confirmations
    if "File created" in text or "has been updated" in text or "has been overwritten" in text:
        return "SKIP"

    # Skip file reads (code is on disk)
    if is_file_read(text):
        return "SKIP"

    # Skip noisy build output (keep only errors/test results)
    if is_build_noise(text):
        return "SKIP"

    # Skip task create/update acks
    if is_task_ack(text):
        return "SKIP"

    # Skip search results (file path lists)
    if is_search_result(text):
        return "SKIP"

    # Skip "No files found" etc
    if text.strip().startswith("No files found") or text.strip().startswith("No matches"):
        return "SKIP"

    # Skip tool errors that are just "sibling tool call errored"
    if "tool_use_error" in text and "Sibling tool call" in text:
        return "SKIP"

    # Skip "File has not been read yet" errors
    if "File has not been read yet" in text:
        return "SKIP"

    # Skip task stop/kill messages
    if "Successfully stopped task" in text:
        return "SKIP"

    return "KEEP"


def extract_entries(lines, boundary):
    """Extract meaningful entries from pre-compaction transcript."""
    entries = []

    for i, line in enumerate(lines[:boundary]):
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        t = obj.get("type")

        # User requests from queue-operation enqueue
        if t == "queue-operation":
            op = obj.get("operation", "")
            content = obj.get("content", "")
            if op == "enqueue" and content and "<task-notification>" not in content:
                entries.append(("USER", i, content.strip()))
            continue

        # User text messages (not tool results)
        if t == "user":
            msg = obj.get("message", {})
            c = msg.get("content", "")

            if isinstance(c, str):
                c_stripped = c.strip()
                if (c_stripped
                        and not c_stripped.startswith("[Request interrupted")
                        and "<command-message>" not in c_stripped
                        and "<system-reminder>" not in c_stripped
                        and len(c_stripped) > 20):
                    # Skip the initial plan (too long, user has it)
                    if i < 10 and len(c_stripped) > 2000:
                        entries.append(("USER", i,
                            "[Initial plan/instructions provided - see plan file]"))
                    else:
                        entries.append(("USER", i, c_stripped[:1000]))

            elif isinstance(c, list):
                for item in c:
                    if not isinstance(item, dict):
                        continue
                    if item.get("type") == "text":
                        txt = item.get("text", "").strip()
                        if (txt
                                and not txt.startswith("[Request interrupted")
                                and "<command-message>" not in txt
                                and "<system-reminder>" not in txt
                                and len(txt) > 20):
                            entries.append(("USER", i, txt[:1000]))

                    elif item.get("type") == "tool_result":
                        cr = item.get("content", "")
                        text = ""
                        if isinstance(cr, str):
                            text = cr
                        elif isinstance(cr, list):
                            for sub in cr:
                                if isinstance(sub, dict) and sub.get("type") == "text":
                                    text += sub.get("text", "")

                        if classify_tool_result(text) == "KEEP" and len(text) > 50:
                            entries.append(("RESULT", i, text[:3000]))
            continue

        # Assistant text responses (skip tool_use calls)
        if t == "assistant":
            msg = obj.get("message", {})
            content_items = msg.get("content", [])
            if isinstance(content_items, list):
                for item in content_items:
                    if isinstance(item, dict) and item.get("type") == "text":
                        txt = item.get("text", "").strip()
                        if len(txt) > 40:
                            entries.append(("ASSISTANT", i, txt[:3000]))
            continue

    return entries


def format_output(entries, max_chars):
    """Format extracted entries into readable output, truncating at max_chars."""
    output_parts = []
    output_parts.append("# Recovered Session Transcript\n")
    output_parts.append(f"Extracted {len(entries)} entries from pre-compaction transcript.\n")
    output_parts.append("\n## Chronological Session Flow\n")

    total_chars = 0
    for entry_type, line_num, content in entries:
        if total_chars > max_chars:
            output_parts.append(
                f"\n[Truncated at {max_chars} chars — {len(entries)} total entries]\n")
            break

        prefix = {"USER": "USER", "ASSISTANT": "CLAUDE", "RESULT": "OUTPUT"}[entry_type]
        marker = {"USER": ">>>", "ASSISTANT": "<<<", "RESULT": "---"}[entry_type]

        output_parts.append(f"\n{marker} [{prefix}] (line {line_num})")
        output_parts.append(content)
        total_chars += len(content)

    return "\n".join(output_parts)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    transcript_path = sys.argv[1]
    max_chars = 60000
    if "--max-chars" in sys.argv:
        idx = sys.argv.index("--max-chars")
        max_chars = int(sys.argv[idx + 1])

    if not os.path.exists(transcript_path):
        print(f"Error: {transcript_path} not found", file=sys.stderr)
        sys.exit(1)

    with open(transcript_path) as f:
        lines = f.readlines()

    boundary = find_compaction_boundary(lines)
    print(f"Transcript: {len(lines)} lines, compaction at line {boundary}",
          file=sys.stderr)

    entries = extract_entries(lines, boundary)

    # Stats
    counts = Counter(t for t, _, _ in entries)
    chars = Counter()
    for t, _, c in entries:
        chars[t] += len(c)

    print(f"Extracted: {len(entries)} entries", file=sys.stderr)
    for t in ("USER", "ASSISTANT", "RESULT"):
        if counts[t]:
            print(f"  {t}: {counts[t]} items, {chars[t]} chars", file=sys.stderr)

    output = format_output(entries, max_chars)
    print(output)


if __name__ == "__main__":
    main()
