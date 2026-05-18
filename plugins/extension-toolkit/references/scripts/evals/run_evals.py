#!/usr/bin/env python3
"""run_evals.py - 実行ベース evals CI ランナー（B-2: improvement-backlog 由来）

case-*.md のフロントマターに `runnable: true` が指定されたケースを、
実機 dry-run で実行し、`expect_output_regex` と照合して合否判定する。

設計上の重要原則:
- 副作用ゼロを担保する仕組みとして、フロントマターには **dry-run コマンドのみ**
  を記述する規約を設ける（実適用系はオプトインで `requires_destructive: true`
  を要求し、`--allow-destructive` フラグなしには実行しない）。
- 標準出力には進捗ログ（ASCII プレフィックス）のみを出す。結果 JSON は
  必ず --output ファイルに書き込む（PowerShell + chcp 経由の文字化け回避）。
- 各ケースの実行は **並列** で行う（ThreadPoolExecutor、デフォルト 4 並列）。
- 各ケース実行のタイムアウト既定 120 秒。長時間処理は `timeout_sec` で個別指定。

呼び出し方:
    python run_evals.py --target <evals ディレクトリ or プラグインルート> \\
        --output <結果 JSON 出力先> [--scope-root <スコープルート>] \\
        [--parallel 4] [--allow-destructive]

引数:
    --target              evals ディレクトリ or それを含む親（再帰探索）
    --output              結果 JSON 出力ファイル
    --scope-root          パストラバーサル防止のため target がこの配下にあることを保証
    --parallel            並列実行数（既定: 4）
    --allow-destructive   requires_destructive: true のケースも実行する（既定: スキップ）

入力ケースのフロントマター仕様:

    ---
    runnable: true                    # 必須。false / 未指定なら自動実行対象外
    command: |                        # 必須。実行するシェルコマンド（pwsh で起動）
      pwsh -NoProfile -File scripts/foo.ps1 -DryRun
    expect_exit_code: 0               # 任意（既定: 0）
    expect_output_regex:              # 任意（複数可）。全てマッチしないと失敗
      - "^\\[OK\\]"
      - "ケース 1: 成功"
    expect_output_not_regex:          # 任意（複数可）。1 つでもマッチしたら失敗
      - "(?i)error"
    timeout_sec: 120                  # 任意（既定: 120）
    cwd: plugins/maintenance          # 任意（既定: プラグインルート）
    requires_destructive: false       # 任意（既定: false）。true なら --allow-destructive 必須
    env:                              # 任意。実行時に追加する環境変数
      DRY_RUN: "1"
    ---

    # Case {番号}: {ケース名}
    （以下、通常の evals ケース本文）

出力（JSON ファイル）:
    {
      "target": "...",
      "total": N,
      "runnable": N,
      "passed": N,
      "failed": N,
      "skipped": N,
      "results": [
        {
          "case_file": "...",
          "status": "passed" | "failed" | "skipped",
          "reason": "...",
          "exit_code": int,
          "duration_sec": float,
          "stdout_preview": "...",
          "stderr_preview": "..."
        }
      ]
    }

依存:
    PyYAML（references/scripts/setup/requirements.txt 既存）
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import pathlib
import re
import subprocess
import sys
import time
from typing import Any

# python-encoding-mandatory.md 必須3点セット
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

import yaml


# --------------------------------------------------------------------------- #
# 定数
# --------------------------------------------------------------------------- #

EXCLUDE_DIRS = {".git", ".venv", "node_modules", "__pycache__", ".tox", ".mypy_cache", ".claude"}

DEFAULT_TIMEOUT_SEC = 120
DEFAULT_PARALLEL = 4
MAX_PARALLEL = 32           # ThreadPoolExecutor の上限（DoS 防御、sec M-2）
MAX_TIMEOUT_SEC = 600       # case ごとの timeout 上限（極端値防御、impl M-03）
PREVIEW_LIMIT = 1500        # 出力プレビュー上限


# --------------------------------------------------------------------------- #
# ユーティリティ
# --------------------------------------------------------------------------- #


def assert_in_scope(scope_root: pathlib.Path, file_path: pathlib.Path) -> None:
    """パストラバーサル防止: file_path が scope_root 配下にあることを保証する。"""
    scope_real = scope_root.resolve(strict=False)
    file_real = file_path.resolve(strict=False)
    try:
        file_real.relative_to(scope_real)
    except ValueError as exc:
        raise ValueError(f"out of scope: {file_path} not under {scope_root}") from exc


def is_excluded(path: pathlib.Path, root: pathlib.Path) -> bool:
    """除外ディレクトリ配下のパスかチェック。"""
    try:
        rel_parts = path.relative_to(root).parts
    except ValueError:
        return False
    return any(seg in EXCLUDE_DIRS for seg in rel_parts)


def split_frontmatter(text: str) -> tuple[dict[str, Any] | None, str]:
    """先頭の --- ... --- フロントマターを切り出して dict として返す。

    フロントマターが無い、または不正な YAML の場合は (None, 元テキスト) を返す。
    """
    if not text.startswith("---"):
        return None, text
    # 改行コードに依存しない分割
    parts = re.split(r"\r?\n---\r?\n", text[3:], maxsplit=1)
    if len(parts) != 2:
        return None, text
    fm_text, body = parts
    try:
        fm = yaml.safe_load(fm_text)
    except yaml.YAMLError:
        return None, text
    if not isinstance(fm, dict):
        return None, text
    return fm, body


def preview(text: str, limit: int = PREVIEW_LIMIT) -> str:
    """長文の冒頭プレビューを返す。"""
    text = text or ""
    if len(text) <= limit:
        return text
    return text[:limit] + f"\n...(truncated, total {len(text)} chars)"


# --------------------------------------------------------------------------- #
# ケース実行
# --------------------------------------------------------------------------- #


def collect_case_files(target: pathlib.Path) -> list[pathlib.Path]:
    """target 配下から evals/case-*.md を再帰収集する。"""
    cases: list[pathlib.Path] = []
    if target.is_file() and target.name.startswith("case-") and target.suffix == ".md":
        return [target]
    for path in target.rglob("case-*.md"):
        if path.suffix != ".md":
            continue
        if is_excluded(path, target):
            continue
        # evals/ 配下のみを対象（templates/ 配下は除外）
        if "templates" in path.parts:
            continue
        cases.append(path)
    return sorted(cases)


def execute_case(
    case_file: pathlib.Path,
    cwd_base: pathlib.Path,
    allow_destructive: bool,
    scope_root: pathlib.Path | None = None,
) -> dict[str, Any]:
    """1 ケースを実行し、結果 dict を返す。"""
    started = time.monotonic()
    try:
        text = case_file.read_text(encoding="utf-8")
    except OSError as exc:
        return {
            "case_file": str(case_file),
            "status": "failed",
            "reason": f"read error: {exc}",
            "exit_code": None,
            "duration_sec": 0.0,
            "stdout_preview": "",
            "stderr_preview": "",
        }

    fm, _body = split_frontmatter(text)
    if not fm or not fm.get("runnable"):
        return {
            "case_file": str(case_file),
            "status": "skipped",
            "reason": "no frontmatter or runnable!=true",
            "exit_code": None,
            "duration_sec": 0.0,
            "stdout_preview": "",
            "stderr_preview": "",
        }

    if fm.get("requires_destructive") and not allow_destructive:
        return {
            "case_file": str(case_file),
            "status": "skipped",
            "reason": "requires_destructive=true and --allow-destructive not specified",
            "exit_code": None,
            "duration_sec": 0.0,
            "stdout_preview": "",
            "stderr_preview": "",
        }

    command = fm.get("command")
    if not isinstance(command, str) or not command.strip():
        return {
            "case_file": str(case_file),
            "status": "failed",
            "reason": "missing or invalid 'command' field",
            "exit_code": None,
            "duration_sec": 0.0,
            "stdout_preview": "",
            "stderr_preview": "",
        }

    expect_exit = fm.get("expect_exit_code", 0)
    expect_regexes = fm.get("expect_output_regex") or []
    expect_not_regexes = fm.get("expect_output_not_regex") or []
    _raw_timeout = fm.get("timeout_sec")
    try:
        timeout_sec = int(_raw_timeout) if _raw_timeout is not None else DEFAULT_TIMEOUT_SEC
    except (ValueError, TypeError):
        timeout_sec = DEFAULT_TIMEOUT_SEC
    timeout_sec = max(1, min(timeout_sec, MAX_TIMEOUT_SEC))
    case_cwd = fm.get("cwd")
    extra_env = fm.get("env") or {}

    if isinstance(expect_regexes, str):
        expect_regexes = [expect_regexes]
    if isinstance(expect_not_regexes, str):
        expect_not_regexes = [expect_not_regexes]

    # 環境変数（既存 + ケース固有を上書き）
    run_env = dict(os.environ)
    if isinstance(extra_env, dict):
        for k, v in extra_env.items():
            run_env[str(k)] = str(v)
    # 必須: Python 子プロセスへの UTF-8 継承
    run_env.setdefault("PYTHONUTF8", "1")
    run_env.setdefault("PYTHONIOENCODING", "utf-8")

    # cwd 解決（指定なければプラグインルート相当）
    if isinstance(case_cwd, str) and case_cwd:
        run_cwd = (cwd_base / case_cwd).resolve()
    else:
        run_cwd = cwd_base.resolve()

    # パストラバーサル防御: case フロントマターの cwd が scope_root 配下に
    # 収まることを検証する（B-2 設計時の前提「副作用ゼロ」を担保する）。
    # scope_root 未指定なら cwd_base を fallback とする（同程度の保護）。
    boundary = scope_root if scope_root is not None else cwd_base
    try:
        assert_in_scope(boundary, run_cwd)
    except ValueError as exc:
        return {
            "case_file": str(case_file),
            "status": "failed",
            "reason": f"cwd '{case_cwd}' is out of scope: {exc}",
            "exit_code": None,
            "duration_sec": round(time.monotonic() - started, 3),
            "stdout_preview": "",
            "stderr_preview": "",
        }

    # コマンドは pwsh で起動（クロスプラットフォーム配慮、Windows 既定）
    # command 文字列は shell スクリプトとして pwsh -Command に渡す
    try:
        proc = subprocess.run(
            ["pwsh", "-NoProfile", "-NonInteractive", "-Command", command],
            cwd=str(run_cwd),
            env=run_env,
            capture_output=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout_sec,
        )
    except FileNotFoundError:
        return {
            "case_file": str(case_file),
            "status": "skipped",
            "reason": "pwsh not found (PowerShell 7+ required)",
            "exit_code": None,
            "duration_sec": time.monotonic() - started,
            "stdout_preview": "",
            "stderr_preview": "",
        }
    except subprocess.TimeoutExpired as exc:
        return {
            "case_file": str(case_file),
            "status": "failed",
            "reason": f"timeout after {timeout_sec}s",
            "exit_code": None,
            "duration_sec": time.monotonic() - started,
            "stdout_preview": preview(exc.stdout if isinstance(exc.stdout, str) else ""),
            "stderr_preview": preview(exc.stderr if isinstance(exc.stderr, str) else ""),
        }

    duration = time.monotonic() - started
    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")

    # 期待値検証
    failures: list[str] = []
    if proc.returncode != expect_exit:
        failures.append(f"exit_code: expected {expect_exit}, got {proc.returncode}")

    for pat in expect_regexes:
        try:
            if not re.search(str(pat), combined, re.MULTILINE):
                failures.append(f"missing regex: {pat}")
        except re.error as exc:
            failures.append(f"invalid regex {pat!r}: {exc}")

    for pat in expect_not_regexes:
        try:
            if re.search(str(pat), combined, re.MULTILINE):
                failures.append(f"unexpected regex match: {pat}")
        except re.error as exc:
            failures.append(f"invalid not-regex {pat!r}: {exc}")

    return {
        "case_file": str(case_file),
        "status": "passed" if not failures else "failed",
        "reason": "ok" if not failures else "; ".join(failures),
        "exit_code": proc.returncode,
        "duration_sec": round(duration, 3),
        "stdout_preview": preview(proc.stdout or ""),
        "stderr_preview": preview(proc.stderr or ""),
    }


# --------------------------------------------------------------------------- #
# メインフロー
# --------------------------------------------------------------------------- #


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--target", required=True, help="evals ディレクトリ or プラグインルート")
    parser.add_argument("--output", required=True, help="検査結果を書き出す JSON ファイルパス")
    parser.add_argument(
        "--scope-root",
        default=None,
        help="パストラバーサル防止のため target がこの配下にあることを保証する基準ディレクトリ",
    )
    parser.add_argument(
        "--parallel",
        type=int,
        default=DEFAULT_PARALLEL,
        help=f"並列実行数（既定: {DEFAULT_PARALLEL}）",
    )
    parser.add_argument(
        "--allow-destructive",
        action="store_true",
        help="requires_destructive: true のケースも実行する（既定: スキップ）",
    )
    args = parser.parse_args()

    target = pathlib.Path(args.target)
    if not target.exists():
        print(f"[ERROR] target not found: {target}", file=sys.stderr)
        return 2

    scope_root = pathlib.Path(args.scope_root) if args.scope_root else target
    if not scope_root.exists():
        print(f"[ERROR] scope-root not found: {scope_root}", file=sys.stderr)
        return 2

    try:
        assert_in_scope(scope_root, target)
    except ValueError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 2

    case_files = collect_case_files(target)
    print(f"[INFO] found {len(case_files)} case-*.md file(s) under {target}")

    cwd_base = scope_root.resolve()
    scope_root_resolved = scope_root.resolve()

    results: list[dict[str, Any]] = []
    parallel = max(1, min(args.parallel, MAX_PARALLEL))

    with concurrent.futures.ThreadPoolExecutor(max_workers=parallel) as pool:
        futures = {
            pool.submit(
                execute_case,
                case,
                cwd_base,
                args.allow_destructive,
                scope_root_resolved,
            ): case
            for case in case_files
        }
        for fut in concurrent.futures.as_completed(futures):
            res = fut.result()
            status = res["status"]
            tag = {"passed": "[PASS]", "failed": "[FAIL]", "skipped": "[SKIP]"}.get(status, "[?]")
            print(f"{tag} {res['case_file']} ({res['reason']})")
            results.append(res)

    # 集計
    total = len(results)
    runnable = sum(1 for r in results if r["status"] in ("passed", "failed"))
    passed = sum(1 for r in results if r["status"] == "passed")
    failed = sum(1 for r in results if r["status"] == "failed")
    skipped = sum(1 for r in results if r["status"] == "skipped")

    output_path = pathlib.Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(
            {
                "target": str(target),
                "scope_root": str(scope_root),
                "total": total,
                "runnable": runnable,
                "passed": passed,
                "failed": failed,
                "skipped": skipped,
                "results": sorted(results, key=lambda r: r["case_file"]),
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(
        f"[DONE] wrote {output_path} "
        f"(total={total}, runnable={runnable}, passed={passed}, failed={failed}, skipped={skipped})"
    )
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
