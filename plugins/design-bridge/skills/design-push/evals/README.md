# Evals: design-push

このディレクトリは `design-push` スキルの動作分岐ごとの期待挙動を定義するケース集。各ケースは仕様書として機能する（`DesignSync` への実アクセスと対話承認を伴うため、自動実行フロントマターは付与しない）。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| [case-01_pending_all.md](case-01_pending_all.md) | 引数なし。`pending.txt` の全件を対象に、計画提示 → 承認 → push → 未反映記録のクリアまで実行する | 引数 = なし かつ `pending.txt` が非空 → 対話モード・pending 全件 |
| [case-02_screen_id.md](case-02_screen_id.md) | 画面 ID を指定。その画面の設計書・モックのみを対象に非対話で進行する（計画提示は省略しない） | 引数 = 画面 ID → 非対話モード・対象限定 |
| [case-03_all_mocks.md](case-03_all_mocks.md) | `--all` 指定。`mocksDir` 配下の全モックを対象にし、リモート側の余剰ファイル（削除候補）をユーザーに確認する | 引数 = `--all` → 非対話モード・全モック。かつ `list_files` に削除候補あり |
| [case-04_pending_empty.md](case-04_pending_empty.md) | 引数なしで `pending.txt` が空。「反映すべき変更はありません」と報告して正常終了し、スクショ生成も push も行わない | 引数 = なし かつ `pending.txt` が空 |
| [case-05_push_failure.md](case-05_push_failure.md) | `write_files` が失敗。未反映記録（`pending.txt` / `block-count`）を削除せず、失敗として報告する | `write_files` の結果 = 失敗（完全失敗 / 一部失敗） |
| [case-06_auth_error.md](case-06_auth_error.md) | design-system 未認可。`get_project` が認可エラーを返した時点で `/design-login` を案内して中断する | `DesignSync` の応答 = 認可エラー |

## カバレッジ

| 観点 | 対応ケース |
|-----|----------|
| 対話モード | case-01、case-04 |
| 非対話モード | case-02、case-03 |
| 対象決定の 3 分岐（なし / 画面 ID / `--all`） | case-01、case-02、case-03 |
| 正常終了（対象ゼロ） | case-04 |
| エラー系（送信失敗） | case-05 |
| エラー系（前提不足） | case-06 |

## 安全性の中心的な不変条件

case-05 と case-06 が検証するのは design-push の最重要要件である。

> **push が完全に成功した場合にのみ `pending.txt` と `block-count` を削除する。**

この不変条件が破れると、未反映の変更が Stop フックに検出されなくなり、「反映済みのつもりで未反映」という、design-bridge が防ごうとしている状態そのものが発生する。

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

- `DesignSync` への実アクセスを伴うため、検証用の design-system プロジェクトに対して実施する
- case-05 / case-06 の確認後は、`pending.txt` が削除されずに残っていることをファイルシステム上で確認する
- 計画提示と承認 UI（`AskUserQuestion`）の実発火は機械検証の射程外のため、人間レビューで確認する

## ケース追加ルール

対象決定の規則、`DesignSync` の呼び出し順序、未反映記録のクリア条件のいずれかを変更した場合は、対応するケースを必ず追加・更新する。
