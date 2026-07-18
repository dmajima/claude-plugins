# case-08 MCP 新規登録失敗 + ランナー未検出の複合 → PARTIAL

Playwright MCP の新規登録コマンド自体が失敗（再試行 1 回も失敗 → `failed`）し、テストランナーも未検出（`none`）という複合状態で、総合判定 PARTIAL と影響範囲の明示を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=<slug> base=<base> levels=unit,functional`（playwright / runner / venv すべてチェック対象） |
| 起動形態 | 委譲（オーケストレータ test の setup フェーズ） |
| 前提 | `claude mcp list` に playwright 系の既存登録なし。規約コマンドによる新規登録がコマンドエラーで失敗し、再試行 1 回も失敗する。対象プロジェクトにテストランナーの検出根拠（設定ファイル・依存）が存在しない。venv は構築成功する |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/setup-procedures.md` 3.2（新規登録: 登録失敗〔コマンドエラー〕は `failed`・エラー内容を詳細欄に記録・リトライは 1 回まで）・4 章（ランナー `none`: unit レベルのケースは実行時に skipped となる見込みを引き継ぎ事項に記録）・6.1（ロード状態 `not-checked` = 登録なしで判定不能）・6.2（総合判定: `RESTART_REQUIRED` は newly-registered / not-loaded のみ。停止は不要だがいずれかの項目が `failed` / `none` → **PARTIAL**）・7 章（引き継ぎ事項: 利用不可項目と後続影響）・8 章（登録コマンドが失敗する → エラー出力を詳細欄に記録し failed とする。1 回だけ再試行してよい。規約コマンドの改変による回避はしない）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（条件付き動的検証: 利用不可項目に対応するケースは skipped + reason）。

## 期待動作

- 規約コマンド（playwright-mcp.md 1 章）をそのまま実行し、失敗を確認したら**再試行は 1 回まで**とする（それ以上のリトライ・規約コマンドの改変〔オプション削除等〕による回避をしない）
- 再試行も失敗したら登録状態を `failed` とし、エラー出力を詳細欄に記録する（登録成功を偽装しない）
- 登録が存在しないためロード状態は判定不能 → `not-checked` とする（ToolSearch 判定へ進まない）
- 登録失敗が判明しても残りのチェック（ランナー・venv）を**継続して完了させる**（途中で投げ出さない）
- テストランナーは検出表のいずれにも該当せず `none`（検出のみ行い、ランナーを実行しない）。venv は `created`（または `ready`）
- 総合判定: `newly-registered` / `not-loaded` に該当しないため RESTART_REQUIRED ではなく、`failed` と `none` を含むため **PARTIAL** とする（setup-procedures.md 6.2）
- 影響範囲を引き継ぎ事項に明示する: MCP 登録失敗により Playwright 必要レベル（functional 等）の実行が不能見込み（run 前の MCP ゲートで停止、または実行時 skipped）/ ランナー未検出により unit レベルのケースは実行時に skipped となる見込み / venv は利用可のため実績管理・報告書生成は可能
- 続行可否の最終判断はオーケストレータに委ねる（本スキルで run の中止を決めない）
- 再起動ハンドオフは出力しない（再起動で解消する状態ではない）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | venv（構築成功分）のみ。MCP 登録は失敗のため登録追加なし。test-results.yaml へは書き込まない |
| 標準出力（要約） | 環境検証レポート（総合判定 = PARTIAL、登録 = failed〔エラー内容・再試行 1 回失敗を詳細欄に記録〕、ロード = not-checked、ランナー = none、venv = created）+ 影響範囲（functional 等は実行不能見込み・unit は skipped 見込み）の引き継ぎ事項 |
| 終了状態 | PARTIAL で返却（停止・ハンドオフなし）。続行可否はオーケストレータに委ねる |

## 関連ケース

- case-01: 新規登録が成功して RESTART_REQUIRED となる側（登録の成否で総合判定が分かれる）
- case-07: venv 失敗 + MCP 利用可という別の組み合わせの PARTIAL
- case-04: ランナーが検出できる場合の返却形式（none との対比）
