#!/usr/bin/env python3
"""Stage or publish the generated ReaSpeech bundle in the Team Audio ReaPack repo."""

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


def require_clean(repo: Path, label: str) -> None:
    if git(repo, "status", "--porcelain", capture=True):
        raise RuntimeError(f"{label} working tree is not clean")


def show_diff(repo: Path, target: Path) -> None:
    relative = target.relative_to(repo)
    tracked = subprocess.run(
        ["git", "ls-files", "--error-unmatch", str(relative)],
        cwd=repo, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode == 0
    if tracked:
        subprocess.run(["git", "diff", "--stat", "--", str(relative)], cwd=repo, check=True)
        print(f"Review with: git -C {repo} diff -- {relative}")
    else:
        # diff returns 1 when differences are found, which is the expected result.
        subprocess.run(
            ["git", "diff", "--no-index", "--stat", "/dev/null", str(relative)],
            cwd=repo,
        )
        print(f"Review with: git -C {repo} diff --no-index /dev/null {relative}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--reascripts-dir", required=True, type=Path)
    parser.add_argument(
        "--release", action="store_true",
        help="commit the package and index (the default only stages files for review)",
    )
    args = parser.parse_args()

    bundle = args.bundle.resolve()
    destination_repo = args.reascripts_dir.resolve()
    if not bundle.is_file():
        raise RuntimeError(f"bundle not found: {bundle}")
    if not (destination_repo / ".git").exists():
        raise RuntimeError(f"not a git repository: {destination_repo}")
    if args.release and shutil.which("reapack-index") is None:
        raise RuntimeError("reapack-index is required for --release")

    match = VERSION_RE.search(bundle.read_text(encoding="utf-8"))
    if not match:
        raise RuntimeError("bundle has no valid ReaPack @version header")
    version = match.group(1)
    if args.release:
        require_clean(destination_repo, "ReaPack repository")

    target = destination_repo / PACKAGE_PATH
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(bundle, target)
    print(f"Staged ReaSpeech {version} in {target}")
    if not args.release:
        show_diff(destination_repo, target)
        print("Review the change, then restore it and rerun with --release.")
        return 0

    git(destination_repo, "add", str(PACKAGE_PATH))
    git(destination_repo, "commit", "-m", f"ReaSpeech {version}")
    run("reapack-index", "--commit", str(destination_repo), cwd=destination_repo)
    if git(destination_repo, "status", "--porcelain", capture=True):
        raise RuntimeError("ReaPack repository is dirty after indexing")
    print("ReaPack commits created. Review them, then push the ReaPack repository manually.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
