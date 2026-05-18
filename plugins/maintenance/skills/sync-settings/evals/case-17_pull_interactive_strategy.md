# Case 17: `/sync-pull --strategy interactive`（差分 1 件ずつ AskUserQuestion）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "/sync-pull --scope project --strategy interactive" or "/sync-pull"（対話モード）|
| 引数 | `--scope project --strategy interactive`（または引数なしで対話モード経由） |
| 既存状態 | カレントディレクトリの project マッピング設定済 + リモートに差分あり |

## 期待動作

### Phase 1: 差分一覧取得（sync.ps1 -EmitDiffJson）

```powershell
$tmpJson = ".claude/.local/work/<session>/workspace/sync-diff.json"
pwsh -NoProfile -File "...sync.ps1" -Mapping project -EmitDiffJson "$tmpJson"
```

- sync.ps1 が差分検出後、JSON ファイルへ書き出して exit 0
- 実適用はしない

### Phase 2: JSON 解析 + 件数分岐

| 差分件数 | 動作 |
|---------|------|
| 0 件 | 「同期不要」と報告して終了 |
| 1〜5 件 | 各差分について AskUserQuestion 個別発火（Phase 3-A）|
| 6 件以上 | 一括選択 AskUserQuestion（Phase 3-B）|

### Phase 3-A: 差分 1 件ごとの AskUserQuestion（少数時）

各エントリについて:

```text
question: "差分 [<Op>] <RelPath>（残り <N> 件）をどう扱いますか？"
options:
  - 上書き（リモートで上書き）
  - 保持（ローカルを保持）
  - スキップ（この差分を無視）
```

### Phase 3-B: 一括選択 AskUserQuestion（大量時）

```text
question: "差分が <N> 件あります。一括処理するか個別判断するか選択してください。"
options:
  - 全件 overwrite
  - 全件 skip
  - 個別判断
  - キャンセル
```

「個別判断」が選ばれた場合は Phase 3-A のループに分岐。

### Phase 4: 決定に従った適用（Claude 直接）

| 決定 | Op=ADD/MOD | Op=DEL |
|-----|----------|--------|
| 上書き | `Copy-Item $Remote → $Local -Force` | `Remove-Item $Local -Force` |
| 保持 / スキップ | 何もしない | 何もしない |

バックアップ取得（`--no-backup` 未指定時）も Claude 主導で `~/.claude/.local/plugins/maintenance/backup/<YYYYMMDD_HHmmss>/` に実施。

### Phase 5: 完了報告

適用 N 件 / 保持 N 件 / スキップ N 件 / 失敗 N 件を集計提示。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| AskUserQuestion 発火回数 | 差分件数 1〜5 件: そのまま件数分。6 件以上: 1 回（一括）or 1+N 回（個別判断選択時）|
| 生成/更新ファイル | バックアップディレクトリ + 上書き決定の対象ファイル |
| 標準出力 | 完了報告サマリ |
| 終了状態 | 成功（exit 0）。AskUserQuestion キャンセル時は途中終了 |

## 分岐の根拠

このケースが分岐するトリガーは `--strategy interactive` 指定 である。

## 設計意図

- 競合解決を **ユーザに 1 件ずつ確認** することで、誤った一括上書きを防ぐ
- 6 件以上は UX 負荷が高いため一括選択を優先（plugin-updater Phase G の閾値設計と同等）
- sync.ps1 改修を最小限に抑え、Claude 主導のループで個別適用（簡易実装）
- バックアップは Claude 主導で取得（sync.ps1 の通常フローと同等の安全性）

## 関連ケース

- `case-13_map_set_interactive.md`（マッピング設定の対話モード）
- `case-02_interactive_overwrite.md`（overwrite 戦略の対話モード）
- `case-05_merge_strategy.md`（merge 戦略）
