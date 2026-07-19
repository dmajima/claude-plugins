# case-05 analysis.yaml 欠落時の軽量補完（analysis_consumed: false・confidence を下げる・能動プローブしない）

`test-analyze` をスキップして fixture を単独起動したケース。材料 `analysis.yaml` が存在しないため、Read/Glob/Grep で認証入口・外部依存・テストディレクトリ構成を軽量に補完し、`analysis_consumed: false` と各 fixture の `confidence` 降格に反映することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | 「このアプリのフィクスチャ基盤を作って（解析はまだ）」 |
| 起動形態 | 単独（ユーザー直接起動・対話） |
| 前提 | `{base}/{target-slug}/analysis.yaml` が**存在しない** / SUT ソースは Read 可能（ログイン画面・外部 API 呼び出しがコード上に存在）/ 既存 Playwright 基盤なし |

## 分岐の根拠

SKILL.md「前提」（analysis.yaml が無ければ Read/Glob/Grep で軽量補完する）・「実行フロー」2（非存在時は 3.2 の軽量補完）・「重要な制約」（捏造禁止: 補完時は analysis_consumed: false と confidence を下げ推定を確定情報として書かない・能動プローブしない）、`${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` 3.2 章（未生成時の軽量補完・能動プローブ禁止・MCP 追加は既定しない）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` 1.1 章（`analysis_consumed: false` は軽量補完・confidence を下げる）。

## 期待動作

- `{base}/{target-slug}/analysis.yaml` の非存在を Read で確認する
- Read/Glob/Grep で認証入口（ログイン画面 / 認証ミドルウェア）・外部依存（外部 API 呼び出し）・既存テストディレクトリ構成を**静的に軽量補完**する（対象アプリへの能動プローブ＝実ログイン試行・実 HTTP アクセスはしない）
- 補完で得た所見をもとに認証 / モック / base のフィクスチャを生成するが、各 fixture の `confidence` を `medium` / `low` に下げる（材料の確からしさが低いため）
- `{base}/{target-slug}/fixtures.yaml` の `meta.analysis_consumed: false` を明示する（推定を確定情報として書かない・`source_refs` は確認できた範囲のみ・捏造しない）
- 実ログインフロー探索が要る場合でも既定では Playwright MCP を使わない（SKILL.md frontmatter への MCP 追加は行わない）
- `deep-test:fixture-architect` を単独起動し、補完由来の confidence 降格の妥当性・材料整合をレビューさせ、重大指摘を反映してから返却する
- test-results.yaml / test-cases.yaml へは書き込まない。analysis.yaml を**生成もしない**（一次解析は test-analyze の責務・逆生成しない）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{base}/{target-slug}/fixtures.yaml`（`meta.analysis_consumed: false`・各 fixture の confidence は medium/low）・SUT テストコード。analysis.yaml は生成しない。test-results.yaml / test-cases.yaml へは書き込まない |
| 標準出力（要約） | フィクスチャ構築結果サマリ（analysis_consumed: false・補完で得た材料の要約・confidence を下げた旨・fixture-architect 所見・「一次解析は test-analyze の責務」の注記） |
| 終了状態 | 軽量補完で下地を生成しつつ、材料の不確かさを analysis_consumed: false と confidence 降格で誠実に表現して返却。能動プローブはしない |

## 関連ケース

- case-01: analysis.yaml 消費あり（analysis_consumed: true・本ケースの対）
- case-03: 材料ありでの no-op 判定（本ケースは補完して有効判定する対比）
- case-06: 書き込み境界（analysis.yaml を生成しない・逆生成しないことも本ケースで確認）
