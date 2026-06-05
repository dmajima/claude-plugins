# Case 03: mermaid.ink 不通 → テキストフォールバック

## 入力

- 入力 MD: mermaid コードブロックを含む

  ````markdown
  # 図解
  ```mermaid
  flowchart TD
      A --> B
  ```
  ````

- ネットワーク状態: `mermaid.ink` への HTTPS 接続が失敗

## 期待動作

1. `fetch_mermaid_png` 内で `requests.get` がタイムアウト or 例外
2. stderr に `Warning: mermaid.ink fetch failed: ...` または `Warning: mermaid.ink returned status=...` を出力
3. PNG が取得できないため、mermaid 部分を **テキストコードブロック** として配置（モノスペースフォントのテキストフレーム）
4. 処理は中断せず、PPTX 生成は完了

## 期待出力

- スライド内に mermaid コードがテキストとして配置される
- 図形としてはレンダリングされない
- スライド全体は正常に出力される

## 分岐の根拠

`SKILL.md`「重要な制約」:
> mermaid 図の取得には `mermaid.ink` への HTTPS 接続が必要。オフライン時はテキストのコードブロック表示にフォールバック

`references/scripts/convert-pptx/convert_pptx.py:fetch_mermaid_png`:
- 失敗時 `return None`
- 呼び出し側でテキスト配置にフォールバック

## 関連ケース

なし（エラー系）
