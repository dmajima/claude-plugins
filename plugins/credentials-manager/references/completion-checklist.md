# 作業完了前チェックリスト（credentials-manager プラグイン）

`credentials-reader` / `credentials-manager` スキルの実行フロー末尾、または `/credentials-manager:manage` コマンド完了時に **必ず自己検証する** チェック項目。SKILL.md 各「検証」ステップから参照される。

## 1. 共通チェック（参照系・書き込み系どちらも）

| # | 項目 | 合格条件 |
|---|------|---------|
| 1 | 認証情報パスを正しく解決したか | リポジトリ内 → `<repo_root>/.claude/.local/plugins/credentials-manager/credentials.json` / リポジトリ外 → `~/.claude/.local/plugins/credentials-manager/credentials.json` |
| 2 | フル値を会話出力していないか | ユーザ向け応答・ログに `value` のフル文字列が一切現れない |
| 3 | マスキング規則を守ったか | 9 文字以上は `<先頭4>****<末尾4>` / 8 文字以下は `****`（部分露出禁止） |
| 4 | 認証情報パターンを復唱していないか | プロアクティブ検出時、検出文字列そのものを再表示せずマスクしている |
| 5 | 利用者コンテキストの汚染がないか | `progress.md` / `inputs/` 等にフル値を転記していない |

## 2. 参照系（credentials-reader）追加チェック

| # | 項目 | 合格条件 |
|---|------|---------|
| 6 | スキップ条件の判定が正しいか | localhost / プライベート IP / ユーザの明示「認証なし」指示は自動マッチをスキップ |
| 7 | 引き継ぎ判断が正しいか | 0 件マッチ後の保存承諾、プロアクティブ検出後の保存承諾、JSON パース失敗時 → `credentials-manager` を Skill ツール経由で起動 |
| 8 | 引き継ぎ時にフル値を残していないか | `credentials-manager` への呼び出し引数・自然言語案内のいずれにも `value` のフル文字列を含めない（ユーザ再入力に委ねる） |
| 9 | `credentials.json` を書き込んでいないか | 参照スキルは読み取り専用（書き込みは manager の責務） |

## 3. 書き込み系（credentials-manager）追加チェック

| # | 項目 | 合格条件 |
|---|------|---------|
| 10 | 親ディレクトリを作成したか | 書き込み前に `.claude/.local/plugins/credentials-manager/` の存在を確認 / 作成済み |
| 11 | `.gitignore` 登録を確認したか | リポジトリ内保存時、`.claude/.local/` が `.gitignore` に登録済み（未登録なら警告 + 登録提案 → ユーザ確認） |
| 12 | `auth_method` の既定を適用したか | 未指定時は `header:Authorization:Bearer` を採用 |
| 13 | `created_at` / `updated_at` を更新したか | save 時は両方を現在時刻 / update 時は `updated_at` のみ更新（`created_at` 維持） |
| 14 | エンコーディング・改行コードを維持したか | 既存ファイル更新時、UTF-8 + 元の改行コード（CRLF/LF）を維持 |
| 15 | 削除前確認を行ったか | 対話モードでの delete は `AskUserQuestion` でマスク値・関連ドメイン・更新日を提示してユーザ承諾を取得済み |
| 16 | 修復時のバックアップを作成したか | repair 時は `credentials.json.bak.{ISO8601-timestamp}` を作成してから空ストア再初期化 |
| 17 | 引き継ぎ受け入れ時にフル値を要求したか | reader からの引き継ぎではフル値が渡されない前提で `AskUserQuestion` でユーザに値を再入力させる |

## 4. /manage コマンド追加チェック

| # | 項目 | 合格条件 |
|---|------|---------|
| 18 | メニュー UI が `AskUserQuestion` で実装されているか | 一覧 / 追加 / 編集 / 削除 / 修復（必要時）/ 終了 の選択肢を提示 |
| 19 | 各操作後に「続けますか？」と確認したか | 操作完了後にメニュー再表示 or 終了確認の `AskUserQuestion` を実行 |
| 20 | 削除委譲時の事前確認が二重化されているか | 引数指定（`/credentials-manager:manage delete <name>`）でも `credentials-manager` 側 `operations.md` 節 4 step 3 の事前確認を必ず通す |
| 21 | スキル委譲が Skill ツール経由か | `Skill(skill: "credentials-manager:credentials-reader" / "credentials-manager:credentials-manager", args: "...")` で呼び出し |

## 5. フェイルセーフチェック

| # | 項目 | 合格条件 |
|---|------|---------|
| 22 | 読み取り権限なし時の応答 | エラーをユーザに通知し、フローを停止。元のツール呼び出しの継続可否を `AskUserQuestion` でユーザに確認 |
| 23 | JSON パース失敗時の応答 | reader はバックアップ・再初期化を行わず `credentials-manager` の repair に引き継ぎ提案 |
| 24 | ストアファイル不在時の応答 | 空ストア相当として処理（list は「保存済みなし」、retrieve は保存提案、auto-match は 0 件動作） |

## 自己検証の実施方法

各スキルは実行フロー最終ステップで本ファイルを参照し、上記項目を内省的に確認する。失敗項目があれば該当箇所を修正してから完了報告する。

検証結果はメインコンテキストには出力しない（フル値が含まれる可能性のあるログを残さないため）。失敗が続発する場合のみ、マスキング済みの要約をユーザに提示する。
