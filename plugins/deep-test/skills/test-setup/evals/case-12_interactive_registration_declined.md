# case-12 対話 + Playwright 必要レベルあり + 未登録 → AskUserQuestion で登録否認 → not-registered（PARTIAL）

対話モードで Playwright 必要レベル（functional）を scope に含むが Playwright MCP が未登録の場合に、AskUserQuestion で登録実施を確認し、ユーザーが否認したときに登録せず `not-registered` を記録して総合判定 PARTIAL とすることを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=<slug> base=<base> levels=functional`（対話・`--non-interactive` なし） |
| 起動形態 | 委譲（オーケストレータ test の setup フェーズ・対話） |
| 前提 | `claude mcp list` に playwright 系サーバーの登録が 1 件もない / pytest が検出可能 / venv 構築成功。AskUserQuestion に対しユーザーが登録を否認する |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/setup-procedures.md` 3.2 章（登録要否の判断分岐 b: Playwright 必要レベルを含む + 対話 → AskUserQuestion で登録実施を確認し、承認された場合のみ登録する。否認時は `not-registered` + 理由を詳細欄に記録する）・6.2 章（総合判定: Playwright 必要レベルを含むのに `not-registered`〔3.2 章 b 否認〕 → PARTIAL）・7 章（引き継ぎ事項に利用不可項目と後続影響を記載）、SKILL.md「実行モード判定」の対話行（曖昧な状況のみ AskUserQuestion で確認する）・「重要な制約」（未登録の Playwright MCP を判断分岐を経ずに新規登録しない）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 1.4 章（functional は Playwright 必要レベル）・2 章（利用不可項目に対応するケースは実行時 skipped 見込み）。

## 期待動作

- `claude mcp list` で既存登録なしを確認する
- levels に functional（Playwright 必要レベル）を含み、対話モードのため **AskUserQuestion で登録実施の可否を確認する**（登録という永続的副作用を判断分岐を経ずに作らない。setup-procedures.md 3.2 章 b）
- ユーザーが否認したため**登録を行わない**（規約コマンドを実行しない）
- 登録状態を `not-registered` とし、詳細欄に理由（ユーザーが登録を否認）を記録する
- 登録が存在しないためロード状態は判定不能 → `not-checked`（ToolSearch 判定へ進まない）
- 残りのチェック（ランナー・venv）は継続して完了させる: pytest = `detected`（根拠ファイル・実行コマンド例併記）、venv = `created`
- 総合判定: `newly-registered` / `not-loaded` に該当せず RESTART_REQUIRED ではなく、Playwright 必要レベルを含むのに `not-registered` のため **PARTIAL** とする（setup-procedures.md 6.2 章）
- 影響範囲を引き継ぎ事項に明示する: functional レベルは MCP 未登録のため run 前の MCP ゲートで停止、または実行時 skipped 見込み
- 再起動ハンドオフは出力しない（新規登録も未ロード検知もない）
- 続行可否の最終判断はオーケストレータに委ねる
- test-results.yaml への書き込み・編集を行わない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | venv（構築成功分・created）のみ。ユーザー否認のため Playwright MCP は登録しない。test-results.yaml へは書き込まない |
| 標準出力（要約） | 環境検証レポート（総合判定 = PARTIAL、登録 = not-registered〔ユーザー否認・理由を詳細欄に記録〕、ロード = not-checked、ランナー = detected〔pytest〕、venv = created）+ 影響範囲（functional は skipped 見込み）の引き継ぎ事項 |
| 終了状態 | PARTIAL で返却（停止・ハンドオフなし）。AskUserQuestion で登録を確認し、否認を受けて登録を見送り |

## 関連ケース

- case-11: 同じ未登録 + Playwright 必要レベルの非対話版（AskUserQuestion を発行せず登録を見送り → not-registered）
- case-01: AskUserQuestion で承認相当（ユーザーが明示的に Playwright 登録を要求）→ 新規登録 + RESTART_REQUIRED となる側
- case-06: 別の AskUserQuestion 分岐（複数登録の採用選択）との対比
