# HTTP エラー分岐とレート制限対策（プラグイン共通）

`deep-code-review` プラグイン内で **REST API を curl 呼び出しする際に共通で適用する HTTP ステータス分岐・レート制限・エラー時のロールバック方針**。

> **位置付け**: 旧 `pr-review/references/comment-posting.md` セクション 7.4 から昇格済み。`safe-external-fetch.md` / `comment-sanitization.md` と同様にプラグイン直下 `references/` に配置し、各スキルから片方向参照される共通 Cross-Cutting Concern として扱う。

---

## 1. 適用範囲

以下のいずれかの操作を行うすべてのスキルに適用:

- 外部 / 内部の HTTP API を `curl` で呼び出す
- 認証トークン / NTLM 認証 / Cookie ベースの API を呼ぶ
- レート制限のあるサービス（GitHub / Azure DevOps / TFS / 社内 API）を叩く

---

## 2. API 呼び出し失敗時の方針

| ケース | 対応 |
|--------|------|
| 429 Too Many Requests | 指数バックオフでリトライ（最大3回、初回 1s / 2s / 4s）。それでも失敗したら未送信件数として記録 |
| 部分成功（送信の一部のみ成功） | **完了報告で必ず明示**。失敗件数を出力に含める |
| 認証エラー（401/403） | 即座に処理停止しユーザーに通知（再認証案内）。**リトライしない**（資格情報を含むリクエストの再送を防ぐ） |
| ネットワークエラー | リトライ後失敗なら、未送信のリクエスト本文を `.claude/.local/work/{...}/pending-*.md` に保存してユーザーへ案内 |

---

## 3. 必須実装パターン: HTTP ステータスコードの取得と分岐

`Invoke-RestMethod` は HTTP エラー時に例外を投げるためステータスコードの判別が難しい。
**全ての API 呼び出しは以下のパターンで HTTP コードを変数に格納し、`switch` で分岐すること**（PowerShell では `Invoke-WebRequest` + `try/catch` で `Response.StatusCode` を取得する）:

> **サンプルコード中の簡略形について**: 各スキルの API 呼び出し例には、読みやすさ優先で **簡略形** を使っている:
>
> ```powershell
> if ([int]$resp.StatusCode -lt 200 -or [int]$resp.StatusCode -ge 300) {
>     Write-Host "HTTP $($resp.StatusCode)"; throw "request failed"
> }
> ```
>
> これは「2xx 以外はすべて即 throw」する保守的フェイル形式で、サンプルコードの認知負荷を抑えるための **教材的省略形**。**プロダクション実装では下記の完全 switch 分岐**（429 指数バックオフ / 401-403 即停止 / 5xx 単発リトライ）**を使うこと**。簡略形は誤動作を生まない（429 でリトライしないだけで、失敗が安全側に倒れる）ため学習用には十分だが、本番品質には不足する。

### 完全 switch 分岐パターン

```powershell
function Invoke-Api {
    param([string]$Url, [string]$BodyPath, [string]$Netrc)
    # Windows PowerShell の Invoke-WebRequest は NTLM を直接ハンドリングしないため
    # curl.exe（Windows 10/11 同梱）を呼んでステータスコードを文字列で取得する
    $resp = & curl.exe -sS --max-time 30 --ntlm --netrc-file $Netrc `
        -H 'Content-Type: application/json' `
        -X POST --data-binary "@$BodyPath" `
        -o $RespFile -w '%{http_code}' `
        $Url
    return [int]$resp
}

$HttpCode = Invoke-Api -Url $Url -BodyPath $BodyFile -Netrc $Netrc

switch -Regex ([string]$HttpCode) {
    '^2\d{2}$' {
        # 成功: $RespFile に応答 JSON が格納されている
    }
    '^(401|403)$' {
        # 認証エラー: リトライ厳禁
        Write-Host "認証エラー (HTTP $HttpCode): $TfsUser で $TfsHost にアクセス不可。再認証してください"
        throw '認証エラー'
    }
    '^429$' {
        # レート制限: 指数バックオフでリトライ（最大3回）
        foreach ($delay in 1, 2, 4) {
            Start-Sleep -Seconds $delay
            $HttpCode = Invoke-Api -Url $Url -BodyPath $BodyFile -Netrc $Netrc
            if ([string]$HttpCode -match '^2\d{2}$') { break }
        }
        if ([string]$HttpCode -notmatch '^2\d{2}$') {
            throw "レート制限解除されず (最終 HTTP $HttpCode)"
        }
    }
    '^5\d{2}$' {
        # サーバーエラー: 1 度だけリトライ
        Start-Sleep -Seconds 5
        $HttpCode = Invoke-Api -Url $Url -BodyPath $BodyFile -Netrc $Netrc
        if ([string]$HttpCode -notmatch '^2\d{2}$') {
            throw "サーバーエラー継続 (HTTP $HttpCode)"
        }
    }
    default {
        Write-Host "予期しない HTTP $HttpCode"
        Get-Content -LiteralPath $RespFile -TotalCount 20 -Encoding utf8
        throw "予期しない HTTP $HttpCode"
    }
}
```

> **`-fsSL` は使用しないこと**: `-f` は HTTP エラー時に出力を抑制し非ゼロ終了するため、ステータスコードの判別ができない。代わりに `-sS`（プログレス抑制 + エラー時のみメッセージ）+ `--write-out '%{http_code}'` + `-o <tmpfile>` を使う。
> **`Invoke-RestMethod` だけでは不可**: 例外メッセージから HTTP コードを取り出すのは脆く、Windows PowerShell では NTLM の取り回しも難しいため、Windows 同梱の `curl.exe` を呼んで `%{http_code}` を文字列で受け取る方式を採用する。

---

## 4. 部分失敗時のロールバック方針

API 呼び出しの **連続実行（複数スレッドの status 更新等）** が部分失敗した場合:

- 既に更新済み（resolve / fixed 済み等）のリソースはそのまま
- 未更新のリソースは「失敗件数」として報告
- **既存状態を巻き戻すことはしない**（手動で操作されている可能性があるため）

---

## 4.5 リトライ時の幂等性ガード（必須）

429 / 5xx のリトライ時、**前回の試行で部分的に成功している可能性** に注意する。
特に PR コメント・スレッド作成系のエンドポイントは、リトライで **同一指摘の重複スレッド** を生むリスクがある。

### 4.5.1 重複防止の原則

| 操作 | 幂等性 | リトライ時の対応 |
|------|--------|----------------|
| GET（取得系） | 幂等 | そのままリトライ可 |
| PATCH `status` 更新 | 幂等（同じ status を再設定） | そのままリトライ可 |
| POST スレッド作成 | **非幂等**（重複スレッド生成リスク） | リトライ前に「直前 5 秒以内に同一 `[CR-NNN]` ラベルを持つスレッドが既に存在するか」を確認 |
| POST reply 追加 | **非幂等**（重複コメントリスク） | リトライ前に「同一スレッドに同一本文・直前 5 秒以内のコメントが存在するか」を確認 |

### 4.5.2 スレッド作成リトライ時の確認パターン

```powershell
# 429 / 5xx でリトライ前に重複チェック
$Label = "[CR-$findingNum]"
$threadsJson = & curl.exe -sS --max-time 30 --ntlm --netrc-file $Netrc `
    "$ApiBase/threads?api-version=6.0"
$threads = $threadsJson | ConvertFrom-Json
$duplicate = $threads.value |
    Where-Object { $_.comments[0].content -like "*$Label*" } |
    Select-Object -First 1

if ($duplicate) {
    Write-Host "INFO: 重複スレッド検出 (id=$($duplicate.id))。リトライをスキップして既存 ID を採用"
    $threadId = $duplicate.id
    # 後続の finding-thread-map.json 更新時にこの ID を使う
} else {
    # 通常リトライ
    # ...
}
```

リトライで重複が発生した場合（ガード前に既に複数スレッドが残っている場合）の検出は、`completion-checklist.md` E セクションで実施する。

---

## 5. シェル前提

本ファイルのサンプルは **PowerShell 7+ (pwsh)** を前提とする。HTTP コードの分岐には `switch -Regex` を使用する。
Windows PowerShell 5.1 でも動作するが、`pwsh` の方が `?.`・`??`・三項演算子等を含めた構文が充実しているため推奨。`switch -Regex` の実装例はセクション 3（必須実装パターン）のリトライ制御付きブロックを参照（簡略形は `2xx` 以外を throw）。

---

## 6. 適用契約

本ファイルは **プラグイン共通の HTTP エラー分岐・レート制限対策** を規定する。
REST API を curl で呼ぶ個別スキルは、本ファイルの規定（HTTP コード取得 + case 分岐 / 401-403 即停止 / 429 指数バックオフ / 5xx 単発リトライ / 部分失敗ロールバック方針）に準拠を宣言したうえで利用すること。

依存方向（共通 references から個別スキルへの参照を持たない一方向）の SSOT は同ディレクトリ `CLAUDE.md`「原則」。

---

## 7. 禁止事項

- `curl -fsSL` のみで API 呼び出しを行うこと（HTTP コード判別不能）
- 401/403 でリトライすること（資格情報の再送リスク）
- 429 でバックオフなしに即時リトライすること
- 部分失敗時に既存状態を勝手に巻き戻すこと
