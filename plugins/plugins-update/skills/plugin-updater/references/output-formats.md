# Output Formats (plugin-updater)

`plugin-updater` スキルが Phase F / G で出力するテーブル・警告・質問文のフォーマット集約 SSOT。
変数表記の `<count>` 等は実行時に実際の値に置き換える。

サニタイズ規則は [`cross-cutting-rules.md`](cross-cutting-rules.md) の XR-3 を、結果分類は
[`architecture-decisions.md`](architecture-decisions.md) の ADR-PU-005 を参照。

---

## Phase F-1. サマリ

`Missing` 列は B-1（マーケットプレイス更新）では現在の CLI が MP 単位の Missing を返さないため `-` 固定
（将来 CLI が MP レベルで `not found` を返すようになった場合は仕様改訂）。
**列名定義**: 「成功」= Updated（実際に更新が走ったエントリ）、「変更なし」= No change（既に最新版）、
「Missing」= マーケットプレイスから消失（リトライ対象外）、「スキップ」= XR-1 不正値 / XR-2 サーキットブレーカー作動 /
A-2 MP 未登録等で対象外、「失敗」= Failed（リトライ対象）、「Unknown」= exit code と出力解析で分類できなかった
要手動確認エントリ。

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

## Phase F（dry-run モード）

`mode = dry-run` 時は Phase B / C / D / E を実行せず、以下フォーマットで「実行予定コマンド一覧」のみを
提示する。F-4 / G はスキップ。

### F-1（dry-run）. 実行予定サマリ

```markdown
## 実行予定サマリ（dry-run）

| 区分 | 実行予定件数 | スキップ | （備考）|
|-----|------------|---------|--------|
| マーケットプレイス | <count> | - | 全 MP 対象 |
| User プラグイン | <count> | <count> | scope=<scope> によりフィルタ |
| Project プラグイン | <count> | <count> | 同上 / git リポジトリ外なら省略 |
| Local プラグイン | <count> | <count> | 同上 |
```

### F-2（dry-run）. マーケットプレイス実行予定詳細

```markdown
### マーケットプレイス（実行予定コマンド）

| マーケットプレイス | 実行予定コマンド |
|-----------------|---------------|
| <name> | `claude plugin marketplace update` |
```

（CLI が個別 MP 指定をサポートした際は `claude plugin marketplace update <name>` 形式に切替）

### F-3（dry-run）. スコープ別実行予定詳細

```markdown
### User プラグイン（実行予定コマンド）

| プラグイン | マーケットプレイス | 実行予定コマンド |
|----------|-----------------|---------------|
| <plugin> | <marketplace> | `claude plugin update <plugin>@<marketplace> --scope user` |

### Project プラグイン（実行予定コマンド）
（User と同形式。git リポジトリ外なら "リポジトリ外のため省略" を表示）

### Local プラグイン（実行予定コマンド）
（User と同形式）
```

dry-run 時の備考列は「（実行予定）」固定文言を入れ、サニタイズ対象の実エラー出力は発生しないため
XR-3 適用は不要。

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
      { label: "全件リトライ", description: "Failed エントリをもう一度更新する。マーケットプレイス Failed 時は Phase B を全件再実行するため、サーキットブレーカー作動中の MP も再試行され得る（XR-2 の設計上の許容事項）" },
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

### 切り詰めアルゴリズム（疑似コード）

```text
function truncate_with_mask_safety(text, limit=500):
    if len(text) <= limit:
        return text

    cut = text[:limit]

    # 末尾から走査して、未閉鎖の `***` ペア境界に到達するまで後退
    # `***...***` パターンは固定マーカーで両端が `***` のため、
    # cut 内の `***` 出現回数が **奇数** であれば最後の `***` ブロックが未完結
    star_count = count_occurrences(cut, "***")
    if star_count % 2 == 1:
        # 最後の `***` 出現位置の手前まで切り戻す
        last_star_pos = rfind(cut, "***")
        cut = cut[:last_star_pos]

    return cut + "...（省略）"
```

**設計意図**:
- 既知マスクトークン（`***GITHUB_TOKEN***` / `***POSSIBLE_SECRET***` 等）は両端が `***` で固定。
- `***` の出現回数が偶数なら全ペアが完結している。奇数なら最後の `***` ブロックが切れているため、
  その手前まで戻すことで「機密が部分露出する事故」を回避する。
- `<netrc-credential>` 等の山括弧マスクは部分露出しても秘匿性を破らないため、本アルゴリズムでは
  追加処理しない（必要なら山括弧版も同等の偶奇判定で拡張可能）。

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
