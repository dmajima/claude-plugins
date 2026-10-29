# Case 02: 非対話モード（要件全指定）

## 入力

- ユーザー依頼: 「デザイン名 warm-paper、primary #8D6E63、code_bg #FFF8E1 で PPTX テーマを追加。確認不要で進めて」

## 期待動作

1. デザイン名・色が確定しているため `AskUserQuestion` を出さずに進行する
2. テーマ JSON 生成 → `validate_theme.py` PASS → サンプル変換成功まで自動で実施する
3. 配置先判定も自動で行い、結果（配置先パス）を報告する

## 期待出力

- 確認プロンプトなしで配置まで完了
- 実施内容（生成・検証・変換・配置先）の要約報告

## 分岐の根拠

`SKILL.md`「実行モード判定」:
> デザイン名と要件（色等）が引数で全指定 → 非対話

## 関連ケース

- [case-01_interactive_basic.md](case-01_interactive_basic.md): 対話モード
