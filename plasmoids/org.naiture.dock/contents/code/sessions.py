#!/usr/bin/env python3
"""Recent Claude Code sessions, for the start sheet's third column.

Everything here comes off disk; there is no API to ask.

  ~/.claude/projects/<escaped cwd>/<session id>.jsonl
      one transcript per session. Which folder it is filed under is what
      decides where it can be resumed: `claude --resume <id>` looks the session
      up under the *current* directory's escaped name, and resuming from
      anywhere else simply does not find it.

      So the folder is the authority on the directory, and the `cwd` written
      inside is only a hint. Usually they agree, and the cwd is the better read
      because the folder name is the path with its slashes swapped for dashes,
      which is lossy — a real dash and a slash become the same character. When
      they disagree, because the transcript was moved into another project, the
      folder wins: the cwd inside still names wherever the session began, which
      may no longer be anywhere.

  the transcript's `custom-title` / `ai-title` records
      what the session is called: the name its owner gave it, else the one
      Claude wrote. Both are rewritten as the session goes on, so the last of
      each is the current one, and only the end of the file is read — these
      transcripts run to tens of megabytes.

  ~/.claude/history.jsonl
      every prompt ever typed, with its session. Only used for a session that
      has no title at all, to fall back on its opening question.

Sessions whose directory has since been moved or deleted are left out: they
cannot be resumed, and a row that always fails is worse than no row.

Duplicates are left out too. One session can be filed under two folders — the
escaping is lossy, and a project reached by two paths writes two transcripts of
the same id — and beyond that, two rows carrying the same title in the same
project are the same row as far as anyone reading the sheet is concerned. The
newest transcript wins in both cases, since that is the one still being written.
"""
import argparse
import glob
import json
import os
import sys

HOME = os.path.expanduser("~")
CLAUDE = os.path.join(HOME, ".claude")

# How much of a transcript's end to read looking for its title.
TAIL = 256 * 1024

# How far into a transcript the session's own cwd should appear.
HEAD_LINES = 60


def records(lines):
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            yield json.loads(line)
        except ValueError:
            # A tail read starts mid-line; a truncated write leaves one behind.
            continue


def recorded_cwd(path):
    with open(path, errors="replace") as f:
        head = [next(f, "") for _ in range(HEAD_LINES)]
    for record in records(head):
        cwd = record.get("cwd")
        if cwd:
            return cwd
    return None


def folder_path(path):
    """The directory a transcript's folder name stands for, if that reading of
    it is a directory that exists. The escaping is lossy, so this is only ever
    accepted when it lands somewhere real."""
    name = os.path.basename(os.path.dirname(path))
    guess = name.replace("-", "/")
    return guess if os.path.isdir(guess) else None


def project_of(path):
    """Where this session can be resumed from."""
    cwd = recorded_cwd(path)
    folder = folder_path(path)

    # The folder is what `--resume` searches, so a cwd that disagrees with a
    # folder that exists is a session someone has moved.
    if folder and (not cwd or os.path.normpath(cwd) != os.path.normpath(folder)):
        return folder
    return cwd


def title_of(path):
    size = os.path.getsize(path)
    with open(path, "rb") as f:
        f.seek(max(0, size - TAIL))
        tail = f.read().decode("utf-8", "replace")

    custom = ai = None
    for record in records(tail.split("\n")):
        if record.get("type") == "custom-title" and record.get("customTitle"):
            custom = record["customTitle"]
        elif record.get("type") == "ai-title" and record.get("aiTitle"):
            ai = record["aiTitle"]
    return custom or ai


def opening_prompts():
    """The first prompt of each session that says anything about it."""
    path = os.path.join(CLAUDE, "history.jsonl")
    first = {}
    try:
        with open(path, errors="replace") as f:
            for record in records(f):
                session = record.get("sessionId")
                display = (record.get("display") or "").strip()
                if not session or session in first:
                    continue
                if len(display) < 4 or display.startswith("/") or display == "exit":
                    continue
                first[session] = " ".join(display.split())
    except OSError:
        pass
    return first


def deduped(entries):
    """Newest first in, so the first of each kind is the one to keep."""
    seen = set()
    kept = []
    for entry in entries:
        keys = (
            ("id", entry["id"]),
            ("row", os.path.normpath(entry["project"]), entry["title"].casefold()),
        )
        if any(key in seen for key in keys):
            continue
        seen.update(keys)
        kept.append(entry)
    return kept


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exclude", default="",
                        help="a directory whose sessions are throwaway")
    parser.add_argument("--limit", type=int, default=14)
    args = parser.parse_args()

    exclude = os.path.normpath(args.exclude) if args.exclude else None
    prompts = None
    found = []

    for path in glob.glob(os.path.join(CLAUDE, "projects", "*", "*.jsonl")):
        session = os.path.basename(path)[:-len(".jsonl")]
        try:
            project = project_of(path)
            when = os.path.getmtime(path)
        except OSError:
            continue
        if not project or not os.path.isdir(project):
            continue
        if exclude and os.path.normpath(project) == exclude:
            continue

        try:
            title = title_of(path)
        except OSError:
            title = None
        if not title:
            if prompts is None:
                prompts = opening_prompts()
            title = prompts.get(session)
        if not title:
            title = os.path.basename(project.rstrip("/")) or project

        found.append({
            "id": session,
            "project": project,
            "title": title[:120],
            "when": when,
        })

    found.sort(key=lambda entry: -entry["when"])
    json.dump(deduped(found)[:args.limit], sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
