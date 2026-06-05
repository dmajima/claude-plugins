# 実行手順詳細

`session-usage` スキルの動作手順を詳細化する。SKILL.md の実行フローを補足する。

## ステップ 1: 引数解釈

`$ARGUMENTS` を以下のルールで解釈する。

| パターン | 処理 |
|---------|------|
| 空 | `SessionId` 未指定で `aggregate.sh` を起動 |
| 36 文字の UUID 形式 (`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`) | `SessionId` として渡す |
| その他 | 警告出力後、空扱いで進行 |

## ステップ 2: 集計実行（結果取得のみ、自動コピーなし）

Bash で以下を実行する:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/session-usage/scripts/aggregate/aggregate.sh" \
  --stdout [--session-id <UUID>]
```
| フラグ | 役割 |
|-------|------|
| `--stdout` | UTF-8 で stdout に直接書き出し（Bash 経由でも文字化けしない） |
| `--session-id <UUID>` | 引数で指定された場合のみ |

スクリプトの標準出力は Claude のコンテキストへ取り込まれる。Claude UI の
Bash 出力エリアでは折りたたまれて表示されることがあるが、**次のステップで
`AskUserQuestion` の `preview` に埋め込んで全文表示する** ため、Bash 生出力の
見え方は気にしない。
**`-Copy` は付けない**。クリップボードへのコピーはユーザが選択したときだけ行う。

## ステップ 3: AskUserQuestion による対話ループ（3 択 + preview）

集計結果をコンテキストに取得した後、Claude が `AskUserQuestion` で次のアクションを尋ねる。
**3 つすべてのオプションに `preview` フィールドで集計結果全文を必ず埋め込む**こと。

```text
AskUserQuestion({
  questions: [{
    question: "集計結果",
    header: "session-usage",
    options: [
      {
        label: "クリップボードへコピー",
        description: "現在表示している整形済み結果をクリップボードへコピーします",
        preview: "<集計結果全文>"
      },
      {
        label: "再集計",
        description: "進行中の値を最新化して再表示します",
        preview: "<集計結果全文>"
      },
      {
        label: "終了",
        description: "対話を終えます",
        preview: "<集計結果全文>"
      }
    ],
    multiSelect: false
  }]
})
```

`preview` のおかげで Claude UI は左右分割レイアウトになり、選択肢にフォーカス
した瞬間に右ペインで集計結果が monospace box として全文表示される。Bash 出力の
折りたたみとは別経路の表示なので、結果が省略されることはない。

ユーザの選択に応じて分岐:

### 選択: クリップボードへコピー

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/session-usage/scripts/aggregate/aggregate.sh" \
  --copy [--session-id <UUID>]
```
- `--copy` のみ指定（`--stdout` なし）
- aggregate.sh が再集計し、結果をクリップボードへコピー（OS 別に `clip.exe` / `pbcopy` / `xclip` を自動選択）
- stdout には `[OK] clipboard へコピーしました` のみ出る（罫線レイアウトは再表示しない）
- 完了後、ステップ 3 へ戻り再度 AskUserQuestion を提示

### 選択: 再集計

ステップ 2 を再実行（`-Stdout` のみ）。表示後、ステップ 3 へ戻る。

### 選択: 終了

対話終了。

### ループ継続条件

「終了」が選ばれるまで継続。「コピー」や「再集計」の後も再度選択肢を出す。

## ステップ 4: エラー処理

| 状況 | 動作 |
|------|------|
| プロジェクトディレクトリが見つからない | aggregate.sh が throw → Claude が原因を簡潔に報告 |
| 指定 UUID の JSONL が見つからない | 同上 |
| Set-Clipboard 失敗 | aggregate.sh が `[NG] Set-Clipboard failed: ...` を stdout に出す |

## 関連スキル / コマンド

- 呼び出し元コマンド: `commands/session-usage.md`
- 比較対象: Claude Code 組み込み `/usage`（時間枠ベース）、`/doctor`（環境診断）

## 利用例

### 例 1: カレントセッションを表示してコピー選択

```text
/session-usage
→ 集計結果を表示（コピーなし）
→ AskUserQuestion: [クリップボードへコピー / 再集計 / 終了]
→ ユーザ「クリップボードへコピー」選択
→ aggregate.sh -Copy 実行
→ "[OK] clipboard へコピーしました" 表示
→ AskUserQuestion: [クリップボードへコピー / 再集計 / 終了]（再提示）
→ ユーザ「終了」選択
→ 終了
```

### 例 2: 進行中セッションの再集計を繰り返す

```text
/session-usage
→ 表示（クリップボード未触）
→ ユーザ「再集計」 → 最新値表示 → 再度選択肢
→ ユーザ「再集計」 → さらに最新値 → 再度選択肢
→ ユーザ「クリップボードへコピー」→ コピー → 再度選択肢
→ ユーザ「終了」
```
