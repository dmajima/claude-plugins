# orchestrator-design スキル

実装を伴わない設計業務（設計書作成・実装方針の検討・技術選定の整理）を 4 フェーズ（指示受領 → 分析 → 設計 → 報告）で統括する設計ワークフローのオーケストレーター。設計観点・リスク・データフローは SSOT（`references/design-principles.md`）に、言語のコード構造は言語スキルに委譲する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。

## 導入手順

本スキルは `coding` プラグインに同梱されています。プラグイン本体の導入手順（マーケットプレイス登録・インストール・自動更新）は [プラグイン README](../../README.md) を参照してください。本スキル単体での追加インストールは不要です。

導入後は下記「使い方」のトリガーフレーズ（「この機能の設計をして」等）でユーザが直接起動できます。設計完了後に実装へ進む場合は `orchestrator-coding` へ引き継がれます。

## 使い方

### トリガーフレーズ例

| 発話例 | 動作 |
|-------|------|
| 「この機能の設計をして」 | 4 フェーズの設計ワークフロー |
| 「実装方針を検討して」 | 同上（代替案比較を含む） |
| 「設計して --non-interactive」 | 非対話モード |

### 入力 → 出力の流れ

1. 設計依頼を受け取り、設計ゴール（何を決めれば完了か）を明文化
2. 言語検出・規約解決・現状構造の把握（実装ワークフローと同じ SSOT を使用）
3. 設計原則（SSOT）+ 言語スキルのコード構造知識で設計書を作成、必要に応じて architect レビュー
4. 設計報告書（design-report.md）を生成し、実装への引き継ぎ事項を整理

## 動作例

```text
ユーザ: 「注文キャンセル機能の設計をして。実装はまだしない」

→ Phase 1: 設計ゴールの明文化（implementation-plan.md）
→ Phase 2: C# / ASP.NET Core を検出 → coding-csharp を参照（impact-analysis.md）
→ Phase 3: 設計書作成 + 代替案比較 + architect レビュー（implementation-design.md）
→ Phase 4: 設計報告（design-report.md）。実装に進む場合は orchestrator-coding へ引き継ぎ
```

## カスタマイズ・拡張

| やりたいこと | 方法 |
|-------------|------|
| フェーズ手順の調整 | `references/workflow.md` を編集 |
| 設計観点・リスク分類の変更 | プラグイン SSOT `../../references/design-principles.md` を編集 |
| 設計レビュー体制の変更 | `references/agents.md` を編集 |

## ファイル構成

```text
skills/orchestrator-design/
├── SKILL.md                          # オーケストレーター定義
├── README.md                         # 本ファイル（人間向け）
├── references/
│   ├── workflow.md                   # 4 フェーズ詳細・品質ゲート
│   └── agents.md                     # エージェント運用定義（architect）
└── evals/                            # 動作分岐の期待挙動（6 ケース)
    ├── README.md
    └── case-01 〜 case-06
```

言語検出・規約解決・設計原則・成果物テンプレートはプラグイン直下 `references/`（SSOT）を参照する。
