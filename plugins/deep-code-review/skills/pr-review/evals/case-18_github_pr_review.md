# case-18 GitHub PR URL フレーズでの起動（トリガー検証）

GitHub の PR URL を渡したときに pr-review が起動し、URL からホストを GitHub と判定してレビューフローへルーティングされることを検証するトリガーケース。認証確認から投稿までの詳細正常系は case-01 が担う。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "https://github.com/owner/repo/pull/123 をレビューして" |
| モード | 対話 |

## 分岐の根拠

SKILL.md description / トリガー条件「GitHub / Azure DevOps の PR URL を渡された場合」に GitHub PR URL が合致し pr-review が起動する。Step 1/1.5 のホスト判定で URL から GitHub（github.com）を検出する（P1: PR 識別子のホワイトリスト正規表現バリデーションの GitHub 形式に一致）。本ケースは起動・ホスト判定・ルーティングの分岐を検証し、認証確認から投稿までの詳細正常系は case-01 が担う。

## 期待動作

- GitHub PR URL のフレーズで pr-review スキルが起動する（トリガー条件）
- P1 に従い URL が GitHub 形式のホワイトリスト正規表現に一致することを検証する
- Step 1/1.5: URL からホストを GitHub と判定し、connector:github へ読み取り操作を委譲する（認証確認は connector 側で実行）
- Step 2: gh CLI 等の必要ツールを確認し、不足時は env-setup スキルへ委譲する（E5: 個別スキルの独自インストール禁止）
- Step 3/6: PR メタ情報・差分を取得し code-review オーケストレーターへ委譲する
- Step 7: レビュー結果を PR にインラインコメント + サマリースレッドとして投稿する（既定で投稿必須・P5）

## 関連ケース

- case-01: GitHub PR の初回標準レビュー正常系（認証確認〜投稿までの詳細フロー）
- case-19: Azure DevOps PR フレーズでの起動（対になるホスト分岐）
- case-20: 短い PR レビュー依頼フレーズでの起動（識別子なしの分岐）
