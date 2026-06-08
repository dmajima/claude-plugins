# Case 05: ADR-018 必須 4 要素欠落の自動補完（プラグイン README）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`legacy-toolkit` プラグインの README を更新" |
| 引数 | `--plugin legacy-toolkit` |
| フラグ | なし（対話モード） |
| 既存状態 | `plugins/legacy-toolkit/README.md` 存在、ただし「導入手順」に A. マーケットプレイス経由のみ記載、B. ローカル複製 / C. 自動更新 / D. 依存関係セクションが欠落 |

## 期待動作

### Phase 1: 対象種別判定

プラグイン名から `plugins/legacy-toolkit/.claude-plugin/plugin.json` 存在を確認。プラグイン対象として認識。

### Phase 2: 既存内容のスキャン + 必須要素検査（ADR-018 準拠）

[`../../../references/policies/readme-policy.md`](../../../references/policies/readme-policy.md) 節 5.1 の必須 4 要素を検査:

| 要素 | 検出パターン | 状態 |
|-----|------------|-----|
| A. マーケットプレイス経由 | `### A.` または `/plugin marketplace add` を含むセクション | 存在 |
| B. ローカル複製 | `### B.` または `git clone` + `/plugin marketplace add <local-path>` | **欠落** |
| C. 自動更新 | `### C.` または `autoUpdate` キーワード | **欠落** |
| D. 依存関係 | `### D.` または `dependencies` キーワード | **欠落** |

### Phase 3: ユーザへの提示

```text
README の「導入手順」に必須要素の欠落を検出しました（ADR-018 準拠）:

欠落要素:
- B. ローカル複製してインストール（オフライン環境向け）
- C. 自動更新の有効化（autoUpdate: true 設定）
- D. 依存関係のインストール

選択肢:
1. テンプレートから自動補完（推奨）
2. 手動で補完するためのスケルトンを提示
3. 補完せず終了（このまま ADR-018 違反として記録）
```

`AskUserQuestion` で選択させる。

### Phase 4: 自動補完（選択 1）

[`../../../references/templates/plugin/README.md`](../../../references/templates/plugin/README.md) テンプレートから B / C / D 要素を抽出し、プレースホルダ部分（`{marketplace-url}` `{plugin-name}` 等）を実値で置換して挿入。
既存 A 要素のセクションはそのまま維持。

### Phase 5: 検証 + 引き渡し

| 項目 | 動作 |
|-----|------|
| 補完後 README に A/B/C/D 4 要素揃う | 必須 |
| プレースホルダ残存なし | 必須 |
| Markdown リンク valid | 必須 |
| 既存内容の不要削除なし | 必須 |

```text
README の必須 4 要素を自動補完しました。

補完内容:
- B. ローカル複製してインストール（git clone + ローカルパス指定）
- C. 自動更新の有効化（autoUpdate: true 設定例）
- D. 依存関係のインストール（dependencies の手動インストール手順）

差分プレビューを確認し、内容を承認してください。
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `plugins/legacy-toolkit/README.md`（B/C/D 要素追加） |
| 標準出力 | 欠落要素の警告 + 選択肢 + 補完結果差分 |
| 終了状態 | 成功（選択 1）/ スケルトン提示後終了（選択 2）/ 警告のみ（選択 3） |

## 分岐の根拠

プラグイン対象 + 既存 README あり + ADR-018 必須要素欠落検出。

## 関連ケース

- `case-01_plugin_readme_new.md`（新規作成、最初から 4 要素揃い）
- `case-02_skill_readme_update.md`（スキル README、4 要素適用外）
- `case-03_remove_history.md`（過去履歴除去）
- `case-04_non_interactive.md`（非対話モード）
