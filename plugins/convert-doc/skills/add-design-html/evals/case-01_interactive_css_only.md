# Case 01: 対話モード・CSS のみの基本フロー

## 入力

- ユーザー依頼: 「HTML 資料に温かみのある紙っぽいデザインを追加して」
- デザイン名・詳細は未指定

## 期待動作

1. `AskUserQuestion` 等でデザイン名（kebab-case）と HTML 構造変更の要否を確定する（既定: CSS のみ）
2. セッション作業フォルダと venv を構築する
3. `template.css` と `css-contract.md` を読み込み、契約セレクタを網羅した新 CSS を `workspace/` に生成する
4. `validate_css.py` で `RESULT: PASS` を確認する
5. サンプル MD を `--css-template` 付きで変換し HTML 生成を確認する
6. 配置先（開発 / 利用者モード）を判定・提示し、承認後に配置する
7. `convert-html` / `convert-pdf` での使い方を案内し、venv を削除する

## 期待出力

- 検証 PASS 済みのデザイン CSS が配置先に存在
- サンプル HTML がセッションフォルダに生成されユーザーに提示される
- デフォルト `template.css` / `template.html` は無変更

## 分岐の根拠

`SKILL.md`「実行フロー」1〜10、「HTML 構造変更の原則」:
> 既定は CSS のみ

## 関連ケース

- [case-04_html_pair_generation.md](case-04_html_pair_generation.md): HTML 変更が必要な場合
