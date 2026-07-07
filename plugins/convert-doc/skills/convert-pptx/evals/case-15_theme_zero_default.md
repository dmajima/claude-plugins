# Case 15: テーマ 0 個（選択 UI なし）

> 前提の注意: v4.0.0 以降の配布状態ではサンプルテーマ `dark-console.json` が
> `${CLAUDE_PLUGIN_ROOT}/assets/pptx-themes/` に同梱されるため、クリーンインストールの
> 既定は 1 件（→ [case-13](case-13_theme_selection.md) の分岐）になる。本ケースは
> 「0 件」分岐の仕様検証であり、サンプルを除去したカスタム構成で成立する
> （README ADR-004 のトレードオフ参照）。

## 入力

- 3 箇所（skill / plugin / ローカル designs）のいずれにもテーマ JSON が存在しない状態
- ユーザー依頼: 「この MD をスライドにして」（対話モード・テーマ未指定）

## 期待動作

1. テーマ列挙の結果が 0 件であることを確認する
2. **テーマ選択の `AskUserQuestion` を出さない**
3. `--theme` を付けずに変換する（内蔵デフォルトデザイン）

## 期待出力

- 従来どおりのデフォルトデザイン（ネイビー基調）の PPTX
- テーマに関する対話プロンプトが一切表示されない

## 分岐の根拠

`references/theme-selection.md`「選択の分岐」:
> 0 | 選択 UI を出さずデフォルトデザインで変換する

## 関連ケース

- [case-01_normal_with_h2.md](case-01_normal_with_h2.md): デフォルトデザインでの標準変換
- [case-13_theme_selection.md](case-13_theme_selection.md): テーマが存在する場合
