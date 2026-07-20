#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""deep-test 実績 YAML（test-results.yaml）操作スクリプト。

test-results.yaml への書き込みの唯一経路（test オーケストレータが使用）。加えて test-report
スキルが validate / summary を読み取り目的で実行する共有スクリプトでもある。実績 YAML の追記・
集計・抽出・検証を本スクリプトに一元化する（LLM による test-results.yaml の直接編集は禁止）。
書き込み系（init / start-run / record / finish-run / annotate）と読み取り系（select / validate /
summary）の区別は、呼び出すサブコマンドの制約によって担保される（読み取り専用の実行者は書き込み系
サブコマンドを呼ばないため、共有しても書き込み制約は破られない）。

- スキーマの SSOT: <plugin>/references/yaml-schema.md
- 再テスト対象判定マトリクスの SSOT: <plugin>/references/retest-policy.md
- 中間結果フォーマット（record の JSON 入力）の SSOT: <plugin>/references/execution-policy.md 4 章
- テストレベル定数の SSOT: <plugin>/references/scripts/lib/levels.py（散文は references/test-levels.md）

サブコマンド:
  init        {base}/{target}/ を初期化（test-results.yaml 骨格・evidence/ 生成）
  start-run   run 開始記録（run_id 採番・status=in_progress）。run_id と active_runs_warning を
              含む JSON を stdout に出力（scope に未承認 draft ケースを含む場合は既定 exit 2。
              --allow-draft 指定時のみ [WARN] で続行）
  record      ケース結果 1 件追記 + latest 更新（JSON 入力。fail は一次バリデーション）
  finish-run  run 完了記録（scope と results の突合・欠落検出・status 確定）
  select      再テスト対象抽出（full / ng-only / ids。JSON 出力）
  validate    整合性チェック（fail の defect 3 点セット・エビデンス実在・scope 突合・
              annotations 構造検証。未完了 run の未記録ケースを resumable_runs として
              JSON 出力し、resume 判定に使える）
  summary     レベル別集計（latest 採用）+ run 横断推移データ（JSON 出力）
  annotate    所見・注記 1 件追記（トップレベル annotations リストへ append-only。
              実行結果 runs / results / latest には一切影響しない）

exit code:
  0   正常終了
  1   一般エラー（引数値の実行時検証エラー・確定済み run への操作・ファイル不在・
      スキーマ不整合・YAML/JSON 解析失敗）
  2   バリデーションエラー（fail の defect 3 点セット欠落・必須フィールド欠落・
      completed 確定不能・start-run の未承認 draft scope（--allow-draft なし）・
      validate の violations 検出。欠落フィールドは stderr に出力）
  3   ロック競合（test-results.yaml.lock が既に存在）
  64  引数パースエラー（サブコマンド不明・オプション名の typo・choices 外の値等の
      argparse 構文エラー、および annotate の --text 空。EXIT_VALIDATION=2 と
      区別するため EX_USAGE 相当の 64 を使う）
"""

import sys

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")
if hasattr(sys.stdin, "reconfigure"):
    sys.stdin.reconfigure(encoding="utf-8")

import argparse
import json
import os
import re
import time
from datetime import datetime

try:
    import yaml
except ImportError:
    print(
        "[ERROR] PyYAML がインストールされていません。"
        "venv を setup_venv.sh で構築し、venv の python で実行してください。",
        file=sys.stderr,
    )
    sys.exit(1)

# テストレベル定数の共有モジュール（<plugin>/references/scripts/lib/levels.py）を import する。
# 本ファイル（skills/test/references/scripts/results/）からプラグインルート直下の
# references/scripts/lib/ までの相対深度は 5 階層（../ を 5 個）。
sys.path.insert(
    0,
    os.path.normpath(
        os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "..", "..", "..", "..", "..", "references", "scripts", "lib",
        )
    ),
)
from levels import CASE_ID_PATTERN, ID_PREFIX_TO_LEVEL, LEVEL_ORDER  # noqa: E402

EXIT_OK = 0
EXIT_ERROR = 1
EXIT_VALIDATION = 2
EXIT_LOCKED = 3
EXIT_USAGE = 64  # 引数パースエラー（argparse 既定の 2 は EXIT_VALIDATION と衝突するため分離）

SCHEMA_VERSION = 1
RESULT_STATUS = ("pass", "fail", "blocked", "skipped", "na")
REASON_REQUIRED_STATUS = ("blocked", "skipped", "na")
ACTUAL_REQUIRED_STATUS = ("pass", "fail")
EXECUTED_BY = ("playwright-mcp", "playwright-test", "test-framework", "api", "human-assisted")
RUN_ACTIVE_STATUS = ("in_progress", "interrupted")
RUN_FINISH_STATUS = ("completed", "interrupted", "aborted")
MODES = ("full", "ng-only", "ids")
SEVERITIES = ("critical", "high", "medium", "low")
NG_STATUSES = ("fail", "blocked", "skipped")
# LEVEL_ORDER / ID_PREFIX_TO_LEVEL / CASE_ID_PATTERN はテストレベル定数の共有モジュール
# levels.py（コード SSOT。散文 SSOT は references/test-levels.md）から import している（上部参照）。
SLUG_PATTERN = re.compile(r"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$")
DEFAULT_TIMEOUT_SEC = 120


# ---------------------------------------------------------------------------
# 共通ユーティリティ
# ---------------------------------------------------------------------------

def err(msg):
    print(msg, file=sys.stderr)


def warn(msg):
    err(f"[WARN] {msg}")


def info(msg):
    err(f"[INFO] {msg}")


def die(msg, code=EXIT_ERROR):
    err(f"[ERROR] {msg}")
    sys.exit(code)


def print_json(obj):
    print(json.dumps(obj, ensure_ascii=False, indent=2))


def now_iso():
    return datetime.now().astimezone().isoformat(timespec="seconds")


def norm_path(path):
    """パス区切りをスラッシュに統一する（JSON・警告テキスト出力の表記揺れ防止）。

    Windows のファイル操作 API は "/" 区切りをそのまま受理するため動作には影響しない。
    """
    return str(path).replace(os.sep, "/")


def evidence_path_issue(rel):
    """エビデンス相対パス 1 件の安全性を検証し、問題があれば理由文字列を、無ければ None を返す。

    yaml-schema.md 2.1 の「相対パスは {target-slug}/ 直下基準」規約をコードで強制し、
    パストラバーサル（親ディレクトリ参照）・絶対パスによる target-slug 配下外への書き出し・
    参照を record 取り込み前に拒否する。実ファイルの有無には依存しない純粋な字句検査。
    """
    if not isinstance(rel, str) or not rel.strip():
        return "空のエビデンスパスは指定できません"
    s = rel.strip()
    # POSIX 絶対パス（/foo）・Windows 絶対/UNC（\\foo, //server）・先頭ドライブ指定（C:foo, C:/foo）を拒否
    if os.path.isabs(s) or re.match(r"^[A-Za-z]:", s):
        return "絶対パスは許可されません（{target-slug}/ 直下基準の相対パスで記述してください）"
    # 区切りを正規化し、各パス要素を検査する
    parts = re.split(r"[\\/]+", s)
    # 親ディレクトリ参照（..）を含むパスを拒否する
    if any(part == ".." for part in parts):
        return "親ディレクトリ参照（..）を含むパスは許可されません（{target-slug}/ 直下基準）"
    # 中間・末尾要素のドライブレター指定（例: sub/C:evil）を拒否する。
    # Windows の os.path.join は途中要素にドライブ指定があるとそれ以前の target_dir を破棄し、
    # drive-relative パスとして target-slug 配下の外へ逃げるため、先頭以外の要素も個別に検査する。
    for part in parts:
        if re.match(r"^[A-Za-z]:", part):
            return (
                "ドライブレター（C: 等）を含むパス要素は許可されません"
                "（{target-slug}/ 直下基準の相対パスで記述してください）"
            )
    return None


def resolve_paths(args):
    target = args.target
    if not SLUG_PATTERN.match(target):
        die(
            "target-slug が命名規約（kebab-case: 小文字英数字とハイフン）に一致しません: "
            f"{target}（規約は references/data-locations.md 参照）"
        )
    target_dir = os.path.join(args.base, target)
    # 出力（JSON・警告テキスト）に含まれるパスの区切りを統一するため、解決時点で正規化する
    return {
        "base": norm_path(args.base),
        "target": target,
        "target_dir": norm_path(target_dir),
        "results": norm_path(os.path.join(target_dir, "test-results.yaml")),
        "cases": norm_path(os.path.join(target_dir, "test-cases.yaml")),
        "evidence": norm_path(os.path.join(target_dir, "evidence")),
    }


class ResultsLock:
    """書き込み系サブコマンドの排他制御（.lock ファイル方式）。

    既存 lock がある場合は exit code 3 で終了する（別プロセス実行中の可能性）。
    プロセス異常終了で残留した lock は、実行中プロセスがないことを確認のうえ手動削除する。
    """

    def __init__(self, results_file):
        self.lock_path = results_file + ".lock"
        self.fd = None

    def __enter__(self):
        try:
            self.fd = os.open(self.lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            die(
                f"ロックファイルが存在します: {self.lock_path}\n"
                "別の results_manager.py が実行中の可能性があります。"
                "実行中でないことを確認できた場合のみ、手動で lock を削除して再実行してください。",
                EXIT_LOCKED,
            )
        except FileNotFoundError:
            # 対象ディレクトリ不在 = init 前の書き込み系サブコマンド実行（生トレースバックを出さない）
            die(
                f"対象ディレクトリが存在しません: {os.path.dirname(self.lock_path)}\n"
                "target-slug が未初期化です。init を先に実行してください。"
            )
        os.write(self.fd, f"pid={os.getpid()} at={now_iso()}\n".encode("utf-8"))
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.fd is not None:
            os.close(self.fd)
        try:
            os.unlink(self.lock_path)
        except OSError:
            warn(f"ロックファイルの削除に失敗しました: {self.lock_path}")
        return False


def load_yaml_file(path, desc):
    if not os.path.isfile(path):
        die(f"{desc} が見つかりません: {path}")
    # UnicodeDecodeError（非 UTF-8 バイト列）・OSError（読み取り失敗）・YAMLError（構文エラー）を
    # 生トレースバックにせず die() 経由の統一診断メッセージへ変換する
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
    except (yaml.YAMLError, UnicodeDecodeError, OSError) as e:
        die(f"{desc} の読み込み / YAML 解析に失敗しました（UTF-8 想定）: {path}\n{e}")
    if not isinstance(data, dict):
        die(f"{desc} のスキーマ不整合（トップレベルはマップ）: {path}")
    return data


def load_results(path):
    data = load_yaml_file(path, "test-results.yaml")
    meta = data.get("meta")
    if not isinstance(meta, dict):
        die(f"test-results.yaml のスキーマ不整合（meta がマップではありません）: {path}")
    if meta.get("schema_version") != SCHEMA_VERSION:
        die(
            f"test-results.yaml のスキーマ版数が不一致です（期待 {SCHEMA_VERSION} / "
            f"実際 {meta.get('schema_version')}）: {path}"
        )
    for key, typ in (("runs", list), ("results", list), ("latest", dict)):
        if data.get(key) is None:
            data[key] = typ()
        if not isinstance(data[key], typ):
            die(
                f"test-results.yaml のスキーマ不整合（{key} は "
                f"{'リスト' if typ is list else 'マップ'}）: {path}"
            )
    for i, run in enumerate(data["runs"]):
        if not isinstance(run, dict) or "run_id" not in run:
            die(f"test-results.yaml のスキーマ不整合（runs[{i}] に run_id がありません）: {path}")
    for i, res in enumerate(data["results"]):
        if not isinstance(res, dict) or "case_id" not in res or "run_id" not in res:
            die(
                f"test-results.yaml のスキーマ不整合（results[{i}] に case_id / run_id が"
                f"ありません）: {path}"
            )
    # annotations は任意のトップレベルキー（annotate サブコマンドが追記する所見・注記）。
    # 存在する場合のみリスト型を検証する（要素単位の構造検証は validate が担当）
    annotations = data.get("annotations")
    if annotations is not None and not isinstance(annotations, list):
        die(f"test-results.yaml のスキーマ不整合（annotations はリスト）: {path}")
    return data


def load_cases(path):
    data = load_yaml_file(path, "test-cases.yaml")
    meta = data.get("meta")
    if not isinstance(meta, dict) or meta.get("schema_version") != SCHEMA_VERSION:
        die(f"test-cases.yaml のスキーマ不整合（meta.schema_version={SCHEMA_VERSION} 必須）: {path}")
    cases = data.get("cases")
    if cases is None:
        cases = []
    if not isinstance(cases, list) or not all(isinstance(c, dict) for c in cases):
        die(f"test-cases.yaml のスキーマ不整合（cases はマップのリスト）: {path}")
    ids = [c.get("id") for c in cases]
    # id 欠落（None / 空文字）の明示チェック（黙殺すると select / summary の集計から漏れる）
    missing_id_indexes = [
        i for i, cid in enumerate(ids)
        if cid is None or (isinstance(cid, str) and not cid.strip())
    ]
    if missing_id_indexes:
        die(
            "test-cases.yaml に id が欠落（None / 空文字）したケースがあります"
            f"（cases のインデックス: {missing_id_indexes}）: {path}"
        )
    dups = sorted({i for i in ids if i is not None and ids.count(i) > 1})
    if dups:
        die(f"test-cases.yaml に重複したケース ID があります: {dups}")
    # destructive（任意・既定 false）の正規化。承認ゲートが機械集計する破壊的操作フラグであり、
    # 非真偽値は false 扱いとして警告する（型を厳密化して下流の集計を安定させる）
    for c in cases:
        dv = c.get("destructive")
        if dv is None:
            c["destructive"] = False
        elif not isinstance(dv, bool):
            warn(f"destructive が真偽値ではないため false として扱います（id={c.get('id')}）: {dv!r}")
            c["destructive"] = False
        # level enum 検証: levels.py の LEVEL_ORDER（8 値）以外の level は過去互換のため die せず
        # 警告し、値は保持する。未知レベルは集計・ソート・報告書のレベル別分類から静かに脱落する
        # ため、検出して呼び出し側（オーケストレータ・validate）へ surfacing する。
        lv = c.get("level")
        if lv is not None and lv not in LEVEL_ORDER:
            warn(
                "level が既知のテストレベル以外です"
                f"（保持しますが集計・分類から外れる可能性があります。id={c.get('id')}）: {lv!r}"
            )
    data["cases"] = cases
    return data


def save_results(path, data):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        yaml.safe_dump(
            data, f, allow_unicode=True, sort_keys=False, default_flow_style=False, width=120
        )
    os.replace(tmp, path)


def find_run(data, run_id):
    for run in data["runs"]:
        if run.get("run_id") == run_id:
            return run
    return None


def run_scope(run):
    scope = run.get("scope")
    return list(scope) if isinstance(scope, list) else []


def results_of_run(data, run_id):
    return [r for r in data["results"] if r.get("run_id") == run_id]


def level_of_case(case):
    return case.get("level")


def level_sort_key(case_id, level):
    idx = LEVEL_ORDER.index(level) if level in LEVEL_ORDER else len(LEVEL_ORDER)
    return (idx, case_id)


def level_from_case_id(case_id):
    m = CASE_ID_PATTERN.match(str(case_id))
    if m:
        return ID_PREFIX_TO_LEVEL.get(m.group(1))
    return None


# ---------------------------------------------------------------------------
# fail 時の一次バリデーション（defect 3 点セット）
# ---------------------------------------------------------------------------

def _non_empty_str_list(value):
    return (
        isinstance(value, list)
        and len(value) > 0
        and all(isinstance(s, str) and s.strip() for s in value)
    )


def check_fail_requirements(result):
    """fail 結果の必須要件（defect 3 点セット等）の欠落フィールドリストを返す。

    要件の SSOT は references/evidence-policy.md 1 章（3 点セット）および
    references/yaml-schema-results.md 4 章（defect サブオブジェクト）。
    """
    missing = []
    if not _non_empty_str_list(result.get("evidence")):
        missing.append("evidence（fail 時は結果本体にも 1 件以上必須）")
    defect = result.get("defect")
    if not isinstance(defect, dict) or not defect:
        missing.append("defect（fail 時必須: severity / reproduction_steps / test_data / evidence）")
        return missing
    if defect.get("severity") not in SEVERITIES:
        missing.append(f"defect.severity（{' / '.join(SEVERITIES)} のいずれか）")
    if not _non_empty_str_list(defect.get("reproduction_steps")):
        missing.append("defect.reproduction_steps（環境情報を含む再現手順リスト・空不可）")
    test_data = defect.get("test_data")
    if not ((isinstance(test_data, str) and test_data.strip()) or (isinstance(test_data, dict) and test_data)):
        missing.append("defect.test_data（入力値・期待値・実際値）")
    if not _non_empty_str_list(defect.get("evidence")):
        missing.append("defect.evidence（エビデンス相対パス 1 件以上）")
    else:
        # 各エビデンスパス要素の安全性検証（絶対パス・パストラバーサルの拒否）
        for p in defect.get("evidence"):
            issue = evidence_path_issue(p)
            if issue is not None:
                missing.append(f"defect.evidence のパスが不正です: {p}（{issue}）")
    return missing


# ---------------------------------------------------------------------------
# init
# ---------------------------------------------------------------------------

def cmd_init(args):
    paths = resolve_paths(args)
    os.makedirs(paths["target_dir"], exist_ok=True)
    os.makedirs(paths["evidence"], exist_ok=True)
    created = False
    with ResultsLock(paths["results"]):
        if os.path.isfile(paths["results"]):
            load_results(paths["results"])  # 既存ファイルのスキーマ検証のみ
            info(f"test-results.yaml は既に存在します（再初期化しません）: {paths['results']}")
        else:
            skeleton = {
                "meta": {"target": paths["target"], "schema_version": SCHEMA_VERSION},
                "runs": [],
                "results": [],
                "latest": {},
            }
            save_results(paths["results"], skeleton)
            created = True
    print_json(
        {
            "ok": True,
            "created": created,
            "target_dir": paths["target_dir"],
            "results_file": paths["results"],
            "evidence_dir": paths["evidence"],
        }
    )


# ---------------------------------------------------------------------------
# start-run
# ---------------------------------------------------------------------------

def parse_csv(value, opt_name):
    items = [s.strip() for s in str(value).split(",")]
    items = [s for s in items if s]
    if not items:
        die(f"{opt_name} に有効な値がありません: {value}")
    seen = set()
    uniq = []
    for s in items:
        if s not in seen:
            seen.add(s)
            uniq.append(s)
    return uniq


def cmd_start_run(args):
    paths = resolve_paths(args)
    scope = parse_csv(args.scope, "--scope")
    environment = args.environment.strip()
    if not environment:
        die("--environment が空です（OS・ブラウザ・対象 URL/ビルド等を記載してください）")

    with ResultsLock(paths["results"]):
        data = load_results(paths["results"])

        active = [r["run_id"] for r in data["runs"] if r.get("status") in RUN_ACTIVE_STATUS]
        if active:
            warn(
                f"未完了の run が存在します: {active}\n"
                "  中断からの継続は resume（新規 run を作らない）が正です。"
                "再開しない run はユーザー確認のうえ finish-run --status aborted で整理してください"
                "（references/retest-policy.md 6 章）。"
            )

        if os.path.isfile(paths["cases"]):
            cases_data = load_cases(paths["cases"])
            case_map = {c.get("id"): c for c in cases_data["cases"]}
            unknown = [cid for cid in scope if cid not in case_map]
            if unknown:
                warn(f"scope に test-cases.yaml 未定義のケース ID が含まれています: {unknown}")
            deprecated = [
                cid for cid in scope if cid in case_map and case_map[cid].get("deprecated") is True
            ]
            if deprecated:
                warn(f"scope に deprecated ケースが含まれています（select の抽出漏れの疑い）: {deprecated}")
            draft = [
                cid
                for cid in scope
                if cid in case_map and case_map[cid].get("review_status") != "approved"
            ]
            if draft:
                # 承認済みケースゲートの機械的強制。未承認（draft）ケースを scope に含む start-run は
                # 既定で拒否（exit 2）し、未実行の run レコードを残さない。意図的に draft を含める
                # 場合のみ --allow-draft で [WARN] に緩和する（承認ゲートは references/retest-policy.md 4 章）。
                if args.allow_draft:
                    warn(
                        "scope に未承認（draft）ケースが含まれています"
                        f"（--allow-draft 指定のため続行します）: {draft}"
                    )
                else:
                    die(
                        "scope に未承認（draft）ケースが含まれています"
                        f"（承認済みケースゲート未通過のため run を開始できません）: {draft}\n"
                        "  既定では approved 化済みケースのみ実行できます。test-review（設計文脈）で "
                        "approved 化してから再実行するか、意図的に draft を含める場合は "
                        "--allow-draft を付与してください（references/retest-policy.md 4 章）。",
                        EXIT_VALIDATION,
                    )
        else:
            warn(f"test-cases.yaml が見つからないため scope の照合を省略しました: {paths['cases']}")

        existing_ids = {r.get("run_id") for r in data["runs"]}
        run_id = None
        for attempt in range(3):
            candidate = datetime.now().strftime("R%Y%m%d-%H%M%S")
            if candidate not in existing_ids:
                run_id = candidate
                break
            time.sleep(1)
        if run_id is None:
            die("run_id の採番に失敗しました（同一秒での重複が解消できません）")

        data["runs"].append(
            {
                "run_id": run_id,
                "executed_at": now_iso(),
                "finished_at": None,
                "status": "in_progress",
                "mode": args.mode,
                "scope": scope,
                "environment": environment,
            }
        )
        save_results(paths["results"], data)

    info(f"run を開始しました: {run_id}（mode={args.mode} / scope {len(scope)} 件）")
    # 非対話オーケストレータが stderr の警告を見落とさないよう、検出済みの未完了 run
    # （in_progress / interrupted）の run_id リストを active_runs_warning として JSON にも明示する
    # （非検出時は空リスト）。run_id 取得側は本 JSON の run_id フィールドを参照する。
    print_json(
        {
            "ok": True,
            "run_id": run_id,
            "mode": args.mode,
            "scope_size": len(scope),
            "active_runs_warning": active,
        }
    )


# ---------------------------------------------------------------------------
# record
# ---------------------------------------------------------------------------

def read_result_json(source):
    # 標準入力・ファイルの読み取りで発生する UnicodeDecodeError（不正 UTF-8）・OSError を
    # 生トレースバックにせず die() 経由の統一診断メッセージへ変換する
    if source == "-":
        try:
            raw = sys.stdin.read()
        except (UnicodeDecodeError, OSError) as e:
            die(f"--result-json（標準入力）の読み込みに失敗しました（UTF-8 想定）: {e}")
    else:
        if not os.path.isfile(source):
            die(f"--result-json のファイルが見つかりません: {source}")
        try:
            with open(source, "r", encoding="utf-8") as f:
                raw = f.read()
        except (UnicodeDecodeError, OSError) as e:
            die(f"--result-json の読み込みに失敗しました（UTF-8 想定）: {source}\n{e}")
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as e:
        die(f"--result-json を JSON として解析できません: {e}")
    if isinstance(payload, dict) and "case_id" in payload:
        return payload
    if isinstance(payload, dict) and isinstance(payload.get("results"), list):
        results = payload["results"]
        if len(results) == 1 and isinstance(results[0], dict):
            info("中間結果ラッパー形式（results 配列 1 件）を検出したため要素を取り出しました。")
            return results[0]
        die(
            "record は 1 件ずつ記録します。中間結果 JSON の results 配列から要素を 1 件ずつ"
            "取り出して渡してください（フォーマットは references/execution-policy.md 4 章）。"
        )
    die("--result-json の形式が不正です（case_id を含む結果オブジェクトを渡してください）")
    return None  # 到達しない


def validate_record_payload(payload, run, existing_results):
    """record 入力の検証。エラーメッセージのリストと正規化済みエントリを返す。"""
    errors = []
    entry = {}

    case_id = payload.get("case_id")
    if not isinstance(case_id, str) or not case_id.strip():
        errors.append("case_id（必須・文字列）")
        case_id = None
    else:
        case_id = case_id.strip()
        scope = run_scope(run)
        if case_id not in scope:
            errors.append(f"case_id が run の scope に含まれていません: {case_id}（scope={scope}）")
        for r in existing_results:
            if r.get("case_id") == case_id and r.get("run_id") == run.get("run_id"):
                errors.append(
                    f"同一 run に {case_id} の結果が既に記録されています"
                    "（append-only のため上書き不可。再テストは新規 run で行ってください）"
                )
                break

    case_revision = payload.get("case_revision")
    if isinstance(case_revision, bool) or not isinstance(case_revision, int) or case_revision < 1:
        errors.append("case_revision（必須・1 以上の整数）")

    status = payload.get("status")
    if status not in RESULT_STATUS:
        errors.append(f"status（{' / '.join(RESULT_STATUS)} のいずれか）")

    executed_by = payload.get("executed_by")
    if executed_by not in EXECUTED_BY:
        errors.append(f"executed_by（{' / '.join(EXECUTED_BY)} のいずれか）")

    reason = payload.get("reason")
    if status in REASON_REQUIRED_STATUS:
        if not isinstance(reason, str) or not reason.strip():
            errors.append(f"reason（status={status} の場合は必須）")

    actual = payload.get("actual")
    if status in ACTUAL_REQUIRED_STATUS:
        if not isinstance(actual, str) or not actual.strip():
            errors.append(f"actual（status={status} の場合は必須）")

    duration_sec = payload.get("duration_sec")
    if duration_sec is not None:
        if isinstance(duration_sec, bool) or not isinstance(duration_sec, (int, float)) or duration_sec < 0:
            errors.append("duration_sec（数値・0 以上）")

    evidence = payload.get("evidence")
    if evidence is None:
        evidence = []
    if not isinstance(evidence, list) or not all(isinstance(p, str) and p.strip() for p in evidence):
        errors.append("evidence（相対パス文字列のリスト）")
        evidence = []
    else:
        # 各エビデンスパス要素の安全性検証（絶対パス・パストラバーサルの拒否）
        for p in evidence:
            issue = evidence_path_issue(p)
            if issue is not None:
                errors.append(f"evidence のパスが不正です: {p}（{issue}）")

    defect = payload.get("defect")
    if status != "fail" and defect:
        errors.append("defect は status=fail の場合のみ指定できます")

    payload_run_id = payload.get("run_id")
    if payload_run_id is not None and payload_run_id != run.get("run_id"):
        errors.append(
            f"JSON 内の run_id（{payload_run_id}）が --run-id（{run.get('run_id')}）と一致しません"
        )

    # 正規化エントリの構築（キー順はスキーマの記載順）
    entry["case_id"] = case_id
    entry["case_revision"] = case_revision
    entry["run_id"] = run.get("run_id")
    entry["status"] = status
    if isinstance(reason, str) and reason.strip():
        entry["reason"] = reason.strip()
    entry["executed_by"] = executed_by
    if duration_sec is not None:
        # 型・範囲の不正は上の検証で errors に積まれ、errors ありの場合は entry ごと破棄される
        entry["duration_sec"] = duration_sec
    if isinstance(actual, str) and actual.strip():
        entry["actual"] = actual.strip()
    # 結果自体に付随する構造化情報（status を問わず任意の map。空・非 dict は記録しない）
    extras = payload.get("extras")
    if isinstance(extras, dict) and extras:
        entry["extras"] = extras
    if evidence:
        entry["evidence"] = evidence

    if status == "fail":
        if isinstance(defect, dict) and defect:
            normalized_defect = {
                "severity": defect.get("severity"),
                "reproduction_steps": defect.get("reproduction_steps"),
                "test_data": defect.get("test_data"),
                "evidence": defect.get("evidence"),
            }
            extras = defect.get("extras")
            if isinstance(extras, dict) and extras:
                normalized_defect["extras"] = extras
            entry["defect"] = normalized_defect
        # fail 必須要件（defect 3 点セット + 結果本体 evidence）の一次バリデーション
        fail_missing = check_fail_requirements(
            {"evidence": evidence, "defect": entry.get("defect")}
        )
        errors.extend(fail_missing)

    known_keys = {
        "case_id", "case_revision", "run_id", "status", "reason", "executed_by",
        "duration_sec", "actual", "extras", "evidence", "defect", "skill",
    }
    unknown_keys = [k for k in payload.keys() if k not in known_keys]
    if unknown_keys:
        warn(f"未知のフィールドは記録しません: {unknown_keys}")

    return errors, entry


def cmd_record(args):
    paths = resolve_paths(args)
    payload = read_result_json(args.result_json)

    with ResultsLock(paths["results"]):
        data = load_results(paths["results"])
        run = find_run(data, args.run_id)
        if run is None:
            die(f"run が見つかりません: {args.run_id}（start-run を先に実行してください）")
        if run.get("status") not in RUN_ACTIVE_STATUS:
            die(
                f"run {args.run_id} は確定済み（status={run.get('status')}）のため記録できません。"
                "再テストは新規 run（start-run）で行ってください。"
            )

        errors, entry = validate_record_payload(payload, run, data["results"])
        if errors:
            err(
                "[VALIDATION] record を確定できません（test-results.yaml は変更していません）。"
                "欠落・不正フィールド:"
            )
            for e in errors:
                err(f"  - {e}")
            if entry.get("status") == "fail":
                err(
                    "  → fail の必須 3 点セット（reproduction_steps / test_data / evidence）は"
                    " references/evidence-policy.md 1 章参照。実行スキルに追加取得を指示してください。"
                )
            sys.exit(EXIT_VALIDATION)

        data["results"].append(entry)

        latest = data["latest"]
        prev = latest.get(entry["case_id"])
        latest_updated = False
        if not isinstance(prev, dict) or str(prev.get("run_id") or "") <= entry["run_id"]:
            latest[entry["case_id"]] = {
                "status": entry["status"],
                "run_id": entry["run_id"],
                "case_revision": entry["case_revision"],
            }
            latest_updated = True

        save_results(paths["results"], data)

        recorded_ids = {r.get("case_id") for r in results_of_run(data, args.run_id)}
        remaining = [cid for cid in run_scope(run) if cid not in recorded_ids]

    print_json(
        {
            "ok": True,
            "run_id": args.run_id,
            "case_id": entry["case_id"],
            "status": entry["status"],
            "latest_updated": latest_updated,
            "recorded": len(recorded_ids),
            "scope_size": len(run_scope(run)),
            "remaining": remaining,
        }
    )


# ---------------------------------------------------------------------------
# finish-run
# ---------------------------------------------------------------------------

def cmd_finish_run(args):
    paths = resolve_paths(args)
    with ResultsLock(paths["results"]):
        data = load_results(paths["results"])
        run = find_run(data, args.run_id)
        if run is None:
            die(f"run が見つかりません: {args.run_id}")
        if run.get("status") not in RUN_ACTIVE_STATUS:
            # 確定済み run への操作は record 側と統一して一般エラー（EXIT_ERROR=1）で返す
            # （EXIT_VALIDATION=2 は docstring の定義どおり記録内容のバリデーションエラー専用）
            die(f"run {args.run_id} は既に確定済みです（status={run.get('status')}）。")

        scope = run_scope(run)
        recorded_ids = [r.get("case_id") for r in results_of_run(data, args.run_id)]
        recorded_set = set(recorded_ids)
        missing = [cid for cid in scope if cid not in recorded_set]
        extra = sorted(recorded_set - set(scope))
        if extra:
            warn(f"scope 外の結果が記録されています（整合性要確認）: {extra}")

        if args.status is not None:
            status = args.status
            if status == "completed" and missing:
                err("[VALIDATION] scope に未記録のケースがあるため completed にできません:")
                for cid in missing:
                    err(f"  - {cid}")
                err("  → 未記録ケースを record するか、--status interrupted / aborted を指定してください。")
                sys.exit(EXIT_VALIDATION)
        else:
            status = "completed" if not missing else "interrupted"

        run["status"] = status
        run["finished_at"] = now_iso()
        save_results(paths["results"], data)

    if missing:
        info(f"scope の未記録ケースを検出しました（{len(missing)} 件）。resume の対象です。")
    print_json(
        {
            "ok": True,
            "run_id": args.run_id,
            "status": status,
            "scope_size": len(scope),
            "recorded": len(recorded_set & set(scope)),
            "missing": missing,
        }
    )


# ---------------------------------------------------------------------------
# select
# ---------------------------------------------------------------------------

def cmd_select(args):
    paths = resolve_paths(args)
    cases_data = load_cases(paths["cases"])
    cases = cases_data["cases"]
    case_map = {c.get("id"): c for c in cases}

    warnings = []
    if os.path.isfile(paths["results"]):
        latest = load_results(paths["results"])["latest"]
    else:
        latest = {}
        warnings.append(
            f"test-results.yaml が未初期化のため全ケースを未実行として扱います: {paths['results']}"
        )

    if args.mode == "ids" and not args.ids:
        die("--mode ids では --ids <case_id,...> の指定が必須です")
    if args.mode != "ids" and args.ids:
        warn(f"--ids は --mode ids でのみ使用します（無視しました）: {args.ids}")

    selected = []
    excluded_deprecated = []
    unknown_ids = []

    def latest_status(case_id):
        e = latest.get(case_id)
        return e.get("status") if isinstance(e, dict) else None

    if args.mode in ("full", "ng-only"):
        for case in cases:
            cid = case.get("id")
            if cid is None:
                continue
            if case.get("deprecated") is True:
                excluded_deprecated.append(cid)
                continue
            st = latest_status(cid)
            if args.mode == "full":
                # full: na（対象外判定）を除く全ケース（未実行含む）
                if st == "na":
                    continue
                selected.append(cid)
            else:
                # ng-only: fail / blocked / skipped + 未実行（新規追加ケース）
                if st in NG_STATUSES or st is None:
                    selected.append(cid)
    else:  # ids
        for cid in parse_csv(args.ids, "--ids"):
            case = case_map.get(cid)
            if case is None:
                unknown_ids.append(cid)
                warnings.append(f"test-cases.yaml に存在しないケース ID を除外しました: {cid}")
                continue
            if case.get("deprecated") is True:
                excluded_deprecated.append(cid)
                warnings.append(
                    f"deprecated ケースはモードに関わらず対象外のため除外しました: {cid}"
                    "（references/retest-policy.md 2 章）"
                )
                continue
            st = latest_status(cid)
            if st == "na":
                warnings.append(
                    f"{cid} の最新 status は na（対象外判定）です。対象外判定そのものの再確認の"
                    "意図がある場合のみ実行してください。"
                )
            selected.append(cid)

    if excluded_deprecated and args.mode in ("full", "ng-only"):
        warnings.append(f"deprecated ケースを対象外にしました: {excluded_deprecated}")

    approved_cases = []
    draft_cases = []
    details = {}
    for cid in selected:
        case = case_map[cid]
        review_status = case.get("review_status")
        if review_status == "approved":
            approved_cases.append(cid)
        else:
            draft_cases.append(cid)
            if review_status != "draft":
                warnings.append(
                    f"{cid} の review_status が不明値（{review_status}）のため draft として扱います。"
                )
        latest_entry = latest.get(cid) if isinstance(latest.get(cid), dict) else None
        latest_case_revision = latest_entry.get("case_revision") if latest_entry else None
        current_revision = case.get("revision")
        # 実績記録時点の revision と現行 revision の不一致 = 実行後にケースが改訂されている
        # （ng-only の fail 起点の再テストで、改訂内容の再承認漏れを検知する）
        if (
            latest_case_revision is not None
            and current_revision is not None
            and latest_case_revision != current_revision
        ):
            warnings.append(
                f"ケース {cid} は改訂されています（実績 rev{latest_case_revision} / "
                f"現行 rev{current_revision}）。review_status を確認してください"
            )
        details[cid] = {
            "level": case.get("level"),
            "title": case.get("title"),
            "priority": case.get("priority"),
            "automation": case.get("automation"),
            "timeout_sec": case.get("timeout_sec", DEFAULT_TIMEOUT_SEC),
            "revision": current_revision,
            "review_status": review_status,
            # destructive: 破壊的操作ケースか（既定 false）。人間承認ゲートが機械集計する
            "destructive": bool(case.get("destructive", False)),
            "latest_status": latest_status(cid),
            "latest_run_id": latest_entry.get("run_id") if latest_entry else None,
            "latest_case_revision": latest_case_revision,
        }

    def sort_key(cid):
        return level_sort_key(cid, details[cid]["level"])

    approved_cases.sort(key=sort_key)
    draft_cases.sort(key=sort_key)

    if draft_cases:
        warnings.append(
            "draft_cases は承認済みケースゲートの対象です。実行前に test-review（設計文脈）の"
            "PASS による approved 化が必要です（references/retest-policy.md 4 章）。"
        )

    print_json(
        {
            "mode": args.mode,
            "cases": approved_cases,
            "draft_cases": draft_cases,
            "excluded_deprecated": excluded_deprecated,
            "unknown_ids": unknown_ids,
            "warnings": warnings,
            "details": details,
        }
    )


# ---------------------------------------------------------------------------
# validate
# ---------------------------------------------------------------------------

def evidence_file_violations(paths, result, defect_only=False):
    """エビデンス相対パスの安全性 + 実在チェック。問題のあるパスのリストを返す。

    以下のいずれかに該当するパスを violation として報告する（yaml-schema.md 2.1 の
    「相対パスは {target-slug}/ 直下基準」規約をコードで強制する）:
    - 絶対パス要素（target_dir が破棄される）・親ディレクトリ参照（..）を含むパス
    - 正規化後に target_dir（{target-slug}/）配下から外れるパス（パストラバーサル）
    - 上記に該当しないが実ファイルが存在しないパス
    """
    issues = []
    targets = []
    if not defect_only:
        targets.extend(result.get("evidence") or [])
    defect = result.get("defect")
    if isinstance(defect, dict):
        targets.extend(defect.get("evidence") or [])
    target_abs = os.path.abspath(paths["target_dir"])
    for rel in targets:
        if not isinstance(rel, str) or not rel.strip():
            continue
        rel_s = rel.strip()
        # 絶対パス・.. を含むパスは os.path.join で target_dir が破棄される危険があるため先に拒否
        if evidence_path_issue(rel_s) is not None:
            issues.append(rel)
            continue
        candidate = os.path.abspath(os.path.join(target_abs, *re.split(r"[\\/]+", rel_s)))
        # 正規化後に target_dir 配下へ収まることを commonpath で確認（二重防御）
        try:
            inside = os.path.commonpath([target_abs, candidate]) == target_abs
        except ValueError:
            # ドライブが異なる等で共通パスを取得できない = 配下外
            inside = False
        if not inside or not os.path.isfile(candidate):
            issues.append(rel)
    # 重複除去（結果本体と defect で同一パスを共有する場合）
    seen = set()
    uniq = []
    for p in issues:
        if p not in seen:
            seen.add(p)
            uniq.append(p)
    return uniq


def cmd_validate(args):
    paths = resolve_paths(args)
    data = load_results(paths["results"])
    violations = []
    warnings = []

    case_map = {}
    if os.path.isfile(paths["cases"]):
        case_map = {c.get("id"): c for c in load_cases(paths["cases"])["cases"]}
        # level enum 整合性検査: LEVEL_ORDER（8 値）以外の level を持つケースを構造化警告として
        # surfacing する（load_cases も stderr 警告するが、validate の warnings は
        # オーケストレータが機械的に読む経路のため見落とし防止として二重に出す）。
        unknown_level = sorted(
            f"{cid}={case.get('level')!r}"
            for cid, case in case_map.items()
            if case.get("level") is not None and case.get("level") not in LEVEL_ORDER
        )
        if unknown_level:
            warnings.append(
                "既知のテストレベル（levels.py の LEVEL_ORDER）以外の level を持つケースがあります"
                f"（集計・分類から外れる可能性があります）: {unknown_level}"
            )
    else:
        warnings.append(
            f"test-cases.yaml が見つからないためケース定義との照合を省略しました: {paths['cases']}"
        )

    if args.run_id is not None:
        run = find_run(data, args.run_id)
        if run is None:
            die(f"run が見つかりません: {args.run_id}")
        runs = [run]
        results = results_of_run(data, args.run_id)
    else:
        runs = data["runs"]
        results = data["results"]

    known_run_ids = {r.get("run_id") for r in data["runs"]}

    # 1) fail の defect 3 点セット + エビデンス実在チェック
    for res in results:
        rid = res.get("run_id")
        cid = res.get("case_id")
        if res.get("status") == "fail":
            missing_fields = check_fail_requirements(res)
            if missing_fields:
                violations.append(
                    {
                        "type": "fail_defect_missing",
                        "run_id": rid,
                        "case_id": cid,
                        "detail": missing_fields,
                    }
                )
            missing_files = evidence_file_violations(paths, res)
            if missing_files:
                violations.append(
                    {
                        "type": "evidence_file_missing",
                        "run_id": rid,
                        "case_id": cid,
                        "detail": missing_files,
                    }
                )
        elif res.get("status") in REASON_REQUIRED_STATUS:
            reason = res.get("reason")
            if not isinstance(reason, str) or not reason.strip():
                violations.append(
                    {
                        "type": "reason_missing",
                        "run_id": rid,
                        "case_id": cid,
                        "detail": [f"status={res.get('status')} に reason がありません"],
                    }
                )
        if rid not in known_run_ids:
            violations.append(
                {
                    "type": "orphan_result",
                    "run_id": rid,
                    "case_id": cid,
                    "detail": ["runs に存在しない run_id を参照しています"],
                }
            )
        # extras（結果直下 / defect 配下）は存在する場合マップであること（yaml-schema-results.md）
        extras = res.get("extras")
        if extras is not None and not isinstance(extras, dict):
            violations.append(
                {
                    "type": "extras_invalid",
                    "run_id": rid,
                    "case_id": cid,
                    "detail": ["results[].extras はマップ（dict）である必要があります"],
                }
            )
        defect = res.get("defect")
        if isinstance(defect, dict):
            extras = defect.get("extras")
            if extras is not None and not isinstance(extras, dict):
                violations.append(
                    {
                        "type": "extras_invalid",
                        "run_id": rid,
                        "case_id": cid,
                        "detail": ["defect.extras はマップ（dict）である必要があります"],
                    }
                )

    # 2) run ごとの scope vs results 突合 + resume 用の構造化出力（resumable_runs）
    resumable_runs = []
    for run in runs:
        rid = run.get("run_id")
        scope = run_scope(run)
        recorded = [r.get("case_id") for r in results_of_run(data, rid)]
        recorded_set = set(recorded)
        missing = [cid for cid in scope if cid not in recorded_set]
        extra = sorted(recorded_set - set(scope))
        dup = sorted({cid for cid in recorded if recorded.count(cid) > 1})
        status = run.get("status")
        if status == "completed" and missing:
            violations.append(
                {
                    "type": "scope_results_mismatch",
                    "run_id": rid,
                    "case_id": None,
                    "detail": [f"completed なのに未記録ケースがあります: {missing}"],
                }
            )
        elif status in RUN_ACTIVE_STATUS:
            warnings.append(
                f"run {rid} は {status} です（未記録 {len(missing)} 件）。resume の対象です。"
            )
            # 副作用なしで resume scope（未記録 case_id リスト）を取得できる構造化データ
            resumable_runs.append({"run_id": rid, "status": status, "missing": missing})
        if extra:
            violations.append(
                {
                    "type": "extra_result",
                    "run_id": rid,
                    "case_id": None,
                    "detail": [f"scope 外の結果が記録されています: {extra}"],
                }
            )
        if dup:
            violations.append(
                {
                    "type": "duplicate_result",
                    "run_id": rid,
                    "case_id": None,
                    "detail": [f"同一 run に重複記録があります: {dup}"],
                }
            )

    # 3) 全体チェック（--run-id 指定なしの場合のみ）
    if args.run_id is None:
        expected_latest = {}
        for res in data["results"]:
            cid = res.get("case_id")
            rid = str(res.get("run_id") or "")
            prev = expected_latest.get(cid)
            if prev is None or str(prev.get("run_id") or "") <= rid:
                expected_latest[cid] = {
                    "status": res.get("status"),
                    "run_id": res.get("run_id"),
                    "case_revision": res.get("case_revision"),
                }
        if expected_latest != data["latest"]:
            diff_ids = sorted(
                {
                    cid
                    for cid in set(expected_latest) | set(data["latest"])
                    if expected_latest.get(cid) != data["latest"].get(cid)
                }
            )
            violations.append(
                {
                    "type": "latest_mismatch",
                    "run_id": None,
                    "case_id": None,
                    "detail": [f"latest が results から再計算した値と一致しません: {diff_ids}"],
                }
            )
        if case_map:
            for cid, entry in data["latest"].items():
                case = case_map.get(cid)
                if case is None:
                    warnings.append(f"latest のケースが test-cases.yaml に存在しません: {cid}")
                    continue
                if (
                    isinstance(entry, dict)
                    and entry.get("status") == "pass"
                    and case.get("priority") == "high"
                ):
                    res = next(
                        (
                            r
                            for r in data["results"]
                            if r.get("case_id") == cid and r.get("run_id") == entry.get("run_id")
                        ),
                        None,
                    )
                    if res is not None:
                        if not res.get("evidence"):
                            warnings.append(
                                f"priority: high の pass ケースにエビデンスがありません: {cid}"
                                "（references/evidence-policy.md 6 章の警告対象）"
                            )
                        else:
                            # 記載パスの実在チェック（欠落は fail と異なり警告に留める）
                            missing_files = evidence_file_violations(paths, res)
                            if missing_files:
                                warnings.append(
                                    f"priority: high の pass ケースのエビデンスファイルが"
                                    f"実在しません: {cid} → {missing_files}"
                                )
        # 4) annotations の構造検証（所見・注記。スキーマは yaml-schema-results.md）
        for i, entry in enumerate(data.get("annotations") or []):
            if not isinstance(entry, dict):
                violations.append(
                    {
                        "type": "annotation_invalid",
                        "run_id": None,
                        "case_id": None,
                        "detail": [f"annotations[{i}] がマップではありません"],
                    }
                )
                continue
            problems = []
            text = entry.get("text")
            if not isinstance(text, str) or not text.strip():
                problems.append("text（必須・空でない文字列）")
            for key in ("case_id", "run_id"):
                value = entry.get(key)
                if value is not None and (not isinstance(value, str) or not value.strip()):
                    problems.append(f"{key}（null または空でない文字列）")
            source = entry.get("source")
            if not isinstance(source, str) or not source.strip():
                problems.append("source（必須・空でない文字列）")
            if problems:
                violations.append(
                    {
                        "type": "annotation_invalid",
                        "run_id": entry.get("run_id") if isinstance(entry.get("run_id"), str) else None,
                        "case_id": entry.get("case_id") if isinstance(entry.get("case_id"), str) else None,
                        "detail": [f"annotations[{i}]: {p}" for p in problems],
                    }
                )
                continue
            if entry.get("case_id") and case_map and entry.get("case_id") not in case_map:
                warnings.append(
                    f"annotations[{i}] の case_id が test-cases.yaml に存在しません: {entry.get('case_id')}"
                )
            if entry.get("run_id") and entry.get("run_id") not in known_run_ids:
                warnings.append(
                    f"annotations[{i}] の run_id が runs に存在しません: {entry.get('run_id')}"
                )

    ok = len(violations) == 0
    print_json(
        {
            "ok": ok,
            "violations": violations,
            "warnings": warnings,
            "resumable_runs": resumable_runs,
        }
    )
    if not ok:
        err(f"[VALIDATION] violations {len(violations)} 件を検出しました（詳細は stdout の JSON）。")
        sys.exit(EXIT_VALIDATION)


# ---------------------------------------------------------------------------
# summary
# ---------------------------------------------------------------------------

def cmd_summary(args):
    paths = resolve_paths(args)
    data = load_results(paths["results"])
    warnings = []

    cases = []
    if os.path.isfile(paths["cases"]):
        cases = load_cases(paths["cases"])["cases"]
    else:
        warnings.append(
            "test-cases.yaml が見つからないため、latest のケース ID プレフィクスから"
            "レベルを推定して集計しました。"
        )

    status_keys = list(RESULT_STATUS)

    def new_bucket():
        bucket = {"total": 0}
        for s in status_keys:
            bucket[s] = 0
        bucket["not_run"] = 0
        return bucket

    levels = {}
    deprecated_cases = []

    def bucket_for(level):
        key = level if level in LEVEL_ORDER else "unknown"
        if key not in levels:
            levels[key] = new_bucket()
        return levels[key]

    counted_ids = set()
    if cases:
        for case in cases:
            cid = case.get("id")
            if cid is None:
                continue
            if case.get("deprecated") is True:
                deprecated_cases.append(cid)
                continue
            counted_ids.add(cid)
            bucket = bucket_for(case.get("level"))
            bucket["total"] += 1
            entry = data["latest"].get(cid)
            st = entry.get("status") if isinstance(entry, dict) else None
            if st in status_keys:
                bucket[st] += 1
            else:
                bucket["not_run"] += 1
    # ケース定義がない（または定義外の）latest エントリの補完集計
    for cid, entry in data["latest"].items():
        if cid in counted_ids or cid in deprecated_cases:
            continue
        if cases:
            warnings.append(f"test-cases.yaml に存在しないケースの実績を unknown として集計しました: {cid}")
            level = None
        else:
            level = level_from_case_id(cid)
        bucket = bucket_for(level)
        bucket["total"] += 1
        st = entry.get("status") if isinstance(entry, dict) else None
        if st in status_keys:
            bucket[st] += 1
        else:
            bucket["not_run"] += 1

    ordered_levels = {}
    for lv in list(LEVEL_ORDER) + ["unknown"]:
        if lv in levels:
            ordered_levels[lv] = levels[lv]

    totals = new_bucket()
    for bucket in ordered_levels.values():
        for k in totals:
            totals[k] += bucket[k]

    runs_trend = []
    for run in sorted(data["runs"], key=lambda r: str(r.get("run_id") or "")):
        rid = run.get("run_id")
        counts = {s: 0 for s in status_keys}
        recorded = 0
        for res in results_of_run(data, rid):
            recorded += 1
            st = res.get("status")
            if st in counts:
                counts[st] += 1
        runs_trend.append(
            {
                "run_id": rid,
                "executed_at": run.get("executed_at"),
                "finished_at": run.get("finished_at"),
                "status": run.get("status"),
                "mode": run.get("mode"),
                "environment": run.get("environment"),
                "scope_size": len(run_scope(run)),
                "recorded": recorded,
                "counts": counts,
            }
        )

    case_title = {c.get("id"): c.get("title") for c in cases}
    latest_fails = []
    for cid, entry in sorted(data["latest"].items()):
        if not isinstance(entry, dict) or entry.get("status") != "fail":
            continue
        res = next(
            (
                r
                for r in data["results"]
                if r.get("case_id") == cid and r.get("run_id") == entry.get("run_id")
            ),
            None,
        )
        defect = res.get("defect") if isinstance(res, dict) else None
        latest_fails.append(
            {
                "case_id": cid,
                "title": case_title.get(cid),
                "run_id": entry.get("run_id"),
                "case_revision": entry.get("case_revision"),
                "severity": defect.get("severity") if isinstance(defect, dict) else None,
            }
        )

    print_json(
        {
            "target": data["meta"].get("target"),
            "generated_at": now_iso(),
            "levels": ordered_levels,
            "totals": totals,
            "deprecated_case_count": len(deprecated_cases),
            "runs": runs_trend,
            "latest_fails": latest_fails,
            "warnings": warnings,
        }
    )


# ---------------------------------------------------------------------------
# annotate
# ---------------------------------------------------------------------------

def read_annotation_text(text_opt, text_file_opt):
    """annotate の注釈本文を取得する（record の --result-json と同方式で長文入力に対応）。

    - --text <本文>       : 引数に本文を直接指定
    - --text -            : 標準入力から本文を読む
    - --text-file <path>  : ファイルから本文を読む（- で標準入力）

    --text と --text-file の同時指定はエラー（exit 64）。読み取り失敗（不正 UTF-8・OSError）は
    die() 経由の統一診断メッセージへ変換する。空文字判定は呼び出し元（cmd_annotate）が行う。
    """
    if text_opt is not None and text_file_opt is not None:
        die("--text と --text-file は同時に指定できません", EXIT_USAGE)
    if text_file_opt is not None:
        if text_file_opt == "-":
            try:
                return sys.stdin.read()
            except (UnicodeDecodeError, OSError) as e:
                die(f"--text-file（標準入力）の読み込みに失敗しました（UTF-8 想定）: {e}")
        if not os.path.isfile(text_file_opt):
            die(f"--text-file が見つかりません: {text_file_opt}")
        try:
            with open(text_file_opt, "r", encoding="utf-8") as f:
                return f.read()
        except (UnicodeDecodeError, OSError) as e:
            die(f"--text-file の読み込みに失敗しました（UTF-8 想定）: {text_file_opt}\n{e}")
    if text_opt is not None:
        if text_opt == "-":
            try:
                return sys.stdin.read()
            except (UnicodeDecodeError, OSError) as e:
                die(f"--text（標準入力）の読み込みに失敗しました（UTF-8 想定）: {e}")
        return text_opt
    die("--text または --text-file を指定してください", EXIT_USAGE)
    return None  # die() で終了するため到達しない


def cmd_annotate(args):
    """所見・注記 1 件をトップレベル annotations リストへ追記する（append-only）。

    レビュー所見（test-review）・テスト計画由来の未確認事項などを報告書へ機械的に
    反映するための経路。実行結果（runs / results / latest）には一切影響しない。
    レコード構造の SSOT は references/yaml-schema-results.md（annotations セクション）。
    """
    paths = resolve_paths(args)
    text = read_annotation_text(args.text, args.text_file).strip()
    if not text:
        die("注釈本文が空です（--text / --text-file の内容を指定してください）", EXIT_USAGE)
    source = (args.source or "").strip() or "orchestrator"
    case_id = (args.case_id or "").strip() or None
    run_id = (args.run_id or "").strip() or None

    # case_id の実在検証（不在は警告のみで追記は許可: 柔軟性優先）
    if case_id is not None:
        if os.path.isfile(paths["cases"]):
            case_ids = {c.get("id") for c in load_cases(paths["cases"])["cases"]}
            if case_id not in case_ids:
                warn(
                    f"--case-id が test-cases.yaml に存在しません（注釈は追記します）: {case_id}"
                )
        else:
            warn(f"test-cases.yaml が見つからないため --case-id の照合を省略しました: {paths['cases']}")

    with ResultsLock(paths["results"]):
        data = load_results(paths["results"])
        if run_id is not None and find_run(data, run_id) is None:
            warn(f"--run-id が runs に存在しません（注釈は追記します）: {run_id}")
        annotations = data.get("annotations")
        if annotations is None:
            annotations = []
            data["annotations"] = annotations
        entry = {
            "case_id": case_id,
            "run_id": run_id,
            "source": source,
            "text": text,
        }
        annotations.append(entry)
        save_results(paths["results"], data)
        total = len(annotations)

    info(f"所見・注記を追記しました（計 {total} 件）: source={source}")
    print_json(
        {
            "ok": True,
            "results_file": paths["results"],
            "annotation": entry,
            "annotations_count": total,
        }
    )


# ---------------------------------------------------------------------------
# エントリポイント
# ---------------------------------------------------------------------------

class UsageErrorParser(argparse.ArgumentParser):
    """引数パースエラーを exit code 64 で終了させる ArgumentParser。

    argparse 既定のパースエラーは exit code 2 だが、本スクリプトでは 2 を
    EXIT_VALIDATION（バリデーションエラー）に割り当てているため衝突する。
    引数の構文エラーは EXIT_USAGE=64（sysexits.h の EX_USAGE 相当）に分離する。
    add_subparsers() が生成するサブコマンドパーサも既定で親と同じクラスになるため、
    サブコマンド側のパースエラーも本クラスの error() で処理される。
    """

    def error(self, message):
        self.print_usage(sys.stderr)
        err(f"[ERROR] 引数が不正です: {message}")
        sys.exit(EXIT_USAGE)


def build_parser():
    parser = UsageErrorParser(
        prog="results_manager.py",
        description=(
            "deep-test 実績 YAML（test-results.yaml）操作スクリプト"
            "（書き込みは test オーケストレータ経由。test-report は validate / summary を読み取り実行）"
        ),
    )
    sub = parser.add_subparsers(dest="command", required=True)

    def add_common(sp):
        sp.add_argument("--base", required=True, help="基準ディレクトリ（.claude/.local/plugins/deep-test）")
        sp.add_argument("--target", required=True, help="target-slug（kebab-case）")

    sp = sub.add_parser("init", help="{base}/{target}/ の初期化（test-results.yaml 骨格生成）")
    add_common(sp)
    sp.set_defaults(func=cmd_init)

    sp = sub.add_parser("start-run", help="run 開始記録（run_id 採番。stdout に JSON（run_id 含む）を出力）")
    add_common(sp)
    sp.add_argument("--mode", required=True, choices=MODES, help="実行モード")
    sp.add_argument("--scope", required=True, help="対象ケース ID の CSV（例: TC-FUNC-001,TC-FUNC-002）")
    sp.add_argument("--environment", required=True, help="実行環境情報（OS・ブラウザ・対象 URL/ビルド）")
    sp.add_argument(
        "--allow-draft",
        action="store_true",
        help="未承認（draft）ケースを scope に含めることを許可する（既定は exit 2 で拒否）",
    )
    sp.set_defaults(func=cmd_start_run)

    sp = sub.add_parser("record", help="ケース結果 1 件追記 + latest 更新（JSON 入力）")
    add_common(sp)
    sp.add_argument("--run-id", required=True, help="対象 run_id（start-run の出力）")
    sp.add_argument("--result-json", required=True, help="結果 JSON のパス（- で stdin）")
    sp.set_defaults(func=cmd_record)

    sp = sub.add_parser("finish-run", help="run 完了記録（scope と results の突合・status 確定）")
    add_common(sp)
    sp.add_argument("--run-id", required=True, help="対象 run_id")
    sp.add_argument(
        "--status",
        choices=RUN_FINISH_STATUS,
        default=None,
        help="確定 status（省略時: 欠落なし=completed / 欠落あり=interrupted）",
    )
    sp.set_defaults(func=cmd_finish_run)

    sp = sub.add_parser("select", help="再テスト対象抽出（retest-policy.md マトリクス準拠。JSON 出力）")
    add_common(sp)
    sp.add_argument("--mode", required=True, choices=MODES, help="抽出モード")
    sp.add_argument("--ids", default=None, help="--mode ids のときの対象ケース ID CSV")
    sp.set_defaults(func=cmd_select)

    sp = sub.add_parser("validate", help="整合性チェック（fail 3 点セット・エビデンス実在・scope 突合）")
    add_common(sp)
    sp.add_argument("--run-id", default=None, help="指定 run に限定して検証（省略時は全体）")
    sp.set_defaults(func=cmd_validate)

    sp = sub.add_parser("summary", help="レベル別集計（latest 採用）+ run 横断推移（JSON 出力）")
    add_common(sp)
    sp.set_defaults(func=cmd_summary)

    sp = sub.add_parser(
        "annotate",
        help="所見・注記 1 件追記（annotations へ append-only。実行結果には影響しない）",
    )
    add_common(sp)
    sp.add_argument(
        "--text",
        default=None,
        help="注釈本文（'-' で標準入力。空は exit 64。--text-file と排他）",
    )
    sp.add_argument(
        "--text-file",
        default=None,
        help="注釈本文をファイルから読む（'-' で標準入力。長文向け。--text と排他）",
    )
    sp.add_argument(
        "--case-id", default=None, help="対象ケース ID（任意。test-cases.yaml に不在なら警告のみ）"
    )
    sp.add_argument("--run-id", default=None, help="対象 run_id（任意）")
    sp.add_argument(
        "--source",
        default="orchestrator",
        help="注釈の出所（既定 orchestrator。例: test-review/design / test-review/results / test-plan）",
    )
    sp.set_defaults(func=cmd_annotate)

    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    args.func(args)
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
