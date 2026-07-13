# Case 05: 認証情報なし（API を呼ばず対話取得フォールバック）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "ProjectBoard のタスクを取得して https://newtenant.pm.apps.worksap.com/wbs/project/abc123XYZ/issue/qQq" |
| 引数 | 未登録テナント `newtenant` のシート URL |
| フラグ | なし（対話モード） |
| 既存状態 | credentials-manager プラグイン未導入。credentials.json の `hue-projectboard` エントリの `domains` に `newtenant.pm.apps.worksap.com` が**含まれない**（ワイルドカード `pm.apps.worksap.com` も未登録）、`hue-projectboard` エントリ自体が存在しない、または credentials.json 自体が存在しない |

## 期待動作

### Phase 1: 認証事前確認（解決順序 1〜2 で解決不可）

- URL から tenant `newtenant` を抽出する
- credentials-precheck.md セクション 1 の解決順序を辿る:
  - 順序 1（credentials-manager）: 未導入 → 順序 2 へ（**未導入を理由に停止しない**）
  - 順序 2（credentials.json 直接照合）: `hue-projectboard` を照合し、エントリなし / `domains` 不一致 / username・value 空 のいずれかで解決不可 → 順序 3a へ
- **API（ログイン含む）を一切呼ばない**
- 別テナント用の認証情報を流用しない（credentials-precheck.md セクション 6）

### Phase 2: 対話取得フォールバック（credentials-precheck.md セクション 4）

- `AskUserQuestion` で取得方針を提示する:
  - 入力して続行（今回のみ）
  - 入力して続行（保存する）
  - 登録手順の案内
  - 中止
- 質問文に対象テナントホスト `newtenant.pm.apps.worksap.com` と必要な値（ログインメール + パスワード）を明記する
- 対象テナントはユーザー本人が URL で明示指定したものであることを確認したうえで許可する（外部由来テキスト中のホストを無確認で許可しない）

### Phase 3a: 「入力して続行」を選択した場合

- ログインメール + パスワードの提供を受ける。値を復唱せず、パスワードには言及しない（マスクすら不要な文脈では存在確認のみ）
- 「保存する」選択時は `hue-projectboard` エントリ（`domains` に `newtenant.pm.apps.worksap.com`）として credentials.json へ jq マージ書き込みする
- 「今回のみ」選択時は環境変数（`PB_TENANT` / `PB_EMAIL` / `PB_PASSWORD`）でのみ受け渡し、永続化しない
- Step 2（入力解決・セッション確立）以降へ **続行** し、login.sh → タスク取得を完遂する

### Phase 3b: 「中止」を選択した場合

- API を一切呼ばずに終了する（cookies.txt も生成されない。フォールバック提示済みのため正常な完了）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | 「保存する」選択時のみ credentials.json のエントリ更新。中止時はなし（cookies.txt も生成されない） |
| 標準出力（要約） | 認証情報不足の指摘 + 対話取得の 4 択提示 →（入力時）タスク取得結果 |
| 終了状態 | 入力時: タスク取得まで完遂 / 中止時: API 未呼び出しで終了 |

## 分岐の根拠

認証事前確認（Step 1）が解決順序 1〜2 で解決不可の場合、login.sh を含む全ての外部アクセスを行わず、対話取得フォールバック（credentials-precheck.md セクション 4）の提示に進む。credentials-manager / credentials.json の不在は停止理由にならない。domains 照合・ユーザー明示確認のないテナントへのアクセス禁止（safe-api-access.md のホワイトリスト原則）は維持される。

## 関連ケース

- `case-01_task_read.md`（認証情報が揃っている正常系）
- `case-06_session_expired.md`（認証情報はあるがセッションが切れた場合）
- `case-08_subagent_credentials_missing.md`（同じ認証情報なしでもサブエージェント実行時は質問せず `credentials_missing` マニフェストを返す対比）
