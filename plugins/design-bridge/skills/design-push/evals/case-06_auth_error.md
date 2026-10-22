# Case 06: 認可エラー（/design-login を案内して中断）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「Claude Design に反映して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり（`projectId` 設定済み）。しかし `/design-login` による design-system 認可が未実施、または認可が失効しており、`DesignSync` が認可エラーを返す。`pending.txt` に 2 件 |

## 期待動作

### Phase 1: 導入確認と対象決定
- `.claude/design-bridge.json` を読み、導入済みであることを確認する
- 対象を `pending.txt` の 2 件に決定する

### Phase 5 手前: DesignSync の呼び出しで認可エラーを検出
- 呼び出し順序どおり `get_project` から開始する
- `get_project` が認可エラーを返す
- 認可が無い状態では `list_files` も `finalize_plan` も `write_files` も成功しないため、後続の `DesignSync` 呼び出しを行わずに中断する

### 中断時の扱い
- **`pending.txt` を削除しない**
- **`block-count` を削除しない**
- バンドルを push しない。設計書を「反映済み」として扱わない

### 報告
- design-system への認可が無いため反映できないことを明示する
- ユーザーに `/design-login` の実行を依頼する
- 認可後に `design-push` を再実行すれば、未反映の 2 件がそのまま対象になることを伝える
- Claude 側で認可を回避する手段を試みない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | `/design-login` の実行依頼 |
| 外部呼び出し | `get_project` のみ（認可エラー検出後は `list_files` / `finalize_plan` / `write_files` を呼ばない） |
| 残存ファイル | `pending.txt`（2 件のまま）、`block-count`（存在していれば保持） |
| 標準出力（要約） | 認可エラーの明示、`/design-login` の案内、再実行手順 |
| 終了状態 | 中断（未反映のまま） |

## 分岐の根拠

このケースが分岐するトリガーは `DesignSync` の応答 = 認可エラー である。procedures.md の失敗時の扱いで「認可エラー → `/design-login` の実行をユーザーに依頼して中断。`pending.txt` は残す」と定義された分岐にあたる。

前提条件（design-system 認可）の不足は Claude 側では解消できず、ユーザーの操作を必要とする。そのため自動リトライや代替経路の探索ではなく、明示的な案内と中断が正しい振る舞いになる。

## 関連ケース

- [case-05_push_failure.md](case-05_push_failure.md)（同じく `pending.txt` を残す失敗だが、計画確定後の `write_files` 段階で起きるため、スクショ生成と設計書更新は完了している点が異なる）
- [case-01_pending_all.md](case-01_pending_all.md)（認可済みであれば同じ入力で通常の push フローが完走する）
