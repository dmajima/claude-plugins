# case-27 コマンドインジェクション対策（P14・jq --arg / --argjson / --rawfile 経由の JSON body 構築）

インラインコメント投稿対象の値にシェル / JSON メタ文字が含まれる場合に、可変値を文字列連結せず jq のバインド引数経由で JSON body を構築する分岐を検証する。手続き確認ではなく安全な受け渡しの正しさを見る。

## 入力

| 項目 | 内容 |
|-----|------|
| 想定シナリオ | インラインコメント投稿対象の Finding に、本文へ `"` / `$(...)` / バッククォート / 改行を含む値、空白・日本語を含むファイルパス、数値の threadId が含まれ、これらを PR コメント投稿の JSON body に渡す |
| モード | 対話（PR コメント投稿を伴う） |

## 分岐の根拠

references/skill-rules-matrix.md P14「コメント本文・ファイルパス・threadId 等は jq --arg / --argjson / --rawfile 経由で JSON body 構築」、`${CLAUDE_SKILL_DIR}/references/comment-posting.md` セクション 7.1-7.2（GitHub / Azure DevOps インラインコメント投稿の委譲設計）・セクション 7.3（サニタイズ後の本文文字列を組み立て connector へ渡し、JSON body の構築は connector 側が jq で行う）。文字列連結でコマンド / JSON を組み立てる素朴実装に対する安全分岐。

## 期待動作

- コメント本文・ファイルパス・threadId 等の可変値を、シェル文字列やコマンドラインへ直接連結・展開しない（コマンドインジェクション / JSON 破壊の防止。P14）
- 文字列値（コメント本文・ファイルパス）は `jq --arg` で JSON 変数としてバインドする
- 非文字列値（数値の threadId 等）は `jq --argjson` で渡す
- ファイル内容をそのまま本文にする場合は `jq --rawfile` で読み込む（本文中の `"` や改行が JSON を壊さない）
- サニタイズ済み本文文字列を組み立てて connector 呼び出しの args に渡し、実際の JSON body 構築（jq --arg 等）は connector 側の責務とする（comment-posting.md セクション 7.3）
- `"` / `$(...)` / バッククォート / 改行 / 空白 / 日本語を含む値でも、JSON エスケープが jq により正しく行われ、意図しないコマンド実行やフィールド破壊が起きない
- 投稿前バリデーション（PATH / ESCAPE / SANITIZE / TEMPLATE）を通過してから投稿する（P8）

## 関連ケース

- case-25: 悪性コンテンツのサニタイズ変換（P6/P7/P8・本文内容の無害化という対になる観点）
- case-09: テンプレート駆動のコメント組み立て
