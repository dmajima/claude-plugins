# case-01 フルソース解析（source_availability full・全材料生成 → source-analyst 自己チェック）

リポジトリソースを全面的に取得できるケース。source_availability=full での全解析（アーキ / 依存 / EP / 複雑度 × churn / テスタビリティ / リスク / 攻撃面 / 品質特性）→ analysis.yaml / target-analysis.md 生成 → source-analyst 自己チェック → 返却の一連の流れを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | 「このリポジトリのテスト対象を解析して。カレントがリポジトリルート」 |
| 起動形態 | 単独（ユーザー直接起動・対話） |
| 前提 | 対象リポジトリに画面・API 実装と外部 IF が存在 / 複雑度計測ツール（radon / lizard 等）は未導入 / `spec=` `diff=` 指定なし / 既存 slug なし |

## 分岐の根拠

SKILL.md「実行フロー」1〜6 および「実行モード判定」（対話）、references/procedures.md 2 章（target-slug 確定）・3 章（source_availability 判定）・4 章（full 時の解析 4.1〜4.10）・6 章（生成）・7 章（source-analyst 自己チェック）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-analysis.md` 2〜12 章（代表スキーマ・各セクションの ID 形式 / enum）・16 章（縮退の full 定義）、同 `data-locations.md` 1 章（基準ディレクトリ）・4 章（新規 slug 解決）、同 `agents.md` 4.3 章（共通注入事項）。

## 期待動作

- target-slug を data-locations.md 4 章で解決する（既存なし → 対話で新規 slug 名を確認して作成。基準ディレクトリは同 1 章でリポジトリ配下の `.claude/.local/plugins/deep-test/` に解決）
- リポジトリを Read / Glob / Grep で静的に解析する（read-only。稼働アプリへの能動プローブをしない）。ビルド定義・ディレクトリ構成から `source_availability: full` と判定し、判定根拠を target-analysis.md 冒頭に明記する
- 責務 1〜12 を材料化する: architecture（languages / frameworks / layers / build_run）・entry_points（`EP-{3桁}`・kind / exposure / auth / source_ref）・dependency_summary・hotspots（`HS-{3桁}`）・existing_tests_summary・testability_findings（`TF-{3桁}`）・risk_register（`RISK-{3桁}`）・attack_surface_summary（STRIDE）・coverage_viewpoints・品質特性（ISO 25010:2023）
- churn は Bash の git 読み取り（`git log --format= --name-only ...`）で取得し、複雑度計測ツールが無いため `cyclomatic_complexity: null` + `measured: false` とする（捏造しない）
- 対象種別を `meta.target_type`（web-app 等）へ判定する
- risk_register は likelihood × impact で risk_level を算出し、`suggested_focus` を `level_hint` / `technique_hint` の **提案のみ**に留める（レベル / 技法 / 優先度 / ケースを確定しない = 決定は test-design）
- `spec=` `diff=` 未指定のため `spec_divergence` / `change_impact` を出力しない
- `{target-slug}/analysis.yaml`（yaml-schema-analysis.md 準拠・meta 必須フィールド）と `{target-slug}/target-analysis.md`（procedures.md 6.2 章の章立て・依存グラフは mermaid）を Write で生成する
- Agent ツールで `deep-test:source-analyst` を **単独起動**する（プロンプトに解決済み絶対パスと agents.md 4.3 章の共通注入事項ブロックを含める。並列起動しない）
- source-analyst の重大指摘を材料へ反映してから返却する（エージェントに材料を修正させない）
- test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない（材料 2 ファイルのみ生成）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{target-slug}/analysis.yaml`（`meta.source_availability: full`・EP / HS / TF / RISK 各 ID 形式・複雑度は `measured: false` + `null`）・`{target-slug}/target-analysis.md`（判定根拠 + 依存グラフ mermaid + EP 一覧 + ホットスポット + リスク / 品質特性 + 攻撃面 + カバレッジ観点）。spec_divergence / change_impact は出力しない。test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない |
| 標準出力（要約） | SKILL.md「引き渡し」の解析結果サマリ（対象種別・source_availability: full・entry_points / hotspots / risk_register / testability_findings の件数表・source-analyst 所見・open_questions・「analysis.yaml を材料に test-design がレベル / 技法 / 優先度 / ケースを決定する」） |
| 終了状態 | source-analyst 自己チェック（重大指摘反映）後に材料 2 ファイルを生成して返却。決定は行わず提案（hint）に留め、次フェーズ（test-design）へ |

## 関連ケース

- case-02: `spec=` 指定ありで spec_divergence を追加する分岐
- case-03: `diff=` 指定ありで change_impact を追加する分岐
- case-04: source_availability=none の縮退（コード解析スキップ）
- case-05: 非対話・委譲での自動進行
