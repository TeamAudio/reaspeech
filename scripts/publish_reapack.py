#!/usr/bin/env python3
"""Publish the generated ReaSpeech bundle to the Team Audio ReaPack repo."""

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path


PACKAGE_PATH = Path("ReaSpeech/ReaSpeech.lua")
VERSION_RE = re.compile(r"^--\s*@version\s+(\d+\.\d+\.\d+)\s*$", re.MULTILINE)


def run(*command: str, cwd: Path, capture: bool = False) -> str:
    print("+", " ".join(command))
    result = subprocess.run(
        command, cwd=cwd, check=True, text=True,
        stdout=subprocess.PIPE if capture else None,
    )
    return result.stdout.strip() if capture else ""


def git(repo: Path, *args: str, capture: bool = False) -> str:
    return run("git", *args, cwd=repo, capture=capture)


def require_clean_main(repo: Path, label: str) -> None:
    branch = git(repo, "branch", "--show-current", capture=True)
    if branch != "main":
        raise RuntimeError(f"{label} must be on main (currently {branch or 'detached'})")
    if git(repo, "status", "--porcelain", capture=True):
        raise RuntimeError(f"{label} working tree is not clean")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--reascripts-dir", required=True, type=Path)
    parser.add_argument("--check", action="store_true", help="validate without changing files")
    parser.add_argument("--push", action="store_true", help="push the completed ReaPack release")
    args = parser.parse_args()

    source_repo = Path(__file__).resolve().parents[1]
    bundle = args.bundle.resolve()
    destination_repo = args.reascripts_dir.resolve()
    if not bundle.is_file():
        raise RuntimeError(f"bundle not found: {bundle}")
    if not (destination_repo / ".git").exists():
        raise RuntimeError(f"not a git repository: {destination_repo}")
    if shutil.which("reapack-index") is None:
        raise RuntimeError("reapack-index is required")

    match = VERSION_RE.search(bundle.read_text(encoding="utf-8"))
    if not match:
        raise RuntimeError("bundle has no valid ReaPack @version header")
    version = match.group(1)
    require_clean_main(destination_repo, "ReaPack repository")

    if args.check:
        print(f"ReaSpeech {version} is ready to publish to {destination_repo}")
        return 0

    require_clean_main(source_repo, "ReaSpeech repository")

    target = destination_repo / PACKAGE_PATH
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(bundle, target)
    git(destination_repo, "add", str(PACKAGE_PATH))
    git(destination_repo, "commit", "-m", f"ReaSpeech {version}")
    run("reapack-index", "--commit", str(destination_repo), cwd=destination_repo)
    if git(destination_repo, "status", "--porcelain", capture=True):
        raise RuntimeError("ReaPack repository is dirty after indexing")
    if args.push:
        git(destination_repo, "push", "origin", "main")
    else:
        print("Release committed locally; push the ReaPack main branch to publish it.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
