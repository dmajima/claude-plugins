# 安全装置の詳細

`cleanup-workspace` スキルの多層安全装置の設計と運用ルール。

## 1. 安全装置の階層

| 階層 | 装置 | 防止する事故 |
|-----|------|-----------|
| 1 | パスバリデーション | 不正パスの削除（祖先ディレクトリ・他領域への侵入） |
| 2 | リンク追従禁止 | シンボリックリンク経由での領域外破壊 |
| 3 | 進行中セッション保護 | 実行中のタスクの破壊 |
| 4 | ドライラン推奨 | 想定外の削除（事前確認なし） |
| 5 | AskUserQuestion 確認 | 削除直前の最終承認 |
| 6 | 失敗時の続行 | 1 件の失敗による全体停止 |

## 2. パスバリデーション（必須・省略不可）

### 2.1 検証規則

削除対象として受理される条件:

| 条件 | 内容 |
|-----|------|
| パス末尾の名前 | 正規表現 `^\d{8}_\d{2}_[A-Za-z0-9._\-]+$` に一致 |
| 親ディレクトリ名 | `work`（`.claude/.local/work/` 配下を意味） |
| 祖父ディレクトリ名 | `.local`（`.claude/.local/work/` 構造） |
| 曾祖父ディレクトリ名 | `.claude` |
| 種別 | ディレクトリ（ファイル・シンボリックリンクは不可） |

### 2.2 禁止パターン（絶対に削除しない）

| パターン | 例 |
|---------|---|
| ルートディレクトリ | `/`, `C:\` |
| ホームディレクトリ | `~`, `$env:USERPROFILE` |
| `.claude/` 自体 | `~/.claude/`, `<repo>/.claude/` |
| `.claude/.local/` 自体 | 同上の `/.local` 配下 |
| `.claude/.local/work/` 自体 | 同上の `/work` 配下 |
| セッションフォルダ以外のディレクトリ | `cache/`, `plugins/`, `commands/` 等 |
| 任意のシンボリックリンク | リンクパス自体・リンク先 |

### 2.3 バリデーション実装例

```powershell
function Test-ValidSessionPath {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }

    $item = Get-Item -LiteralPath $Path
    if ($item.LinkType -eq 'SymbolicLink') { return $false }

    $name = $item.Name
    if ($name -notmatch '^\d{8}_\d{2}_[A-Za-z0-9._\-]+$') { return $false }

    $parent = $item.Parent
    if ($null -eq $parent -or $parent.Name -ne 'work') { return $false }

    $grand = $parent.Parent
    if ($null -eq $grand -or $grand.Name -ne '.local') { return $false }

    $great = $grand.Parent
    if ($null -eq $great -or $great.Name -ne '.claude') { return $false }

    return $true
}
```

## 3. シンボリックリンク保護

### 3.1 対象判定

`Get-ChildItem` で取得した `FileSystemInfo` の `LinkType` プロパティを確認する。

| LinkType の値 | 動作 |
|------------|------|
| `$null` または `''` | 通常のディレクトリ・ファイル。バリデーション継続 |
| `SymbolicLink` | スキップ（リンクも削除しない） |
| `Junction`（Windows） | スキップ（リンクも削除しない） |
| `HardLink` | 通常通り扱う（同一 i-node の別エントリのため） |

### 3.2 ハードリンクの扱い

Windows ではディレクトリのハードリンクは作成不可。ファイル単位のハードリンクのみ存在し、ファイル単位削除では参照カウントが減るだけのため、領域外への影響は発生しない。

## 4. 進行中セッション保護

### 4.1 検出ロジック

セッションフォルダ直下の `progress.md` の `LastWriteTimeUtc` が現在時刻から 5 分以内であれば、当該セッションは進行中と判定する。

```powershell
$progressPath = Join-Path $session.FullName 'progress.md'
if (Test-Path $progressPath) {
    $progMtime = (Get-Item $progressPath).LastWriteTimeUtc
    if ($progMtime -gt $nowUtc.AddMinutes(-5)) {
        # 進行中: 削除対象から除外
        return
    }
}
```

### 4.2 5 分閾値の根拠

- Claude Code の典型的なタスク粒度（数十秒〜数分）に対し十分な保護幅
- 連続タスクで `progress.md` が頻繁に更新される運用を前提
- ユーザが明示的に古いセッションを掃除したいケースでは、対象は通常 5 分以上未更新であることが期待される

### 4.3 進行中セッションの強制削除

進行中セッションを意図的に削除したい場合は、`progress.md` を手動更新停止してから本スキルを実行する。`--force-active` 等のフラグは設けない（事故防止のため）。

## 5. ドライラン推奨

### 5.1 既定動作

`--dry-run` を明示しない場合でも、対話モードでは `AskUserQuestion` が必ず発火するため、事実上のドライラン体験を提供する。

### 5.2 非対話モードでの安全装置

`--yes` / `--non-interactive` 指定時は `AskUserQuestion` がスキップされる。この場合でも:

- パスバリデーションは必須
- シンボリックリンク保護は必須
- 進行中セッション保護は必須
- `--dry-run` と `--yes` を同時指定した場合は `--dry-run` が優先（警告ログを出力）

## 6. 失敗時の続行

### 6.1 個別失敗の扱い

| 失敗 | 動作 |
|-----|------|
| 1 件の権限不足 | スキップして次へ |
| 1 件のファイルロック | スキップして次へ |
| バリデーション失敗 | スキップして次へ |
| 並行削除（パス不在） | スキップして次へ |

### 6.2 サマリへの記録

失敗したパスと理由は全件サマリに含める。ユーザは失敗一覧を見て、必要に応じて手動対応する。

## 7. 検証チェックリスト

スキル実装の検証項目:

- [ ] 親ディレクトリ（`work/` 自体）が削除されないことをテスト
- [ ] シンボリックリンクが削除されない・追従されないことをテスト
- [ ] 進行中セッション（`progress.md` 5 分以内）が保護されることをテスト
- [ ] バリデーション失敗時に当該フォルダが削除されないことをテスト
- [ ] `--dry-run` 指定時に実削除が行われないことをテスト
- [ ] `--yes` 指定時にバリデーションが省略されないことをテスト
- [ ] 1 件失敗時に他のセッションの削除は続行されることをテスト

これらは `evals/` 配下の各ケースで動作分岐として記述する。
