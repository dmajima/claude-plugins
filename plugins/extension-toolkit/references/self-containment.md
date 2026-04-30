# プラグイン自己完結性・再現性ポリシー（SSOT）

`extension-toolkit` および本プラグインが生成するすべてのスキル・プラグインに適用される、**利用者環境非依存・再現性** の設計ルール（ADR-022 準拠）。

---

## 1. 原則

> プラグインは **インストールするだけで動作** しなければならない。
> 利用者環境のセットアップ状況に依存させてはならない。

この原則は単なる推奨ではなく、本プラグインが生成・配布する全成果物に適用される **必須要件** とする。

---

## 2. 利用者環境依存の典型パターンと対処

### 2.1 グローバルルール依存（`~/.claude/rules/`）

| 状態 | 判定 | 対処 |
|------|-----|------|
| グローバルルール参照あり | NG | プラグイン内 `references/` に SSOT を持つ |
| グローバルルール存在前提 | NG | 不在時の動作を定義 |
| プラグイン内 SSOT のみ参照 | OK | （現状の本プラグイン） |

**例外**: `~/.claude/rules/common/file-encoding.md` のような OS / Claude Code 共通ルールへの参照は、プラグイン外（OS 規約）として扱い参照を許容する。ただし不在時の動作（フォールバック）を定義する。

### 2.2 グローバルエージェント依存（`~/.claude/agents/`）

| 状態 | 判定 | 対処 |
|------|-----|------|
| グローバルエージェントを `subagent_type` で起動 | 利用者環境にそのエージェントがあるか不明 | プラグイン同梱（`agents/` 配下にコピー）、またはフォールバック設計 |
| プラグイン同梱エージェントのみ起動 | OK | （理想形） |

#### 段階的同梱戦略

本プラグインは、以下の優先度でグローバルエージェントの同梱化を進める:

| 優先度 | 対象 | 理由 |
|-------|------|------|
| 高 | `extension-reviewer` のチームで頻繁に起動するエージェント（`architect` / `implementation-engineer` / `security-engineer` / `test-engineer` 等） | レビューの中核、不在で機能停止 |
| 中 | プラグインのレビュー観点で必要なエージェント（`infrastructure-engineer` / `dba` / `legal-advisor` 等） | 一部のレビューで必要 |
| 低 | 限定シーンのみのエージェント（`ux-designer` / `customer-support` 等） | 任意性が高い |

同梱時は `agents/{name}.md` に配置し、SKILL.md / 各 references の参照を **同梱版優先** に切り替える。
同梱版がない場合のフォールバックを SKILL.md に明記する。

### 2.3 グローバル設定依存（`~/.claude/settings.json`）

| 設定 | 判定 | 対処 |
|-----|-----|------|
| `extraKnownMarketplaces` の `autoUpdate: true` | 推奨だが必須ではない | README で推奨理由を説明、未設定時は `/plugin update` 手動案内 |
| 他の Claude Code 設定 | 設定の有無で動作が変わってはならない | プラグイン内で完結する設計 |

### 2.4 グローバルスキル依存（`~/.claude/skills/` または別プラグインのスキル）

| 状態 | 判定 | 対処 |
|------|-----|------|
| 別プラグイン提供のスキルを Skill ツール経由で呼び出す | 利用者環境にそのプラグインがあるか不明 | 不在時のフォールバック設計を SKILL.md / references に明示 |
| グローバルスキル（`~/.claude/skills/`）への依存 | 利用者環境のセットアップに依存 | 不在時のフォールバック動作を必ず定義（OK） |

**例**: `marketplace-publisher` は認証エラー時に `credentials-manager` グローバルスキルへの接続を提案する。`credentials-manager` 不在時のフォールバックは「ユーザに直接認証情報の確認を依頼」とする（[`../skills/marketplace-publisher/references/secret-scan.md`](../skills/marketplace-publisher/references/secret-scan.md) および [`../skills/marketplace-publisher/references/publish-workflow.md`](../skills/marketplace-publisher/references/publish-workflow.md) で明記）。

### 2.5 外部ツール依存（git / python / gh 等）

| ツール | 依存箇所 | 対処 |
|-------|--------|------|
| git | ローカル複製インストール、`marketplace-publisher` の git 操作 | README「動作要件」に明示。不在時はインストールガイド |
| python 3.10+ | `environment-setup-toolkit` の venv 構築 | 利用しないスキルは独立して動作。venv 利用時のみ前提 |
| gh CLI | `marketplace-publisher` のフルオート PR 作成 | 不在時はハンドオフモードに切替 |

外部ツール前提はすべて README の「動作要件」または「依存関係」セクションに **明示** する（ADR-018 D 要素）。

### 2.6 マーケットプレイス依存

| 依存 | 対処 |
|-----|------|
| `dependencies` で他マーケットプレイスのプラグインを参照 | `marketplace.json` の `allowCrossMarketplaceDependenciesOn` で許可 + README で個別インストール手順を明示 |
| 同マーケットプレイス内の他プラグインを参照 | `marketplace.json` の `plugins[]` に依存先が登録されていることを確認 |

---

## 3. パスの自己完結性

### 3.1 必須記法

| 用途 | 記法 |
|-----|------|
| プラグイン内ファイル参照（自プラグイン） | `${CLAUDE_PLUGIN_ROOT}/...` |
| スキル内ファイル参照（自スキル） | `${CLAUDE_SKILL_DIR}/...` |
| プラグインの永続データ | `${CLAUDE_PLUGIN_DATA}/...` |
| セッション作業領域 | `.claude/.local/work/{yyyyMMdd_nn_summary}/...` |

詳細は [`path-portability.md`](path-portability.md) を参照。

### 3.2 禁止記法

- ローカル絶対パス（`C:\Users\...` / `/home/{user}/...` 等）
- ハードコードされたユーザ名・ホスト名
- インストール時のみ有効なパス

---

## 4. 自己検証項目（completion-checklist 連動）

作業完了前に以下を確認:

- [ ] グローバルルール（`~/.claude/rules/`）への依存がない、または不在時フォールバックがある
- [ ] グローバルエージェント参照がプラグイン同梱版または明示フォールバックを持つ
- [ ] グローバル設定（`~/.claude/settings.json`）への依存がない、または推奨レベルで案内される
- [ ] 外部ツール前提が README「動作要件」「依存関係」に列挙されている
- [ ] すべてのパスが `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_SKILL_DIR}` / セッション作業領域起点
- [ ] ローカル絶対パスのハードコードがない
- [ ] 利用者環境の事前セットアップを前提とする動作がない、または導入手順で明示される
- [ ] プラグインインストール **直後** に最低限の動作が確認できる（`/extension --help` 等）

詳細チェックリストは [`completion-checklist.md`](completion-checklist.md) を参照。

---

## 5. 依存箇所の棚卸し

新規スキル・プラグイン作成時、または改修時には以下を棚卸しする:

| カテゴリ | チェック方法 |
|---------|------------|
| グローバルルール参照 | Grep `~/.claude/rules/` |
| グローバルエージェント参照 | Grep `~/.claude/agents/` または `subagent_type` で起動するエージェント名一覧 |
| グローバル設定依存 | Grep `~/.claude/settings.json` / `extraKnownMarketplaces` 等 |
| 外部ツール依存 | スクリプト内の `command -v` / `which` / 直接呼び出し |
| ローカル絶対パス | Grep `[A-Z]:[\\/]` / `/home/` / `/Users/` |

検出した依存はすべて以下のいずれかに分類:

| 分類 | 対処 |
|-----|------|
| 削除可能 | 削除する |
| プラグイン同梱可能 | プラグインに同梱する |
| 利用者前提として明示 | README「動作要件」「依存関係」に追記 |
| フォールバック設計可能 | 不在時の代替動作を実装 |

---

## 6. 既存スキル・プラグイン改修時の段階的対応

完全な自己完結化を一度に達成するのは困難。以下の段階で進める:

| ステージ | 内容 | 完了基準 |
|---------|------|---------|
| Stage 1: 棚卸し | 依存箇所の全洗い出し | 依存リスト作成 |
| Stage 2: 明示化 | README に依存を明示、利用者環境前提を提示 | README 完備 |
| Stage 3: 同梱化（高優先） | レビューチームの中核エージェント等を同梱 | 主要レビュー機能が同梱版で動作 |
| Stage 4: フォールバック化 | 同梱できない依存に対してフォールバック実装 | 不在環境でも基本動作 |
| Stage 5: 完全自己完結化 | 任意の依存をすべて解消 | プラグインインストールのみで全機能動作 |

本プラグイン（`extension-toolkit`）は現状 **Stage 2 完了 / Stage 3 進行中** とする。
今後の改修で Stage 3 → 4 → 5 と段階的に進める。

---

## 7. 禁止事項

- 利用者にグローバルルール（`~/.claude/rules/`）の特定ファイル設置を前提とする実装
- 利用者にグローバルエージェント（`~/.claude/agents/`）の特定エージェント存在を前提とし、不在時の挙動が未定義
- ローカル絶対パスのハードコード
- 利用者の `~/.claude/settings.json` の特定キー設定を必須前提とする実装（推奨は OK）
- 「自分の環境では動いた」を理由に依存を許容すること

---

## 8. 関連ファイル

| 用途 | ファイル |
|-----|---------|
| パス記法（自己完結性のサブセット） | [`path-portability.md`](path-portability.md) |
| 依存関係宣言 | [`dependencies-policy.md`](dependencies-policy.md) |
| 検証ルール | [`validation-rules.md`](validation-rules.md)（新節 1.x で本ポリシー検証） |
| 完了チェック | [`completion-checklist.md`](completion-checklist.md) |
| アーキテクチャ決定 | [`architecture-decisions.md`](architecture-decisions.md)（ADR-022） |
