# Case 17: 非対話呼び出し時のテーマ扱い

## 入力

- 別スキルからの `Skill(skill: "convert-pptx", args: ...)` 呼び出し（対話不可の文脈）
- パターン A: args に `--theme` 指定なし
- パターン B: args に `--theme "<パス>"` 指定あり

## 期待動作

1. テーマ選択の `AskUserQuestion` / テキスト選択を **一切出さない**（テーマ以外の引数 `--aspect` / `--title` 等も含め、確認プロンプトなしで args の値をそのまま適用する）
2. パターン A: `--theme` を付けずデフォルトデザインで変換する
3. パターン B: 指定された `--theme` をそのまま渡して変換する

## 期待出力

- 対話プロンプトなしで完了した PPTX（A: デフォルトデザイン、B: 指定テーマ適用）

## 分岐の根拠

`references/theme-selection.md`「非対話時の動作」:
> 別スキルからの `Skill(...)` 呼び出しなど対話が難しい場合は、選択 UI を出さず以下を適用する
> - 呼び出し引数に `--theme` があればそれを使用
> - なければデフォルトデザイン

## 関連ケース

- [case-12_noninteractive_aspect.md](case-12_noninteractive_aspect.md): 非対話でのアスペクト比指定
- [case-18_theme_named_resolution.md](case-18_theme_named_resolution.md): ユーザーがテーマ名を明示した場合
