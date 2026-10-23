#!/usr/bin/env python3
"""Minimal macOS clipboard history: local JSONL history + fzf selection."""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
HISTORY = HOME / ".yank_history"
MAX_ITEMS = int(os.environ.get("YANK_MAX_ITEMS", "50"))
POLL_SECONDS = float(os.environ.get("YANK_POLL_SECONDS", "0.6"))


def read_items():
    if not HISTORY.exists():
        return []
    items = []
    try:
        with HISTORY.open("r", encoding="utf-8") as f:
            for line in f:
                try:
                    item = json.loads(line)
                    if isinstance(item, dict) and isinstance(item.get("text"), str):
                        items.append(item)
                except (json.JSONDecodeError, TypeError):
                    continue
    except OSError:
        pass
    # Newest first; IDs are timestamps but ordering in the file is canonical.
    return list(reversed(items))


def write_items(items_newest_first):
    HISTORY.parent.mkdir(parents=True, exist_ok=True)
    tmp = HISTORY.with_suffix(".tmp")
    with tmp.open("w", encoding="utf-8") as f:
        for item in reversed(items_newest_first[:MAX_ITEMS]):
            f.write(json.dumps(item, ensure_ascii=False) + "\n")
    os.replace(tmp, HISTORY)
    try:
        HISTORY.chmod(0o600)
    except OSError:
        pass


def clipboard_text():
    try:
        p = subprocess.run(["/usr/bin/pbpaste"], capture_output=True, check=True)
        return p.stdout.decode("utf-8", errors="replace")
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def record_loop():
    last = None
    # Avoid recording whatever happened to be on the clipboard when the watcher starts.
    last = clipboard_text()
    while True:
        time.sleep(POLL_SECONDS)
        current = clipboard_text()
        if current is None or current == "" or current == last:
            continue
        last = current
        items = read_items()
        if items and items[0]["text"] == current:
            continue
        items.insert(0, {"time": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "text": current})
        write_items(items)


def copy_text(text):
    subprocess.run(["/usr/bin/pbcopy"], input=text.encode("utf-8"), check=True)


def preview(text, limit=4):
    lines = text.replace("\x00", "�").splitlines() or [""]
    shown = " ⏎ ".join(line for line in lines[:limit])
    if len(lines) > limit:
        shown += " …"
    return shown.replace("\t", " ⇥ ")


def list_items(n=20):
    items = read_items()[:max(0, n)]
    if not items:
        print("No clipboard history yet.")
        return
    for i, item in enumerate(items, 1):
        print(f"{i:>3}  {preview(item['text'], 2)}")


def choose_item():
    items = read_items()
    if not items:
        print("No clipboard history yet.", file=sys.stderr)
        return 1
    if not subprocess.run(["/usr/bin/env", "bash", "-lc", "command -v fzf >/dev/null 2>&1"]).returncode == 0:
        print("fzf is required. Install it with: brew install fzf", file=sys.stderr)
        return 1
    # Store each selection's exact text in a temporary JSON file; fzf only displays previews.
    import tempfile
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as tf:
        path = tf.name
        for idx, item in enumerate(items, 1):
            tf.write(json.dumps({"index": idx, "text": item["text"]}, ensure_ascii=False) + "\n")
    try:
        fmt = "{1:>3}  {2}"
        # Use a stable numeric index as the selectable line prefix; preview remains readable.
        lines = []
        for idx, item in enumerate(items, 1):
            lines.append(f"{idx:03d}\t{preview(item['text'], 3)}")
        proc = subprocess.run(
            ["fzf", "--with-nth=2..", "--delimiter=\t", "--layout=reverse", "--height=80%",
             "--prompt=yank\u003e ", "--no-multi"],
            input="\n".join(lines) + "\n", text=True, capture_output=True,
        )
        if proc.returncode != 0 or not proc.stdout.strip():
            return 0
        try:
            index = int(proc.stdout.split("\t", 1)[0]) - 1
            copy_text(items[index]["text"])
            print(f"Copied history item {index + 1} to clipboard. Press ⌘V to paste.")
            return 0
        except (ValueError, IndexError):
            print("Could not read selection.", file=sys.stderr)
            return 1
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass


def main():
    args = sys.argv[1:]
    if args and args[0] == "_watch":
        record_loop()
    if not args:
        return choose_item()
    if args[0] in ("list", "ls"):
        try:
            n = int(args[1]) if len(args) > 1 else 20
        except ValueError:
            print("Usage: yank list [N]", file=sys.stderr)
            return 2
        list_items(n)
        return 0
    if args[0] in ("help", "-h", "--help"):
        print("Usage: yank [N] | yank list [N]\n\n  yank       Select a history item with fzf and copy it back\n  yank N     Restore the Nth newest item (1 = most recent)\n  yank list [N]  Print the N most recent items (default 20)\n\nAfter restoring, press ⌘V to paste. History: ~/.yank_history")
        return 0
    try:
        n = int(args[0])
    except ValueError:
        print("Usage: yank [N] | yank list [N]", file=sys.stderr)
        return 2
    items = read_items()
    if n < 1 or n > len(items):
        print(f"Item {n} not found; history contains {len(items)} item(s).", file=sys.stderr)
        return 1
    copy_text(items[n - 1]["text"])
    print(f"Copied history item {n} to clipboard. Press ⌘V to paste.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
