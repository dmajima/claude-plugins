# deep-code-review プラグイン ロードマップ

本プラグインの機能計画・共通化昇格基準・リリース判定・ガバナンスを管理する。

> **位置付け**: `${CLAUDE_PLUGIN_ROOT}/references/roadmap.md`（プラグイン直下 references）。
> 過去の変更履歴は Git コミット履歴で管理する（CHANGELOG は持たない）。

---

## 1. 現行バージョン（v1.0.0）の機能全体像

成熟したレビュー基盤（観点別マルチエージェント・PR レビュー・状態永続化）に、多言語・多フレームワーク対応を統合した初回リリース。

| 機能群 | 内容 |
|--------|------|
| 観点別レビュー | 5 観点スキル（実装品質 / テスト / セキュリティ / アーキテクチャ / フロントエンド）が最大 10 種の専門エージェントを並列動員 |
| 言語・FW 観点プロファイル | 8 言語（C# / Python / JavaScript / TypeScript / HTML / CSS / PHP / SQL）+ 主要 FW（.NET 系 / PHP Web / Python Web / Node / React / Vue / FE ツール / ORM）+ SQL 方言 3 種。差分から自動検出して適用（`language-detection.md` / `languages/` / `frameworks/`） |
| 規約優先順位解決 | ユーザー指示 > 機械設定 > 文書規約 > 既存慣習 > 言語デファクトの 5 段階（`conventions-resolution.md`） |
| 信頼度スコア | 全指摘に信頼度 0〜100 を付与（U15）し、統合時に 60 未満を足切り（C24）して誤検知を抑制 |
| PR レビュー | GitHub / Azure DevOps（クラウド + オンプレ TFS の NTLM）のサマリー・インラインコメント投稿・スレッド解消管理・worktree 分離チェックアウト |
| 状態永続化 | state.yaml（ブランチ単位）による再レビュー時の前回指摘引き継ぎ・inputs フォルダの仕様書管理 |
| Agent Teams | 大規模・クリティカル変更時の 5 パターン議論レビュー（ユーザー承認制） |
| 環境構築 | env-setup スキルによる外部依存ツール（gh / az / jq / LSP 等）の確認・インストール提案 |

---

## 2. 計画中

### 短期

| 項目 | 内容 |
|------|------|
| 言語プロファイルの実運用フィードバック反映 | 実レビューでの検出精度・観点の過不足を評価し、`languages/` / `frameworks/` の観点を改訂 |
| evals の多言語ケース拡充 | 言語検出（C23）・信頼度足切り（C24）の分岐を検証するケースを追加 |

### 中長期（バージョン未定）

- **言語プロファイルの追加**: Go / Rust / Ruby / Java / Kotlin 等（`languages/CLAUDE.md` の章構成テンプレートに準拠して追加）
- **env-setup 独立プラグイン化**: 汎用ランタイム（.NET SDK / Node.js / Python 等）のインストール機能を `tooling-installer` プラグインとして分離し、env-setup はカテゴリ A（pr-review 必須ツール）のみに縮小
- **GitLab / Bitbucket 対応**: pr-review にホスト分岐追加
- **macOS / Linux のインストール手順整備**: 現状は Windows 主想定（winget 使用）
- **Agent Teams パターンの拡充**: 利用実績に応じてテンプレート追加
- **evals の extension-toolkit `eval-guide.md` 形式への段階移行**: 「期待出力」フィールド・自動実行形式への統一
- **共通 references の「片方向参照」原則と実態の整合整理**: 規範本体の SSOT がスキル側にあるケースの整理

---

## 3. 共通化昇格の判定基準

`pr-review` / `code-review-*` 等の **個別スキル references** から、プラグイン共通 `${CLAUDE_PLUGIN_ROOT}/references/` へ昇格させる際の判定基準。

### 3.1 昇格対象の特徴

以下を **複数満たす** 場合、共通化を検討する:

| 観点 | 内容 |
|------|------|
| **Cross-Cutting Concern** | セキュリティ / SSRF 対策 / サニタイズ / HTTP エラー処理 / レート制限など、特定のドメインに紐付かない横断的関心事 |
| **複数スキルから参照** | 2 つ以上の個別スキルから同等の規則を参照する必要がある（または、1 スキルしか使わなくても将来の拡張で 2 つ目以降が見込まれる） |
| **規則性が高い** | 「規範 + 実装サンプル」の構造で、ホスト固有実装には依存しない（DI 可能な抽象） |
| **片方向参照可能** | 共通モジュールが個別スキルを **知らない** 設計が成立する（Clean Architecture: 共通 → 個別 の参照ゼロ） |

### 3.2 既存の昇格事例

| ファイル | 元位置 | 昇格理由 |
|---------|--------|---------|
| `references/safe-external-fetch.md` | `pr-review/references/expected-behavior.md` 内の SSRF 対策 | SSRF 対策は他スキル（将来の `issue-review` 等）でも再利用される横断的関心事 |
| `references/comment-sanitization.md` | `pr-review/references/` 内のサニタイズ規則 | コメント本文サニタイズは PR / Issue / 外部資料転載の全スキルで適用される |
| `references/http-error-handling.md` | `pr-review/references/comment-posting.md` の HTTP エラー分岐 | HTTP エラー分岐は全 REST API 呼び出しで適用される横断規則・GitLab / Bitbucket 拡張時の再利用も見込まれる |
| `references/languages/` + `references/frameworks/` | 新設（coding プラグインの言語規約知識をレビュー観点に変換） | 言語・FW 観点は全観点別スキル・全エージェントが参照する横断知識 |

### 3.3 昇格時の手順

1. プラグイン共通 `${CLAUDE_PLUGIN_ROOT}/references/<name>.md` に新規ファイルを作成
2. 元位置からコンテンツを移動（または短縮 + 参照のみに変更）
3. 各スキルから新位置への参照を `${CLAUDE_PLUGIN_ROOT}/references/<name>.md` 形式で更新
4. **依存方向を厳守**: 共通モジュールから個別スキルへの参照を一切持たない（「適用契約」セクションで明示宣言）
5. `references/CLAUDE.md` のナビゲーション表を同期する

### 3.4 昇格しないもの

- ホスト固有の API 呼び出し（`azure-devops-tfs-ntlm.md` / `github.md` など）
- 単一スキル内でしか意味を持たないドメインロジック（`re-review-flow.md` の 4 パターン分岐など）
- 一時的な実装メモ / 履歴記述

---

## 4. リリース判定

サマリースレッド冒頭の「レビュー結果」項目に従う:

| 状態 | リリース可否 |
|------|------------|
| **OK** | マージ可能・追加対応不要 |
| **NG（再レビュー：不要）** | 軽微な指摘あり。任意対応で次バージョンに持ち越し可能 |
| **NG（再レビュー：要）** | 重要な指摘あり（Critical / High）。修正後の再レビューが必須 |

詳細な判定ルールは `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/comment-posting.md` セクション 7.5 を参照。

---

## 5. ガバナンス

- **作業フロー**: 指摘単位コミット → コミット後ローカル並列レビュー → 指摘あれば修正・反復（指摘無くなるまで）→ プッシュ → PR レビュー
- **バージョン管理**: `plugin.json` の `version` を 1 コミット 1 更新（メジャー = 新スキル追加・機能刷新 / マイナー = 既存スキル拡張 / パッチ = バグ修正・ドキュメント）
- **進捗管理**: 3 タスク以上の作業では `progress.md` を必ず作成・維持
- **エージェント活用**: 中規模以上の変更では impl + arch の並列レビューを基本とする
