# Playwright MCP 利用規約（playwright-mcp）

`deep-test` プラグインが実動作テストに用いる Playwright MCP のセットアップ・既存登録検出・実利用可否判定・正本ツールリスト・エビデンス出力の規約 SSOT。
セットアップ実務は `test-setup` スキル、実行時利用は各実行スキルが本規約に従う。

> 2 モードの棲み分け: 本ファイルは **探索的モード**（Playwright MCP でその場操作する正本。`automation: playwright` / `executed_by: playwright-mcp`）を規定する。一方、**再現可能モード**（`.spec.ts` + フィクスチャを `npx playwright test` で反復実行する。`automation: playwright-test`）の正本は `playwright-test.md`（fixtures.yaml スキーマ・Playwright Test 実行規約・認証/モック/シードのパターン規範）である。両者は補完関係であり、本ファイルの正本ツールリスト等の規定は不変。

---

## 1. 登録手順（新規登録時）

既存登録が無い場合のみ（セクション 2 の検出を先に実施）、以下のコマンドで登録する。

```bash
claude mcp add playwright -s local \
  -- cmd /c npx '@playwright/mcp@latest' \
  --headless \
  --output-dir '.claude/.local/plugins/deep-test/playwright' \
  --ignore-https-errors
```

| 要素 | 規範 | 理由 |
|------|------|------|
| `-s local` | 必須 | ローカルスコープ登録。リポジトリのファイルを汚染しない |
| `--headless` | 必須 | ヘッドレス原則（セクション 7） |
| `--output-dir '.claude/.local/plugins/deep-test/playwright'` | 必須（固定） | raw 出力先の固定。基準ディレクトリ（リポジトリ配下 / ホーム）の解決は data-locations.md 参照 |
| `--ignore-https-errors` | 必須 | ローカル開発環境の自己署名証明書による SSL エラーを無視する |

- Windows 環境では `cmd /c npx` 経由で起動する（上記コマンドのまま使用する）
- 登録を行った場合は、必ずセクション 3 の再起動ハンドオフを実施する

## 2. 既存登録の検出と再利用

登録前に必ず `claude mcp list` を実行し、playwright 系サーバー（名前が `playwright` の登録、または Playwright MCP を起動コマンドに持つ登録）の有無を確認する。

| 状況 | 対応 |
|------|------|
| 既存登録あり | **再利用**する。重複登録・上書き（remove して add し直す等）は禁止 |
| 既存登録の output-dir が本規約と異なる | raw 出力先を**その設定値として扱い**、data-locations.md の移送規約を適用する（エビデンスの最終配置が `evidence/{run_id}/{case_id}/` である点は不変） |
| 既存登録の output-dir が判別できない | Playwright MCP の既定出力先が使われるものとして、スクリーンショット取得結果の実パスから raw 出力先を特定し、同様に移送規約を適用する |
| 既存登録なし | セクション 1 の手順で新規登録する |

- ツール名プレフィクスは登録名に従い `mcp__{サーバー名}__` となる。既定の登録名 `playwright` では `mcp__playwright__*`。異なる名前で登録済みの場合は、ToolSearch の実結果に表れる実プレフィクスを使用する（本書の `mcp__playwright__*` 表記は読み替える）

## 3. セッション再起動制約と再起動ハンドオフ

Claude Code は**起動時に MCP サーバーをロード**するため、登録直後の同一セッションでは `mcp__playwright__*` ツールは利用できない。

登録を行った場合は、以下の再起動ハンドオフを**必ず**出力して停止する。

1. 状態保存の確認: test-cases.yaml / test-results.yaml 等の状態は既に永続化済みであることを明記する
2. 再起動依頼: MCP ツールがセッション起動時にのみロードされるため Claude Code の再起動が必要である旨を 1〜2 文で説明する
3. 再開手順の提示: 再起動後に `/deep-test:test resume` で中断箇所から継続できること（run 未開始の場合は元のコマンドを再実行すればよいこと）を示す

ハンドオフメッセージ例:

> Playwright MCP を登録しました。MCP ツールは Claude Code の起動時にロードされるため、続行には再起動が必要です。
> 状態（テストケース・実績 YAML）は保存済みです。Claude Code を再起動後、`/deep-test:test resume` を実行すると中断箇所から再開します。

## 4. ツール利用可否の実判定（MCP ゲートの判定方法）

登録済みに見えても現セッションでロードされていない場合があるため、**実利用可否は ToolSearch で判定**する。オーケストレータの MCP ゲート（execution-policy.md）はこの手順を用いる。

1. ToolSearch で `mcp__playwright__` 系ツールを検索する（例: `select:mcp__playwright__browser_snapshot`、またはキーワード `+mcp__playwright__ browser`）
2. スキーマが取得できた → **利用可**（MCP ゲート通過）
3. 1 件もマッチしない → **未ロード**（MCP ゲート停止 → セクション 3 の再起動ハンドオフ）

- `claude mcp list` の登録有無だけで「利用可」と判定してはならない（登録直後のセッションでは未ロード）
- 実行スキル側でも、初回のブラウザ操作前にツールがロード済みであることを前提にせず、未ロードを検出した場合は実行を偽装せずオーケストレータへ skipped + reason で返却する（execution-policy.md 条件付き動的検証）

## 5. 正本ツールリスト

各実行スキルが利用する Playwright MCP ツールの**正本リスト**。各実行スキルの frontmatter（allowed-tools 等）に列挙する MCP ツールは、本リストからコピーして同期する（**同期義務**: 本リスト改訂時は利用側スキル全件へ反映する）。

> 注記: `@playwright/mcp` のバージョンによりツール名・有無に差異がある場合は、**実環境の ToolSearch 結果を優先**する。差異を検出した時点で本リストを改訂し、各スキルへ再同期する。

| ツール（`mcp__playwright__` プレフィクスを付けて使用） | 用途 |
|---------------------------------------------------|------|
| `browser_navigate` | 指定 URL へ遷移する |
| `browser_navigate_back` | 直前のページへ戻る |
| `browser_click` | 要素をクリックする（要素 ref は直近の snapshot から取得） |
| `browser_type` | 要素へテキストを入力する |
| `browser_press_key` | キーボードのキーを押下する |
| `browser_hover` | 要素へマウスオーバーする |
| `browser_select_option` | ドロップダウンの選択肢を選択する |
| `browser_snapshot` | アクセシビリティスナップショットを取得する（要素 ref の取得元・失敗時エビデンス） |
| `browser_take_screenshot` | スクリーンショットを保存する（エビデンス収集の中核） |
| `browser_console_messages` | ブラウザコンソールのメッセージを取得する（失敗時エビデンス） |
| `browser_network_requests` | ネットワークリクエスト一覧を取得する（API 連携確認・性能補助情報） |
| `browser_evaluate` | ページ上で JavaScript を実行する（性能計測値の取得等） |
| `browser_wait_for` | テキストの出現・消滅・時間経過を待機する |
| `browser_fill_form` | 複数のフォームフィールドを一括入力する |
| `browser_handle_dialog` | alert / confirm 等のダイアログに応答する |
| `browser_tabs` | タブの一覧・作成・切替・クローズを行う |
| `browser_resize` | ブラウザウィンドウのサイズを変更する（レスポンシブ確認） |
| `browser_close` | ページを閉じる（実行終了時の後片付け） |

## 6. エビデンス出力

| 項目 | 規範 |
|------|------|
| filename 指定 | `browser_take_screenshot` は `filename` を**必ず指定**する（未指定の自動命名は raw 出力先での特定を困難にする） |
| 保存先 | filename を指定しても保存先は raw 出力先（`--output-dir`、既定 `.claude/.local/plugins/deep-test/playwright/`）配下の**フラット配置**となる |
| 推奨 filename | `{case_id}_{ステップ番号 2 桁}_{ラベル}.png`（例: `TC-FUNC-001_03_submit.png`）。raw 出力先は複数ケースのファイルが混在するため、ファイル名だけでケースとステップを識別できるようにする |
| 移送 | 取得ステップの**直後**に `evidence/{run_id}/{case_id}/` へ移送する（移送手順・移送後の命名詳細は data-locations.md 参照） |
| テキスト系 | `browser_console_messages` / `browser_network_requests` の取得結果は、テキストファイルとして evidence/ に保存する |
| 機微情報 | 保存時のマスキング配慮は evidence-policy.md に従う |

## 7. ヘッドレス原則・待機・対象 URL

### 7.1 ヘッドレス原則

- 実行は常にヘッドレス（`--headless` で登録済み）。可視ブラウザの表示を前提にした手順を組まない
- 画面の目視確認はスクリーンショット・アクセシビリティスナップショットで代替する

### 7.2 待機・タイムアウト

- 固定時間の待機ではなく、`browser_wait_for` による条件待機（テキストの出現・消滅）を優先する
- ケース単位タイムアウト（既定 120 秒・上書き可）と超過時の blocked 記録は execution-policy.md に従う

### 7.3 対象 URL の扱い

| 項目 | 規範 |
|------|------|
| スキーム | http / https のいずれも対象化できる |
| 自己署名証明書 | `--ignore-https-errors`（登録時必須）により証明書エラーは無視される。ケース側での追加設定は不要 |
| 本番環境 URL | 既定で禁止（execution-policy.md 環境安全に従う） |

## 8. 関連 references

| ファイル | 参照内容 |
|---------|---------|
| execution-policy.md | MCP ゲートの位置付け・タイムアウト・環境安全・条件付き動的検証 |
| data-locations.md | raw 出力先の基準ディレクトリ解決・evidence/ への移送手順 |
| evidence-policy.md | エビデンス必須要件・機微情報マスキング |
