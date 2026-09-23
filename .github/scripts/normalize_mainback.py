#!/usr/bin/env python3
"""Normalize the current mainback branch after upstream changes are merged."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

PROTECTED_FILES = {"README.md", "LICENSE"}
PROTECTED_PREFIXES = (".github/",)

REPLACEMENTS = (
    ("PiliPlus", "PiliBro"),
    ("piliplus", "pilibro"),
    ("PILIPLUS", "PILIBRO"),
    ("Piliplus", "Pilibro"),
)

# Exact compatibility strings that are intentionally kept in their old form.
ALLOWED_LITERALS = {
    "lib/pages/webdav/webdav.dart": (
        "${directory}PiliPlus",
        "piliplus_settings_${DeviceUtils.platformName}.json",
    ),
}

LEFTOVER_RE = re.compile(r"piliplus", re.IGNORECASE)


def tracked_files() -> list[str]:
    raw = subprocess.check_output(["git", "ls-files", "-z"])
    return [item.decode("utf-8") for item in raw.split(b"\0") if item]


def protected(path: str) -> bool:
    return path in PROTECTED_FILES or path.startswith(PROTECTED_PREFIXES)


def normalize_token(value: str) -> str:
    for old, new in REPLACEMENTS:
        value = value.replace(old, new)
    return value


def mask_allowed(path: str, text: str) -> tuple[str, dict[str, str]]:
    masked = text
    restore: dict[str, str] = {}
    for index, literal in enumerate(ALLOWED_LITERALS.get(path, ())):
        token = f"__BRO_KEEP_{index}_7F3A9D__"
        if literal in masked:
            masked = masked.replace(literal, token)
            restore[token] = literal
    return masked, restore


def restore_allowed(text: str, restore: dict[str, str]) -> str:
    for token, literal in restore.items():
        text = text.replace(token, literal)
    return text


def normalize() -> int:
    renamed = 0
    changed_files = 0
    counts = {old: 0 for old, _ in REPLACEMENTS}

    for src in sorted(tracked_files(), key=lambda p: (p.count("/"), len(p)), reverse=True):
        if protected(src):
            continue

        dst = normalize_token(src)
        if dst == src:
            continue

        dst_path = Path(dst)
        if dst_path.exists():
            print(f"::error file={src}::Cannot rename to {dst}: destination already exists")
            return 2

        dst_path.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "mv", "--", src, dst], check=True)
        renamed += 1
        print(f"RENAME {src} -> {dst}")

    for rel in tracked_files():
        if protected(rel):
            continue

        path = Path(rel)
        try:
            data = path.read_bytes()
        except FileNotFoundError:
            continue

        if b"\0" in data:
            continue

        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            continue

        original = text
        text, restore = mask_allowed(rel, text)

        for old, new in REPLACEMENTS:
            n = text.count(old)
            if n:
                counts[old] += n
                text = text.replace(old, new)

        text = restore_allowed(text, restore)

        if text != original:
            path.write_bytes(text.encode("utf-8"))
            changed_files += 1

    print(f"Renamed tracked paths: {renamed}")
    print(f"Changed text files: {changed_files}")
    for old, _ in REPLACEMENTS:
        print(f"{old}: {counts[old]} replacement(s)")

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write("### Mainback normalization\n\n")
            f.write(f"- Renamed tracked paths: **{renamed}**\n")
            f.write(f"- Changed text files: **{changed_files}**\n")
            for old, _ in REPLACEMENTS:
                f.write(f"- Replaced {old}: **{counts[old]}**\n")

    return 0


def audit() -> int:
    issues: list[tuple[str, int, str]] = []

    for rel in tracked_files():
        if protected(rel):
            continue

        if LEFTOVER_RE.search(rel):
            issues.append((rel, 0, f"tracked path still contains a source-brand variant: {rel}"))

        path = Path(rel)
        try:
            data = path.read_bytes()
        except FileNotFoundError:
            continue

        if b"\0" in data:
            continue

        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            continue

        for line_no, line in enumerate(text.splitlines(), 1):
            check_line = line
            for literal in ALLOWED_LITERALS.get(rel, ()):
                check_line = check_line.replace(literal, "")

            if LEFTOVER_RE.search(check_line):
                snippet = line.strip()
                if len(snippet) > 220:
                    snippet = snippet[:217] + "..."
                issues.append((rel, line_no, snippet))

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(f"- Unexpected source-brand leftovers: **{len(issues)}**\n")

    if not issues:
        print("Audit passed: no unexpected source-brand variants remain.")
        print("::notice::Mainback normalization audit passed.")
        return 0

    print(f"Audit failed: {len(issues)} unexpected occurrence(s) remain.")
    print("Any successful normalization commit has already been pushed to mainback.")
    for rel, line_no, snippet in issues:
        if line_no:
            print(f"::error file={rel},line={line_no}::{snippet}")
        else:
            print(f"::error file={rel}::{snippet}")
    return 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("normalize", "audit"))
    args = parser.parse_args()
    return normalize() if args.mode == "normalize" else audit()


if __name__ == "__main__":
    sys.exit(main())
