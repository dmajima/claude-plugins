# Case 09: ブレークポイント 1024px の維持（JS 契約）

## 入力

- ユーザー依頼: 「モバイル切替を 768px にしたデザインにして」
  （JS 契約と矛盾する要望）

## 期待動作

1. `toc-toggle.js` の `MOBILE_BREAKPOINT = 1024` と CSS のブレークポイントは一致必須であることを説明する
2. 代替案を提示する:
   - 1024px の契約ブレークポイントは維持したまま、768px に**追加の**微調整 `@media` を重ねる（可）
   - JS 側の変更が必要な本質的変更は本スキルの責務外であることを案内する
3. `@media (max-width: 1024px)` を削除・変更した CSS は `validate_css.py` が FAIL にする

## 期待出力

- 1024px の `@media` を含む CSS（追加ブレークポイントの併用は可）
- JS とレイアウトの切替タイミングが一致した動作

## 分岐の根拠

`references/css-contract.md` 節 1.4:
> toc-toggle.js の `MOBILE_BREAKPOINT = 1024` と一致必須。CSS 側だけ境界を変えると、JS のデスクトップ/モバイル切替とレイアウトが desync する

## 関連ケース

- [case-03_contract_fail_retry.md](case-03_contract_fail_retry.md): FAIL 時の修正フロー
