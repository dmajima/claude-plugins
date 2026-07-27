"""Delete <base>/sessions/<sid>/ directories older than 30 days.

Invoked by /router-status --clean. Required environment: PYTHONUTF8=1
(provided by Claude Code settings.json env). All paths are local user data.

Usage:
    python clean_old_sessions.py <base>

Exit 0 always (fail-open): unrecoverable errors are printed to stderr but the
surrounding /router-status flow must continue.
"""
from __future__ import annotations

import shutil
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

_AGE_THRESHOLD_SECONDS = 30 * 24 * 60 * 60  # 30 days


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: clean_old_sessions.py <base>", file=sys.stderr)
        return 0

    base = Path(argv[1])
    sessions_root = base / "sessions"

    # <base> はリポジトリ配下に解決されうる。clone したリポジトリが
    # `sessions` を $HOME へのシンボリックリンクとして同梱していると、
    # リンクを辿った削除でユーザのディレクトリを消してしまう。
    # リンクは辿らず、実ディレクトリのみを対象にする。
    if sessions_root.is_symlink():
        print(f"clean_old_sessions: refusing to follow symlink {sessions_root}",
              file=sys.stderr)
        return 0
    if not sessions_root.is_dir():
        print(f"clean_old_sessions: nothing to do (no {sessions_root})")
        return 0
    try:
        root_resolved = sessions_root.resolve()
    except OSError:
        return 0

    now = time.time()
    removed = 0
    failed = 0
    for entry in sessions_root.glob("*"):
        # リンク（およびリンク経由で外へ出るパス）は対象外。削除範囲を
        # sessions/ の実体配下に閉じ込める。
        if entry.is_symlink() or not entry.is_dir():
            continue
        try:
            resolved = entry.resolve()
            if resolved.parent != root_resolved:
                continue
            age = now - entry.stat().st_mtime
        except OSError:
            continue
        if age <= _AGE_THRESHOLD_SECONDS:
            continue
        try:
            # ignore_errors は使わない。大量削除が無警告で進むと、
            # 誤対象に対する取り消しの機会が失われる。
            shutil.rmtree(entry)
        except OSError as exc:
            failed += 1
            print(f"clean_old_sessions: failed to remove {entry}: {exc}",
                  file=sys.stderr)
            continue
        removed += 1

    print(f"clean_old_sessions: removed {removed} session(s) older than 30 days")
    if failed:
        print(f"clean_old_sessions: {failed} session(s) could not be removed",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
