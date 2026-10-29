# Case 01: 未導入プロジェクト（bridge-init を案内）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "設計書とデザインのずれを確認して" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `.claude/design-bridge.json` が存在しない（design-bridge 未導入のリポジトリ）。`.claude/.local/plugins/design-bridge/` も存在しない |

## 期待動作

### Phase 1: 導入状態の確認

- プロジェクトルートの `.claude/design-bridge.json` を読もうとする
- 不在を検出した時点で後続フェーズへ進まない
- 環境の健全性チェック（`jq` の有無・`.claude/.local/plugins/design-bridge/.venv` の有無・`.gitignore` の `.claude/.local/` 登録）も行わない。いずれも導入済みを前提とした確認であり、未導入時点では `bridge-init` の案内に集約する

### Phase 2: 未導入としての報告と案内

- 「このプロジェクトは design-bridge 未導入である」と報告する
- `bridge-init`（`/design-init`）による導入を案内する
- エラー・失敗としては扱わない（未導入は想定内の状態）

### Phase 3: 実施しないこと

- `pending.tsv` / `block-count` / `dismissed` / `last-push.json` を読まない（状態ディレクトリ自体が存在しない）
- `list_files` / `get_file` を呼ばない
- ディレクトリ・設定ファイル・venv を新規作成しない（導入は `bridge-init` の責務であり、本スキルは肩代わりしない）
- `.gitignore` を書き換えない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 変更ファイル | なし |
| 削除ファイル | なし |
| DesignSync 呼び出し | なし（読み取り系を含め 1 回も呼ばない） |
| 標準出力（要約） | 「design-bridge は未導入です（`.claude/design-bridge.json` が見つかりません）」「`/design-init` で導入してください」 |
| 終了状態 | 正常終了（未導入のため照合は未実施） |

## 読み取り専用の検証ポイント

- 設定ファイル・状態ディレクトリ・venv を「ついでに」作成していないこと
- `git status --porcelain` が実行前後で変化しないこと

## 分岐の根拠

このケースが分岐するトリガーは `.claude/design-bridge.json` の存在 = なし である。SKILL.md「前提」1 と「実行フロー」手順 1 の「無ければ未導入として報告し、`bridge-init` を案内して終了する」に対応する。

## エッジケース

| 状況 | 動作 |
|-----|------|
| `--local` を付けて起動した | 同じく未導入として案内する（`--local` は導入済みを前提とするフラグであり、判定順序は変わらない） |
| 設定ファイルを探せない（プロジェクトルートを特定できない） | 未導入として扱い、`bridge-init` を案内する |
| 設定ファイルが空の `{}` | **未導入ではない**。存在自体が導入済みの判定条件のため、既定値で case-03 の流れに進む |
| 設定は無いが `.claude/.local/plugins/design-bridge/` だけ残っている | 未導入として扱う。残骸の状態ファイルを読んで未反映件数を報告しない（紐付け先が不明のため） |

## 関連ケース

- `case-03_full_drift_check.md`（導入済み・既定モードの正常系）
- `case-04_unauthorized_remote.md`（導入済みだが認可が無い場合。未導入とは明確に区別して報告する）
- `case-05_no_baseline.md`（導入済みだが `last-push.json` が無い場合。こちらも未導入とは区別する）
