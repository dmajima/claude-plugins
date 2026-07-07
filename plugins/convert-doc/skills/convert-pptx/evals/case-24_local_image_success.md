# Case 24: ローカル画像の正常埋め込み

## 入力

- 入力 MD と同ディレクトリ配下に実在する画像を参照:

  ```markdown
  # 資料

  ## セクション

  ![図1](images/figure01.png)
  ```

- `images/figure01.png` は `base_dir`（入力 MD の親）配下に実在する PNG

## 期待動作

1. `_load_image_bytes` が `base_dir` 配下の相対パスとして検証を通過し、バイト列を読み込む
2. `measure_image_bytes` でサイズを取得し、テーマの `image_max_width/height` に収まるよう
   アスペクト比を保って縮小（`fit_size_inches`）
3. `slide.shapes.add_picture` でスライドに配置される

## 期待出力

- 該当スライドに画像が実寸ベースの適正サイズで埋め込まれた PPTX
- プレースホルダテキスト（`[画像が見つかりません: ...]`）が出ない

## 分岐の根拠

`references/procedures.md`「ブロック要素のレンダリング」:
> ローカル画像 | `shapes.add_picture`

（拒否側の対照: [case-14_local_image_traversal.md](case-14_local_image_traversal.md)）

## 関連ケース

- [case-14_local_image_traversal.md](case-14_local_image_traversal.md): base_dir 外参照の拒否
- [case-25_mermaid_success.md](case-25_mermaid_success.md): mermaid の正常埋め込み
