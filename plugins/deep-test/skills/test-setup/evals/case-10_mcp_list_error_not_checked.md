# case-10 `claude mcp list` 自体がエラー終了（claude CLI 未導入等）→ 登録状態 not-checked として続行

Playwright 必要レベルを含むためMCP チェック対象でありながら、`claude mcp list` の実行自体がエラー終了する（`claude` CLI 未導入・パス不通等）ケース。登録検出を確定できないため登録状態を `not-checked`（理由付き）とし、setup 全体を中断せずテストランナー検出・venv 確認へ続行することを検証する。scope 対象外による `not-checked`（case-05）とは要因が異なる。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=<slug> base=<base> levels=functional,unit`（playwright チェック対象を含む） |
| 起動形態 | 委譲（オーケストレータ test の setup フェーズ） |
| 前提 | `claude mcp list` を実行するとエラー終了する（`claude` CLI 未導入・実行パス不通・非ゼロ終了）。テストランナー（pytest）は検出可能。セッション作業領域の venv は構築可能 |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/setup-procedures.md` 8 章 トラブルシュート表（`claude mcp list` がエラーになる → `claude` CLI の導入状態を確認する。解消しない場合は登録状態を `not-checked` とし、理由を詳細欄に記録して**続行する**）・3.1 章（既存登録の検出は `claude mcp list` に依拠）・6.1 章（状態値: 登録 `not-checked` / ロード `not-checked`〔登録判定不能〕）・6.2 章（総合判定）・7 章（引き継ぎ事項に利用不可・未確認項目と後続影響を記載）、SKILL.md「重要な制約」（利用不可・未チェック項目を「利用可」「問題なし」と書かない。execution-policy.md 2 章）。

## 期待動作

- `claude mcp list` を実行し、エラー終了を検出する。**setup 全体を中断しない**（登録検出の失敗を致命エラーにしない）
- 登録状態を `not-registered` や `failed` と誤記せず、判定不能を表す **`not-checked`** とし、詳細欄に理由（`claude mcp list` がエラー・claude CLI の導入状態を要確認）を必ず記録する（setup-procedures.md 8 章）
- 登録を確定できないため ToolSearch によるロード判定（3.3 章の前提「登録済み時のみ」）も行えず、ロード状態も `not-checked`（判定不能）とする。存在しない登録に対して新規登録コマンドを実行しない
- テストランナー検出（4 章）・venv 確認（5 章）は `claude mcp list` の結果に依存しないため**継続実行**する（runner=detected、venv=ready / created）
- 総合判定は、Playwright 必要レベル（functional）を含むのに MCP 可否を確認できていないため **PARTIAL** とする（`newly-registered` / 確定した `not-loaded` を伴わないため RESTART_REQUIRED ではない）。続行可否の最終判断はオーケストレータに委ねる（6.2 章）
- 引き継ぎ事項に「MCP 可否は未確認（claude mcp list エラー）であり、実行前の MCP ゲート（ToolSearch 実判定）で再判定が必要・未ロードなら functional 等は skipped 見込み」を記載する（7 章・execution-policy.md 2 章）
- MCP を「利用可」「問題なし」と偽装しない
- test-results.yaml への書き込み・編集を行わない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | venv（未構築時は `created`。既存なら `ready`）。MCP 新規登録は行わないため登録関連の生成物なし |
| 標準出力（要約） | 環境検証レポート（総合判定 = PARTIAL、MCP 登録 = not-checked〔claude mcp list エラー・理由記録〕、MCP ロード = not-checked、ランナー = detected、venv = ready / created）+ MCP 未確認と MCP ゲート再判定の引き継ぎ事項 |
| 終了状態 | PARTIAL で返却（停止しない）。MCP 可否を未確認のまま runner / venv を完了し、続行可否をオーケストレータに委ねる |

## 関連ケース

- case-05: `levels=unit` のみで playwright を**対象外**として `not-checked` にする（本ケースは対象でありながら**検出手段エラー**で not-checked になる別要因）
- case-02: `claude mcp list` が正常で登録済み + ロード済み → READY（本ケースの正常系）
- case-07 / case-08: venv 失敗・登録失敗による PARTIAL（同じ総合判定 PARTIAL だが要因が failed / none）
