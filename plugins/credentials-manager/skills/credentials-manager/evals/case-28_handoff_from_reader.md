# Case 28: credentials-reader 引き継ぎ受け入れ（save）

## 入力

| 項目 | 値 |
|-----|---|
| 起動契機 | `credentials-reader` が URL アクセス時に 0 件マッチを検知し、ユーザの保存承諾を受けて本スキルを `save` モードで起動 |
| 渡されるパラメータ | 候補名（推定）、推定種別、推定 `domains`、推定 `auth_method`、マスク済み値（reader からは **フル値は渡されない** [`../../credentials-reader/references/handoff.md`](../../credentials-reader/references/handoff.md) 節 3） |
| 既存状態 | `credentials.json` 不在 or 該当エントリなし |

## 期待動作

### Phase 1: 引き継ぎ受け入れ

- `credentials-reader` からの起動を認識
- 渡された候補名・推定ドメイン・推定 `auth_method` を初期値として読み込み

### Phase 2: フル値の取得

- フル値は渡されないため、`AskUserQuestion` でユーザに値の入力を求める
- 入力された値はマスクして確認表示

### Phase 3: 不足パラメータの確認

- 識別名・種別・関連 URL/ドメイン・`auth_method` のうち未確定項目を `AskUserQuestion` で確認
- 推定値があれば既定値として提示

### Phase 4: 保存

- パス解決 + `.gitignore` 確認
- エントリを書き込み（`created_at` / `updated_at` を現在時刻）

### Phase 5: 完了通知 → reader への復帰

- マスク済み値で完了通知
- 制御を `credentials-reader` に戻し、元の URL アクセス処理を続行

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `credentials.json`（解決パス） |
| 標準出力（要約） | 候補名提示 → 値入力 → 確認 → 保存完了通知 → URL アクセス再開 |
| 終了状態 | 成功 |

## 分岐の根拠

「reader 引き継ぎ + save」分岐。reader 側で取得済みの推定情報を初期値として活用し、不足するフル値のみユーザに再入力させる安全動作を検証する。reader 経由でのフル値非伝達も主要観点。

## 関連ケース

- `credentials-reader:case-03_auto_match_none.md`（reader 側の 0 件マッチ → 引き継ぎ提案）
- `credentials-reader:case-07_proactive_detect.md`（プロアクティブ検出からの引き継ぎ）
- `case-01_save_with_url.md`（直接 save 呼び出し）
