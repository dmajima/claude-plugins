# Case 03: スキーマ検証 FAIL → 修正リトライ

## 入力

- 生成したテーマ JSON に誤りがある状態（例: `colors.primaryy` のタイポ、`"string"` に不正色 `"green"`）

## 期待動作

1. `validate_theme.py` が `[FAIL] theme: unknown key 'colors.primaryy' ...` 等を出力し exit 1
2. エラーメッセージに従い JSON を修正する（キー名修正・hex 形式化）
3. 再度 `validate_theme.py` を実行し `RESULT: PASS` を得る
4. **PASS になるまで配置に進まない**

## 期待出力

- 最終的に PASS したテーマ JSON のみが配置される
- FAIL のまま配置された形跡がない

## 分岐の根拠

`SKILL.md`「重要な制約」:
> テーマ JSON は必ず `validate_theme.py` の PASS とサンプル変換の成功を確認してから配置する

## 関連ケース

- [case-08_dark_theme_contrast.md](case-08_dark_theme_contrast.md): 検証は通るが品質調整が必要なケース
