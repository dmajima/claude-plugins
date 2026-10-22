# Case 04: pending.txt が空（反映すべき変更なしで正常終了）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「Claude Design に反映して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり。認可済み。直前の `design-push` が成功しているため `.claude/.local/plugins/design-bridge/pending.txt` が存在しない、または空である |

## 期待動作

### Phase 1: 導入確認と対象決定
- `.claude/design-bridge.json` を読み、導入済みであることを確認する
- 引数が無いため、対象は `pending.txt` の全件となる
- `pending.txt` が存在しない、または空であることを検出する
- 対象決定表の条件「`pending.txt` が空で引数も無い場合」に合致するため、ここで正常終了に分岐する

### Phase 2 以降: 実行しない
- スクリーンショットの再生成を行わない
- 設計書の画面イメージセクションを書き換えない
- バンドルを作成しない
- `DesignSync` を一切呼び出さない（`get_project` も `list_files` も呼ばない）
- `pending.txt` / `block-count` に対する削除操作も行わない（そもそも未反映が無い状態のため）

### 報告
- 「反映すべき変更はありません」と報告して終了する
- 全件を強制的に反映したい場合は `--all` を使えることを案内してよい

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | なし（確認を要する操作を行わないため） |
| 生成ファイル | なし |
| 更新ファイル | なし |
| 外部呼び出し | `DesignSync` の呼び出し 0 回 |
| 標準出力（要約） | 「反映すべき変更はありません」 |
| 終了状態 | 成功（正常終了。エラーでも中断でもない） |

## 分岐の根拠

このケースが分岐するトリガーは 引数 = なし かつ `pending.txt` = 空（または不在） である。SKILL.md の対象決定で明示された早期正常終了の分岐であり、空のバンドルを push して Claude Design 側を意図せず空にする事故を防ぐ役割を持つ。

## 関連ケース

- [case-01_pending_all.md](case-01_pending_all.md)（同じ引数なしでも `pending.txt` が非空なら通常の push フローへ進む）
- [case-03_all_mocks.md](case-03_all_mocks.md)（`pending.txt` が空でも `--all` を指定すれば `mocksDir` 配下の全モックを対象に push する）
