# Case 25: mermaid 図の正常埋め込み

## 入力

- mermaid コードブロックを含む MD（mermaid.ink へ HTTPS 接続可能な環境）:

  ```markdown
  ## フロー

  ```mermaid
  flowchart LR
      A --> B
  ```
  ```

## 期待動作

1. `fetch_mermaid_png` が mermaid.ink から HTTP 200 + `Content-Type: image/png` +
   PNG マジックバイト（`\x89PNG`）のレスポンスを取得する
2. 3 条件をすべて満たすため PNG バイト列が返る（サイズ上限 20MB 以内）
3. テーマの `mermaid_max_width/height` に収まるサイズでスライドに配置される

## 期待出力

- 該当スライドに mermaid 図が PNG 画像として埋め込まれた PPTX
- テキストのコードブロックへのフォールバックが発生しない

## 分岐の根拠

`SKILL.md`「出力の特徴」:
> mermaid 図は PNG として取得してスライドに配置

（失敗側の対照: [case-03_mermaid_ink_unavailable.md](case-03_mermaid_ink_unavailable.md) /
[case-20_mermaid_bad_response.md](case-20_mermaid_bad_response.md)）

## 関連ケース

- [case-03_mermaid_ink_unavailable.md](case-03_mermaid_ink_unavailable.md): 接続失敗フォールバック
- [case-20_mermaid_bad_response.md](case-20_mermaid_bad_response.md): 不正レスポンス拒否
