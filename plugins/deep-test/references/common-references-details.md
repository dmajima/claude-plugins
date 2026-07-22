# worker スキル共通リファレンス — 詳細節（`common-references.md` の条件付き参照）

`common-references.md`（共通参照インデックス）のうち、**代表的な unit 中心フローの worker 起動では参照されない節** を条件付きロード用に分離したもの。
`test-setup`（3.5 セットアップ時）・`test-environment`（3.8 環境構築時）の起動時、および全 worker スキル一覧の確認時にのみ読む。
節番号は `common-references.md` と一致する（本ファイルは 1 章・3.5・3.8 の本文を保持し、`common-references.md` 側は各見出しと本ファイルへのポインタを温存する）。

---

## 1. 対象スキル（13 worker スキル）

| 区分 | スキル |
|------|-------|
| フェーズスキル（7） | `test-setup` / `test-analyze` / `test-fixture` / `test-environment` / `test-design` / `test-review` / `test-report` |
| 実行スキル（6） | `test-run-unit` / `test-run-functional` / `test-run-integration` / `test-run-scenario` / `test-run-performance` / `test-run-security` |

## 3. 場面別参照（条件付き節）

### 3.5 セットアップ時（`test-setup`）

| ファイル | 利用目的 |
|---------|---------|
| `playwright-mcp.md` | MCP 登録・既存登録検出（重複登録禁止）・起動オプション・正本ツールリスト |
| `data-locations.md` | Playwright 出力先規約・target-slug 配下の初期化 |
| `execution-policy.md` | ツール利用可否判定の結果記録方法（後続の MCP ゲート判定材料） |

### 3.8 環境構築時（`test-environment`）

| ファイル | 利用目的 |
|---------|---------|
| `yaml-schema-environment.md` | `environment.yaml` の生成・スキーマ遵守（`applicability` 縮退・ライフサイクル状態・コマンド規約形・enum 値） |
| `yaml-schema-analysis.md` | 材料として消費する `analysis.yaml`（`architecture.build_run` / `dependency_summary.external_dependencies` / `meta.target_type` / `entry_points`）のスキーマ |
| `data-locations.md` | `environment.yaml` / `environment/` 配下の配置先・target-slug 解決・SUT docker 資産は read-only である旨 |
| `execution-policy.md` | Docker デーモン利用不可時の縮退（skipped）・非対話既定値（environment up の可否・health 未達時の扱い） |
| `agents.md` | env-architect の起動・プロンプト組み立て |
