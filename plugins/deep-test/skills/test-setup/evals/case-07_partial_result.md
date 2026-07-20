# case-07 venv 構築失敗 + MCP 利用可の混在 → 総合判定 PARTIAL

一部チェックが失敗（venv 構築失敗）しつつ他は利用可（MCP ロード済み）という混在状態で、総合判定 PARTIAL を返し、影響範囲（実行可能なレベル・不可なレベル）を明示することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=<slug> base=<base> levels=functional,unit`（フルチェック） |
| 起動形態 | 委譲（オーケストレータ test の setup フェーズ） |
| 前提 | Playwright MCP は登録済み + ロード済み（`loaded`）/ テストランナー（pytest）検出可 / セッション作業領域の `workspace/.venv` 構築が失敗する（setup スクリプト実行エラー等） |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/setup-procedures.md` 5 章（venv 構築失敗は `failed`・構築を偽装しない）・6.2 章（総合判定: 停止不要だがいずれかの項目が `failed` / `none` → PARTIAL）・7 章（引き継ぎ事項に利用不可項目と後続影響を記載）、SKILL.md「検証」（venv の構築失敗を ready と偽装していない）・「引き渡し」（総合判定 READY / RESTART_REQUIRED / PARTIAL）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（利用不可項目に対応するケースは実行時 skipped 見込み）。

## 期待動作

- MCP ロード判定（ToolSearch）= `loaded`、テストランナー = `detected`、venv = `failed`（構築失敗の理由を詳細欄に記録し `ready` と偽装しない。setup-procedures.md 5 章）
- 停止（RESTART_REQUIRED）には該当しないが、venv が `failed` のため**総合判定を PARTIAL** とする（setup-procedures.md 6.2）
- 影響範囲を引き継ぎ事項に明示する:
  - MCP 利用可のためブラウザ依存レベル（functional 等）は実行可能な見込み
  - venv 失敗によりオーケストレータの実績管理（results_manager.py）・報告書生成（test-report）が実行不能となる旨（venv の用途は setup-procedures.md 5 章）
- チェック項目表の 4 項目すべてに状態を付与する（`not-checked` 含め行を省略しない）
- 続行可否の最終判断はオーケストレータに委ねる（PARTIAL の後続の扱い。setup-procedures.md 6.2）
- test-results.yaml への書き込み・編集を行わない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（venv 構築が失敗。MCP 新規登録もない）。詳細欄に venv 失敗理由を記録 |
| 標準出力（要約） | 環境検証レポート（総合判定 = PARTIAL、MCP ロード = loaded、ランナー = detected、venv = failed）+ 影響範囲の引き継ぎ事項 |
| 終了状態 | PARTIAL で返却（停止せず）。実行可能レベル・不可レベルを明示し続行可否をオーケストレータに委ねる |

## 関連ケース

- case-02: 全項目利用可の READY（本ケースの正常系）
- case-01 / case-03: RESTART_REQUIRED（停止を伴う総合判定との対比）
- case-06: 複数登録の曖昧解消（同じく環境検証レポートを返す分岐）
