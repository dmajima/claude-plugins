# design-bridge.json スキーマ

`<repo>/.claude/design-bridge.json` の形式。プロジェクトと claude.ai/design の紐付けを記録する設定ファイルで、**コミット対象**（チームで共有する）。

## 全体像

```json
{
  "projectId": "ffa33a4a-0000-0000-0000-000000000000",
  "projectName": "BANSHO",
  "specsDir": "specs/screens",
  "assetsDir": "specs/assets",
  "mocksDir": "mocks",
  "watch": [
    { "dir": "specs", "ext": "md" },
    { "dir": "mocks", "ext": "html" }
  ],
  "blockLimit": 3,
  "viewport": { "width": 1280, "height": 800 }
}
```

## フィールド

| フィールド | 型 | 必須 | 既定値 | 用途 |
|----------|---|------|-------|------|
| `projectId` | string (UUID) | 必須 | — | push 先の design-system プロジェクト ID |
| `projectName` | string | 任意 | — | 表示用。照合には使わない |
| `specsDir` | string | 任意 | `specs/screens` | 画面設計書（Markdown）の置き場 |
| `assetsDir` | string | 任意 | `specs/assets` | スクリーンショットの出力先 |
| `mocksDir` | string | 任意 | `mocks` | モック HTML の置き場 |
| `watch` | array | 任意 | 下記 | フックの監視対象 |
| `blockLimit` | number | 任意 | `3` | Stop フックの連続ブロック上限 |
| `viewport` | object | 任意 | `1280x800` | スクリーンショットのビューポート |

パスはすべてプロジェクトルートからの相対パスで書く。

## watch

PostToolUse フックが「未反映として記録すべき変更か」を判定するために読む。

```json
"watch": [
  { "dir": "specs", "ext": "md" },
  { "dir": "mocks", "ext": "html" }
]
```

| キー | 意味 |
|-----|------|
| `dir` | プロジェクトルートからの相対ディレクトリ。この配下（再帰）が対象 |
| `ext` | 対象の拡張子（ドットなし） |

判定は「相対パスが `<dir>/` で始まり、かつ `.<ext>` で終わる」。`watch` が未設定・空・解析不能の場合は既定値（`specs` の `.md` と `mocks` の `.html`）が使われる。

`specsDir` を `specs/screens` にしている場合でも、`watch` の `dir` は `specs` のままでよい（配下すべてを対象にするため）。設計書を `specs/` 直下にも置くなら、この既定のままが扱いやすい。

## blockLimit

Stop フックが連続してブロックできる回数の上限。この回数に達すると警告のみを出して応答の終了を許可し、カウンタをリセットする。push が繰り返し失敗する状況でセッションが固まることを防ぐための安全弁。

| 値 | 挙動 |
|---|------|
| `1` | 1 回ブロックしたら次は通す（最も緩い） |
| `3`（既定） | 3 回ブロック、4 回目で通す |
| 大きな値 | 強制力は上がるが、復旧不能な状況で固まるリスクも上がる |

`0` 以下や数値以外を設定した場合は既定値 `3` が使われる。

## viewport

`design-push` がスクリーンショットを撮る際のビューポート。`capture.py` の `--width` / `--height` に渡される。全画面を縦に収める撮影（full page）が既定のため、`height` は初期表示の折り返し位置の目安として働く。

## フックが読むフィールド

フック（`mark_design_dirty.sh` / `block_unsynced_design.sh`）が読むのは次の 2 つだけ。

- `watch`
- `blockLimit`

それ以外はスキル側が読む。**このファイルが存在すること自体** が「design-bridge 導入済み」の判定条件であり、中身が空の `{}` でもフックは既定値で動作する。

## 関連する状態ファイル（コミット対象外）

| パス | 内容 |
|-----|------|
| `.claude/.local/plugins/design-bridge/pending.txt` | 未反映パスの一覧（1 行 1 パス） |
| `.claude/.local/plugins/design-bridge/block-count` | 連続ブロック回数 |
| `.claude/.local/plugins/design-bridge/bundle/` | push 用に集約したファイル |

`.gitignore` に `.claude/.local/` を登録しておくこと。
