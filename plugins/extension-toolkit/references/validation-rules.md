# 検証ルール（SSOT）

`extension-toolkit` の各 `*-toolkit` および `extension-reviewer` が共通で参照する検証チェックリスト。同じ検証ルールを複数箇所に書かないようにこのファイルに集約する。

## 1. 共通検証項目（全拡張要素）

| 項目 | 重大度 | 確認方法 |
|-----|-------|---------|
| frontmatter valid | Critical | YAML パース |
| JSON valid | Critical | JSON パース |
| パスポータビリティ | Critical or High | Grep（[`path-portability.md`](path-portability.md) 参照） |
| プレースホルダ残存（`{kebab-case}`） | High | Grep `{[a-z][a-z0-9-]*}` |
| `§` 記号の使用 | Medium | Grep `§` |
| エンコーディング・改行コード保持 | Critical | バイト列比較 |
| description 文字数 | Medium | 文字数カウント（[`description-guide.md`](description-guide.md) 参照） |
| ディレクトリ構造の許可リスト遵守 | High | `conventions.md` 節 2.1 / 3.1 と照合 |
| 利用者環境非依存性（ADR-022） | High | グローバルルール / グローバルエージェント / 外部ツール前提の棚卸し（[`self-containment.md`](self-containment.md) 節 5） |
| レビュー起動はフレッシュインスタンス（ADR-021） | High | スポーンプロンプトに必須引き継ぎ事項が含まれ、引き継ぎ禁止事項が含まれないこと（[`review-freshness.md`](review-freshness.md) 節 2-3） |

### 1.1 ディレクトリ構造の許可リスト機械チェック（厳格対象のみ）

[`conventions.md`](conventions.md) の許可リストを正典として、**厳格運用 2 階層** に対して機械チェックする。`references/` 直下と `scripts/` 直下は推奨例のため対象外（人間レビューで確認）。

| 階層 | 厳格度 | 許可リスト | 違反時の重大度 |
|-----|-------|----------|------------|
| プラグイン直下 | **厳格** | `.claude-plugin/` `README.md` `commands/` `skills/` `agents/` `hooks/` `mcp/` `references/` | High |
| スキル直下 | **厳格** | `SKILL.md` `README.md` `references/` `scripts/` `agents/` `evals/` | High |
| `references/` 直下 | 推奨例 | （機械チェックなし、人間レビュー） | - |
| `scripts/` 直下 | 推奨例 + 一部禁止 | 禁止項目（`knowledge/` `lib/` `bin/`、拡張子別サブフォルダ）のみ機械検出 | Medium |

許可リスト外のエントリ（厳格 2 階層）を検出した場合は High 指摘とし、ADR で例外として明示されているか確認する。明示されていなければ修正必須。

#### Bash でのチェック例

以下の例は **テンプレート** であり、`{plugin-name}` を実プラグイン名（例: `dev-toolkit`）に置換してから実行する必要がある。
そのまま実行するとリテラル文字列 `{plugin-name}` として glob 展開されず、空ループになる点に注意。

```bash
# プラグイン名を変数化（{plugin-name} を実値に置換）
PLUGIN_NAME="dev-toolkit"   # ← 実値に置換

# プラグイン直下に許可されないディレクトリ・ファイルがあるか
ALLOWED_PLUGIN_ROOT=".claude-plugin commands skills agents hooks mcp references README.md"
for entry in plugins/"$PLUGIN_NAME"/*; do
  name=$(basename "$entry")
  if ! echo "$ALLOWED_PLUGIN_ROOT" | grep -qw "$name"; then
    echo "[High] Disallowed entry at plugin root: $entry"
  fi
done

# スキル直下に許可されないエントリがあるか
ALLOWED_SKILL_ROOT="SKILL.md README.md references scripts agents evals"
for skill_dir in plugins/"$PLUGIN_NAME"/skills/*/; do
  for entry in "$skill_dir"*; do
    name=$(basename "$entry")
    if ! echo "$ALLOWED_SKILL_ROOT" | grep -qw "$name"; then
      echo "[High] Disallowed entry at skill root: $entry"
    fi
  done
done

# scripts/ 配下の禁止命名チェック
for forbidden in knowledge lib bin py sh; do
  find plugins/"$PLUGIN_NAME"/skills/*/scripts -maxdepth 1 -type d -name "$forbidden" 2>/dev/null \
    | while read d; do echo "[Medium] Forbidden subfolder name: $d"; done
done
```

## 2. 種別別検証項目

### 2.1 スキル（`skill-toolkit` 出力）

| 項目 | 重大度 | 確認方法 |
|-----|-------|---------|
| `SKILL.md` 200 行以内 | High | `wc -l` |
| frontmatter `name` がディレクトリ名と一致 | High | パス比較 |
| 必須セクション存在（責務 / 責務外 / トリガー条件 / 前提 / 実行モード判定 / 実行フロー / 重要な制約） | High | パターン検索 |
| `scripts/` 命名（`knowledge/` 不可） | Medium | パス確認 |
| Python 利用時の依存リスト保有（`scripts/deps/requirements.txt` または `references/setup.md`） | High | ファイル存在確認 |
| Python 利用時の venv 構築・撤去は `environment-setup-toolkit` に委譲（スキル内 `scripts/setup/setup_venv.sh` 等は配置不要） | Medium | パターン不在確認 |
| `agents/` 削除痕跡なし（更新時） | High | git diff |
| 動作分岐がある場合 `evals/` 存在 | High | ディレクトリ存在確認 |
| `README.md` 存在 | Medium | ファイル存在確認 |

### 2.2 プラグイン（`plugin-toolkit` 出力）

| 項目 | 重大度 | 確認方法 |
|-----|-------|---------|
| `plugin.json` の `name` がディレクトリ名と一致 | High | パス比較 |
| `README.md` 存在 | High | ファイル存在確認 |
| 移管シナリオで元ファイルが無傷 | Critical | git diff |
| 移管後の `settings.json` が改変されていない | Critical | git diff |
| 含まれるスキル/コマンド/エージェント/フックの種別別検証合格 | High | 本ファイルの該当節 |
| シークレットファイル不在（`.env` / `*.pem` / `*.key` / `id_rsa` / `credentials.json` / `secrets.json` 等） | Critical | ファイル名パターン + 内容パターンスキャン（[`../skills/marketplace-publisher/references/secret-scan.md`](../skills/marketplace-publisher/references/secret-scan.md) 参照） |

### 2.3 コマンド（`command-toolkit` 出力）

| 項目 | 重大度 | 確認方法 |
|-----|-------|---------|
| frontmatter `description` 60 文字以内 | Medium | 文字数カウント |
| 引数仕様が description に記載されていない | Low | パターン検索 |
| frontmatter `argument-hint` 存在（引数受取コマンド、ADR-023） | High | YAML キー存在 + 本文 `$ARGUMENTS` 有無の照合 |
| `argument-hint` 60 文字以内・改行なし | Medium | 文字数 + 改行検査 |
| `argument-hint` の引数表記規則順守（`<...>` / `[...]` / `[--flag]`） | Medium | 正規表現照合 |
| ルーティング先スキルが存在（オーケストレータ型） | High | スキル存在確認 |

### 2.4 エージェント（`agent-toolkit` 出力）

| 項目 | 重大度 | 確認方法 |
|-----|-------|---------|
| frontmatter `name` `description` `model` `tools` 全指定 | High | YAML 検査 |
| 評価観点 3 つ以上 | High | パターン検索 |
| 出力フォーマット定義済 | High | パターン検索 |
| プロンプトテンプレートあり | Medium | パターン検索 |

### 2.5 エージェントチーム（`agent-toolkit` チームモード出力）

| 項目 | 重大度 | 確認方法 |
|-----|-------|---------|
| メンバー数 3 名以上（レビュー系） | High | リスト件数確認 |
| リードエージェント指定済 | High | パターン検索 |
| 各メンバーのエージェント定義が存在 | High | ファイル存在確認 |
| 議論ラウンド数 3 以上 | Medium | パターン検索 |
| 専門性が相補的（重複なし） | Medium | 担当エージェント比較 |

### 2.6 フック（`hook-toolkit` 出力）

| 項目 | 重大度 | 確認方法 |
|-----|-------|---------|
| JSON valid | Critical | JSON パース |
| イベント名が正規 | High | 既知イベントとの照合 |
| matcher 正規表現 valid（PreToolUse / PostToolUse） | High | 正規表現パース |
| command にローカル絶対パスのハードコードなし | Critical | パスポータビリティ |
| timeout 指定済 | Medium | フィールド存在確認 |
| `settings.json` 既存エントリの保全（マージ書き戻し） | Critical | 既存比較 |

### 2.7 README（`readme-toolkit` / `marketplace-toolkit` 出力）

#### プラグイン・スキル READMEの共通項目

| 項目 | 重大度 | 確認方法 |
|-----|-------|---------|
| 「このドキュメントについて」セクション存在 | Medium | パターン検索 |
| ファイル構成が実構成と一致 | High | ツリー比較 |
| 過去履歴・変更経緯記載なし | Medium | パターン検索 |
| プレースホルダ残存なし | High | Grep |

#### プラグイン README 固有項目（ADR-018 準拠）

| 項目 | 重大度 | 確認方法 |
|-----|-------|---------|
| 導入手順 4 要素の存在（A: マーケットプレイス経由 / B: ローカル複製 / C: 自動更新 / D: 依存関係） | High | 必須セクションパターン検索 |
| ローカル複製手順に `git clone` + `/plugin marketplace add <local-path>` の両方が記載されている | High | パターン検索 |
| 自動更新セクションに `autoUpdate: true` の設定例が記載されている | Medium | パターン検索 |
| 依存関係セクションが存在（依存なしの場合も「依存関係なし」と明示） | High | パターン検索 |

### 2.8 マーケットプレイス（`marketplace-toolkit` 出力、ADR-019 / ADR-020 準拠）

#### marketplace.json

| 項目 | 重大度 | 確認方法 |
|-----|-------|---------|
| `marketplace.json` JSON valid | Critical | JSON パース |
| `name` がリポジトリディレクトリ名と一致 | High | パス比較 |
| `plugins[]` 各エントリに `name` / `source` / `description` 必須 | High | キー存在確認 |
| 各 `plugins[].source` が実在 | Critical | パス確認 |
| 各 `plugins[].name` が `<source>/.claude-plugin/plugin.json` の `name` と一致 | High | クロス参照 |
| バージョン情報を `marketplace.json` に持たせない（`plugin.json` のみが正典） | Medium | フィールド不在確認 |
| `plugins[]` がアルファベット順 | Low | ソート比較 |

#### マーケットプレイス直下 README

| 項目 | 重大度 | 確認方法 |
|-----|-------|---------|
| 「プラグイン一覧」セクション存在 | Critical | パターン検索 |
| プラグイン一覧テーブル行数 = `marketplace.json` の `plugins[]` 件数 | Critical | カウント比較 |
| 各行のプラグイン名が `marketplace.json` と完全一致 | Critical | クロス参照 |
| バージョン列が各 `<source>/.claude-plugin/plugin.json` の `version` と一致 | High | クロス参照 |
| 「マーケットプレイスの追加方法」セクション存在（A: URL / B: ローカル複製の両方） | High | パターン検索 |
| 「自動更新の有効化」セクション存在 | High | パターン検索 |
| `marketplace.json` 編集と同一コミットに README 変更が含まれる | High | git diff 確認 |

## 3. 検証実施タイミング

| タイミング | 実施者 |
|----------|-------|
| `*-toolkit` 実行直後 | 各 `*-toolkit` 自身（自己検証） |
| プラグイン公開前 | `extension-reviewer`（並列エージェント + 機械チェック） |
| マーケットプレイス登録前 | `marketplace-publisher`（プラグイン実体検証部分のみ） |

## 4. 自動修正の可否

| 項目 | 自動修正可否 |
|-----|-----------|
| プレースホルダ残存 | 不可（置換値の判断必要） |
| `§` 記号 | 可（代替表現に置換） |
| 明確な NG パス | 一部可 |
| 構造的問題（必須セクション欠落等） | 不可 |
| description 不適切 | 不可 |
| エンコーディング破壊 | 不可（バックアップ必要） |

## 5. 検証失敗時の対応

| 重大度 | 対応 |
|-------|------|
| Critical | 即時修正必須。ユーザに提示後、修正完了まで次工程に進めない |
| High | 修正推奨。修正なしで進行する場合はユーザの明示的承認を要する |
| Medium | 検討推奨。指摘として記録し、ユーザの判断に委ねる |
| Low | 改善提案として記録 |

## 6. 各 toolkit / reviewer からの参照

| 参照元 | 参照部分 |
|-------|---------|
| `skill-toolkit` | 1 + 2.1（スキル出力検証） |
| `plugin-toolkit` | 1 + 2.2（プラグイン外形検証）+ 種別別の該当節 |
| `command-toolkit` | 1 + 2.3 |
| `agent-toolkit` | 1 + 2.4（単体）or 2.5（チーム） |
| `hook-toolkit` | 1 + 2.6 |
| `readme-toolkit` | 1 + 2.7 |
| `marketplace-toolkit` | 1 + 2.8（マーケットプレイス本体検証） |
| `extension-reviewer` | 全節 + 自動チェック手順は [`../skills/extension-reviewer/references/automated-checks.md`](../skills/extension-reviewer/references/automated-checks.md) |
| `marketplace-publisher` | 1 + 2.2（実体検証）+ 2.8（マーケットプレイス README 同期確認） |

## 7. 関連ファイル

| 用途 | ファイル |
|-----|---------|
| 命名・配置規約 | [`conventions.md`](conventions.md) |
| AI 誤認回避 | [`ai-readability.md`](ai-readability.md) |
| description 設計 | [`description-guide.md`](description-guide.md) |
| ポータブルパス | [`path-portability.md`](path-portability.md) |
| evals 設計 | [`eval-guide.md`](eval-guide.md) |
| アーキテクチャ決定 | [`architecture-decisions.md`](architecture-decisions.md) |
