# render-check (skill)

外部サービス（Backlog / Azure DevOps）へ投稿する本文が、投稿先のレンダリング方式で意図どおり表示されるかを **投稿前に** 検証するスキルです。記法不一致・意図しない自動リンクやメンション・構造崩れ・機密情報・サイズ超過を検出し、プレビューと修正案を提示します。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 責務（要約）

- 投稿本文のレンダリング検証（5 カテゴリ: NOTATION / AUTOLINK / STRUCTURE / SECRET / SIZE）
- 総合判定（PASS / WARN / FAIL）と修正案の提示
- 投稿プレビュー（レンダリング後の見え方の説明付き）の提示

実際の投稿・更新は行いません（`backlog` / `azure` スキルの責務）。

## 導入手順

### 前提

- Claude Code がインストール済み
- connector プラグインがインストール済み

## 使い方

起動経路は 2 つあります。

### 1. backlog / azure スキルからの自動ゲート（主用途）

`backlog` / `azure` スキルがコメント投稿・本文更新などの **書き込み操作を行う直前に、必須ゲートとして自動で本スキルを呼び出します**。ユーザーが明示的に起動する必要はありません。Backlog の記法設定（`textFormattingRule`）は呼び出し元が API で判定した値を引き継ぎます。

### 2. 単体起動（トリガーフレーズ例）

以下のフレーズで自動起動します。単体起動では投稿は行わず、結果レポートの提示で終了します。

- 「このコメントが Backlog で正しく表示されるかチェックして」
- 「投稿前にレンダリング確認して」
- 「この本文 TFS でどう見える？」

単体起動でターゲット記法が不明な場合（特に Backlog の記法設定が分からない場合）は、推測せず AskUserQuestion で確認してからチェックを実行します。

## 動作例（FAIL → 修正 → PASS）

Backlog 記法（`textFormattingRule="backlog"`）のプロジェクトに、次の Markdown 混じりの本文を投稿しようとした場合の流れです。

````text
## 修正内容

ログ出力の **強調表示** を追加しました。

```java
System.out.println("done");
```
````

1. **検出（FAIL）**: NOTATION で 3 件を検出します。`## 見出し`・`**太字**`・バッククォートのコードフェンスは Backlog 記法スペースではレンダリングされず、そのまま文字として表示されるため、行番号付きで FAIL を報告します
2. **修正案の提示**: 変換表に基づく修正済み本文を提示します（`## 修正内容` → `** 修正内容`、`**強調表示**` → `''強調表示''`、コードフェンス → `{code:java}` 〜 `{/code}`）
3. **再チェック（PASS）**: 採用すると修正後本文で 5 カテゴリ全てを再チェックし、検出なしで総合判定 PASS となり、確定本文を呼び出し元へ引き渡します

詳細な期待挙動は `evals/case-01_backlog_notation_fail.md` を参照してください。

## チェックカテゴリ

| カテゴリ | 検査内容 | 検出時の主な判定 |
|---------|---------|----------------|
| NOTATION | ターゲット記法と本文構文の整合（Markdown / Backlog 記法の混入検出） | 不一致 = FAIL（タスクリスト・打消し線など一部は WARN） |
| AUTOLINK | 自動リンク・メンション暴発（`@` / `#` / `!` / 課題キー）。メンションは通知が飛ぶことを明示 | WARN（ユーザー判断） |
| STRUCTURE | コードフェンス開閉・表の列数・リストネスト・HTML タグ開閉 | 崩れ = FAIL（区切り行・ヘッダ指定の欠落などは WARN） |
| SECRET | 機密情報パターン（トークン・キー・パスワード・秘密鍵）。コード領域も検査対象 | 確定的パターン = FAIL / ヒューリスティック = WARN |
| SIZE | 文字数上限・長文（Backlog 系 8,000 文字 / ADO PR 説明 4,000 文字が目安） | 超過 = WARN（分割を提案） |

### 判定の意味

| 判定 | 意味 |
|------|------|
| PASS | 問題なし。本文をそのまま呼び出し元へ引き渡す |
| WARN | ユーザー判断。「このまま投稿 / 修正する」を選択できる |
| FAIL | 投稿ブロック。選択肢は修正 or 中止のみ（FAIL のまま投稿する選択肢は提示されない） |

総合判定は FAIL（1 件でも FAIL）> WARN（FAIL なし・WARN あり）> PASS の順で決まります。機密情報の検出値はマスク（先頭 4 文字 + `***` + 末尾 4 文字）して報告され、フル値は会話に出力されません。

## ターゲット種別

| ターゲット | 投稿先 | 参照ルール（プラグイン共通 references） |
|-----------|-------|--------------------------------------|
| `backlog-notation` | Backlog（textFormattingRule=`backlog`） | `references/rendering/backlog-notation.md` |
| `backlog-markdown` | Backlog（textFormattingRule=`markdown`） | `references/rendering/backlog-markdown.md` |
| `ado-markdown` | Azure DevOps の PR 説明・PR コメント・クラウド作業項目コメント | `references/rendering/azure-devops-markdown.md` |
| `ado-workitem-html` | TFS 作業項目コメント（`System.History`、Markdown 非解釈） | 同上（セクション 1・5） |

## 関連スキル

| スキル | 関係 |
|-------|------|
| `backlog` | 呼び出し元。Backlog への書き込み前に本スキルを必須ゲートとして実行する |
| `azure` | 呼び出し元。Azure DevOps への書き込み前に本スキルを必須ゲートとして実行する |
| credentials-manager プラグイン | 責務外の認証情報管理を担当する |

## ファイル構成

```
skills/render-check/
├── SKILL.md                                  # スキル定義（Claude が実行時に読み込む）
├── README.md                                 # 本ファイル（人間向け・Claude 動作では不使用）
├── references/
│   └── check-procedures.md                   # 5 カテゴリ検査の適用手順（前処理・判定・結果組み立て）
└── evals/
    ├── README.md                             # ケース一覧と実行確認方法
    ├── case-01_backlog_notation_fail.md      # NOTATION FAIL → 修正採用 → 再チェック PASS
    ├── case-02_autolink_warn.md              # AUTOLINK WARN → このまま投稿
    ├── case-03_pass.md                       # 5 カテゴリ全 PASS
    ├── case-04_secret_fail.md                # SECRET FAIL → マスク報告 → 投稿中止
    ├── case-05_standalone_target_unknown.md  # 単体起動・ターゲット確認が先行
    ├── case-06_structure_fail.md             # フェンス未クローズを前処理で STRUCTURE FAIL
    ├── case-07_warn_user_fixes.md            # AUTOLINK WARN → 修正する → 再チェック PASS
    └── demo.sh                               # 構造検証スクリプト（読み取り専用）
```

検出パターンの定義本体はプラグイン共通の `../../references/rendering/` 配下（backlog-notation.md / backlog-markdown.md / azure-devops-markdown.md）にあります。

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `SKILL.md` | スキル定義とトリガー条件・実行フロー |
| `references/check-procedures.md` | 5 カテゴリ検査の適用手順 |
| `../../references/rendering/backlog-notation.md` | Backlog 記法の検出パターン・変換表 |
| `../../references/rendering/backlog-markdown.md` | Backlog Markdown の検出パターン・変換表 |
| `../../references/rendering/azure-devops-markdown.md` | Azure DevOps（PR / 作業項目）の検出パターン・変換表 |
| `evals/` | 動作分岐の期待挙動 |
