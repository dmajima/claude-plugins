# orchestrator-coding スキル

対象リポジトリの言語・フレームワークを自動検出し、プロジェクト規約に準拠した実装を 6 フェーズ（指示受領 → 分析 → 設計 → 実装 → 自己レビュー → 報告）で統括する実装ワークフローのオーケストレーター。言語固有の知識は言語スキル（`coding-{lang}`）に委譲する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。

## 導入手順

本スキルは `coding` プラグインに同梱されています。プラグイン本体の導入手順（マーケットプレイス登録・インストール・自動更新）は [プラグイン README](../../README.md) を参照してください。本スキル単体での追加インストールは不要です。

導入後は下記「使い方」のトリガーフレーズ（「この機能を実装して」等）でユーザが直接起動できます。言語固有の知識を担う言語スキル（`coding-{lang}`）は本オーケストレーターから自動的に参照されます。

## 使い方

### トリガーフレーズ例

| 発話例 | 動作 |
|-------|------|
| 「この機能を実装して」 | 標準モード（全 6 フェーズ） |
| 「このバグを直して」（小規模） | クイックモード（分析と設計を統合） |
| 「○○を実装して --non-interactive」 | 非対話モード（確認なしで進行） |

### 入力 → 出力の流れ

1. タスク説明を受け取り、セッション作業領域 `.claude/.local/work/{yyyyMMdd_nn_summary}/` を作成
2. マーカーファイルから言語を検出し、言語スキル（`coding-csharp` 〜 `coding-sql`）を選択（SSOT: `references/skill-index.md`）
3. プロジェクト独自規約を走査し、言語スキルのデファクト規約と統合した「適用規約サマリ」を生成（SSOT: `references/conventions-resolution.md`）
4. 設計（SSOT: `references/design-principles.md`）→ 実装 → レビューエージェント並列レビュー → 報告書生成

## 動作例

```text
ユーザ: 「ユーザ一覧画面に検索フィルタを実装して」

→ Phase 1: タスク分解・確認（implementation-plan.md）
→ Phase 2: TypeScript + React を検出 → coding-typescript + SSOT frameworks/react.md を適用、
           .editorconfig と CLAUDE.md の規約を優先適用（impact-analysis.md）
→ Phase 3: 実装方針・変更ファイルリスト（implementation-design.md）
→ Phase 4: 規約準拠で実装、lint / 型チェック実行（file-list.md）
→ Phase 5: impl-reviewer + test-engineer 並列レビュー（self-review-result.md）
→ Phase 6: 報告書生成・機密チェック（implementation-report.md）
```

## カスタマイズ・拡張

| やりたいこと | 方法 |
|-------------|------|
| フェーズ手順の調整 | `references/workflow.md` を編集 |
| レビュー体制の変更 | `references/agents.md` を編集 |
| 新しい言語への対応 | プラグイン SSOT `../../references/language-skill-template.md` に従い言語スキルを追加 |
| 成果物形式の変更 | プラグイン SSOT `../../references/template/` を編集 |

## ファイル構成

```text
skills/orchestrator-coding/
├── SKILL.md                          # オーケストレーター定義
├── README.md                         # 本ファイル（人間向け）
├── references/
│   ├── workflow.md                   # 6 フェーズ詳細・品質ゲート・遡行規定
│   └── agents.md                     # エージェント運用定義
└── evals/                            # 動作分岐の期待挙動（12 ケース)
    ├── README.md
    └── case-01 〜 case-12
```

言語検出・規約解決・設計原則・成果物テンプレートはプラグイン直下 `references/`（SSOT）を参照する。
