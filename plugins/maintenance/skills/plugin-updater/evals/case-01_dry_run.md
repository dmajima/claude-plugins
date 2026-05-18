# Case 01: dry-run モード（変更系 CLI 呼び出しなし）

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all --dry-run` |
| コマンドから委譲される `mode` | `dry-run` |
| コマンドから委譲される `scope` | `all`（既定） |
| 既存状態 | マーケットプレイス 3 件・各 user/project/local スコープにプラグイン複数 |

## 期待動作

### Phase A-0-1: 引数バリデーション
- `mode` を `dry-run` と確定
- `scope` を `all` と確定

### Phase A-0-2: Claude Code CLI 存在チェック
- `claude plugin marketplace list` などのサブコマンドが利用可能であることを検証

### Phase A: 対象収集
- `claude plugin marketplace list` でマーケットプレイス列挙
- 各スコープの `settings.json` から `enabledPlugins` のみ Grep で抽出（XR-Sec）

### Phase A-1〜A-3: 入力検証
- プラグイン名 / MP 名 / スコープ名の正規表現照合（XR-1）
- 未登録 MP の早期除外
- `installed_plugins.json` の `scope` / `projectPath` でプロジェクト外エントリを除外

### Phase B〜E: 更新実行（dry-run）
- **変更系 CLI（`claude plugin marketplace update` / `claude plugin update`）は呼び出さない**
- 各 Phase で「実行予定」の対象を集計するのみ

### Phase F: 結果報告
- サマリに「dry-run（実適用なし）」を明記
- 更新予定のマーケットプレイス・プラグインを一覧表示
- 「(dry-run) 変更系コマンドは実行していません」を出力

### Phase G: 失敗対応
- 変更系を実行していないため通常は発火しない
- 検証フェーズで失敗があった場合のみリトライ案内（dry-run 中はリトライも実行しない）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | なし |
| 標準出力（要約） | 「===== 更新サマリ =====」「(dry-run) 実適用は行いません」 |
| 終了状態 | 成功（exit 0） |

## 分岐の根拠

このケースが分岐するトリガーは `mode = dry-run` である。

## 関連ケース

- `case-05_scope_all.md`（同じ scope だが mode = normal）
- `case-06_invalid_scope.md`（A-0-1 バリデーション失敗）
- `case-09_phase_g_retry.md`（mode = normal で Failed が出た場合の Phase G）
