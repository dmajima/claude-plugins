# Case 04: --non-interactive モード（自動抽出して書き戻し）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "プラグイン `dev-toolkit` の README を更新" |
| 引数 | `--plugin dev-toolkit --non-interactive` |
| フラグ | `--non-interactive` |
| 既存状態 | `plugins/dev-toolkit/README.md` が古い構成で存在 |

## 期待動作

### Phase 1: モード判定

`--non-interactive` 検出 → 非対話モード。
セクション順序や「このドキュメントについて」の文面確認等のユーザ対話をスキップ。

### Phase 2: 対象種別判定

`--plugin dev-toolkit` から対象を確定。

### Phase 3: 既存内容からの自動抽出

既存 `README.md` から:

- 概要文
- 動作要件
- スキル一覧
- 利用例

を自動抽出。プラグインの実構成（`plugin.json` / `skills/` / `commands/` / `agents/` / `references/`）を Read してファイル構成ツリーを再生成。

### Phase 4: テンプレート充填（自動）

[`../../../references/templates/readme/`](../../../references/templates/readme/) のテンプレートを利用し、必須セクションを埋める。

[`../../../references/readme-policy.md`](../../../references/readme-policy.md) に従い:

- 履歴記述は除外（ADR-016 準拠）
- 「このドキュメントについて」の人間向け明記を必須挿入

### Phase 5: 検証 + 書き戻し

検証チェックリスト（リンク切れ / プレースホルダ / `§` 等）合格後、`README.md` に書き戻し。
失敗時は標準エラー出力に提示し、対話なしで終了。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 更新ファイル | `plugins/dev-toolkit/README.md` |
| 標準出力 | 「`dev-toolkit` README 更新完了」+ ファイルパス |
| 終了状態 | 成功 |
| ユーザ対話 | 発生しない |

## 分岐の根拠

`--non-interactive` フラグ → 自動化スクリプト・CI からの呼び出しを想定し、対話ゲートを全て省略。
不適合（必須セクション欠落等）はエラー終了。

## 関連ケース

- `case-01_plugin_readme_new.md`（対話モード・新規作成）
- `case-02_skill_readme_update.md`（対話モード・更新）
- `case-03_remove_history.md`（履歴記述の除去）
