# セキュリティ動的チェック手順（test-run-security 固有）

`test-run-security` が OWASP 観点の動的チェックを実行する際の固有手順。
実行共通規範・エビデンス要件・データ配置・severity 判定・機微情報マスキング・中間結果フォーマットは重複記載せず、`${CLAUDE_PLUGIN_ROOT}/references/` の各 SSOT を参照する（本ファイルは観点別チェックの実務と操作境界のみを扱う）。

---

## 0. 実行してよい操作 / 禁止操作の境界（最初に確認）

本スキルは「稼働中アプリの非破壊的な動的チェック」に限定される。実行前に必ず本境界を確認する。

### 0.1 実行してよい操作

- 承認済みケース（test-cases.yaml）に**記載された範囲**の確認操作（対象システム所有者の合意範囲内）
- 保護リソースへの未認証アクセス**可否の確認**（到達できるかの判定。到達後にデータを改変しない）
- HTTP ヘッダ・Cookie 属性・レスポンス内容の**観察**（`curl -I` / `browser_network_requests`）
- **無害な**検証用ペイロードの入力と、その**反射・エラー表示の観察**（下記 3 章の無害ペイロードのみ）
- エラーページ・HTML コメント・公開ディレクトリの**閲覧**

### 0.2 禁止操作（実行しない）

| 禁止 | 理由 |
|------|------|
| 実データの改変・削除・作成を伴う攻撃 | 破壊的操作。環境汚染・データ破壊のリスク |
| DoS・総当たり（ブルートフォース）・大量リクエスト | 可用性への破壊的影響 |
| 権限昇格の**実行**（他者データの実際の窃取・改変） | 到達可否の確認に留め、実害を発生させない |
| エクスプロイトの実証・攻撃連鎖 | ペネトレーションテストの領域（対象外。`${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` 8 章） |
| 承認済みケースに記載のない対象・操作 | 所有者の合意範囲外 |
| 本番環境への実行 | 既定で禁止（`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 環境安全） |

- 禁止操作に該当する検証は**実施せず**、その旨を actual / reason に記録する（「未確認: 破壊的検証のため実施せず」等）
- 判断に迷う操作は実行せず、ケースの承認範囲を確認する（範囲外なら skipped + reason）

## 1. 前段: 環境・範囲・MCP の確認

1. 対象が**テスト環境**であることを確認する（本番 URL なら実行しない。test-levels.md 4.8 入口基準）
2. 実行対象が承認済みケースの範囲内であることを確認する
3. Playwright MCP のロード状態を初回ブラウザ操作前に確認する。未ロードなら Playwright を要する観点のケースを `skipped` + reason（MCP 未ロード）で返す（`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 条件付き動的検証）。ヘッダ確認のみ `curl` で完結するケースは Bash で継続してよい

## 2. 観点別チェック手順

### 2.1 認証（未認証アクセス制御・認証エラー時の情報露出）

| チェック | 手順 | 欠陥の判断 |
|---------|------|-----------|
| 未認証アクセス制御 | ログアウト状態（または新規セッション）で保護 URL へ `browser_navigate`。到達可否を観察する | 未認証でも保護コンテンツに到達できる → fail（認可不備） |
| 認証エラー時の情報露出 | 誤った認証情報でログイン試行し、エラーメッセージを観察する | 「ユーザーが存在しない」等でアカウント有無を示唆する / 内部例外を露出する → fail |

- 到達可否の**確認**に留め、到達後にデータを操作しない（0.2 禁止操作）

### 2.2 セッション管理（ログアウト後の無効化・Cookie 属性）

| チェック | 手順 | 欠陥の判断 |
|---------|------|-----------|
| ログアウト後のセッション無効化 | ログイン → セッション Cookie を記録 → ログアウト → 記録した保護 URL へ再アクセス（同一セッション） | ログアウト後もセッションが有効で保護コンテンツに到達 → fail（セッション残存） |
| Cookie 属性 | `browser_network_requests` のレスポンスヘッダ、または Bash `curl -I` で `Set-Cookie` を観察する | `Secure` / `HttpOnly` / `SameSite` の欠如 → fail |

Cookie 属性の確認コマンド例（Bash）:

```bash
# Set-Cookie 行の属性を観察する（-k は自己署名証明書のテスト環境向け。読み取りのみ）
curl -sk -I "https://localhost:5001/login" | grep -i '^set-cookie:'
# 期待: Secure; HttpOnly; SameSite=Lax|Strict 等が付与されていること
```

- セッション ID・Cookie 値そのものは機微情報。記録・報告時はマスクする（5 章）

### 2.3 入力検証（XSS 反射・SQL エラー露出・パストラバーサル基礎）

| チェック | 手順 | 欠陥の判断 |
|---------|------|-----------|
| XSS 反射確認 | 入力欄・クエリパラメータに**無害な**マーカー文字列を入力し、エスケープされずに反射・実行されるか観察する | 無害マーカーが HTML/JS として解釈される（`browser_handle_dialog` で無害 alert を検知等）→ fail |
| SQL エラーメッセージ露出 | 単一引用符等の境界文字を入力し、DB エラーメッセージがそのまま露出するか観察する | SQL 例外・スタックトレースが画面に露出 → fail（情報露出。実際のインジェクションは行わない） |
| パストラバーサル基礎 | ファイル参照パラメータに `../` 等の基礎パターンを入力し、想定外パスへ到達するか観察する | 範囲外ファイルの内容が返る兆候 → fail（内容の窃取・改変は行わず、到達兆候の観察に留める） |

**無害ペイロードの原則**:

- 破壊を伴わない検知用マーカーのみを用いる（例: XSS 検知は `alert()` のように**視覚的検知だけ**で副作用のない最小ペイロード。データ改変・外部送信・Cookie 窃取スクリプトは使わない）
- SQL・パストラバーサルは「エラー露出・到達兆候の**観察**」に留め、データ抽出・改変を行わない（0.2 禁止操作）
- 反射確認で使用したペイロード文字列はエビデンス・reproduction_steps に残す（再現のため。ただし機微情報は含めない）

### 2.4 セキュリティヘッダ（CSP・X-Frame-Options・HSTS 等）

`browser_network_requests` のレスポンスヘッダ、または Bash `curl -I` で主要セキュリティヘッダの有無・設定値を観察する。

```bash
# 主要セキュリティヘッダの観察（読み取りのみ）
curl -sk -I "https://localhost:5001/" | grep -iE '^(content-security-policy|x-frame-options|strict-transport-security|x-content-type-options|referrer-policy):'
```

| ヘッダ | 欠如/不備の例 |
|-------|-------------|
| `Content-Security-Policy` | 未設定 / `unsafe-inline` 等の緩い設定 |
| `X-Frame-Options` / CSP `frame-ancestors` | 未設定（クリックジャッキング耐性なし） |
| `Strict-Transport-Security`（HSTS） | 未設定（HTTPS 強制なし） |
| `X-Content-Type-Options: nosniff` | 未設定 |

- 欠如・不備は fail とし、`owasp_category` に該当カテゴリ（例: A05:2021 Security Misconfiguration）を記録する

### 2.5 情報露出（スタックトレース・コメント内機密・ディレクトリリスティング）

| チェック | 手順 | 欠陥の判断 |
|---------|------|-----------|
| エラーページのスタックトレース | 意図的にエラーを誘発（不正入力・存在しない URL）し、スタックトレース・内部パスが露出するか観察する | 詳細スタックトレース・フレームワーク内部情報の露出 → fail |
| コメント内機密 | ページ HTML ソース・JS のコメントに認証情報・内部 URL・TODO 等の機密が含まれるか観察する | 機密がコメントに残存 → fail（露出値はマスクして記録） |
| ディレクトリリスティング | 一般的な公開ディレクトリ（例: `/uploads/`）へアクセスし、一覧が表示されるか観察する | ディレクトリ一覧が閲覧可能 → fail |

## 3. 判定と severity

- 検出した欠陥は `status: fail` とし、`defect.extras.owasp_category` に該当カテゴリを記録する（フィールド定義は `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 4 章）
- severity は**悪用可能性と影響範囲**で判定する。判定基準の SSOT は `${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md` 4.2（OWASP 対応表。本ファイルに複製しない）
- 悪用の成立（実際に権限外データへ到達できた等）を確認できた場合は 1 段階の引き上げを検討し、理由を defect に記録する（severity-policy.md 4.2）
- 対象外領域（ペネトレーションテスト・SCA・SAST）は「未確認」として扱い「問題なし」と結論しない（test-levels.md 8 章。報告書側の未確認事項記載は report-format.md）

## 4. エビデンス

| エビデンス | 内容 |
|-----------|------|
| リクエスト/レスポンス記録 | 確認したヘッダ・Set-Cookie・エラーレスポンス（テキスト。機微情報マスク済み） |
| スクリーンショット | 未認証到達画面・エラー画面・反射結果等 |
| コンソールログ | XSS 検知時等の `browser_console_messages` テキスト |

- すべてステップ実行直後に `evidence/{run_id}/{case_id}/` へ move する（`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 5 章）
- テキスト系エビデンスは**保存前に**機微情報を置換してから保存する（5 章）

## 5. 機微情報マスキング手順（本スキルは特に高頻度）

セキュリティテストのエビデンスは認証情報・トークン・セッション ID・個人情報を含む頻度が高い。マスク形式・対象・タイミングの SSOT は `${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 5 章。本スキルでの適用手順:

| タイミング | 手順 |
|-----------|------|
| テキストエビデンス保存時 | Set-Cookie 値・Authorization ヘッダ・トークン・パスワード・個人情報を、保存前にマスク形式（9 文字以上=先頭4+`****`+末尾4 / 8 文字以下=`********`）へ置換する |
| スクリーンショット | 機微情報が画面に表示される手順を避ける設計にする。表示が避けられない場合は当該領域を扱いに注意し、報告転載時にマスク画像へ差し替える |
| actual / reason / defect | マスク値のみを記載する。生値を書かない。マスクで再現に必要な情報が欠ける場合は「値の取得方法・格納場所」を reproduction_steps に記載する（evidence-policy.md 5.3） |

- 報告書への転載時マスクは必須（report-format.md）。本スキルは中間データ返却時点で既にマスク済みの値のみを渡す

## 6. 達成チェックリスト（返却前）

```
[ ] 実行環境がテスト環境であることを確認済み（本番でない）
[ ] 実行操作が承認済みケースの範囲内（所有者合意範囲内）に限定されている
[ ] 破壊的攻撃（実データ改変・削除・DoS・総当たり）を実行していない
[ ] XSS 等は無害ペイロードのみを使用し、データ改変・窃取を行っていない
[ ] fail に extras.owasp_category を記録している
[ ] severity を severity-policy.md 4.2（OWASP 対応表）で判定している（引き上げ時は理由を記録）
[ ] 対象外領域（ペネトレーションテスト・SCA・SAST）を「未確認」とし「問題なし」と書いていない
[ ] エビデンスの機微情報をマスク済み（テキストは保存前に置換）
[ ] actual / reason / defect に機微情報の生値を書いていない
[ ] fail に defect 3 点セット（reproduction_steps / test_data / evidence）を収集している
[ ] scope の全ケースに 1 エントリを返している（skipped/blocked も reason 付き）
[ ] executed_by / evidence を各エントリに埋めている
[ ] test-results.yaml を直接編集していない（返却のみ）
```

## 7. 関連 references

| 参照先 | 内容 |
|-------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` | security の定義・入口/出口基準・スコープ境界（8 章） |
| `${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md` | 4.2 セキュリティテストの severity 判定（OWASP 対応表） |
| `${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` | fail 時 defect 3 点セット・機微情報マスキング（5 章） |
| `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` | 中間結果返却フォーマット（4 章）・環境安全・条件付き動的検証 |
| `${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` | browser_network_requests / browser_handle_dialog・エビデンス出力 |
| `${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` | エビデンス移送（5 章）・パス規約 |
| `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` | results / defect / extras（owasp_category） |
