# Case 05: 認証情報なし（API を呼ばず停止）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "ProjectBoard のタスクを取得して https://newtenant.pm.apps.worksap.com/wbs/project/abc123XYZ/issue/qQq" |
| 引数 | 未登録テナント `newtenant` のシート URL |
| フラグ | なし（対話モード） |
| 既存状態 | credentials.json の `hue-projectboard` エントリの `domains` に `newtenant.pm.apps.worksap.com` が**含まれない**（ワイルドカード `pm.apps.worksap.com` も未登録）、または `hue-projectboard` エントリ自体が存在しない |

## 期待動作

### Phase 1: 認証事前確認（ここで停止）
- URL から tenant `newtenant` を抽出する
- credentials.json の `hue-projectboard` を照合し、以下のいずれかで不適合と判定する:
  - エントリが存在しない
  - `domains` にホストが合致しない
  - username / value が空
- **API（ログイン含む）を一切呼ばずに停止する**

### Phase 2: ユーザーへの案内
- 不足している内容（エントリなし / ドメイン未登録）を具体的に伝える
- credentials-manager での登録手順（type=password / username=メール / auth_method=form:email:password /
  domains にテナントホスト）を案内する
- ユーザーが情報を整えるまで操作は進まない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（cookies.txt も生成されない） |
| 標準出力（要約） | 認証情報不足の指摘 + credentials.json への登録手順の案内 |
| 終了状態 | 停止（API 未呼び出し） |

## 分岐の根拠

認証事前確認（Step 1）が不適合の場合、login.sh を含む全ての外部アクセスを行わない。
domains 照合に合致しないテナントへのアクセス禁止は SKILL.md の重要な制約
（safe-api-access.md のホワイトリスト原則）である。

## 関連ケース

- `case-01_task_read.md`（認証情報が揃っている正常系）
- `case-06_session_expired.md`（認証情報はあるがセッションが切れた場合）
