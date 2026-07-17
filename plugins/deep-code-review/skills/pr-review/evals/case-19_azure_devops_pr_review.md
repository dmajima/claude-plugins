# case-19 Azure DevOps PR フレーズでの起動（トリガー検証）

「Azure DevOps の PR #45」の自然言語フレーズで pr-review が起動し、ID 形式 + ホスト明示から Azure DevOps と判定、ツール不足時に env-setup へ委譲することを検証するトリガーケース。az CLI 投稿経路の詳細正常系は case-02 が担う。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "Azure DevOps の PR #45 をレビューして" |
| モード | 対話 |

## 分岐の根拠

SKILL.md description「Azure DevOps の PR をレビューして」に合致し pr-review が起動する。起動フレーズは URL ではなく ID 形式（#45）+ ホスト明示キーワード「Azure DevOps」のため、SKILL.md 入力表の host 指定（host=azure 相当）で Azure DevOps と判定する（P1 の ID 単体形式）。Step 2 のツール確認で az CLI / azure-devops 拡張の不足を検知した場合、E5（個別スキルの独自インストール禁止）に従い env-setup スキルへ委譲する。az CLI 投稿経路の詳細正常系は case-02 が担う。

## 期待動作

- 「Azure DevOps の PR #45 をレビューして」で pr-review スキルが起動する（トリガー条件）
- URL 不在・ID 形式のため、ホスト明示キーワードから Azure DevOps と判定する（P1 の ID 単体形式・host=azure 相当）
- Step 2: az CLI と azure-devops 拡張の存在を確認する（SKILL.md 対応ホスト表）
- 不足時は自スキルで install せず env-setup スキルへ委譲する（E5）
- connector:azure へ読み取りを委譲し PR メタ情報・差分を取得する
- Step 6: code-review オーケストレーターへ委譲する
- Step 7: レビュー結果を PR にインラインコメント + サマリースレッドとして投稿する（既定で投稿必須・P5。Azure は render-check 通過済みを明示）

## 関連ケース

- case-02: クラウド Azure DevOps PR の正常系（az CLI 投稿経路の詳細）
- case-06: オンプレ TFS Server（NTLM 経路、対になるホスト分岐）
- case-18: GitHub PR URL フレーズでの起動（対になるホスト分岐）
