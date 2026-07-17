# code-review-spec-inference 達成チェックリスト

`code-review-spec-inference` スキルが **出力 JSON を返却する前** に通過すべきルール群。
ID 体系・SSOT は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` を参照。

> **確認タイミング**: Step 5（矛盾事項の検出）完了後、出力 JSON 返却前。
> **未通過時**: 該当項目を解消してから返却する。

---

## A. Universal ルール（全スキル共通）

> 規範本文・達成基準は **`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md`** を参照（プラグイン内 SSOT）。
> 適用範囲は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` セクション8 を参照。

```
[ ] (U1) スキル構成規約への準拠
[ ] (U2) ファイル文字コード・改行コードの維持
[ ] (U3) ローカルデータ領域の規約遵守
[ ] (U4) セッション作業領域の規約遵守
[ ] (U5) 進捗管理ルール（progress.md）
[ ] (U6) ポータブルパス記法の遵守
[ ] (U7) PR 外への影響禁止
[ ] (U8) 別 PR 推奨の禁止
[ ] (U12) 認証情報の取り扱い
[ ] (U14) 提出コードの信頼性原則（コードからの規約類推制限・ユーザー承認義務化）
[ ] (U15) 指摘への信頼度（0〜100）付与（仮定ベースは 60 未満・動的検証実証済みは 90 以上。severity-ranking.md セクション 7）※本スキルはレビュー指摘を生成しないため実質対象外（skill-rules-matrix.md セクション 8 脚注）。指摘を出す場合のみ適用
[ ] (U16) 差分の削除側（- 行）で既存の防御コード（例外処理・入力検証・リソース解放・a11y 属性・認可・エラー表示 UI）が失われていれば回帰として指摘している ※本スキルはコード差分レビューを行わないため実質対象外（skill-rules-matrix.md セクション 8 脚注）。差分を評価する場合のみ適用

本スキル適用外: U9, U10, U11, U13（規範マトリクス セクション8 脚注で確認）
```

---

## B. Inference ルール（推論支援スキル固有）

```
[ ] (I1)  情報源の優先順位（仕様書 > description 構造化見出し > 外部リンク > リポジトリ内資料 > 過去コメント > Bot 過去レビュー）に従っている
[ ] (I2)  外部 fetch は safe-external-fetch.md のドメインホワイトリスト方式に厳密準拠している
[ ] (I3)  取得結果に comment-sanitization.md のサニタイズ規則を適用している
[ ] (I4)  複数情報源間の矛盾を検出し、出力 JSON `conflicts` フィールドに格納している
[ ] (I5)  出力 JSON が 5 フィールド構造（expected_behavior_summary / requirements / acceptance_criteria / conflicts / sources_used）になっている
```

---

## C. 出力 JSON チェック

```bash
# C-Auto-1: 出力が有効な JSON であること
echo "$OUTPUT_JSON" | jq -e '.' >/dev/null 2>&1 || echo "ERROR: Invalid JSON"

# C-Auto-2: 必須フィールドが揃っているか
required_fields=("expected_behavior_summary" "requirements" "acceptance_criteria" "conflicts" "sources_used")
for f in "${required_fields[@]}"; do
  echo "$OUTPUT_JSON" | jq -e ".${f}" >/dev/null 2>&1 || echo "MISSING field: $f"
done

# C-Auto-3: sources_used に priority と type が含まれているか
echo "$OUTPUT_JSON" | jq -e '.sources_used[] | select((.priority? | not) or (.type? | not))' >/dev/null 2>&1 \
  && echo "WARN: sources_used に priority または type が欠落"

# C-Auto-4: 外部 fetch 失敗の透明性
echo "$OUTPUT_JSON" | jq -e '.sources_used[] | select(.type == "external-link") | .fetch_status' >/dev/null 2>&1 \
  || echo "WARN: external-link の fetch_status が欠落（success/failure/skipped を明示すること）"

# C-Auto-5: 機密文字列の伏字化
echo "$OUTPUT_JSON" | grep -nEi "Bearer [A-Za-z0-9_+/=.-]{16,}|gh[ps]_[A-Za-z0-9]{36,}|AKIA[0-9A-Z]{16}" \
  && echo "WARN: 認証情報パターンが出力 JSON に含まれている可能性。伏字化推奨"
```

---

## D. 未通過時の対応

| 未通過 ID | 対応 |
|----------|------|
| I1 | 情報源の優先順位を再評価し、出力の `sources_used` を並べ替え |
| I2 | ホワイトリスト不一致 URL を fetch 対象から除外、`sources_used.fetch_status` を "skipped" に |
| I3 | 取得資料に comment-sanitization.md セクション3-4 を再適用 |
| I4 | 矛盾検出ロジックを再実行し `conflicts` フィールドを更新 |
| I5 | 出力 JSON のスキーマを修正（5 フィールド構造） |
| U12 | 認証情報パターンを伏字化（comment-sanitization.md セクション3-4 参照） |

---

## E. 関連リファレンス

- `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` — 全スキルのルール ID 体系
- `${CLAUDE_PLUGIN_ROOT}/references/safe-external-fetch.md` — 外部 fetch 安全方針
- `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` — サニタイズ・機密文字列伏字化
- `${CLAUDE_SKILL_DIR}/references/expected-behavior.md` — 期待挙動推論ロジック詳細
- `${CLAUDE_SKILL_DIR}/SKILL.md` — 本スキルの実行フロー・出力フォーマット
