# Case 03: 既存プラグインへの追加配置

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`dev-toolkit` プラグインに既存スキル `linter` を追加" |
| 引数 | `dev-toolkit --add skill:linter` |
| フラグ | なし |
| 既存状態 | `dev-toolkit` プラグインが既存、`linter` スキルが未配置 |

## 期待動作

### Phase 1: プラグイン存在確認

`plugins/dev-toolkit/` の存在を確認。存在するため追加シナリオで進行。

### Phase 2: 衝突確認

`plugins/dev-toolkit/skills/linter/` の存在を確認。未存在なので新規追加へ。

### Phase 3: 移管実行

case-02 と同じ移管手順。

### Phase 4: プラグイン README 更新案内

「提供機能」が変わるため `readme-toolkit` への接続を提案。

### Phase 4.5: ADR-024 / ADR-025 準拠化（追加スキルが旧構造の場合）

case-02 と同じ要領で、追加対象スキルが **旧構造（廃止済）** を含む場合は新ルールに変換する。下記の旧構造は ADR-024/025 で廃止されており、新規スキルでは使用しない:

| 旧構造（廃止済・追加スキル検出時のみ） | 変換後 |
|---------------------------------|-------|
| スキル直下 `scripts/{業務}/` | `references/scripts/{業務}/` にリネーム |
| スキル直下 `requirements.txt` / `scripts/deps/requirements.txt` | **既存プラグイン直下** `references/scripts/setup/requirements.txt` にマージ（バージョン競合あればユーザ確認） |
| スキル直下 `setup_venv.ps1` / `setup_venv.sh` 等 | 削除（プラグイン直下 `setup_venv.ps1` を再利用、PowerShell 統一） |

バージョン競合時の 3 択分岐（上書き / 維持 / キャンセル）は case-02 Phase 5.5 の競合判断分岐と同じ動作とする（キャンセル時は追加全体をロールバック）。

### Phase 5: 検証 + 引き渡し

通常の検証 + マーケットプレイス公開済みの場合は `marketplace-publisher` で更新公開を提案。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `plugins/dev-toolkit/skills/linter/`（移管） |
| 標準出力（要約） | 「`linter` スキルを `dev-toolkit` プラグインに追加」+ README 更新と公開の案内 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーはプラグイン名 = 既存プラグイン である。
