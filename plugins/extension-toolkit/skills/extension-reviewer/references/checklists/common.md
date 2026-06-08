# 共通チェックリスト（全対象共通）

すべてのレビュー対象に適用する共通チェック項目。対象種別固有の項目は別ファイル（`skill.md` / `plugin.md` / 等）を参照する。

## C-1. 機械チェック（`run_checks.py`）の完了確認

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| C-1-1 | Critical | `run_checks.py` を venv 内 Python + Bash 経由で実行済み（PowerShell 直接起動禁止） | [automated-checks.md](../automated-checks.md) |
| C-1-2 | Critical | 実行結果 JSON ファイルを Read で読み取り、`issues` 配列を統合済み | [automated-checks.md](../automated-checks.md) |
| C-1-3 | High | 実行失敗（exit != 0）時は stderr の `[ERROR]` 行を `progress.md` に転記済み | [automated-checks.md](../automated-checks.md) |
| C-1-4 | Critical | venv 関連はプラグイン直下 `references/scripts/setup/` のスクリプトに委譲（ADR-024） | [scripts-policy.md](../../../references/policies/scripts-policy.md) |

## C-2. パスポータビリティ

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| C-2-1 | High | Windows ドライブレター（`C:\` 等）のハードコードなし | [path-portability.md](../../../references/policies/path-portability.md) |
| C-2-2 | High | Unix 系絶対パス（`/home/` `/Users/` `/root/`）のハードコードなし | 同上 |
| C-2-3 | High | Windows 環境変数（`%USERPROFILE%` 等）のハードコードなし | 同上 |
| C-2-4 | High | シェル HOME 変数（`$HOME` `${HOME}`）のハードコードなし | 同上 |
| C-2-5 | High | UNC パス（`\\server\share`）のハードコードなし | 同上 |
| C-2-6 | High | `.claude/skills/{name}/` のハードコードなし（自己参照は `${CLAUDE_SKILL_DIR}` を使う） | 同上 |
| C-2-7 | Medium | 例外パス（依存システム）が README「依存システム / 動作要件」に明示されている | [path-portability.md](../../../references/policies/path-portability.md) 節 4 |

## C-3. 文字コード・記号

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| C-3-1 | Critical | 既存ファイルのエンコーディング・改行コードが維持されている（`Edit`/`Write` 適用先のバイト比較） | [validation-rules.md](../../../references/checklists/validation-rules.md) 節 1 |
| C-3-2 | Medium | `§`（U+00A7）記号が本文・コメント・ファイル名に含まれない | [conventions.md](../../../references/policies/conventions-structure.md) 節 12.3 |
| C-3-3 | Medium | 装飾的な絵文字がドキュメント・README に含まれない（ユーザ明示指示なき限り） | [readme-policy.md](../../../references/policies/readme-policy.md) 節 9 |

## C-4. AI 誤認回避（ライティング）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| C-4-1 | Medium | 「適切に」「必要に応じて」「等」「など」「上記」「下記」等の曖昧表現を使用していない | [ai-readability.md](../../../references/policies/ai-readability.md) 節 3 |
| C-4-2 | Medium | 「できれば」「望ましい」ではなく「必須」「推奨」「任意」を使い分けている | 同上 |
| C-4-3 | Medium | 否定形では NG / OK を併記、または「〜してはならない」を断定で書いている | [ai-readability.md](../../../references/policies/ai-readability.md) 節 7 |

## C-5. プレースホルダ・テンプレート残存

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| C-5-1 | High | `{kebab-case}` 形式のプレースホルダが本番ファイルに残存していない（`templates/` 配下は除外可） | [validation-rules.md](../../../references/checklists/validation-rules.md) 節 1 |
| C-5-2 | High | `<...>` で示された必須項目が空のまま残されていない | [conventions.md](../../../references/policies/conventions-structure.md) |

## C-6. シークレット混入

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| C-6-1 | Critical | `.env` `*.pem` `*.key` `id_rsa` `credentials.json` `secrets.json` 等のシークレットファイルが含まれていない | [validation-rules.md](../../../references/checklists/validation-rules.md) 節 2.2 |
| C-6-2 | Critical | コード内・コメント内に API キー・トークン・パスワードらしい文字列が含まれていない | [marketplace-publisher の secret-scan.md](../../marketplace-publisher/references/secret-scan.md) |

## C-7. 状態ファイル形式（生成・参照対象内）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| C-7-1 | Medium | 構造化データを Markdown 表で長期保存していない（JSON / YAML / JSONL を選択） | [state-files.md](../../../references/policies/state-files.md) |
| C-7-2 | Low | 形式選択の判断が「人間 vs プログラム」「件数」「追記頻度」の基準に沿っている | 同上 |

## C-8. ドキュメント履歴記載禁止

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| C-8-1 | Medium | プラグイン内ドキュメントに「## 変更履歴」「## Changelog」等のセクションが含まれない | [conventions.md](../../../references/policies/conventions-structure.md) 節 12.5 / ADR-016 |
| C-8-2 | Medium | 「当初は」「改訂」「Round-N で」「リネーム時点で」等の時系列記述が本文に含まれない | 同上 |

## C-9. 自己完結性（利用者環境非依存・ADR-022）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| C-9-1 | High | グローバルルール（`~/.claude/rules/`）に依存していない、または不在時フォールバックがある | [self-containment.md](../../../references/policies/self-containment.md) 節 2.1 |
| C-9-2 | High | グローバルエージェント（`~/.claude/agents/`）への依存がプラグイン同梱版または明示フォールバックを持つ | 同 節 2.2 |
| C-9-3 | High | グローバル設定（`~/.claude/settings.json` の特定キー）への依存がない、または推奨レベルで案内される | 同 節 2.3 |
| C-9-4 | High | 外部ツール（git / python / gh 等）への依存が README「動作要件」「依存関係」に明示されている | 同 節 2.5 |
| C-9-5 | High | グローバルスキル依存（別プラグイン提供の Skill 呼び出し）に不在時フォールバックがある | 同 節 2.4 |

## C-10. レビューフレッシュ起動原則（ADR-021）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| C-10-1 | High | レビュー起動時にスポーンプロンプトに必須引き継ぎ事項（目的 / 役割 / ユーザー指摘 / 対象 / 観点 / 出力フォーマット）が含まれている | [review-freshness.md](../../../references/checklists/review-freshness.md) 節 2 |
| C-10-2 | High | 引き継ぎ禁止事項（過去レビュー結論 / 「修正済み」「対応完了」等のメタ評価 / 重大度予断）がスポーンプロンプトに含まれていない | 同 節 3 |
| C-10-3 | High | 修正実装と同一インスタンスでレビューを行っていない（別 Agent / フレッシュインスタンスで起動） | 同 節 5 |

## C-11. ユーザ対話（AskUserQuestion 優先）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| C-11-1 | Medium | 重要な選択（公開・削除・上書き・修正適用 等）を AskUserQuestion で実施している | [user-interaction.md](../../../references/guides/user-interaction.md) |
| C-11-2 | Medium | AskUserQuestion の選択肢が 2〜5 個に収まっている | 同上 |
| C-11-3 | Medium | 重要な操作の選択肢に「キャンセル」が含まれている | 同 節 5 |

## C-12. エージェント並列起動の網羅性（ADR-006 / ADR-011）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| C-12-1 | High | 最低 3 名のエージェントが並列起動された（観点が 2 つに固定の場合は 2 名で可、理由必須） | [agent-utilization.md](../../../references/guides/agent-utilization.md) 節 6 |
| C-12-2 | High | エージェントは独立観点で並列起動（同一メッセージ内に複数 Agent 呼び出し）された | [review-perspectives.md](../review-perspectives.md) |
| C-12-3 | High | フック / 外部公開機能を含む場合、`security-engineer` が必須メンバーに含まれている | [review-perspectives.md](../review-perspectives.md) 節「観点網羅の原則」 |
| C-12-4 | Medium | チーム機能利用不可時のフォールバック起動でユーザ報告に「Agent 並列起動で代替」が明記されている（該当時） | [agent-utilization.md](../../../references/guides/agent-utilization.md) 節 6.1.5 |

## C-13. 結果統合と総合判定

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| C-13-1 | Critical | 総合判定が `APPROVE` / `CONDITIONAL_APPROVE` / `REJECT` のいずれかで明示されている | [review-perspectives.md](../review-perspectives.md) |
| C-13-2 | High | Critical 1 件以上 → `REJECT`、Critical 0 + High 1 件以上 → `CONDITIONAL_APPROVE`、Critical 0 + High 0 → `APPROVE` のルールに従っている | 同上 |
| C-13-3 | Medium | 重複指摘が 1 件に集約され、根拠が併記されている | 同上 |
| C-13-4 | High | エージェント間で矛盾する指摘がある場合、ユーザに提示され判断を仰ぐ運用になっている | 同上 |

## C-14. 自動修正の境界

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| C-14-1 | High | `--auto-fix` モードでも、構造的問題・description 不適切・セキュリティ指摘は自動修正対象外として扱っている | [SKILL.md](../../SKILL.md) 節 6 |
| C-14-2 | Critical | セキュリティ指摘（Critical / High）は必ずユーザ確認を経ている | 同上 |
