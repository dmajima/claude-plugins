# Case 07: argument-hint 必須化（引数を受け取るコマンド、ADR-023）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "新しい `/run-tests` コマンドを作って。引数で対象パスとフラグを受け取る" |
| 引数 | `run-tests --description "現在のブランチでテストを実行" --placement plugins/dev-toolkit --args "<対象パス> [--coverage] [--bail]" --non-interactive` |
| フラグ | `--non-interactive` |
| 既存状態 | `run-tests.md` 未存在 |

## 期待動作

### Phase 1: パラメータ確定

- コマンド名: `run-tests`
- description: `現在のブランチでテストを実行`
- argument-hint: `<対象パス> [--coverage] [--bail]`（`--args` 引数から取得）
- 配置先: `plugins/dev-toolkit/commands/run-tests.md`

### Phase 2: argument-hint 表記規則の自動検証

| 検査項目 | 期待結果 |
|---------|---------|
| 必須引数が `<...>` で表記されている | OK（`<対象パス>`）|
| 省略可フラグが `[...]` で表記されている | OK（`[--coverage]` `[--bail]`）|
| 60 文字以内 | OK |
| 改行なし | OK |

### Phase 3: テンプレート展開

`${CLAUDE_PLUGIN_ROOT}/references/templates/command/command.md` をコピーし、`argument-hint` プレースホルダを `<対象パス> [--coverage] [--bail]` に置換。

### Phase 4: 検証 + 引き渡し

| 項目 | 動作 |
|-----|------|
| frontmatter `description` 60 文字以内 | 必須 |
| frontmatter `argument-hint` 存在 + 表記規則順守 | 必須（ADR-023）|
| 本文に `$ARGUMENTS` 参照あり | 引数受取コマンドのため必須 |
| description 内に引数仕様の重複記載なし | SSOT 保持 |

## 期待出力

生成された frontmatter:

```yaml
---
description: 現在のブランチでテストを実行
argument-hint: <対象パス> [--coverage] [--bail]
---
```

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `plugins/dev-toolkit/commands/run-tests.md` |
| 標準出力 | 「`/run-tests` コマンド生成完了 + argument-hint 検証合格」 |
| 終了状態 | 成功 |

## 引数なしコマンドの場合のサブシナリオ

引数を受け取らないコマンド（`$ARGUMENTS` 不参照）の場合:

| 項目 | 期待動作 |
|-----|---------|
| `argument-hint` | テンプレートから **行ごと削除** |
| 検証項目「`argument-hint` 存在」 | スキップ（引数なしのため不要）|

## 異常系: argument-hint 欠落

引数を受け取るのに `argument-hint` が指定されていない場合:

| モード | 動作 |
|-------|------|
| 対話モード | `AskUserQuestion` で argument-hint 設計を促す |
| 非対話モード | High 指摘でエラー終了（標準エラー出力に提示）|

## 分岐の根拠

ADR-023（`argument-hint` 必須化）の遵守確認、および引数有無による省略判定。

## 関連ケース

- `case-01_new_command_interactive.md`（対話モード新規作成）
- `case-05_non_interactive.md`（`--non-interactive` モード基本動作）
