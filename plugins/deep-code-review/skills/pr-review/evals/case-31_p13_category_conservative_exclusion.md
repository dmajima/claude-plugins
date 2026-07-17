# case-31 P13 解消判定の系統別分類と保守的除外（コード修正系=解消 / 設計・仕様系=未解決維持）

再レビューで既存自著スレッド 2 件をコメント本文のカテゴリで分類し、コード修正系は Pattern A で解消、設計・仕様系はコード変更があっても自動判定不能として Pattern C で未解決維持する分岐を検証する。P13 の 3 系統分類と comment-resolution-judge.md の保守的除外（false negative 許容）が要点。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "PR #123 をレビューして"（既存自著インラインスレッド 2 件: (a)「nullチェック追加して」＝該当行に null チェック追加済み / (b)「この設計だと拡張性が低いのでは」＝当該メソッド周辺にコード変更はあるが設計論点への応答なし。auto-resolve 引数なし＝既定） |
| モード | 非対話 |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/checklist.md` P13「解消判定はコード修正系 / テスト追加系 / ドキュメント系の 3 系統で実施している」（SSOT: `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` P13）+ `${CLAUDE_PLUGIN_ROOT}/references/comment-resolution-judge.md` セクション 2（Step 1 のカテゴリ分類 = コード修正系 / テスト追加系 / ドキュメント系 / 設計・仕様系 / 質問系、Step 3 の保守的な扱い = 設計・仕様系・質問系は自動判定不能につき未解決のまま残す・false negative 許容）。両スレッドが同一の再レビューで異なるカテゴリに分類され Pattern A / C に分岐する点が、全件解消の case-16・単一未解消の case-17 との差別化点。

## 期待動作

- 各スレッドのコメント本文を comment-resolution-judge.md セクション 2 Step 1 でカテゴリ分類する
  - (a)「nullチェック追加して」→ **コード修正系** に分類し、当該 `path:line` のコード差分に null チェックが追加されたことを確認して解消候補とする（セクション 2 Step 2 のコード修正系の判定）
  - (b)「この設計だと拡張性が低いのでは」→ **設計・仕様系** に分類する（セクション 2 Step 1 のカテゴリ表）
- (a) コード修正系スレッド: Pattern A で解消確認 reply を投稿し status=fixed（Azure DevOps）/ resolved（GitHub）に更新する（auto-resolve 既定・re-review-flow.md セクション 2/3）
- (b) 設計・仕様系スレッド: **当該メソッド周辺にコード変更があっても** 設計論点の解消は自動判定不能と扱い、Pattern C として再観察 reply のみ投稿し status=active を維持する（comment-resolution-judge.md セクション 2 Step 3「判定が曖昧な場合は解消とみなさない」・設計・仕様系は false negative 許容）
- コード変更の存在を根拠に設計・仕様系を解消扱いにしない（保守的除外の中核ガード）
- サマリーの「6. 既存指摘の解消判定」セクションに、各スレッドを「どの系統で解消と判定したか」（(a)=コード修正系で解消 / (b)=設計・仕様系のため自動判定不能・未解決維持）を系統名付きで記載する（comment-resolution-judge.md セクション 3 の報告フォーマット）
- 完了報告に、コード修正系での解消 1 件・設計仕様系での未解決維持 1 件を系統別に区別し、未解決維持の根拠（自動判定不能・手動確認推奨）を明記する

## 関連ケース

- case-16: Pattern A 全件解消の auto-resolve（本ケースの (a) と同じ解消系統だが全件解消の分岐）
- case-17: Pattern C 未解消スレッドへの再観察 reply（本ケースの (b) と同じ status=active 維持だが「指摘箇所未修正」による未解消の分岐）
- case-29: 自著限定の auto-resolve（自著 / 他者起票の軸での分岐）
- case-32: P26/P27 残存 active スレッドの確認と完了報告記載（本ケースの (b) が残す active スレッドの完了時検証）
