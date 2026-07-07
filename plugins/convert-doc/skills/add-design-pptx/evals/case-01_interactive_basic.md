# Case 01: 対話モードの基本フロー

## 入力

- ユーザー依頼: 「PPTX にコーポレートグリーンのデザインテーマを追加して」
- デザイン名・詳細は未指定

## 期待動作

1. `AskUserQuestion` 等でデザイン名（kebab-case）と変更範囲（色のみ等）を確定する
2. セッション作業フォルダと venv を構築する
3. `--dump-default-theme` でデフォルト値を取得する
4. 変更キーのみの部分指定でテーマ JSON を `workspace/` に生成する
5. `validate_theme.py` で `RESULT: PASS` を確認する
6. サンプル MD を `--theme` 付きで変換し `Generated:` を確認する
7. 配置先（開発 / 利用者モード）を判定・提示し、承認後に配置する
8. `convert-pptx` での使い方を案内し、venv を削除する

## 期待出力

- 検証 PASS 済みのテーマ JSON が配置先に存在
- サンプル PPTX がセッションフォルダに生成されユーザーに提示される

## 分岐の根拠

`SKILL.md`「実行フロー」1〜10。

## 関連ケース

- [case-02_noninteractive_full.md](case-02_noninteractive_full.md): 非対話モード
