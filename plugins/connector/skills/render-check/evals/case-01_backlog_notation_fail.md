# Case 01: Backlog 記法ターゲットへの Markdown 混入（NOTATION FAIL → 修正採用 → 再チェック PASS）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この内容で Backlog の課題 PROJ-12 にコメントして"（`backlog` スキルへの発話。render-check はその内部ゲートとして起動） |
| 起動経路 | `backlog` スキルの書き込み操作直前の必須ゲート呼び出し |
| 引数 | 本文（下記）+ ターゲット `backlog-notation` |
| フラグ | なし |
| 既存状態 | 投稿先プロジェクトの `textFormattingRule` は `backlog` と API で判定済み（呼び出し元が引き継ぐ） |

### チェック対象本文（行番号は先頭行を 1 行目として数える）

````text
## 修正内容

ログ出力の **強調表示** を追加しました。

```java
System.out.println("done");
```
````

## 期待動作

### Phase 1: 入力確定
- 本文とターゲット `backlog-notation` を呼び出し元から受領する
- ターゲットは確定済みのため、ターゲット確認の AskUserQuestion は発火しない

### Phase 2: チェック実行（1 回目）
- 前処理: `{code}` 〜 `{/code}` が存在しないため本文全体を地の文として扱う（バッククォートフェンスは `backlog-notation` ではコード領域の境界にならない）
- NOTATION: backlog-notation.md セクション 3 の混入検出パターンで 3 件を検出する
  - 1 行目: 行頭 `## `（Markdown 見出し）= FAIL
  - 3 行目: `**強調表示**`（Markdown 太字）= FAIL
  - 5 行目・7 行目: 行頭バッククォート 3 つ（Markdown コードフェンス）= FAIL
- AUTOLINK / STRUCTURE / SECRET / SIZE: 検出なし（短文でも 5 カテゴリ全てを省略せず実施する）

### Phase 3: 結果レポート
- カテゴリ / 判定 / 内容 / 位置（行番号）の表で NOTATION FAIL 3 件を提示する
- 総合判定 FAIL（投稿不可）を明示し、「Backlog 記法スペースでは検出構文がレンダリングされず、そのまま文字として表示される」ことを説明する

### Phase 4: 修正提案と採用確認
- backlog-notation.md セクション 4 の変換表に基づく修正済み本文を提示する
  - `## 修正内容` → `** 修正内容`
  - `**強調表示**` → `''強調表示''`
  - ```` ```java ```` 〜 ```` ``` ```` → `{code:java}` 〜 `{/code}`
- AskUserQuestion で採用可否を確認する（選択肢: 「修正案を採用して再チェック」/「投稿を中止」。「FAIL のまま投稿」は提示しない）
- ユーザーが「修正案を採用して再チェック」を選択する

### Phase 5: 再チェック（2 回目）と引き渡し
- 修正後本文で 5 カテゴリ **全て** を再チェックする（NOTATION のみの部分再検査をしない）
- 全カテゴリ検出なし → 総合判定 PASS
- 投稿プレビュー（`** 修正内容` が見出し 2、`''強調表示''` が太字、`{code:java}` ブロックがコードとして表示される旨の説明付き）を提示する
- `backlog` スキルへ総合判定 PASS と修正後本文を返す（投稿処理自体は `backlog` スキルが実施する）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（render-check はファイルを生成しない） |
| 標準出力（要約） | 1 回目: NOTATION FAIL 3 件の表（行番号付き）+ 総合判定 FAIL + Backlog 記法への変換案 / 2 回目: 総合判定 PASS + プレビュー |
| 終了状態 | 成功（PASS + 修正後本文を `backlog` スキルへ引き渡し） |

## 分岐の根拠

このケースが分岐するトリガーは NOTATION 検査の検出結果 = 検出あり（ターゲット `backlog-notation` の地の文に Markdown 見出し・太字・コードフェンスの 3 種が混入）である。NOTATION の記法不一致は FAIL のため修正提案フローへ進み、採用後の全カテゴリ再チェックで PASS に転じる。

## 関連ケース

- `case-03_pass.md`（同じ Backlog 投稿ゲートで検出 0 件の場合。修正提案フローに入らない）
- `case-05_standalone_target_unknown.md`（同種の NOTATION FAIL だが、単体起動のためターゲット確認の AskUserQuestion が先行する）
- `case-06_structure_fail.md`（FAIL → 修正採用 → 全カテゴリ再チェック → PASS の流れが共通。FAIL の発生源が STRUCTURE である点が異なる）
