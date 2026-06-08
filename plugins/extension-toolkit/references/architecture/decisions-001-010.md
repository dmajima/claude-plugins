# アーキテクチャ決定記録（ADR-001〜010）

ADR-011〜020 は `decisions-011-020.md`、ADR-021 以降は `decisions-021-033.md` を参照。

## ADR-001: 11 スキル + 1 オーケストレータコマンドの 3 層構成（ADR-029 で mit-license-toolkit 追加）

| 項目 | 内容 |
|------|------|
| 決定 | `toolkit` 系 9（skill / plugin / command / agent / hook / readme / environment-setup / marketplace / mit-license、`marketplace` 追加は ADR-020、`mit-license` 追加は ADR-029 を参照）+ `reviewer` 1 + `publisher` 1 = **11 スキル** + オーケストレータ `/extension` の 3 層パイプラインで構成 |
| 理由 | 1 スキル 1 責務（SRP）の徹底。各スキルが他スキルを Skill ツール経由で呼び出す疎結合。ユーザはオーケストレータ（`/extension`）または個別スキル（自然言語起動）の両方で利用可能 |
| トレードオフ | スキル間連携のオーケストレーションが `/extension` と各 SKILL.md「引き渡し」表に分散する |
| 代替案 | 単一の mega-skill で全機能提供 → SKILL.md 200 行制約に違反、却下 |

## ADR-002: SSOT・チーム定義・テンプレートをすべて `references/`（プラグイン直下）に集約

| 項目 | 内容 |
|------|------|
| 決定 | プラグイン横断の共通ナレッジ（命名規約・AI 誤認回避・description 設計・パスポータビリティ・evals ガイド・検証ルール・本 ADR）+ エージェントチーム定義（`teams/`）+ 推奨構成テンプレート（`templates/`）をすべてプラグイン直下の `references/` 配下に集約。プラグイン直下に独自ディレクトリは置かない（Claude Code 公式仕様の `agents/` / `commands/` / `hooks/` / `skills/` / `mcp/` のみ） |
| 理由 | (1) 名称はスキル内 `references/` と一貫し、エコシステム全体の慣用と整合する。(2) プラグイン直下を Claude Code 公式仕様のディレクトリに限定することで構造を予見可能にする。(3) すべての独自リソースが `references/` 配下にあることで「何が独自か」が明確になる |
| トレードオフ | プラグイン直下とスキル内で同名ディレクトリ（`references/`）が両方存在するが、パスで区別される。`teams/` `templates/` のパスが `references/teams/` `references/templates/` と階層が深くなる |
| 代替案 | (1) `shared/` 命名 → 命名一貫性が劣る、却下。(2) プラグイン直下に `teams/` `templates/` を置く → 構造が乱立、却下 |

## ADR-003: テンプレートの 2 階層管理（プラグイン横断 + スキル固有）

| 項目 | 内容 |
|------|------|
| 決定 | `references/templates/{種別}/`（横断、プラグイン直下）と `skills/*/references/template/`（固有、各スキル内）の 2 階層で管理。固有テンプレートは横断テンプレートをコピーしてから差分を加える |
| 理由 | 横断テンプレートで全スキル共通の推奨構成を SSOT 化し、スキル固有の派生は局所化する。生成物のムラを抑える |
| トレードオフ | 2 階層の運用が複雑化しうる。固有テンプレートが必要になるケースは限定的 |
| 代替案 | 横断のみ → 柔軟性低下。固有のみ → 共通変更時の散在 |
| 補記 | 当面は横断のみで運用し、固有テンプレートが必要となった時点で導入する遅延戦略 |

## ADR-004: `marketplace-publisher` がフルオートで git push + PR まで担う

| 項目 | 内容 |
|------|------|
| 決定 | `marketplace-publisher` は **公開ワークフロー**（重複検査・実体検証・シークレットスキャン・git add / commit / push / PR 作成）を主責務とし、ユーザが明示的に選択した場合のみフルオートで実行する。`marketplace.json` の編集とマーケットプレイス README 同期は **`marketplace-toolkit` に委譲**（ADR-020 参照） |
| 理由 | 「公開」というユーザ意図に対し、マーケットプレイスへの登録と git リポジトリへの反映は不可分なため、公開フローは同一スキルで完結させたほうがユーザ体験が良い。一方、`marketplace.json` 編集ロジックは独立した責務として `marketplace-toolkit` に分離する（ADR-020）|
| トレードオフ | publisher と toolkit の連携呼び出しが必要（Skill ツール経由で疎結合に保つ） |
| 代替案 | git/PR 操作を `release-publisher` 等に分離 → スキル間連携が増え、ユーザ操作が複雑化、却下 |
| 制約 | フルオートは明示的選択時のみ。main / master 直接 push は禁止。フィーチャーブランチ確認必須。シークレット混入時は fail-closed |

## ADR-005: `agent-toolkit` が単体エージェントとチーム編成の両方を担当

| 項目 | 内容 |
|------|------|
| 決定 | エージェント単体作成 とエージェントチーム編成を `agent-toolkit` 1 スキルで担当（モード判定で内部分岐） |
| 理由 | 両者は「エージェントを設計する」という同じドメイン。チーム編成も内部的にメンバー候補のエージェント定義参照を伴うため、単体作成と密結合 |
| トレードオフ | チーム編成は議論ラウンド・相補性検証など固有の不変条件を持ち、DDD 観点では境界コンテキストが混在 |
| 代替案 | `team-toolkit` への分離 → 単体エージェント定義の参照・派生作成が困難 |
| 将来検討 | チーム編成の複雑度がさらに増した場合、`team-toolkit` への分離余地を残す |

## ADR-006: `extension-reviewer` が並列エージェント起動を担う（最低 3 名）

| 項目 | 内容 |
|------|------|
| 決定 | `extension-reviewer` は対象種別に応じて最低 3 名の専門エージェント（`implementation-engineer` / `architect` / `security-engineer` 等）を **並列起動** し、結果を統合する |
| 理由 | 観点網羅と独立した評価が品質向上に寄与（agent-architecture.md の Independent 型）。並列実行により時間効率も確保 |
| トレードオフ | Independent 型はエラー増幅率が高い（17.2x）が、メイン Claude が結果統合時に検証ボトルネックとして機能することで抑制 |
| 制約 | レビュー系チームは最低 3 名。フック・外部公開機能では `security-engineer` を必須含める |

## ADR-007: `/extension` ルーティングはコマンド本文に直書き

| 項目 | 内容 |
|------|------|
| 決定 | 引数パターン → スキル名のマッピングを `commands/extension.md` 本文に表形式で直書きする |
| 理由 | Claude Code のスラッシュコマンドは Markdown プロンプトであり、ルーティングロジックは AI が読み解く前提。外部設定ファイルに切り出すと AI が読み取れない |
| トレードオフ | 新種別追加時に `commands/extension.md` 編集が必要（OCP に微違反） |
| 代替案 | ルーティング設定の YAML 外部化 → AI が直接参照しづらい、却下 |
| 影響軽微 | 追加頻度が低く、修正は 1 行追加で済むため許容 |

## ADR-008: 検証ルールは `references/checklists/validation-rules.md` に集約

| 項目 | 内容 |
|------|------|
| 決定 | 各 `*-toolkit` の検証セクション と `extension-reviewer/references/automated-checks.md` で参照する検証ルールを [`validation-rules.md`](../checklists/validation-rules.md) に集約。各参照元はチェックリストの該当節を指定して引用する |
| 理由 | 検証ルールが 11 スキル（toolkit 系 9 + extension-reviewer + marketplace-publisher）に散在すると更新時の整合性維持が困難（SSOT 違反） |
| トレードオフ | 参照階層が深くなる |
| 代替案 | 各スキル内に重複記述 → 更新コスト増、却下 |

## ADR-009: スキル名を `*-creator` から `*-toolkit` にリネーム

| 項目 | 内容 |
|------|------|
| 決定 | toolkit 系 9 スキル（skill / plugin / command / agent / hook / readme / environment-setup / marketplace / mit-license、`marketplace` 追加は ADR-020、`mit-license` 追加は ADR-029 参照）の名称を `*-toolkit` で統一。プラグイン名 `extension-toolkit`、Git ブランチ `feature/extension-toolkit` も同命名 |
| 理由 | (1) `creator` は新規作成のみのニュアンスだが、これらスキルは改修・高度化も担当する。(2) `example-skills:skill-creator` という外部スキルとの命名衝突を回避 |
| トレードオフ | リネームによる参照置換ミスのリスクがあり、規約遵守時はレビューによる検証が必要 |
| 代替案 | 一部スキルのみリネーム → 命名規則の不統一、却下 |

## ADR-010: 環境構築スキル `environment-setup-toolkit` を分離（ADR-024 で更新済）

| 項目 | 内容 |
|------|------|
| 決定 | **本 ADR は ADR-024 で更新済**。現行決定は ADR-024（プラグイン単位 venv + プラグイン直下 `references/scripts/setup/` 配置）を参照。本 ADR は当初「Python venv 構築・撤去スクリプトを `environment-setup-toolkit` に集約し、各スキルは依存リストのみを保有する」と決定したが、スキル単位 venv の重複構築や `requirements.txt` の分散による依存競合という課題が顕在化したため ADR-024 で再設計した |
| 理由 | 各スキルが個別に setup_venv スクリプトを持つと（1）スクリプトの重複、（2）改善時の同期コスト、（3）「責務単一」の規約違反、を招く |
| トレードオフ | 各スキル内に直接スクリプトを置けば自己完結性が上がるが、責務単一化を優先 |
| 代替案 | 各スキル個別保有 → 重複・SSOT 違反、却下 |