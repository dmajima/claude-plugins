#!/usr/bin/env python3
"""aggregate.py - Claude Code セッション JSONL からトークン消費量を集計する (Python 再実装版)

aggregate.sh から起動する Python 集計スクリプト。

設計:
- 標準ライブラリのみで実装（pyperclip 等の追加依存なし）
- 全角幅計算は東アジア幅プロパティの簡易判定
- クリップボードコピーは OS 標準コマンド経由 (Windows: clip.exe, macOS: pbcopy, Linux: xclip)
- 出力エンコーディングは UTF-8 固定
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# python-encoding-mandatory.md 必須3点セット
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")


WIDTH = 60


def display_width(s: str) -> int:
    """全角は 2 幅、それ以外は 1 幅で計算 (CJK 領域の簡易判定)."""
    w = 0
    for ch in s:
        code = ord(ch)
        if code >= 0x1100 and (code <= 0x115F or code >= 0x2E80):
            w += 2
        else:
            w += 1
    return w


def wrap_line(line: str, width: int = WIDTH) -> list[str]:
    """行を表示幅で折り返す (先頭インデントを継承)."""
    if display_width(line) <= width:
        return [line]
    # 先頭の連続スペースを継承
    indent = ""
    for ch in line:
        if ch == " ":
            indent += " "
        else:
            break
    indent_w = display_width(indent)

    result: list[str] = []
    current = ""
    current_w = 0
    for ch in line:
        code = ord(ch)
        cw = 2 if (code >= 0x1100 and (code <= 0x115F or code >= 0x2E80)) else 1
        if current_w + cw > width:
            result.append(current)
            current = indent
            current_w = indent_w
        current += ch
        current_w += cw
    if current:
        result.append(current)
    return result


def format_kp(n: int, total: int) -> str:
    """K 単位 + 割合のフォーマット."""
    pct = (n / total * 100) if total > 0 else 0.0
    return f"{n / 1000.0:>9,.1f}k ({pct:>5,.1f}%)"


def format_k(n: int) -> str:
    """K 単位フォーマット."""
    return f"{n / 1000.0:>9,.1f}k"


def parse_iso_timestamp(s: str) -> datetime | None:
    """ISO 8601 タイムスタンプを datetime に変換 (Z サポート)."""
    try:
        if s.endswith("Z"):
            s = s[:-1] + "+00:00"
        return datetime.fromisoformat(s)
    except (ValueError, TypeError):
        return None


def copy_to_clipboard(text: str) -> tuple[bool, str]:
    """OS 標準コマンドでクリップボードにコピー."""
    plat = sys.platform
    try:
        if plat.startswith("win"):
            # Windows: clip.exe
            proc = subprocess.run(
                ["clip.exe"],
                input=text,
                encoding="utf-16le",
                errors="replace",
                check=True,
                capture_output=True,
            )
            return True, ""
        elif plat == "darwin":
            subprocess.run(
                ["pbcopy"],
                input=text,
                encoding="utf-8",
                errors="replace",
                check=True,
                capture_output=True,
            )
            return True, ""
        else:
            # Linux
            for cmd in (["xclip", "-selection", "clipboard"], ["xsel", "-b", "-i"]):
                try:
                    subprocess.run(
                        cmd,
                        input=text,
                        encoding="utf-8",
                        errors="replace",
                        check=True,
                        capture_output=True,
                    )
                    return True, ""
                except (FileNotFoundError, subprocess.CalledProcessError):
                    continue
            return False, "no clipboard command available (xclip / xsel)"
    except Exception as exc:  # noqa: BLE001
        return False, str(exc)


def aggregate(jsonl_path: Path, session_id: str = "") -> dict[str, Any]:
    """JSONL を 1 行ずつパースして集計."""
    totals = {
        "msg_count": 0,
        "input": 0,
        "cache_create": 0,
        "cache_read": 0,
        "output": 0,
        "web_search": 0,
        "web_fetch": 0,
    }
    by_model: dict[str, dict[str, int]] = {}
    first_ts: str | None = None
    last_ts: str | None = None
    custom_title: str | None = None
    ai_title: str | None = None

    with open(jsonl_path, "r", encoding="utf-8", errors="replace") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            if obj.get("type") == "custom-title":
                ct = obj.get("customTitle")
                if ct is not None:
                    custom_title = str(ct)
                continue
            if obj.get("type") == "ai-title":
                at = obj.get("aiTitle")
                if at is not None:
                    ai_title = str(at)
                continue
            if obj.get("type") != "assistant":
                continue

            message = obj.get("message")
            if not message:
                continue
            usage = message.get("usage")
            if not usage:
                continue

            model = str(message.get("model") or "unknown")
            v_in = int(usage.get("input_tokens") or 0)
            v_cc = int(usage.get("cache_creation_input_tokens") or 0)
            v_cr = int(usage.get("cache_read_input_tokens") or 0)
            v_out = int(usage.get("output_tokens") or 0)

            totals["msg_count"] += 1
            totals["input"] += v_in
            totals["cache_create"] += v_cc
            totals["cache_read"] += v_cr
            totals["output"] += v_out

            server_tool_use = usage.get("server_tool_use") or {}
            ws = server_tool_use.get("web_search_requests")
            wf = server_tool_use.get("web_fetch_requests")
            if ws is not None:
                totals["web_search"] += int(ws)
            if wf is not None:
                totals["web_fetch"] += int(wf)

            if model not in by_model:
                by_model[model] = {"count": 0, "total": 0}
            by_model[model]["count"] += 1
            by_model[model]["total"] += v_in + v_cc + v_cr + v_out

            ts = obj.get("timestamp")
            if ts:
                if first_ts is None:
                    first_ts = ts
                last_ts = ts

    grand_total = totals["input"] + totals["cache_create"] + totals["cache_read"] + totals["output"]

    if custom_title:
        session_name = f"{custom_title} (renamed)"
    elif ai_title:
        session_name = f"{ai_title} (auto)"
    else:
        session_name = "(unnamed)"

    period_str = ""
    if first_ts and last_ts:
        start = parse_iso_timestamp(first_ts)
        end = parse_iso_timestamp(last_ts)
        if start and end:
            start_local = start.astimezone()
            end_local = end.astimezone()
            dur = end_local - start_local
            hours = dur.total_seconds() / 3600.0
            if hours >= 1:
                dur_str = f"{hours:,.1f} h"
            else:
                mins = dur.total_seconds() / 60.0
                dur_str = f"{mins:,.0f} min"
            period_str = (
                f"{start_local.strftime('%Y-%m-%d %H:%M')} - "
                f"{end_local.strftime('%H:%M')}  ({dur_str})"
            )
        else:
            period_str = f"{first_ts} - {last_ts}"

    return {
        "session_id": session_id,
        "session_name": session_name,
        "period": period_str,
        "jsonl_path": str(jsonl_path),
        "totals": totals,
        "by_model": by_model,
        "grand_total": grand_total,
    }


def render(result: dict[str, Any]) -> str:
    """集計結果を整形済み文字列に変換."""
    totals = result["totals"]
    by_model = result["by_model"]
    grand_total = result["grand_total"]
    double = "=" * WIDTH
    single_inner = "-" * (WIDTH - 2)

    lines: list[str] = []
    lines.append("")
    lines.append(double)
    lines.append("  Claude Code  Session Usage")
    lines.append(double)
    lines.append(f"  Session  : {result['session_name']}")
    lines.append(f"  ID       : {result['session_id']}")
    if result["period"]:
        lines.append(f"  Period   : {result['period']}")
    lines.append(f"  Requests : {totals['msg_count']:,}")
    lines.append("")
    lines.append("  -- Token Consumption " + ("-" * 37))
    lines.append(f"  Input          : {format_kp(totals['input'], grand_total)}")
    lines.append(f"  Cache Creation : {format_kp(totals['cache_create'], grand_total)}")
    lines.append(f"  Cache Read     : {format_kp(totals['cache_read'], grand_total)}")
    lines.append(f"  Output         : {format_kp(totals['output'], grand_total)}")
    lines.append("  " + single_inner)
    lines.append(f"  Total          : {format_k(grand_total)}")

    lines.append("")
    lines.append("  -- Per-Model " + ("-" * 45))
    for model, stats in by_model.items():
        lines.append(f"  {model}")
        lines.append(f"      {format_k(stats['total'])} / {stats['count']:,} calls")

    if totals["web_search"] > 0 or totals["web_fetch"] > 0:
        lines.append("")
        lines.append("  -- Server Tools " + ("-" * 42))
        if totals["web_search"] > 0:
            lines.append(f"  Web Search Requests : {totals['web_search']:>8,}")
        if totals["web_fetch"] > 0:
            lines.append(f"  Web Fetch  Requests : {totals['web_fetch']:>8,}")

    lines.append("")
    lines.append(double)

    wrapped: list[str] = []
    for line in lines:
        wrapped.extend(wrap_line(line, WIDTH))

    return "\n".join(wrapped)


def find_latest_jsonl(project_dir: Path) -> tuple[Path | None, str]:
    """プロジェクトディレクトリ内の最新 mtime の .jsonl を返す."""
    if not project_dir.is_dir():
        return None, ""
    candidates = list(project_dir.glob("*.jsonl"))
    if not candidates:
        return None, ""
    latest = max(candidates, key=lambda p: p.stat().st_mtime)
    return latest, latest.stem


def resolve_jsonl(session_id: str, project_key: str) -> tuple[Path | None, str, str | None]:
    """JSONL ファイルパスを解決."""
    home = os.environ.get("USERPROFILE") or os.environ.get("HOME") or ""
    project_dir = Path(home) / ".claude" / "projects" / project_key
    if not project_dir.is_dir():
        return None, session_id, f"プロジェクトディレクトリが見つかりません: {project_dir}"

    if session_id:
        candidate = project_dir / f"{session_id}.jsonl"
        if candidate.is_file():
            return candidate, session_id, None
        return None, session_id, f"指定セッションの JSONL が見つかりません: {candidate}"

    latest, sid = find_latest_jsonl(project_dir)
    if latest:
        return latest, sid, None
    return None, session_id, f"セッションログが見つかりません: {project_dir}"


def derive_project_key(cwd: str | None = None) -> str:
    """カレントディレクトリからプロジェクトキーを導出."""
    p = cwd if cwd is not None else os.getcwd()
    # パス区切り文字を '-' に正規化
    key = re.sub(r"[\\:/]", "-", p)
    return key


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--session-id", default="", help="対象セッションID（未指定時は CLAUDE_CODE_SESSION_ID または最新mtime）")
    parser.add_argument("--project-key", default="", help="プロジェクトキー（未指定時は cwd から導出）")
    parser.add_argument("--as-object", action="store_true", help="JSON で結果を返す（整形文字列でなく）")
    parser.add_argument("--stdout", action="store_true", help="整形済み文字列を stdout に出力")
    parser.add_argument("--copy", action="store_true", help="整形済み文字列をクリップボードへコピー")
    args = parser.parse_args()

    session_id = args.session_id or os.environ.get("CLAUDE_CODE_SESSION_ID") or ""
    project_key = args.project_key or derive_project_key()

    jsonl_path, resolved_sid, err = resolve_jsonl(session_id, project_key)
    if err:
        print(err, file=sys.stderr)
        return 1

    result = aggregate(jsonl_path, resolved_sid)

    if args.as_object:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0

    rendered = render(result)

    copy_result = None
    if args.copy:
        ok, err_msg = copy_to_clipboard(rendered)
        if ok:
            copy_result = "  [OK] clipboard へコピーしました"
        else:
            copy_result = f"  [NG] clipboard copy failed: {err_msg}"

    if args.stdout and args.copy:
        print(rendered)
        print(copy_result)
        return 0
    if args.stdout:
        print(rendered)
        return 0
    if args.copy:
        print(copy_result)
        return 0

    # 既定: 整形文字列を stdout
    print(rendered)
    return 0


if __name__ == "__main__":
    sys.exit(main())
