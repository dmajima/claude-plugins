# Case 20: mermaid.ink が不正レスポンスを返す（200 だが PNG でない）

## 入力

- mermaid コードブロックを含む MD
- mermaid.ink が HTTP 200 を返すが、Content-Type が `image/png` でない、または本文が
  PNG マジックバイト（`\x89PNG`）で始まらない状況（レスポンス偽装・エラーページ等）

## 期待動作

1. `fetch_mermaid_png` がステータス・Content-Type・マジックバイトの 3 条件を検証する
2. いずれかを満たさない場合、stderr に `Warning: mermaid.ink returned status=200 content-type='text/html'` 等を出力し `None` を返す
3. mermaid ブロックはテキストのコードブロックとしてフォールバック描画される
4. 変換自体は継続し、正常終了する（exit 0）

## 期待出力

- 不正なバイト列が画像としてスライドに埋め込まれない
- 該当位置に mermaid コードのテキストブロック

## 分岐の根拠

`SKILL.md`「重要な制約」:
> mermaid.ink のレスポンスは Content-Type が `image/png` で、かつ PNG マジックバイト（`\x89PNG`）で始まることを検証してから埋め込む

## 関連ケース

- [case-03_mermaid_ink_unavailable.md](case-03_mermaid_ink_unavailable.md): 接続自体が失敗する場合（例外・タイムアウト）
