# Case 04: design-system 未認可で list_projects が認可エラー（中断）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「デザイン同期をセットアップして」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | git リポジトリ。`jq` 利用可。`/design-login` による design-system 認可が未実施。`.claude/design-bridge.json` なし |

## 期待動作

### Phase 1: 前提チェック
- プロジェクトルートと `jq` の確認までは通常どおり完了する

### Phase 2: Claude Design プロジェクトの決定
- `DesignSync` の `list_projects` が認可エラーを返す
- 認可が済んでいないことを検出し、ユーザに `/design-login` の実行を依頼する
- スキルをその場で中断する

### 以降の Phase
- ディレクトリ構成の作成・設定ファイルの生成・venv 構築は **実行しない**（`projectId` が確定しないため、中途半端な導入状態を残さない）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（`.claude/design-bridge.json`・`specs/`・`mocks/`・venv のいずれも作成しない） |
| 標準出力（要約） | design-system への認可が未完了である旨、`/design-login` の実行依頼、認可後に `/design-init` を再実行する案内 |
| 終了状態 | 中断（未導入のまま） |

## 禁止事項（このケースで起きてはならないこと）

- `/design-login` をスキルが代行実行しようとすること（ユーザ操作が必要）
- `projectId` を空・ダミー値にして `.claude/design-bridge.json` を生成すること
- 認可エラーを無視してディレクトリ構成だけ先に作ること（フックが「導入済み」と誤判定する状態を作らないため）

## 分岐の根拠

このケースが分岐するトリガーは「実行フロー 2 の `list_projects` の応答 = 認可エラー」である。SKILL.md は「`list_projects` が認可エラーを返した場合は `/design-login` の実行をユーザーに依頼し、このスキルを中断する」と定めており、重要な制約にも「認可エラー時に `/design-login` を代行実行しようとしない」が挙げられている。前提 3（`/design-login` による design-system 認可）の NG パスにあたる。

## 関連ケース

- [case-01](case-01_new_setup_interactive.md): 認可済みで `list_projects` が候補を返す正常系
- [case-02](case-02_new_setup_non_interactive.md): 前提の一部（`jq`）が欠けても続行できるケース（認可エラーとは異なり中断しない）
