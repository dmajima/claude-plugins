# 実行手順詳細

`session-usage` スキルの動作手順を詳細化する。SKILL.md の実行フローを補足する。

## ステップ 1: 引数解釈

`$ARGUMENTS` を以下のルールで解釈する。

| パターン | 処理 |
|---------|------|
| 空 | `SessionId` 未指定で `aggregate.ps1` を起動 |
| 36 文字の UUID 形式 (`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`) | `SessionId` として渡す |
| その他 | 警告出力後、空扱いで進行（誤入力対策） |

## ステップ 2: 集計実行 + 表示 + 自動コピー

Bash で以下を実行する:

```bash
pwsh -NoProfile -ExecutionPolicy Bypass \
  -File "${CLAUDE_PLUGIN_ROOT}/skills/session-usage/scripts/aggregate/aggregate.ps1" \
  -Stdout -Copy [-SessionId <UUID>]
```

| フラグ | 役割 |
|-------|------|
| `-Stdout` | UTF-8 で stdout に直接書き出し（Bash 経由でも文字化けしない） |
| `-Copy` | 整形済み文字列を `Set-Clipboard` でクリップボードへ |
| `-SessionId <UUID>` | 引数で指定された場合のみ |

スクリプトの標準出力はそのまま Claude UI に表示される。
末尾に `[OK] clipboard へコピーしました` の通知が付く。

クリップボードに失敗した場合は stderr に `[WARN] Set-Clipboard failed: ...` を出すが、
表示自体は継続する（致命的エラーとはしない）。

## ステップ 3: AskUserQuestion による対話ループ

集計結果を表示・コピーした後、Claude が `AskUserQuestion` で次のアクションを尋ねる。

```
AskUserQuestion({
  questions: [{
    question: "次のアクションを選んでください",
    header: "session-usage",
    options: [
      { label: "再集計", description: "進行中の値を最新化して再表示し、クリップボードも更新します" },
      { label: "終了", description: "対話を終えます（現在の表示・コピーはそのまま残ります）" }
    ],
    multiSelect: false
  }]
})
```

ユーザの選択に応じて分岐:

| 選択 | 動作 |
|-----|------|
| 再集計 | ステップ 2 へ戻る（同じ SessionId / ProjectKey で再実行） |
| 終了 | 対話を終える |

過剰なループを防ぐため、再集計回数は実質的にユーザの判断に委ねる
（コマンド側で上限を設けない）。

## ステップ 4: エラー処理

| 状況 | 動作 |
|------|------|
| プロジェクトディレクトリが見つからない | aggregate.ps1 が throw → Claude が原因を簡潔に報告 |
| 指定 UUID の JSONL が見つからない | 同上 |
| Set-Clipboard 失敗 | stderr に WARN を出すが、表示は継続 |

## 関連スキル / コマンド

- 呼び出し元コマンド: `commands/session-usage.md`
- 比較対象: Claude Code 組み込み `/usage`（時間枠ベース）、`/doctor`（環境診断）

## 利用例

### 例 1: カレントセッションを表示

```text
/session-usage
→ 集計結果が Claude UI に表示
→ クリップボードへ自動コピー
→ 「再集計 / 終了」の選択肢が出る
```

### 例 2: 特定セッションを集計

```text
/session-usage 0988238f-3cbe-4a35-9981-cb523f7ef3d1
→ 該当セッションが集計表示される（rename済セッションは名前で表示）
```

### 例 3: 自然言語起動

```text
ユーザ「今回のセッションでどれくらいトークン使ったか教えて」
→ session-usage スキルが自動的にトリガーされる
```
