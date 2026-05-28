#!/usr/bin/env python3
"""run_checks.py - extension-reviewer 機械チェック一括実行スクリプト

automated-checks.md に列挙された全機械チェックを実施し、結果を JSON ファイルに出力する。

設計上の重要原則:
- 標準出力には進捗ログ（ASCII のみの `[OK]` `[ERROR]` `[DONE]` プレフィックス）のみを出す。
- 検査結果は必ず --output ファイルに書き込む。**stdout に JSON / 日本語を流すと
  PowerShell + chcp 経由の文字化け（UTF-8 → Latin-1 mojibake）を再発する**。
- JSON 出力は `ensure_ascii=False` で UTF-8 ファイルへ書き込むが、これは
  Read ツールがファイル経由でレコードを取得する前提であり、stdout 経由では呼ばないこと。
- detail フィールドには CWE-532 対策で `mask_preview()` を通した行プレビューを格納し、
  生のシークレット値が混入しても露出しないようにする。

呼び出し方:
    python run_checks.py --target <レビュー対象パス> --output <結果JSONファイルパス> [--scope-root <スコープルート>]

引数:
    --target      レビュー対象のディレクトリまたはファイル（必須）
    --output      検査結果を書き出す JSON ファイルパス（必須）
    --scope-root  パストラバーサル防止のため target がこの配下にあることを保証する基準ディレクトリ
                  （省略時は target 自身を scope-root とする）

出力（JSON ファイル）:
    {
      "target": "...",
      "issue_count": N,
      "by_severity": {"Critical": n, "High": n, "Medium": n, "Low": n},
      "issues": [
        {"severity": "...", "item": "...", "file": "...", "line": null, "detail": "..."}
      ]
    }

依存:
    PyYAML (requirements.txt 参照)
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
from typing import Any

# ~/.claude/rules/tools/python-encoding-mandatory.md 必須3点セット (2):
# 環境変数 PYTHONUTF8=1 / PYTHONIOENCODING=utf-8 の補強として、明示的に再構成する。
# stdout は ASCII プレフィックス（[OK]/[ERROR]/[DONE]）のみ流す設計だが、
# 例外スタックトレース等で日本語が混じる経路もあるため安全側に倒す。
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

import yaml


# --------------------------------------------------------------------------- #
# ユーティリティ
# --------------------------------------------------------------------------- #

EXCLUDE_DIRS = {".git", ".venv", "node_modules", "__pycache__", ".tox", ".mypy_cache", ".claude"}

SEVERITY_ORDER = ("Critical", "High", "Medium", "Low")

# DoS 防御: 単一ファイルの読み込み上限（10 MB）
MAX_FILE_BYTES = 10 * 1024 * 1024

# CWE-532 対策: detail に行内容そのままを格納すると偶発的にシークレットが
# 露出する恐れがあるため、英数字を 'x' に置換した「マスク済みプレビュー」を返す。
# 記号・日本語等は維持する（文脈把握用）。
_MASK_PATTERN = re.compile(r"[A-Za-z0-9]")


def mask_preview(line: str, limit: int = 200) -> str:
    """行内容を CWE-532 安全なプレビュー文字列に変換する。"""
    snippet = line.strip()[:limit]
    return _MASK_PATTERN.sub("x", snippet)


class IssueCollector:
    """検出された指摘を蓄積するヘルパ。"""

    def __init__(self) -> None:
        self.issues: list[dict[str, Any]] = []

    def add(
        self,
        severity: str,
        item: str,
        file: pathlib.Path | str | None,
        detail: str,
        line: int | None = None,
    ) -> None:
        self.issues.append(
            {
                "severity": severity,
                "item": item,
                "file": str(file) if file is not None else None,
                "line": line,
                "detail": detail,
            }
        )

    def by_severity(self) -> dict[str, int]:
        counts = {sev: 0 for sev in SEVERITY_ORDER}
        for issue in self.issues:
            sev = issue.get("severity")
            if sev in counts:
                counts[sev] += 1
        return counts


def assert_in_scope(scope_root: pathlib.Path, file_path: pathlib.Path) -> None:
    """file_path が scope_root 配下であることを検証する（パストラバーサル対策）。"""
    scope_resolved = scope_root.resolve()
    file_resolved = file_path.resolve()
    if file_resolved != scope_resolved and scope_resolved not in file_resolved.parents:
        raise ValueError(f"out of scope: {file_path}")


def is_excluded_dir(path: pathlib.Path, root: pathlib.Path) -> bool:
    try:
        rel = path.relative_to(root)
    except ValueError:
        return False
    return any(part in EXCLUDE_DIRS for part in rel.parts)


def iter_text_files(root: pathlib.Path) -> list[pathlib.Path]:
    """root 配下のテキストファイルを列挙する（symlink ループ・除外ディレクトリを安全に処理）。

    - シンボリックリンク経由のディレクトリループを防ぐため `os.walk(followlinks=False)` を使う
    - EXCLUDE_DIRS をディレクトリ単位で枝刈り（rglob 全列挙より高速）
    """
    import os
    files: list[pathlib.Path] = []
    if root.is_file():
        return [root]
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        # 除外ディレクトリは下りない（in-place で書き換えると os.walk が下らない）
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        for filename in filenames:
            files.append(pathlib.Path(dirpath) / filename)
    return files


def read_text_safe(path: pathlib.Path) -> str | None:
    """UTF-8 → CP932 → UTF-16 の順で読み込みを試みる。

    DoS 防御として、`MAX_FILE_BYTES` を超えるファイルは None を返してスキップする。
    OSError や任意のデコードエラーも安全に None で返す。
    """
    try:
        size = path.stat().st_size
    except OSError:
        return None
    if size > MAX_FILE_BYTES:
        return None
    for enc in ("utf-8", "cp932", "utf-16"):
        try:
            return path.read_text(encoding=enc)
        except (UnicodeDecodeError, UnicodeError):
            continue
        except OSError:
            return None
    return None


def split_frontmatter(text: str) -> tuple[dict[str, Any] | None, str, str | None]:
    """`---` 区切りの YAML frontmatter を分離する。

    戻り値: (frontmatter_dict, body, error_message)
    """
    if not text.startswith("---"):
        return None, text, "frontmatter が存在しない"
    parts = text.split("---", 2)
    if len(parts) < 3:
        return None, text, "frontmatter の終端 `---` が見つからない"
    try:
        fm = yaml.safe_load(parts[1]) or {}
    except yaml.YAMLError as exc:
        return None, parts[2], f"YAML パースエラー: {exc}"
    if not isinstance(fm, dict):
        return None, parts[2], "frontmatter が dict ではない"
    return fm, parts[2], None


# --------------------------------------------------------------------------- #
# 個別チェック
# --------------------------------------------------------------------------- #

def check_skill_md_line_count(target: pathlib.Path, collector: IssueCollector) -> None:
    """1. SKILL.md 200 行制約。"""
    for skill_md in target.rglob("SKILL.md"):
        if is_excluded_dir(skill_md, target):
            continue
        try:
            line_count = len(skill_md.read_bytes().splitlines())
        except OSError as exc:
            collector.add("High", "SKILL.md 読み込み失敗", skill_md, str(exc))
            continue
        if line_count > 200:
            collector.add(
                "High",
                "SKILL.md 200 行超過",
                skill_md,
                f"{line_count} 行（上限 200）",
            )


# パスポータビリティ NG パターン（path-portability.md より抜粋）
# - Windows ドライブレター: 直前が英字でない（URL スキーム https:/ 等の誤検出回避）かつ
#   ドライブ文字 1 文字 + ':' + '\' または '/' に限定
PATH_PORTABILITY_PATTERNS: list[tuple[str, str]] = [
    (r"(?<![A-Za-z])[A-Za-z]:[\\/]", "Windows ドライブレター"),
    (r"/home/|/Users/|/root/", "Unix ユーザディレクトリ絶対パス"),
    (r"%USERPROFILE%|%APPDATA%|%LOCALAPPDATA%", "Windows 環境変数"),
    (r"\$HOME\b|\$\{HOME\}", "シェル HOME 変数"),
    (r"\\\\[A-Za-z0-9._-]+\\", "UNC パス"),
]

# パスポータビリティ チェックの除外条件
PATH_PORTABILITY_EXCLUDED_FILES = {".gitignore", ".gitattributes"}
PATH_PORTABILITY_EXCLUDED_DIRS = {"evals", "templates", "tests"}


def _strip_backtick_spans(line: str) -> str:
    """バッククォート（`...` `` ``...`` ``）で囲まれた範囲を空白に置換した行を返す。

    マークダウンドキュメント中で「NG 例: `C:\\Users\\...`」のように
    パターンを例示している箇所を誤検出しないため、バッククォート内を検査対象から外す。
    """
    return re.sub(r"`[^`]*`", lambda m: " " * len(m.group(0)), line)


_FENCE_PATTERN = re.compile(r"^(`{3,}|~{3,})(.*)$")


def iter_inspectable_lines(path: pathlib.Path, text: str):
    """ファイル種別に応じて検査対象行を yield する共通ヘルパ。

    - マークダウン (.md): フェンス付きコードブロック (``` / ~~~) 内・インライン
      バッククォート内は検査対象外。CommonMark 仕様に従いフェンス長を厳密追跡し、
      ネストフェンス（外側 4 個 + 内側 3 個など）も正しく解釈する
    - シェル / Python / PowerShell: 行頭コメント（# / // など）は検査対象外
    - その他: 全行を検査

    yield: (line_num, original_line, sanitized_text)
    """
    suffix = path.suffix
    fence_open_len = 0  # 0 = 非フェンス内、>0 = 開フェンスのバッククォート/チルダ数
    fence_char: str | None = None  # '`' または '~'
    for line_num, line in enumerate(text.splitlines(), start=1):
        if suffix == ".md":
            stripped = line.lstrip()
            match = _FENCE_PATTERN.match(stripped)
            if match:
                marker = match.group(1)
                marker_char = marker[0]
                marker_len = len(marker)
                rest = match.group(2).strip()
                if fence_open_len == 0:
                    # 新規にフェンスを開く
                    fence_open_len = marker_len
                    fence_char = marker_char
                    continue
                else:
                    # フェンス内。CommonMark の閉フェンス条件: 同じ文字 + 開以上の長さ + 後続なし
                    if (
                        marker_char == fence_char
                        and marker_len >= fence_open_len
                        and rest == ""
                    ):
                        fence_open_len = 0
                        fence_char = None
                    # 閉条件を満たさない場合は in fence のまま（内部フェンスとして扱う）
                    continue
            if fence_open_len > 0:
                continue  # フェンス内はスキップ
            yield line_num, line, _strip_backtick_spans(line)
        elif suffix in {".sh", ".py", ".ps1", ".yaml", ".yml"}:
            stripped = line.lstrip()
            if stripped.startswith("#"):
                continue
            yield line_num, line, line
        else:
            yield line_num, line, line


# 自己参照（このスクリプト自身）と marketplace-publisher のシークレットスキャン定義は
# パターン文字列を保持する性質上、検査対象から除外する
SELF_REFERENCE_FILE_NAMES = {
    "run_checks.py",
    "secret-scan.md",
    "path-portability.md",
}


def check_path_portability(target: pathlib.Path, collector: IssueCollector) -> None:
    """2. パスポータビリティ Grep。

    検査対象から除外:
    - マークダウンのフェンス付きコードブロック・インラインバッククォート
    - シェル / Python / PowerShell の行頭コメント
    - 自己参照ファイル（run_checks.py / secret-scan.md / path-portability.md）
    """
    for path in iter_text_files(target):
        if path.suffix not in {".md", ".json", ".sh", ".py", ".ps1", ".yaml", ".yml", ".txt"}:
            continue
        if path.name in PATH_PORTABILITY_EXCLUDED_FILES:
            continue
        if path.name in SELF_REFERENCE_FILE_NAMES:
            continue
        try:
            rel_parts = path.relative_to(target).parts
        except ValueError:
            rel_parts = ()
        if any(part in PATH_PORTABILITY_EXCLUDED_DIRS for part in rel_parts):
            continue
        text = read_text_safe(path)
        if text is None:
            continue
        for line_num, line, check_target in iter_inspectable_lines(path, text):
            for pattern, label in PATH_PORTABILITY_PATTERNS:
                if re.search(pattern, check_target):
                    collector.add(
                        "High",
                        f"パスポータビリティ違反: {label}",
                        path,
                        # CWE-532: 行内容を直接保存せず、英数字をマスクしたプレビューに変換
                        mask_preview(line),
                        line=line_num,
                    )
                    break  # 同一行で複数検出しても一度だけ記録


PLACEHOLDER_PATTERN = re.compile(r"\{[a-z][a-z0-9-]*\}")
# プレースホルダ チェックで例外扱いにする値
PLACEHOLDER_KNOWN_TOKENS = {
    "{name}",
    "{id}",
    "{path}",
    "{plugin-name}",
    "{skill-name}",
    "{command-name}",
    "{agent-name}",
    "{hook-name}",
    "{role}",
}


def check_placeholders(target: pathlib.Path, collector: IssueCollector) -> None:
    """3. プレースホルダ残存（`{...}`）。

    検査対象から除外:
    - フェンス付きコードブロック (``` / ~~~) 内
    - インラインバッククォート内
    - templates / template / evals ディレクトリ配下
    - 自己参照ファイル（run_checks.py / path-portability.md 等）
    """
    for path in iter_text_files(target):
        if path.suffix not in {".md", ".json"}:
            continue
        if path.name in SELF_REFERENCE_FILE_NAMES:
            continue
        try:
            rel_parts = path.relative_to(target).parts
        except ValueError:
            rel_parts = ()
        if any(part in {"templates", "template", "evals"} for part in rel_parts):
            continue
        text = read_text_safe(path)
        if text is None:
            continue
        for line_num, line, check_target in iter_inspectable_lines(path, text):
            for match in PLACEHOLDER_PATTERN.finditer(check_target):
                token = match.group(0)
                if token in PLACEHOLDER_KNOWN_TOKENS:
                    continue
                collector.add(
                    "High",
                    "プレースホルダ残存",
                    path,
                    # CWE-532: 行内容はマスク化、トークン名のみ平文で保持
                    f"検出: {token}（行プレビュー: {mask_preview(line)}）",
                    line=line_num,
                )


TEMPLATE_DIR_NAMES = {"templates", "template"}


def _is_under_template_dir(path: pathlib.Path, target: pathlib.Path) -> bool:
    try:
        rel_parts = path.relative_to(target).parts
    except ValueError:
        return False
    return any(part in TEMPLATE_DIR_NAMES for part in rel_parts)


def check_frontmatter_valid(target: pathlib.Path, collector: IssueCollector) -> None:
    """4a. frontmatter valid (SKILL.md / commands/*.md / agents/*.md)。

    templates/ 配下のひな形ファイルは frontmatter 完備でない設計のため除外する。
    """
    candidates: list[pathlib.Path] = []
    for skill_md in target.rglob("SKILL.md"):
        if is_excluded_dir(skill_md, target):
            continue
        if _is_under_template_dir(skill_md, target):
            continue
        candidates.append(skill_md)
    for cmd_md in target.rglob("commands/*.md"):
        if is_excluded_dir(cmd_md, target):
            continue
        if _is_under_template_dir(cmd_md, target):
            continue
        candidates.append(cmd_md)
    for agent_md in target.rglob("agents/*.md"):
        if is_excluded_dir(agent_md, target):
            continue
        if _is_under_template_dir(agent_md, target):
            continue
        candidates.append(agent_md)
    for path in candidates:
        text = read_text_safe(path)
        if text is None:
            collector.add("High", "ファイル読み込み失敗", path, "テキストとして読めない")
            continue
        fm, _, err = split_frontmatter(text)
        if err is not None:
            collector.add("High", "frontmatter 不正", path, err)


def check_json_valid(target: pathlib.Path, collector: IssueCollector) -> None:
    """4b. JSON valid (plugin.json / marketplace.json / その他 .json)。"""
    for path in target.rglob("*.json"):
        if is_excluded_dir(path, target):
            continue
        text = read_text_safe(path)
        if text is None:
            collector.add("Critical", "JSON 読み込み失敗", path, "テキストとして読めない")
            continue
        try:
            json.loads(text)
        except json.JSONDecodeError as exc:
            collector.add("Critical", "JSON 不正", path, str(exc))


def check_section_symbol(target: pathlib.Path, collector: IssueCollector) -> None:
    """5. § 記号検出。

    自己参照ファイル（このスクリプト自身など）は除外する。
    """
    for path in iter_text_files(target):
        if path.suffix not in {".md", ".json", ".sh", ".py", ".yaml", ".yml", ".txt"}:
            continue
        if path.name in SELF_REFERENCE_FILE_NAMES:
            continue
        text = read_text_safe(path)
        if text is None:
            continue
        for line_num, line, check_target in iter_inspectable_lines(path, text):
            if "§" in check_target:
                collector.add(
                    "Medium",
                    "§ 記号の使用",
                    path,
                    # CWE-532: 行内容を直接保存せず、英数字をマスクしたプレビューに変換
                    mask_preview(line),
                    line=line_num,
                )


REQUIRED_SECTIONS = ("責務", "責務外", "トリガー条件", "前提", "実行フロー", "重要な制約")


def check_required_sections(target: pathlib.Path, collector: IssueCollector) -> None:
    """6. 必須セクション存在チェック (SKILL.md)。

    必須セクション名は **見出しの先頭一致** で判定する（例: `## 責務外（他スキルが担当）`
    は `責務外` とマッチしたとみなす）。括弧書きの補足表記による誤検出を避けるため。
    """
    heading_pattern = re.compile(r"^##\s+(.+?)\s*$", re.MULTILINE)
    for skill_md in target.rglob("SKILL.md"):
        if is_excluded_dir(skill_md, target):
            continue
        text = read_text_safe(skill_md)
        if text is None:
            continue
        headings = [match.group(1).strip() for match in heading_pattern.finditer(text)]
        missing = [
            sec
            for sec in REQUIRED_SECTIONS
            if not any(heading.startswith(sec) for heading in headings)
        ]
        if missing:
            collector.add(
                "High",
                "必須セクション欠落",
                skill_md,
                f"欠落: {', '.join(missing)}",
            )


def _description_text(value: Any) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return " ".join(str(v) for v in value)
    return str(value or "")


def check_description_length(target: pathlib.Path, collector: IssueCollector) -> None:
    """7. description 文字数チェック。

    | 対象 | 目安 |
    | プラグイン description | 80 文字以内 |
    | コマンド description | 60 文字以内 |
    | スキル description | 制限なし |
    | エージェント description | 制限なし |
    """
    # プラグイン
    for plugin_json in target.rglob(".claude-plugin/plugin.json"):
        if is_excluded_dir(plugin_json, target):
            continue
        text = read_text_safe(plugin_json)
        if text is None:
            continue
        try:
            obj = json.loads(text)
        except json.JSONDecodeError:
            continue
        desc = _description_text(obj.get("description"))
        if len(desc) > 80:
            collector.add(
                "Medium",
                "プラグイン description 80 文字超過",
                plugin_json,
                f"{len(desc)} 文字",
            )
    # コマンド
    for cmd_md in target.rglob("commands/*.md"):
        if is_excluded_dir(cmd_md, target):
            continue
        text = read_text_safe(cmd_md)
        if text is None:
            continue
        fm, _, err = split_frontmatter(text)
        if err is not None or fm is None:
            continue
        desc = _description_text(fm.get("description"))
        if len(desc) > 60:
            collector.add(
                "Medium",
                "コマンド description 60 文字超過",
                cmd_md,
                f"{len(desc)} 文字",
            )


ARGUMENTS_PATTERN = re.compile(r"\$ARGUMENTS")
ROUTING_PATTERN = re.compile(r"^##\s*ルーティング", re.MULTILINE)


def check_argument_hint(target: pathlib.Path, collector: IssueCollector) -> None:
    """7.5. コマンド argument-hint 必須化（ADR-023）。"""
    for cmd_md in target.rglob("commands/*.md"):
        if is_excluded_dir(cmd_md, target):
            continue
        text = read_text_safe(cmd_md)
        if text is None:
            continue
        fm, body, err = split_frontmatter(text)
        if err is not None or fm is None:
            collector.add("High", "frontmatter 不在/不正", cmd_md, err or "fm None")
            continue
        has_arguments = bool(ARGUMENTS_PATTERN.search(body))
        has_routing = bool(ROUTING_PATTERN.search(body))
        needs_hint = has_arguments or has_routing
        hint = fm.get("argument-hint")
        if needs_hint and not hint:
            collector.add(
                "High",
                "argument-hint 欠落（ADR-023）",
                cmd_md,
                "$ARGUMENTS 参照ありまたはルーティングコマンドだが argument-hint が未定義",
            )
        if hint:
            hint_str = str(hint)
            if "\n" in hint_str:
                collector.add("Medium", "argument-hint に改行", cmd_md, hint_str[:120])
            if len(hint_str) > 60:
                collector.add(
                    "Medium",
                    "argument-hint 60 文字超過",
                    cmd_md,
                    f"{len(hint_str)} 文字",
                )


# --------------------------------------------------------------------------- #
# 9. シークレット混入チェック（marketplace-publisher の secret-scan.md と同等）
# --------------------------------------------------------------------------- #

FILE_PATTERNS_FULL = [
    r"\.env(\..+)?",
    r".+\.pem", r".+\.key", r".+\.secret", r".+-secret",
    r"id_(rsa|dsa|ecdsa|ed25519)(\..+)?",
    r"credentials\.(json|yaml|yml)",
    r"secrets\.(json|yaml|yml)",
    r".+\.p12", r".+\.pfx", r".+\.kdbx",
    r"\.netrc", r"_netrc",
    r"\.htpasswd", r".+\.htpasswd",
]
EXCLUDE_SUFFIX = (".example", ".sample", ".template")

CONTENT_PATTERNS: dict[str, str] = {
    "aws_access_key": r"AKIA[0-9A-Z]{16}",
    "aws_secret_key": r"aws_secret_access_key\s*=\s*[\"']?[A-Za-z0-9/+=]{40}[\"']?",
    "github_pat": r"ghp_[A-Za-z0-9]{36}",
    "github_oauth": r"gho_[A-Za-z0-9]{36}",
    "github_user_server": r"ghu_[A-Za-z0-9]{36}",
    "github_server_server": r"ghs_[A-Za-z0-9]{36}",
    "github_refresh": r"ghr_[A-Za-z0-9]{36}",
    "slack_token": r"xox[baprs]-[0-9A-Za-z-]{10,}",
    "google_api_key": r"AIza[0-9A-Za-z\-_]{35}",
    "stripe_key": r"sk_live_[0-9a-zA-Z]{24,}",
    "stripe_restricted_key": r"rk_(live|test)_[0-9a-zA-Z]{24,}",
    "anthropic_key": r"sk-ant-(api\d+-)?[A-Za-z0-9\-_]{20,}",
    "openai_key": r"sk-(?!proj-)(?!svcacct-)(?!ant-)[A-Za-z0-9]{48}",
    "openai_proj_key": r"sk-proj-[A-Za-z0-9_-]{20,}",
    "openai_svcacct_key": r"sk-svcacct-[A-Za-z0-9_-]{20,}",
    "private_key_pem": r"-----BEGIN (RSA |EC |OPENSSH |DSA |PGP |)PRIVATE KEY-----",
    "bearer_token": r"Bearer\s+[A-Za-z0-9\-_=]{20,}",
    "generic_password": r"(?i)(password|passwd|secret|api[-_]?key)\s*[:=]\s*[\"']?[A-Za-z0-9+/=_\-\.]{16,}[\"']?",
    "jwt": r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+",
    "azure_storage": r"DefaultEndpointsProtocol=https;AccountName=[A-Za-z0-9]+;AccountKey=[A-Za-z0-9+/=]+",
    "azure_sas_token": r"sig=[A-Za-z0-9%]{20,}(?:&|$)",
    "gcp_private_key_id": r'"private_key_id"\s*:\s*"[a-f0-9]{40}"',
}

PLACEHOLDER_VALUE_PATTERNS = [
    r"\$\{[A-Z_]+\}",
    r"\{\{[a-z_]+\}\}",
    r"<[a-z-]+>",
    r"\$\([A-Z_]+\)",
]


def is_binary_file(path: pathlib.Path) -> bool:
    try:
        chunk = path.read_bytes()[:8192]
    except OSError:
        return True
    if chunk.startswith(b"\xff\xfe") or chunk.startswith(b"\xfe\xff") or chunk.startswith(b"\xef\xbb\xbf"):
        return False
    return b"\x00" in chunk


def is_placeholder_value(value: str) -> bool:
    return any(re.search(pat, value) for pat in PLACEHOLDER_VALUE_PATTERNS)


# シークレット混入チェックの除外ディレクトリ
# tests / evals / templates 配下はテスト fixture / テンプレートのためダミーパターンを許容する
SECRET_SCAN_EXCLUDED_DIRS = {"tests", "evals", "templates", "template"}


def check_secrets(target: pathlib.Path, collector: IssueCollector) -> None:
    """10. シークレット混入チェック。

    除外:
        - tests / evals / templates 配下のテスト fixture / テンプレート
          （ダミーパターン・サンプル値を意図的に含むため、 CWE-532 を侵さない範囲で許容）
    """
    for path in target.rglob("*"):
        if not path.is_file():
            continue
        if is_excluded_dir(path, target):
            continue
        try:
            rel_parts = path.relative_to(target).parts
        except ValueError:
            rel_parts = ()
        if any(part in SECRET_SCAN_EXCLUDED_DIRS for part in rel_parts):
            continue
        # ファイル名照合
        if not path.name.endswith(EXCLUDE_SUFFIX):
            for pat in FILE_PATTERNS_FULL:
                if re.fullmatch(pat, path.name):
                    collector.add(
                        "Critical",
                        "シークレット疑い: ファイル名",
                        path,
                        f"パターン: {pat}",
                    )
                    break
        if is_binary_file(path):
            continue
        text = read_text_safe(path)
        if text is None:
            continue
        for name, pat in CONTENT_PATTERNS.items():
            for match in re.finditer(pat, text):
                matched = match.group(0)
                if is_placeholder_value(matched):
                    continue
                line_num = text[: match.start()].count("\n") + 1
                # CWE-532: 検出値そのものは記録しない。パターン名のみ記録
                collector.add(
                    "Critical",
                    "シークレット疑い: 内容パターン",
                    path,
                    f"パターン: {name}",
                    line=line_num,
                )
                break  # 同一ファイル内の同パターン重複は省略


def _detect_owner_marketplace(target: pathlib.Path, plugin_dir: pathlib.Path) -> str | None:
    """プラグインの所属マーケットプレイス名を推定する。

    優先順:
        1. target が `.claude-plugin/marketplace.json` を含むリポジトリ配下なら、その `name`
        2. target 自身（または scope-root 想定の親）に `.claude-plugin/marketplace.json` があれば、その `name`
        3. 推定不可なら None（呼び出し側で判定スキップ）
    """
    candidates = [target, plugin_dir]
    cur = plugin_dir
    for _ in range(6):  # ルートまで遡上（深さ上限）
        candidates.append(cur)
        if cur.parent == cur:
            break
        cur = cur.parent
    for base in candidates:
        manifest = base / ".claude-plugin" / "marketplace.json"
        if manifest.exists():
            text = read_text_safe(manifest)
            if not text:
                continue
            try:
                data = json.loads(text)
            except json.JSONDecodeError:
                continue
            name = data.get("name")
            if isinstance(name, str) and name:
                return name
    return None


def check_cross_marketplace_readme(target: pathlib.Path, collector: IssueCollector) -> None:
    """11. クロスマーケットプレイス依存時の README D-1/D-2/D-3 揃い検査（R-2-7 / ADR-028）。

    `plugin.json` の `dependencies` 配列に **自プラグイン所属マーケ名と異なる** `marketplace`
    フィールド値を含むエントリが 1 件以上ある場合、対応する README に以下 3 ブロックが
    すべて含まれることを確認する:
        D-1: `/plugin marketplace add` の記載
        D-2: `extraKnownMarketplaces` JSON ブロックの記載
        D-3: 依存プラグインを明示する `/plugin install` の記載
    """
    for plugin_json in target.rglob("plugin.json"):
        if is_excluded_dir(plugin_json, target):
            continue
        if plugin_json.parent.name != ".claude-plugin":
            continue
        plugin_dir = plugin_json.parent.parent
        text = read_text_safe(plugin_json)
        if text is None:
            continue
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            continue  # JSON 不正は別チェックで検出済み

        deps = data.get("dependencies")
        if not isinstance(deps, list) or not deps:
            continue

        owner_mp = _detect_owner_marketplace(target, plugin_dir)
        cross_dep_mps: list[str] = []
        for entry in deps:
            if not isinstance(entry, dict):
                continue  # 文字列形式は同一マーケ依存で対象外
            mp_name = entry.get("marketplace")
            if not isinstance(mp_name, str) or not mp_name:
                continue
            if owner_mp and mp_name == owner_mp:
                continue  # 同一マーケットプレイス依存は対象外
            cross_dep_mps.append(mp_name)

        if not cross_dep_mps:
            continue  # クロスマーケットプレイス依存なし

        readme = plugin_dir / "README.md"
        if not readme.exists():
            collector.add(
                "High",
                "README.md 不在（クロスマーケットプレイス依存時 D-1/D-2/D-3 検証不可）",
                plugin_json,
                f"cross marketplace deps: {','.join(cross_dep_mps)}",
            )
            continue
        readme_text = read_text_safe(readme)
        if readme_text is None:
            collector.add(
                "High",
                "README.md 読み込み失敗",
                readme,
                f"cross marketplace deps: {','.join(cross_dep_mps)}",
            )
            continue

        d1_ok = bool(re.search(r"/plugin\s+marketplace\s+add\s+\S+", readme_text))
        d2_ok = "extraKnownMarketplaces" in readme_text and "autoUpdate" in readme_text
        d3_ok = bool(re.search(r"/plugin\s+install\s+\S+@\S+", readme_text))

        missing = []
        if not d1_ok:
            missing.append("D-1(/plugin marketplace add)")
        if not d2_ok:
            missing.append("D-2(extraKnownMarketplaces JSON)")
        if not d3_ok:
            missing.append("D-3(/plugin install)")
        if missing:
            collector.add(
                "High",
                "ADR-028: クロスマーケットプレイス依存時の README D-1/D-2/D-3 不揃い",
                readme,
                f"missing={','.join(missing)} cross_marketplaces={','.join(cross_dep_mps)}",
            )


# --------------------------------------------------------------------------- #
# 12. PowerShell ベタ起動の hook 検出（Bash 標準・PowerShell フォールバック方針）
#     旧版は Bash 禁止チェックだったが、リポジトリの Bash 標準化方針 (Phase 9)
#     に伴い、検査ロジックを **反転** させた。
# --------------------------------------------------------------------------- #

# hooks.json の command フィールド先頭が `pwsh ...` / `powershell ...` で始まるパターン
# 通常運用は Bash 起動 (`bash "..."`) なので、PowerShell ベタ起動を Medium 指摘で
# 「フォールバック手順以外は Bash 起動にすべき」と促す。
_HOOK_POWERSHELL_COMMAND_PATTERN = re.compile(r"^\s*(pwsh|powershell)(\.exe)?\s+", re.IGNORECASE)

# 除外条件
_BASH_USAGE_EXCLUDED_DIRS = {"templates", "template", "evals", "node_modules", "hooks-fallback"}


def check_no_bash_invocation(target: pathlib.Path, collector: IssueCollector) -> None:
    """12. PowerShell ベタ起動の hook 検出（Bash 標準・PowerShell フォールバック方針）.

    検出項目:
        - hooks.json の command フィールドが `pwsh ...` / `powershell ...` で始まる -> Medium
          (通常運用は Bash 起動。PowerShell 起動は `references/hooks-fallback/` 配下の
           フォールバック専用エントリでのみ許容)

    旧版チェック (撤廃):
        - 旧: `.sh` 残存を High 指摘 -> 撤廃 (Bash 標準方針下では `.sh` は通常運用ファイル)
        - 旧: hooks.json の `bash ...` を High 指摘 -> 撤廃 (Bash 標準方針)
        - 旧: md 内の `bash ...sh` 起動例を Medium 指摘 -> 撤廃 (Bash 主軸書換と矛盾)

    除外:
        - templates / template / evals / hooks-fallback / node_modules 配下
        - hooks/ 配下以外の hooks.json (誤検出防止)
    """
    for hooks_json in target.rglob("hooks.json"):
        if is_excluded_dir(hooks_json, target):
            continue
        try:
            rel_parts = hooks_json.relative_to(target).parts
        except ValueError:
            rel_parts = ()
        if any(part in _BASH_USAGE_EXCLUDED_DIRS for part in rel_parts):
            continue
        if hooks_json.parent.name != "hooks":
            continue
        text = read_text_safe(hooks_json)
        if text is None:
            continue
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            continue  # JSON 不正は別チェックで検出済み

        def _walk(obj: Any) -> None:
            if isinstance(obj, dict):
                for k, v in obj.items():
                    if k == "command" and isinstance(v, str):
                        if _HOOK_POWERSHELL_COMMAND_PATTERN.match(v):
                            collector.add(
                                "Medium",
                                "PowerShell ベタ起動の hook 検出 (Bash 標準方針 / shell-preference.md)",
                                hooks_json,
                                f"通常運用は `bash \"...\"` 起動。PowerShell 起動は references/hooks-fallback/ 配下のみ許容: {mask_preview(v)}",
                            )
                    else:
                        _walk(v)
            elif isinstance(obj, list):
                for item in obj:
                    _walk(item)

        _walk(data)


# --------------------------------------------------------------------------- #
# 13. hook の shell フィールド明示チェック（Bash 標準・PowerShell フォールバック補強）
# --------------------------------------------------------------------------- #

# `bash "..."` を書いていても Claude Code の起動側シェルが PowerShell だと
# 引数解釈や PATH 解決でエッジケースが発生しうる。各 hook エントリで
# `"shell": "bash"` を明示することを必須化する (フォールバック時は `"powershell"`)。
_ALLOWED_SHELL_VALUES = {"powershell", "bash"}
_HOOK_SHELL_EXCLUDED_DIRS = {"templates", "template", "evals", "hooks-fallback"}


def check_hook_shell_field(target: pathlib.Path, collector: IssueCollector) -> None:
    """13. hook の shell フィールド明示チェック（Bash 標準・PowerShell フォールバック補強）.

    検出項目:
        - hooks.json 内の `type: "command"` を持つエントリに `"shell"` キーが存在しない -> High
        - `"shell"` 値が `"bash"` / `"powershell"` 以外                                    -> High
        - 本マーケットプレイス通常運用で `"shell": "powershell"` (フォールバックではない場合) -> Medium

    除外:
        - templates / template / evals / hooks-fallback 配下のテンプレート・テスト fixture
        - hooks/ 配下以外の hooks.json (誤検出防止)
    """
    for hooks_json in target.rglob("hooks.json"):
        if is_excluded_dir(hooks_json, target):
            continue
        try:
            rel_parts = hooks_json.relative_to(target).parts
        except ValueError:
            rel_parts = ()
        if any(part in _HOOK_SHELL_EXCLUDED_DIRS for part in rel_parts):
            continue
        if hooks_json.parent.name != "hooks":
            continue
        text = read_text_safe(hooks_json)
        if text is None:
            continue
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            continue  # JSON 不正は別チェックで検出済み

        hooks_root = data.get("hooks") if isinstance(data, dict) else None
        if not isinstance(hooks_root, dict):
            continue

        for event_name, event_entries in hooks_root.items():
            if not isinstance(event_entries, list):
                continue
            for entry in event_entries:
                if not isinstance(entry, dict):
                    continue
                inner_hooks = entry.get("hooks")
                if not isinstance(inner_hooks, list):
                    continue
                for hook_def in inner_hooks:
                    if not isinstance(hook_def, dict):
                        continue
                    if hook_def.get("type") != "command":
                        continue
                    if "shell" not in hook_def:
                        collector.add(
                            "High",
                            "hook の `shell` フィールド未指定（Bash 標準・PowerShell フォールバック補強、shell-preference.md）",
                            hooks_json,
                            f"event={event_name} command={mask_preview(str(hook_def.get('command', '')))}",
                        )
                        continue
                    shell_value = hook_def.get("shell")
                    if shell_value not in _ALLOWED_SHELL_VALUES:
                        collector.add(
                            "High",
                            "hook の `shell` フィールド値が不正",
                            hooks_json,
                            f"event={event_name} shell={shell_value!r} (期待値: 'bash' / 'powershell')",
                        )
                        continue
                    if shell_value == "powershell":
                        collector.add(
                            "Medium",
                            "hook で `shell: powershell` 指定（本マーケットプレイスは Bash 標準）",
                            hooks_json,
                            f"event={event_name} (通常運用は 'bash' を推奨。PowerShell 起動は references/hooks-fallback/ 配下のフォールバックエントリで利用)",
                        )


_MIT_COPYRIGHT_RE = re.compile(r"^Copyright \(c\) (\S+) (.+)$")


def _resolve_mit_template() -> "pathlib.Path | None":
    """MIT 標準文テンプレートのパスを解決する（mit-license-toolkit が SSOT）。"""
    plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
    if plugin_root:
        candidate = pathlib.Path(plugin_root) / "skills" / "mit-license-toolkit" / "references" / "template" / "LICENSE"
        if candidate.is_file():
            return candidate
    here = pathlib.Path(__file__).resolve()
    candidate = (
        here.parent.parent.parent.parent.parent
        / "mit-license-toolkit"
        / "references"
        / "template"
        / "LICENSE"
    )
    if candidate.is_file():
        return candidate
    return None


def _normalize_license_body(body: str) -> "list[str]":
    """copyright 行を除いた行列を返す（MIT テンプレートと比較するため）。"""
    return [line for line in body.splitlines() if not line.startswith("Copyright (c)")]


def check_mit_license(target: pathlib.Path, collector: IssueCollector) -> None:
    """11. プラグイン MIT LICENSE 配備検査（ADR-029）。

    対象: target 配下のすべてのプラグイン（.claude-plugin/plugin.json を持つディレクトリ）。
    検査項目:
        - プラグイン直下に LICENSE が存在する（Critical）
        - LICENSE 本文が MIT 標準文と一致する（copyright 行除く、Critical）
        - Copyright (c) <year> <holder> 行に year + holder が埋まっている（Critical）
        - plugin.json.license == "MIT"（Critical）
        - README.md に「ライセンス」セクションと LICENSE への相対リンクがある（High）
    """
    template_path = _resolve_mit_template()
    if template_path is None:
        # テンプレート参照不能は環境エラー扱いで High（致命ではないが検証品質低下）
        collector.add(
            "High",
            "ADR-029: MIT LICENSE テンプレートが解決できない（環境エラー）",
            None,
            "$CLAUDE_PLUGIN_ROOT/skills/mit-license-toolkit/references/template/LICENSE が見つからない",
        )
        return

    template_normalized = _normalize_license_body(template_path.read_text(encoding="utf-8"))

    for plugin_json in target.rglob("plugin.json"):
        if is_excluded_dir(plugin_json, target):
            continue
        if plugin_json.parent.name != ".claude-plugin":
            continue
        # references/templates/ 配下のテンプレートファイル（プレースホルダ込み）は除外
        if "templates" in plugin_json.parts:
            continue
        plugin_dir = plugin_json.parent.parent

        # plugin.json.license == "MIT" 検査
        text = read_text_safe(plugin_json)
        if text is not None:
            try:
                data = json.loads(text)
                license_value = data.get("license")
                if license_value != "MIT":
                    collector.add(
                        "Critical",
                        "ADR-029: plugin.json.license != \"MIT\"",
                        plugin_json,
                        f"license={license_value!r} (期待値: \"MIT\")",
                    )
            except json.JSONDecodeError:
                pass  # JSON 不正は別チェックで検出済み

        # LICENSE 存在検査
        license_path = plugin_dir / "LICENSE"
        if not license_path.is_file():
            collector.add(
                "Critical",
                "ADR-029: プラグイン直下 LICENSE 不在",
                license_path,
                "MIT 標準文 + Copyright 行を mit-license-toolkit で配備すること",
            )
            continue

        # LICENSE 本文の MIT 標準文一致検査
        license_text = read_text_safe(license_path)
        if license_text is None:
            collector.add("Critical", "ADR-029: LICENSE 読み込み失敗", license_path, "")
            continue

        if _normalize_license_body(license_text) != template_normalized:
            collector.add(
                "Critical",
                "ADR-029: LICENSE 本文が MIT 標準文と不一致",
                license_path,
                "license-policy.md 節 2.2 の標準文と一字一句一致させること",
            )
            continue

        # Copyright 行検査
        copyright_lines = [line for line in license_text.splitlines() if line.startswith("Copyright (c)")]
        if not copyright_lines:
            collector.add(
                "Critical",
                "ADR-029: LICENSE に Copyright 行がない",
                license_path,
                "Copyright (c) <year> <holder> を含めること",
            )
        else:
            match = _MIT_COPYRIGHT_RE.match(copyright_lines[0])
            if not match:
                collector.add(
                    "Critical",
                    "ADR-029: Copyright 行の書式が不正",
                    license_path,
                    f"line: {copyright_lines[0]}",
                )
            else:
                year, holder = match.group(1).strip(), match.group(2).strip()
                if not year or not holder or "{" in year or "{" in holder:
                    collector.add(
                        "Critical",
                        "ADR-029: Copyright 行に year/holder が空またはプレースホルダ残存",
                        license_path,
                        f"year={year!r} holder={holder!r}",
                    )

        # README ライセンスセクション検査（プラグインのみ、High）
        readme = plugin_dir / "README.md"
        if readme.is_file():
            readme_text = read_text_safe(readme)
            if readme_text is not None:
                has_license_section = bool(
                    re.search(r"^##\s+ライセンス\b", readme_text, re.MULTILINE)
                    or re.search(r"^##\s+License\b", readme_text, re.MULTILINE)
                )
                has_license_link = bool(re.search(r"\[[^\]]*[Ll]icense[^\]]*\]\([^)]*LICENSE[^)]*\)", readme_text))
                if not (has_license_section and has_license_link):
                    missing = []
                    if not has_license_section:
                        missing.append("「## ライセンス」セクション")
                    if not has_license_link:
                        missing.append("LICENSE への相対リンク")
                    collector.add(
                        "High",
                        "ADR-029: README に「ライセンス」セクションまたは LICENSE リンクが不在",
                        readme,
                        f"missing={','.join(missing)}",
                    )


# --------------------------------------------------------------------------- #
# PSScriptAnalyzer 連携（B-1）は廃止 (Bash 標準運用への移行に伴い、
# extension-toolkit から PSModule / PSScriptAnalyzer 機能を削除)。
# 必要な PowerShell コードレビューは extension-reviewer のメイン LLM レビューで
# カバーする（AST ベースの静的解析は PSGallery 依存のため非対応とする）。
# --------------------------------------------------------------------------- #


# --------------------------------------------------------------------------- #
# Python 子プロセス起動の Start-Job ラッパー必須化チェック（automated-checks.md §15）
# --------------------------------------------------------------------------- #

_PY_DIRECT_INVOCATION_PATTERN = re.compile(
    r"""(?<!\w)              # 単語の先頭
    &\s+                     # PowerShell の `&` 呼び出し演算子
    [^\n]*?                  # 中間（venv パス等）
    python(?:\.exe)?         # python 本体
    [^\n]*?                  # 引数
    \.py\b                   # スクリプト末尾
    """,
    re.VERBOSE,
)
_START_PROCESS_NONEWWINDOW_PATTERN = re.compile(
    r"Start-Process\b[\s\S]{0,400}?-NoNewWindow",
    re.IGNORECASE,
)
_RUNNER_HINT_PATTERN = re.compile(
    r"\b(?:Start-Job|run_via_job|run_verify_via_job|Wait-Job)\b",
    re.IGNORECASE,
)
_PY_HANG_EXCLUDED_DIRS = {
    "templates", "template", "evals", "checklists",
}
_PY_HANG_EXCLUDED_FILES = {
    "automated-checks.md",
    "powershell-pitfalls.md",
    "scripts-policy.md",
    "python-subprocess-hang-windows.md",
    "run_checks.py",
}


def _path_excluded_for_py_hang(path: pathlib.Path, target: pathlib.Path) -> bool:
    """Python 直起動チェックの除外判定."""
    if is_excluded_dir(path, target):
        return True
    try:
        rel_parts = path.relative_to(target).parts
    except ValueError:
        rel_parts = ()
    if any(part in _PY_HANG_EXCLUDED_DIRS for part in rel_parts):
        return True
    if path.name in _PY_HANG_EXCLUDED_FILES:
        return True
    return False


def check_python_start_job_wrapper(target: pathlib.Path, collector: IssueCollector) -> None:
    """15. Python 直起動禁止 / Start-Job ラッパー必須チェック.

    Windows + PowerShell + python-pptx 等で Python 子プロセスがハングする
    既知事象（`powershell-pitfalls.md` 節 7.3 / グローバルルール
    `python-subprocess-hang-windows.md`）を踏まえ、プラグイン配下に `.py` ファイルが
    存在する場合、その実行手順が Start-Job 経由ラッパーを介しているかをレビューする。

    検出項目:
        - 起動例が `& "...python(.exe)?" "...\\.py"` 形式で、同じファイルに
          `Start-Job` / `run_via_job` / `Wait-Job` への参照が無い  -> High
        - `Start-Process -NoNewWindow` の組み合わせが .md / .ps1 に出現    -> High
        - .py を含むプラグインに Start-Job を含む .ps1 が一切無い          -> Medium

    除外:
        - templates / template / evals / checklists 配下
        - automated-checks.md / powershell-pitfalls.md / scripts-policy.md /
          python-subprocess-hang-windows.md / run_checks.py (自己参照)
        - プラグイン全体で .py が存在しない場合
    """
    if not target.is_dir():
        return

    # 1. .py ファイルの有無
    py_files = []
    for py_path in target.rglob("*.py"):
        if not any(seg in EXCLUDE_DIRS for seg in py_path.parts):
            py_files.append(py_path)
    if not py_files:
        return

    # 2. .md / .ps1 を走査
    has_start_job_wrapper = False
    for ps1_path in target.rglob("*.ps1"):
        if _path_excluded_for_py_hang(ps1_path, target):
            continue
        text = read_text_safe(ps1_path)
        if text is None:
            continue
        if "Start-Job" in text:
            has_start_job_wrapper = True

        # Start-Process -NoNewWindow 組み合わせ検出
        if _START_PROCESS_NONEWWINDOW_PATTERN.search(text):
            # 自分自身が Start-Job ラッパー（中の説明文ならスキップ）
            if "Start-Job" in text and "ScriptBlock" in text:
                continue
            # Markdown 内のコード例ではないため検出対象
            collector.add(
                "High",
                "Start-Process -NoNewWindow + Python 子プロセスでハングする可能性。Start-Job 経由ラッパーへ移行",
                ps1_path,
                "Start-Process -NoNewWindow を含む PowerShell ファイル",
            )

    for md_path in target.rglob("*.md"):
        if _path_excluded_for_py_hang(md_path, target):
            continue
        text = read_text_safe(md_path)
        if text is None:
            continue
        has_runner_hint = bool(_RUNNER_HINT_PATTERN.search(text))

        for line_num, line, check_target in iter_inspectable_lines(md_path, text):
            if _PY_DIRECT_INVOCATION_PATTERN.search(check_target):
                # 同じファイルに Start-Job / run_via_job 等の参照があれば文脈的に
                # 「禁止例の提示」「正例」として許容する
                if has_runner_hint:
                    continue
                collector.add(
                    "High",
                    "Python スクリプトを `&` で直起動。Start-Job 経由ラッパーが必須",
                    md_path,
                    mask_preview(line),
                    line=line_num,
                )

    # 3. .py がある場合に Start-Job ラッパーが一切無いプラグイン -> Medium
    if not has_start_job_wrapper:
        collector.add(
            "Medium",
            "Python スクリプトがあるが Start-Job ラッパー (.ps1) が見つからない。run_via_job.ps1 相当のラッパー作成を推奨",
            target,
            f"{len(py_files)} .py files but no Start-Job .ps1 found",
        )


# --------------------------------------------------------------------------- #
# メインフロー
# --------------------------------------------------------------------------- #

CHECKS = [
    ("SKILL.md 200 行制約", check_skill_md_line_count),
    ("パスポータビリティ", check_path_portability),
    ("プレースホルダ残存", check_placeholders),
    ("frontmatter valid", check_frontmatter_valid),
    ("JSON valid", check_json_valid),
    ("§ 記号検出", check_section_symbol),
    ("必須セクション存在", check_required_sections),
    ("description 文字数", check_description_length),
    ("argument-hint 必須（ADR-023）", check_argument_hint),
    ("シークレット混入", check_secrets),
    ("クロスマーケ依存時 README D-1/D-2/D-3 揃い（ADR-028 / R-2-7）", check_cross_marketplace_readme),
    ("プラグイン MIT LICENSE 配備（ADR-029）", check_mit_license),
    ("PowerShell ベタ起動の hook 検出（Bash 標準・PowerShell フォールバック方針、shell-preference.md）", check_no_bash_invocation),
    ("hook の shell フィールド明示（Bash 標準・PowerShell フォールバック補強、shell-preference.md）", check_hook_shell_field),
    # PSScriptAnalyzer 静的解析（B-1）は extension-toolkit から削除済み (Bash 標準移行)
    ("Python 直起動禁止 / Start-Job ラッパー必須（automated-checks.md §15）", check_python_start_job_wrapper),
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--target", required=True, help="レビュー対象のディレクトリまたはファイル")
    parser.add_argument("--output", required=True, help="検査結果を書き出す JSON ファイルパス")
    parser.add_argument(
        "--scope-root",
        default=None,
        help="パストラバーサル防止のため target がこの配下にあることを保証する基準ディレクトリ",
    )
    args = parser.parse_args()

    target = pathlib.Path(args.target)
    if not target.exists():
        # 進捗ログは ASCII で出して文字化けを回避
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

    collector = IssueCollector()
    for label, fn in CHECKS:
        try:
            fn(target, collector)
            print(f"[OK] {label}")
        except Exception as exc:  # noqa: BLE001
            print(f"[ERROR] check failed: {label}: {exc}", file=sys.stderr)
            collector.add("High", f"check failed: {label}", None, str(exc))

    output_path = pathlib.Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    result = {
        "target": str(target),
        "scope_root": str(scope_root),
        "issue_count": len(collector.issues),
        "by_severity": collector.by_severity(),
        "issues": collector.issues,
    }
    output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[DONE] wrote {output_path} (issues={len(collector.issues)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
