# guides/

拡張要素の設計・記述における **ベストプラクティスと設計指針** を管理する。

## ファイル一覧

| ファイル | 内容 |
|---------|------|
| [`agent-utilization.md`](agent-utilization.md) | エージェント活用ガイド（チーム選定・並列起動・フォールバック） |
| [`askquestion-strategy.md`](askquestion-strategy.md) | AskUserQuestion の設計戦略（選択肢設計・タイミング） |
| [`description-guide.md`](description-guide.md) | description フィールドの設計ガイド（5W1H・文字数・トリガー判定） |
| [`eval-guide.md`](eval-guide.md) | evals の設計ガイド（ケース構成・分岐網羅・エラー系） |
| [`powershell-pitfalls.md`](powershell-pitfalls.md) | PowerShell の落とし穴と回避策（Windows 環境固有） |
| [`readme-writing-guide.md`](readme-writing-guide.md) | README.md の記述実践ガイド（readme-policy.md の補助） |
| [`user-interaction.md`](user-interaction.md) | ユーザー対話ガイド（確認タイミング・モード判定） |

## 利用ルール

- ガイドは「どう設計・記述すべきか」を示す。「何を禁止するか」は `policies/` に記載する
- ガイド内でポリシーを参照する場合は、ポリシーファイルへのリンクを使う
- 新規ガイドを追加する際は、既存ガイドとの重複がないことを確認する
