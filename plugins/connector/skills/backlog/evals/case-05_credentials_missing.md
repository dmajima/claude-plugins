# Case 05: 認証情報なし（API を呼ばず対話取得フォールバック）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Backlog で OTHER-1 を取得して"（課題 URL から対象スペースは `otherspace.backlog.jp` と特定できる） |
| 引数 | 課題キー `OTHER-1` |
| フラグ | なし（対話モード） |
| 既存状態 | credentials-manager プラグイン未導入。`~/.claude/credentials.json` は存在するが、`domains` に `otherspace.backlog.jp` を含むエントリがない（`example.backlog.jp` 用の別エントリのみ存在する）。credentials.json 自体が存在しない場合も同一の分岐 |

## 期待動作

### Phase 1: 認証事前確認（解決順序 1〜2 で解決不可）

- 対象スペースのホストを `otherspace.backlog.jp` に確定する
- credentials-precheck.md セクション 1 の解決順序を辿る:
  - 順序 1（credentials-manager）: 未導入 → 順序 2 へ（**未導入を理由に停止しない**）
  - 順序 2（credentials.json 直接照合）: 全エントリの `domains` と照合し、一致エントリ 0 件 → 順序 3a へ
- 別スペース（`example.backlog.jp`）用の API キーを流用しない（credentials-precheck.md セクション 6: 別スペースのキー流用禁止）
- 「もしかしたら使えるかもしれない」等の推測で API を呼ばない

### Phase 2: 対話取得フォールバック（credentials-precheck.md セクション 4）

- Backlog API へのリクエストを **1 件も発行せずに** `AskUserQuestion` で取得方針を提示する:
  - 入力して続行（今回のみ）
  - 入力して続行（保存する）
  - 登録手順の案内
  - 中止
- 質問文に対象ホスト `otherspace.backlog.jp` と必要な値（API キー。Backlog の個人設定 > API から発行）を明記する

### Phase 3a: 「入力して続行」を選択した場合

- ユーザーから API キーの提供を受ける。値を復唱せず、言及はマスク形式（先頭 4 文字 + `***` + 末尾 4 文字）に限定する
- 「保存する」選択時はセクション 3 の標準スキーマ（`domains: ["otherspace.backlog.jp"]`）で `~/.claude/credentials.json` へ jq マージ書き込みする（既存エントリを破壊しない）
- 「今回のみ」選択時は credentials.json へ書き込まず、セッション内でのみ利用する
- 受領したキーで Step 2（操作種別判定）以降へ **続行** し、課題取得を完遂する

### Phase 3b: 「中止」を選択した場合

- API を一切呼ばずに終了する（フォールバック提示済みのため正常な完了）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | 「保存する」選択時のみ `~/.claude/credentials.json` の新規エントリ。それ以外はなし |
| 標準出力（要約） | 「`otherspace.backlog.jp` 用の認証情報が確認できない」旨 + 対話取得の 4 択提示 →（入力時）課題 `OTHER-1` の取得結果 |
| 終了状態 | 入力時: 課題取得まで完遂 / 中止時: API リクエスト発行数 0 で終了 |

## 分岐の根拠

このケースが分岐するトリガーは 認証事前確認（SKILL.md Step 1） = 解決順序 1〜2 で解決不可（credentials.json の `domains` 照合で一致エントリ 0 件）である。credentials-manager / credentials.json の不在は停止理由にならず、必ず対話取得フォールバック（credentials-precheck.md セクション 4）の提示に進む。API 呼び出しは認証情報の解決後にのみ行う。

## 関連ケース

- `case-01_issue_get.md`（同じ読み取り依頼で認証事前確認に成功し、Step 3 へ進む対比）
- `case-03_comment_post.md`（書き込み依頼でも Phase 1 の認証事前確認は同一。解決不可なら本ケースと同じくフォールバックする）
- `case-15_subagent_credentials_missing.md`（同じ認証情報なしでもサブエージェント実行時は質問せず `credentials_missing` マニフェストを返す対比）
