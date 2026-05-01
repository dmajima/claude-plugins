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
import pathlib
import re
import sys
from typing import Any

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
PATH_PORTABILITY_EXCLUDED_DIRS = {"evals", "templates"}


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


def check_secrets(target: pathlib.Path, collector: IssueCollector) -> None:
    """10. シークレット混入チェック。"""
    for path in target.rglob("*"):
        if not path.is_file():
            continue
        if is_excluded_dir(path, target):
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
