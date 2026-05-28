# Case 16: `/cleanup-config` 対話モード（引数なし・4 質問同時発火）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "/cleanup-config" |
| 引数（$ARGUMENTS） | 空文字 |
| フラグ | なし |
| 既存状態（A） | `cleanup-config.json` 不在 → 出荷時デフォルトを「現在値」として扱う |
| 既存状態（B） | `cleanup-config.json` 存在（例: `default_days=60` 等の非推奨値あり） |

## 期待動作

### Phase 1: モード判定 + 設定読み込み
- `$ARGUMENTS` が空 → 対話モードに分岐
- `cleanup-config.json` を読み込み、各フィールドの現在値を取得（不在時は出荷時デフォルト）

### Phase 2: AskUserQuestion 1 回で 4 質問同時発火

4 つの質問を **同時** に発火する。各質問の options 構築ルール:

| ルール | 内容 |
|-------|------|
| 1 つ目 | 現在値（設定不在時は出荷時デフォルト）|
| 1 つ目の label 末尾 | `（現在の設定）` または `（既定）` |
| 残り | 推奨値から現在値を除いたもの。現在値が推奨外なら推奨値全部を追加（最大 4 options） |
| Other | AskUserQuestion 仕様で自動付与（整数は自由入力、scope は再入力誘導） |

#### 推奨値テーブル

| 項目 | 推奨値 | description で案内する他の典型値 |
|-----|-------|------------------------------|
| `default_days` | **14 / 30 / 90** | 60 / 180 / 365 |
| `default_keep_recent` | 0 / 3 / 5 | 10 / 20 |
| `default_scope` | both / global / project（全カバー） | （Other は再入力誘導）|
| `active_session_minutes` | 5 / 10 / 15 | 3 / 30 / 60 |

### Phase 3: 質問順序

`default_days` → `default_keep_recent` → `default_scope` → `active_session_minutes` の順に提示。AskUserQuestion の questions 配列順がそのまま表示順となる。

### Phase 4: 変更検出 + スクリプト実行

4 つの選択結果と現在値を比較し、**変更があった項目のみ** を `cleanup-config.sh` の引数として渡す:

| 変更検出 | 動作 |
|---------|------|
| 1 件以上変更あり | `cleanup-config.sh -SetDays N -SetKeepRecent N -SetScope X -SetActiveSessionMinutes N`（変更項目のみ） |
| 変更なし | `cleanup-config.sh -Show`（現在の設定表示のみ）|

### Phase 5: 完了報告

更新後の設定全体を表示し、変更前→変更後の差分をユーザに提示。「`--show` / `--reset --yes` で別操作が可能」と案内を付ける。

## 期待出力

### ケース A（設定ファイル不在）

| 項目 | 期待値 |
|-----|-------|
| Question 1 (default_days) options | `[30（既定）, 14, 90]` の 3 つ |
| Question 2 (default_keep_recent) options | `[0（既定）, 3, 5]` の 3 つ |
| Question 3 (default_scope) options | `[both（既定）, global, project]` の 3 つ |
| Question 4 (active_session_minutes) options | `[5（既定）, 10, 15]` の 3 つ |
| 各質問の Other | 自動付与（システム）|

### ケース B（設定ファイル存在、default_days=60、他は既定値）

| 項目 | 期待値 |
|-----|-------|
| Question 1 (default_days) options | `[60（現在の設定）, 14, 30, 90]` の 4 つ（推奨外のため全推奨値を追加）|
| Question 2 (default_keep_recent) options | `[0（現在の設定）, 3, 5]` の 3 つ |
| Question 3 (default_scope) options | `[both（現在の設定）, global, project]` の 3 つ |
| Question 4 (active_session_minutes) options | `[5（現在の設定）, 10, 15]` の 3 つ |

## 分岐の根拠

このケースが分岐するトリガーは `$ARGUMENTS` が空文字 である。引数が非空の場合は `case-13`（`--show`）/ `case-14`（`--set-*`）の非対話フローに分岐する。

## 設計意図

- **Step 1（設定項目選択）を廃止**: ユーザが「どの項目を変更するか」を選ぶ手間を省き、4 質問を一気に提示することで対話往復を最小化
- **現在値を 1 つ目に配置**: 「変更しない」場合に即選択できる UX
- **`（現在の設定）` / `（既定）` 表記**: 現在の状態がひと目で分かる
- **推奨値外の現在値**: 4 options で推奨値も全列挙し、推奨値への移行を促す
- AskUserQuestion options 上限（4）に収まる設計

## 関連ケース

- `case-13_config_show.md`（`--show` 非対話）
- `case-14_config_set.md`（`--set-*` 非対話）
