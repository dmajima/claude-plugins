# case-11 非対話 + Playwright 必要レベルあり + 未登録 → 登録せず not-registered（PARTIAL）

非対話モードで Playwright 必要レベル（functional）を scope に含むが Playwright MCP が未登録の場合に、新規登録という永続的副作用を勝手に作らず `not-registered` を記録し、総合判定 PARTIAL とすることを検証する。該当レベルが実行時に skipped となる見込みを引き継ぎ事項に報告する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=<slug> base=<base> levels=functional,unit --non-interactive` |
| 起動形態 | 委譲（オーケストレータ test の setup フェーズ・非対話） |
| 前提 | `claude mcp list` に playwright 系サーバーの登録が 1 件もない / pytest が検出可能 / venv 構築成功 |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/setup-procedures.md` 3.2 章（登録要否の判断分岐 c: Playwright 必要レベルを含む + 非対話 → 登録しない・`not-registered`・「Playwright 必要レベルは実行時に skipped になる」旨を引き継ぎ事項に報告・永続的副作用を非対話で勝手に作らない）・6.2 章（総合判定: Playwright 必要レベルを含むのに `not-registered`〔3.2 章 c〕 → PARTIAL）・7 章（引き継ぎ事項に利用不可項目と後続影響を記載）、SKILL.md「実行モード判定」の非対話行（未登録時の新規登録は行わず `not-registered` とする。永続的副作用を非対話で作らない）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 1.4 章（unit 以外の 7 レベルは MCP 必要 = functional は Playwright 必要レベル）・2 章（利用不可項目に対応するケースは実行時 skipped 見込み）。

## 期待動作

- `claude mcp list` で既存登録なしを確認する
- levels に functional（Playwright 必要レベル。execution-policy.md 1.4 章）を含むが、**非対話モードのため新規登録を行わない**（規約コマンドを実行しない。永続的副作用を勝手に作らない。setup-procedures.md 3.2 章 c）
- 登録状態を `not-registered` とし、詳細欄に理由（非対話モードのため登録を見送り）を記録する
- 登録が存在しないためロード状態は判定不能 → `not-checked`（ToolSearch 判定へ進まない）
- 残りのチェック（ランナー・venv）は継続して完了させる: pytest = `detected`（根拠ファイル・実行コマンド例併記）、venv = `created`
- 総合判定: `newly-registered` / `not-loaded` に該当せず RESTART_REQUIRED ではなく、Playwright 必要レベルを含むのに `not-registered` のため **PARTIAL** とする（setup-procedures.md 6.2 章）
- 影響範囲を引き継ぎ事項に明示する: functional レベルは MCP 未登録のため run 前の MCP ゲートで停止、または実行時 skipped 見込み / unit レベルはランナー検出済みのため実行可能見込み
- 再起動ハンドオフは出力しない（新規登録も未ロード検知もないため。RESTART_REQUIRED ではない）
- 続行可否の最終判断はオーケストレータに委ねる（PARTIAL の後続の扱い。setup-procedures.md 6.2 章）
- test-results.yaml への書き込み・編集を行わない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | venv（構築成功分・created）のみ。Playwright MCP は未登録でも登録しない。test-results.yaml へは書き込まない |
| 標準出力（要約） | 環境検証レポート（総合判定 = PARTIAL、登録 = not-registered〔非対話のため見送り・理由を詳細欄に記録〕、ロード = not-checked、ランナー = detected〔pytest〕、venv = created）+ 影響範囲（functional は skipped 見込み・unit は実行可能見込み）の引き継ぎ事項 |
| 終了状態 | PARTIAL で返却（停止・ハンドオフなし）。AskUserQuestion を発行しない |

## 関連ケース

- case-12: 同じ未登録 + Playwright 必要レベルの対話版（AskUserQuestion で登録を確認し否認 → not-registered）
- case-05: `levels=unit` のみで Playwright チェック対象外 → not-checked（READY を妨げない側。not-registered との違い）
- case-01: 未登録から新規登録を実施して RESTART_REQUIRED となる側（登録実施の有無で総合判定が分かれる）
- case-08: 登録試行が失敗して failed となる側（not-registered〔見送り〕との違い）
