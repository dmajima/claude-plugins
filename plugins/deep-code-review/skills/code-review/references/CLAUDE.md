# references/ 読み込みガイド

本ディレクトリは `code-review` オーケストレータースキルのリファレンスを業務単位で分類している。

## 読み込み優先度

| 優先度 | フォルダ | 読み込みタイミング | 内容 |
|--------|---------|-------------------|------|
| **必須** | `flow/` | スキル起動時に `flow.md`（索引）を最初に読み、必要な Step の詳細は `flow-steps-early/review/output.md` を辿る | 実行フロー（Step 0-P〜8.5）・モード選択・スコープ確定・Agent Teams |
| **必須** | `state/` | Step 0-P（事前準備）で読む | state.yaml 管理・inputs 管理・コード信頼性原則（U14） |
| **必須** | `output/` | Step 7-8（結果出力）で読む | 出力フォーマット・Verdict 判定・サマリーテンプレート |
| **必須** | `quality/` | Step 8 統合サマリ出力前に読む | 達成チェックリスト（U1-U16 + C1-C25） |

## フォルダ構成

```
references/
├── CLAUDE.md                          # 本ファイル（読み込みガイド）
├── flow/                              # 実行フロー（Step 0-P〜8.5）
│   ├── flow.md                        # メインフロー索引（最初に読む・300行分割）
│   ├── flow-steps-early.md            # Step 0-P〜3.5 詳細（準備〜動員決定）
│   ├── flow-steps-review.md           # Step 4〜7 詳細（レビュー実行・統合・判定）
│   ├── flow-steps-output.md           # Step 8〜8.5 詳細（出力・state・PR投稿）
│   ├── mode-selection.md              # Step 0: 標準/簡易モード選択
│   ├── scope-detection.md             # Step 1: スコープ確定・比較ブランチ自動判定
│   ├── team-selection.md              # Step 3.5-4T: Agent Teams 5パターン選定 索引
│   ├── team-selection-patterns.md     # 5パターン定義・早見表（詳細）
│   └── team-selection-flow.md         # 選定フロー・運用ルール（詳細）
├── state/                             # 状態管理
│   ├── state-management.md            # state.yaml の管理・読み書き手順
│   ├── inputs-management.md           # 仕様書・設計書（inputs フォルダ）の管理
│   └── code-trustworthiness.md        # コード信頼性原則（U14）
├── output/                            # 出力フォーマット
│   ├── output-format.md               # 出力フォーマット索引（Verdict・Finding ID・300行分割）
│   ├── output-format-details.md       # セクション1-2 出力構成・Finding ID 採番（詳細）
│   └── output-verdict.md              # セクション3-6 Verdict判定・未確認事項・出力例（詳細）
├── template/                          # テンプレート（skill-structure ルール 3 準拠・業務単位で細分化）
│   ├── output/
│   │   ├── review-summary.md          # 統合サマリ テンプレート索引（300行分割）
│   │   ├── review-summary-body-1.md   # セクション1-5 本体（詳細）
│   │   └── review-summary-body-2.md   # セクション6-9 本体（詳細）
│   └── state/
│       └── state_template.yaml        # state.yaml テンプレート
└── quality/                           # 達成チェック
    └── checklist.md                   # U1-U16 + C1-C25 達成チェックリスト
```

## ファイル間の参照ルール

- フォルダ内の相互参照: 相対パスで参照（例: `flow.md` から `mode-selection.md`）
- フォルダ間の参照: `${CLAUDE_SKILL_DIR}/references/<folder>/<file>` 形式
- プラグイン共通参照: `${CLAUDE_PLUGIN_ROOT}/references/<file>` 形式
