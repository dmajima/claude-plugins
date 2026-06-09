# checklists/

作業完了前・レビュー前に走査する **検証項目リスト** を管理する。

## ファイル一覧

| ファイル | 内容 |
|---------|------|
| [`completion-checklist.md`](completion-checklist.md) | 作業完了前の自己検証チェックリスト（動作デモ・ADR-032 含む） |
| [`review-freshness.md`](review-freshness.md) | レビュータスクのフレッシュ起動原則（ADR-021） |
| [`validation-rules.md`](validation-rules.md) | 種別別の検証ルール（構造・命名・必須項目の網羅的チェック） |

## 利用ルール

- チェックリストは **全項目走査** が前提。部分走査や黙っての省略は禁止
- 各項目の判定は OK / NG / NA（理由必須）の 3 値で行う
- チェックリストの出典ポリシーを変更する場合は、ポリシー側を先に更新する（SSOT 優先）
- extension-review スキル固有のレビューチェックリストは `skills/extension-review/references/checklists/` に配置する（本フォルダはプラグイン横断の共通チェックリスト）

## 関連フォルダ

- `policies/` — チェック項目の出典（SSOT）
- `skills/extension-review/references/checklists/` — レビュースキル固有のチェックリスト
