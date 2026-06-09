# Case 04: 非対話モードでの直接適用

## シナリオ

CI スクリプトや `marketplace-publish` のフルオートフローから呼ばれ、対話なしで適用する。

## 入力

```text
/extension license bar-toolkit --non-interactive --copyright-year 2026 --copyright-holder "Acme Corp" --author "Acme Corp" --no-save
```

事前状態:
- `plugins/bar-toolkit/` 配下に LICENSE / `plugin.json.license` なし

## 期待動作

1. `--non-interactive` を検出 → `AskUserQuestion` を一切呼ばない
2. 引数値で確定:
   - `copyright_year=2026` / `copyright_holder=Acme Corp` / `author=Acme Corp`
3. `--no-save` のため `license-info.json` には書き込まない
4. `plugins/bar-toolkit/LICENSE` 生成 + `plugin.json.license = "MIT"`
5. 検証 PASS

## エラーシナリオ

```text
/extension license bar-toolkit --non-interactive
```

引数不足（`--copyright-holder` 不在）→ エラー終了、`AskUserQuestion` を呼ばずにエラーメッセージを返す。

```text
/extension license bar-toolkit --non-interactive --license-id unknown
```

`license-info.json` に `id=unknown` のエントリがない → エラー終了、利用可能 ID 一覧を提示。

## 失敗条件

- `--non-interactive` で対話を始めてしまう
- 引数不足でデフォルト値を勝手に使う（`copyright_holder` は必須）
- `--save` 明示なしでストアに書き込む（デフォルトは `--no-save`）
