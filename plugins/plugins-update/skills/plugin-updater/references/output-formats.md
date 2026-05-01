# Output Formats (plugin-updater)

`plugin-updater` スキルが Phase F / G で出力するテーブル・警告・質問文のフォーマット集約 SSOT。
変数表記の `<count>` 等は実行時に実際の値に置き換える。

サニタイズ規則は [`cross-cutting-rules.md`](cross-cutting-rules.md) の XR-3 を、結果分類は
[`architecture-decisions.md`](architecture-decisions.md) の ADR-PU-005 を参照。

---

## Phase F-1. サマリ

`Missing` 列は B-1（マーケットプレイス更新）では現在の CLI が MP 単位の Missing を返さないため `-` 固定
（将来 CLI が MP レベルで `not found` を返すようになった場合は仕様改訂）。

```markdown
## 更新結果サマリ

| 区分 | 成功 | 変更なし | Missing | スキップ | 失敗 | Unknown |
|-----|-----|---------|---------|---------|-----|---------|
| マーケットプレイス | <count> | <count> | -（CLI 非対応）| <count> | <count> | <count> |
| User プラグイン | <count> | <count> | <count> | <count> | <count> | <count> |
| Project プラグイン | <count> | <count> | <count> | <count> | <count> | <count> |
| Local プラグイン | <count> | <count> | <count> | <count> | <count> | <count> |
```

### F-1.1. Unknown 警告（XR-5 を参照）

XR-5 の閾値（試行済み件数の 20%）を超える場合、cross-cutting-rules.md XR-5 セクションのフォーマットで
警告を併記する。閾値の根拠と全体件数の定義は同セクションを参照。

---

## Phase F-2. マーケットプレイス詳細

```markdown
### マーケットプレイス

| マーケットプレイス | 結果 | 備考 |
|-----------------|-----|-----|
| <name> | OK / Skipped / Failed / Unknown | <サニタイズ後の CLI 出力要約 or エラー> |
```

---

## Phase F-3. スコープ別詳細

```markdown
### User プラグイン

| プラグイン | マーケットプレイス | 結果 | 備考 |
|----------|-----------------|-----|-----|
| <plugin> | <marketplace> | Updated / No change / Missing / Failed / Unknown | <サニタイズ後の備考> |

### Project プラグイン
（User と同形式。git リポジトリ外かつ scope 未指定なら "リポジトリ外のため省略" を表示。
scope=project 明示時は Phase A-0 で git リポジトリ存在を要求し、不在ならエラー中断するため
本テーブルには到達しない）

### Local プラグイン
（User と同形式。同様に scope 未指定時のみ "リポジトリ外のため省略" を表示）
```

---

## Phase F-4. 次のアクション提示

`mode = dry-run` の場合は本セクションを **省略** する（実際の更新がないため）。

```markdown
### 次のアクション

- Claude Code を再起動するか `/reload-plugins` を実行して更新をセッションに反映する
- **重要**: 更新によって新しい hooks / MCP サーバ / commands / agents が追加された可能性があります。
  再起動前に以下を **必ず** 実施してください:

  ```text
  claude plugin show <plugin>@<marketplace>
  ```

  特に `hooks` セクションが新規追加・変更されている場合、次回起動時に自動実行されます。
- Missing と判定されたエントリは `enabledPlugins` から除外することを検討（マーケットプレイスから消失）
- 更新後に問題が発覚した場合のロールバックは README の「ロールバック手順」セクションを参照
- （失敗があれば）次のリトライ・スキップ確認に応答する
```

---

## Phase G-1 質問文（疑似コード）

```text
# pseudocode: Claude が AskUserQuestion ツールを呼び出すパターン
# N > 5 の場合は options から「個別に判断」を除外する（連続質問による UX 劣化防止）
AskUserQuestion({
  questions: [{
    question: "<N> 件の更新失敗があります（マーケットプレイス: <M> 件 Failed / プラグイン: <P> 件 Failed）。どう対応しますか？",
    header: "更新失敗対応",
    options: [
      { label: "全件リトライ", description: "Failed エントリをもう一度更新する" },
      // N <= 5 のときのみ次の選択肢を含める
      { label: "個別に判断", description: "Failed エントリごとにリトライ / スキップを選択" },
      { label: "全件スキップ", description: "Failed エントリは諦めて完了する" }
    ],
    multiSelect: false
  }]
})
```

---

## Phase G-2 質問文（疑似コード）

質問テキストの `<error>` は XR-3 サニタイズ後の値。500 字を超える場合は「...（省略）」で切り詰める
（マスクトークン `***...***` の途中で切らない）。

```text
# pseudocode: Claude が AskUserQuestion ツールを呼び出すパターン
AskUserQuestion({
  questions: [{
    question: "[<scope>] <plugin>@<marketplace> の更新に失敗しました（理由: <サニタイズ後のerror>）。リトライしますか？",
    header: "個別失敗対応",
    options: [
      { label: "リトライ", description: "もう一度更新を試行" },
      { label: "スキップ", description: "このエントリは諦める" }
    ],
    multiSelect: false
  }]
})
```

---

## エラーメッセージ集約

### 不正な scope 値

```text
エラー: 不正な scope 値 "<value>" が指定されました。有効な値は user / project / local / all です。
```

### CLI 不在 / 不正実装

```text
エラー: claude plugin CLI に必要なサブコマンドが見つかりません（または不正な実装の可能性）。
Claude Code のインストール状況と PATH を確認してください。
```

### enabledPlugins ブロック過大

```text
エラー: <scope> スコープの enabledPlugins ブロックが 4000 行を超えるため、
情報漏洩防止のため処理を中断します。settings.json の構造を確認してください。
```

### git リポジトリ外で project/local 明示時

```text
エラー: scope=<scope> が指定されましたが、git リポジトリ外のため Project / Local スコープを処理できません。
```

### git リポジトリ外で scope 未指定時の INFO

```text
INFO: git リポジトリ外で実行されたため Project / Local スコープを対象から除外しました。
```

### Phase B 後新規 MP 追加時の INFO

```text
INFO: Phase B でマーケットプレイス <name> が新規登録されましたが、当該 MP 配下のプラグインは
A-2 時点で未登録判定により Skipped 扱いのため、本セッションでは更新されません。
次回 /update-all 実行時に反映されます。
```
