# Case 03: license-info.json 不在時に新規収集

## シナリオ

新規ユーザがプラグインを作成中。`license-info.json` がまだ存在しない。

## 入力

ユーザ:
> 新規プラグイン `foo-toolkit` に MIT ライセンスを追加

事前状態:
- `license-info.json` が `<repo_root>/.claude/.local/plugins/extension-toolkit/` `~/.claude/.local/plugins/extension-toolkit/` の **両方に** 不在

## 期待動作

1. ストアを探索 → 不在を検出
2. テキスト対話で以下を順次収集:
   - `copyright_holder`: `Taro Yamada`
   - `copyright_year`: 現在年（システム日付）をデフォルト、ユーザが Enter で確定
   - `author`: デフォルトは `copyright_holder` と同値
   - `label`: デフォルト `Taro Yamada用`、ユーザが `個人用` に変更
3. **AskUserQuestion** で「保存する / 一時利用のみ」を確認
4. ユーザが「保存する」を選択
5. `<repo_root>/.claude/.local/plugins/extension-toolkit/license-info.json` を新規作成（親ディレクトリも自動作成）
6. `plugins/foo-toolkit/LICENSE` 生成 + `plugin.json.license = "MIT"`
7. 検証 PASS

## 期待 license-info.json

```json
{
  "version": 1,
  "licenses": [
    {
      "id": "taro-yamada",
      "type": "MIT",
      "copyright_year": "2026",
      "copyright_holder": "Taro Yamada",
      "author": "Taro Yamada",
      "label": "個人用"
    }
  ]
}
```

## 失敗条件

- `AskUserQuestion` を呼ばずに保存してしまう（保存可否は重要選択）
- `license-info.json` を `.gitignore` 対象でない場所に保存する
- 親ディレクトリ未作成でファイル書き込み失敗
- `--non-interactive` で `--copyright-holder` 未指定にもかかわらず処理を続行
