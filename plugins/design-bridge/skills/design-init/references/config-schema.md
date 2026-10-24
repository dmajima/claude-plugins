# 設定と状態ファイルのスキーマ

design-bridge が読み書きするファイルの形式。

## 1. プロジェクト設定 `.claude/design-bridge.json`

プロジェクトと claude.ai/design の紐付けを記録する。**コミット対象**（チームで共有する）。

```json
{
  "projectId": "00000000-0000-0000-0000-000000000000",
  "projectName": "My Design System",
  "specsDir": "specs/screens",
  "assetsDir": "specs/assets",
  "mocksDir": "mocks",
  "watch": [
    { "dir": "specs", "ext": "md", "kind": "spec" },
    { "dir": "mocks", "ext": "html", "kind": "mock" }
  ],
  "viewport": { "width": 1280, "height": 800 }
}
```

| フィールド | 型 | 必須 | 既定値 | 用途 |
|----------|---|------|-------|------|
| `projectId` | string (UUID) | 必須 | — | push 先の design-system プロジェクト ID |
| `projectName` | string | 任意 | — | 表示用。照合には使わない |
| `specsDir` | string | 任意 | `specs/screens` | 画面設計書（Markdown）の置き場 |
| `assetsDir` | string | 任意 | `specs/assets` | スクリーンショットの出力先 |
| `mocksDir` | string | 任意 | `mocks` | モック HTML の置き場 |
| `watch` | array | 任意 | 下記 | フックの監視対象 |
| `viewport` | object | 任意 | `1280x800` | スクリーンショットのビューポート |

パスはすべてプロジェクトルートからの相対パスで書く。`..` や絶対パスは使わない（スクリーンショット生成時に拒否される）。

### このファイルに書けないもの

ブロックの強さ（連続通知の上限）は**ここには書けない**。リポジトリ同梱の設定ファイルは、そのリポジトリを開いた人全員の挙動を左右する。悪意あるリポジトリが応答終了のブロックを恒久化できてしまうため、挙動を変える値は読まない設計にしている。調整は 2 節のユーザースコープ設定で行う。

### watch

PostToolUse フックが「未反映として記録すべき変更か」「どちらの種別か」を判定するために読む。

| キー | 意味 |
|-----|------|
| `dir` | プロジェクトルートからの相対ディレクトリ。この配下（再帰）が対象 |
| `ext` | 対象の拡張子（ドットなし） |
| `kind` | `spec`（設計書）または `mock`（モック）。省略時は `dir` 名に `mock` を含むかで推定 |

判定は「相対パスが `<dir>/` で始まり、かつ `.<ext>` で終わる」。`watch` が未設定・空・解析不能の場合、および `jq` が無い環境では既定値（`specs` の `.md` を spec、`mocks` の `.html` を mock）へ縮退する。

`kind` は Stop フックの誘導先を決める。モックの未反映は `design-push`、設計書の未反映は `design-mock`（モック再生成）へ案内される。設計書だけ直してモックが古いまま放置される事態を防ぐための区別なので、独自の `watch` を書くときも `kind` を明示することを推奨する。

`assetsDir` はどの `watch` エントリにも一致させないこと。一致すると、`design-push` が生成したスクリーンショットが未反映として記録され、解除できないループになる。既定構成では `assetsDir`（`specs/assets`）が `watch` の `specs` 配下にあるが、拡張子が `md` でないため一致しない。

## 2. ユーザースコープ設定 `~/.claude/.local/plugins/design-bridge/user-config.json`

利用者個人の設定。リポジトリには含めない。

```json
{
  "blockLimit": 3
}
```

| フィールド | 型 | 既定値 | 範囲 | 用途 |
|----------|---|-------|------|------|
| `blockLimit` | number | `3` | 1〜10 | 同じ未反映内容について Stop フックが連続でブロックする上限 |

範囲外・非数値・ファイル不在の場合は既定値 3 が使われる。`jq` が無い環境でも既定値で動作する。

上限に達すると、その時点の未反映内容を「却下済み」として記録し、**内容が変わるまで再びブロックしない**。回数を使い切るたびに再武装する作りではないため、反映できない事情がある変更を抱えたままでも作業を続けられる。

## 3. 状態ファイル（コミット対象外）

すべて `<プロジェクトルート>/.claude/.local/plugins/design-bridge/` 配下。`.gitignore` に `.claude/.local/` を登録しておくこと。

| パス | 形式 | 書き手 | 内容 |
|-----|------|-------|------|
| `pending.tsv` | `<kind>\t<相対パス>` の行 | PostToolUse フック | 未反映の変更。追記のみ。重複排除は読み取り側が行う |
| `block-count` | 整数 | Stop フック | 同じ内容に対する連続ブロック回数 |
| `dismissed` | ハッシュ文字列 | Stop フック | 上限到達時の `pending.tsv` の内容ハッシュ。一致する間は再通知しない |
| `last-push.json` | JSON | `design-push` | push マニフェスト。ドリフト判定の基準点 |
| `bundle/` | ディレクトリ | `design-push` | push 用に集約したファイル |
| `.venv/` | ディレクトリ | `design-init` | スクリーンショット生成用の Python 環境 |

### pending.tsv

```text
mock	mocks/S001_login.html
spec	specs/screens/S001_login.md
```

記録してよいのは `[A-Za-z0-9._/-]` のみで構成される 200 文字以内の相対パス。`..` を含むもの、絶対パスは記録しない。Stop フックがこの内容を stderr 経由でモデルへ渡すため、検証を通らない行は記録も表示もしない。

このファイルを手で編集しない。解除は `clear_pending.sh` を使う。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/clear_pending.sh" \
  --project-root "<ルート>" --path "mocks/S001_login.html"
```

### last-push.json

```json
{
  "projectId": "<uuid>",
  "pushedAt": "2026-10-23T12:34:56Z",
  "files": {
    "screens/S001_login.html": { "sha256": "<hash>", "localPath": "mocks/S001_login.html" }
  }
}
```

`design-status` はこれとリモートの `list_files` を突き合わせてドリフトを検出する。`DesignSync` にはリモート変更の通知機構が無いため、この記録が唯一の比較基準になる。

## 4. フックが読むもの

フック（`mark_design_dirty.sh` / `block_unsynced_design.sh`）がプロジェクト設定から読むのは `watch` だけである。それ以外のフィールドはスキルが読む。

**`.claude/design-bridge.json` が存在すること自体** が「design-bridge 導入済み」の判定条件であり、中身が空の `{}` でもフックは既定の監視対象で動作する。
