# Universal Rules — 環境・セッション系（U1〜U6）

`deep-code-review` プラグイン内 SSOT [`universal-rules.md`](universal-rules.md) の詳細サブファイル。
U1〜U6（スキル構成 / ファイル文字コード / ローカルデータ領域 / セッション作業領域 / 進捗管理 / ポータブルパス）の規範本文・達成基準・整合性を保持する。

> **親（索引）**: [`universal-rules.md`](universal-rules.md) の「U マップ（U1〜U16 索引）」を参照。
> 本ファイルは MANDATORY。適用範囲・改訂手順・関連リファレンスは親ファイルが持つ。

---

## U1. スキル構成規約への準拠（MANDATORY）

### 規範

- 各スキルは `SKILL.md`（最小構成）+ `references/`（細分化されたドキュメント）+ 任意で `scripts/` で構成する
- `SKILL.md` には概要・トリガー条件・基本フロー・参照リンクのみを記載する
- 詳細仕様・規範・テンプレートは `references/` 配下に分離する
- `scripts/` 配下は **業務単位サブフォルダ** で分類する（拡張子による分類は禁止）
- テンプレートファイルは `references/template/` に配置する
- 人間向けリファレンスは `README.md`（任意・Claude 動作には使用しない）

### 達成基準

```
[ ] SKILL.md の主目的・トリガー・フロー以外を references/ に分離している
[ ] scripts/ は業務単位サブフォルダ（setup/ input/ output/ 等）で分類している
[ ] テンプレートファイルが references/template/ に配置されている
[ ] 人間向け README.md からスキル動作にはリンクしていない（あれば任意）
```

### 整合性

ユーザーグローバル規約 `~/.claude/rules/skills/skill-structure.md` と整合。プラグイン外利用者の場合は本規約のみで運用可能。

---

## U2. ファイル文字コード・改行コードの維持（MANDATORY）

### 規範

- 既存ファイルを編集する際は **元のエンコーディング・改行コード** を保持する
- UTF-8（BOM なし）を既定とするが、既存ファイルが Shift-JIS / CRLF / BOM 付きの場合はそれを維持する
- 新規ファイルはディレクトリ内同種ファイルのエンコーディング・改行コードに合わせる

### 達成基準

```
[ ] Edit / Write 適用前にファイルのエンコーディング・改行コードを確認した
[ ] 編集後にエンコーディング・改行コードが変わっていないことを確認した
[ ] 新規ファイルはディレクトリ内同種ファイルと同じエンコーディング・改行コードである
```

### 整合性

ユーザーグローバル規約 `~/.claude/rules/common/file-encoding.md` と整合。

---

## U3. ローカルデータ領域の規約遵守（MANDATORY）

### 規範

- バージョン管理対象外データは `.claude/.local/{category}/{name}/...` 配下に配置する
- カテゴリは `skills/` / `commands/` / `plugins/` / `work/` / `shared/` のいずれか
- 利用主体名（`{name}`）はスキル名・コマンド名・プラグイン名と完全一致させる
- 基準ディレクトリは「リポジトリ内 `.git` あり → リポジトリルート」「なし → `~/.claude/.local/`」の優先順位

### 達成基準

```
[ ] ローカルデータが .claude/.local/{category}/{name}/... 配下に配置されている
[ ] カテゴリは公式 5 種（skills/commands/plugins/work/shared）のいずれか
[ ] スキル名・プラグイン名・コマンド名が利用主体名と一致している
[ ] リポジトリルートが優先され、なければ ~/.claude/.local/ にフォールバックしている
```

### 整合性

ユーザーグローバル規約 `~/.claude/rules/claude/local-data-directory.md` と整合。

---

## U4. セッション作業領域の規約遵守（MANDATORY）

### 規範

- 中間生成物・一時ファイル・スクリプト・venv は `.claude/.local/work/{yyyyMMdd_nn_summary}/workspace/` に配置する
- 最終成果物はセッションフォルダ直下に配置する（複数ファイル成果物は成果物名のサブフォルダ）
- ユーザー提供資料は `.claude/.local/work/{...}/inputs/` に配置し、**読み取り専用** として扱う
- Python venv は `workspace/.venv/` に作成し、タスク完了後に削除する

### 達成基準

```
[ ] 最終成果物がセッションフォルダ直下に配置されている
[ ] 中間生成物・一時ファイルが workspace/ 配下に配置されている
[ ] ユーザー提供資料が inputs/ 配下に配置され、編集していない
[ ] Python venv が workspace/.venv/ に配置されている（使用時）
```

### 整合性

ユーザーグローバル規約 `~/.claude/rules/claude/work-directory.md` と整合。

---

## U5. 進捗管理ルール（MANDATORY）

### 規範

- 3 タスク以上の作業 / マルチエージェント作業（エージェント1体以上を起動） / 単一セッションで複数異なる成果物を生成する場合、`progress.md` を作成・維持する
- セッションフォルダ直下（`.claude/.local/work/{...}/progress.md`）に配置する
- タスク着手前に `IN_PROGRESS`、完了後に `DONE`、ブロック時は `BLOCKED` に状態を更新する
- 担当者欄は `Claude (main)` / `Agent: {role}` / `ユーザー` で区別する

### 達成基準

```
[ ] 3 タスク以上 or マルチエージェント時に progress.md を作成している
[ ] タスク着手・完了・ブロック時にステータスを更新している
[ ] 担当者欄を Claude (main) / Agent: {role} / ユーザー で記載している
[ ] 完了サマリーを最終ステータス更新時に記載している
```

### 整合性

ユーザーグローバル規約 `~/.claude/rules/claude/progress-management.md` と整合。

---

## U6. ポータブルパス記法の遵守（MANDATORY）

### 規範

| 参照対象 | 使用する記法 |
|---------|------------|
| 自スキルのファイル（自己参照） | `${CLAUDE_SKILL_DIR}/...` |
| 自プラグインのファイル | `${CLAUDE_PLUGIN_ROOT}/...` |
| セッション作業領域 | `.claude/.local/work/{yyyyMMdd_nn_summary}/...` |
| 他スキルの呼び出し | `Skill` ツール経由（パス直書き禁止） |

- `.claude/skills/{name}/` のハードコードは禁止
- 中間生成物は `workspace/`、一時ファイルは `workspace/tmp/` に配置（セッション直下に置かない）

### 達成基準

```
[ ] スキル自己参照が ${CLAUDE_SKILL_DIR}/... で記述されている
[ ] プラグイン内参照が ${CLAUDE_PLUGIN_ROOT}/... で記述されている
[ ] .claude/skills/{name}/ などのインストール形態依存パスをハードコードしていない
[ ] 他スキル呼び出しは Skill ツール経由を第一に検討している
```

### 整合性

ユーザーグローバル規約 `~/.claude/rules/skills/portable-paths.md` と整合。

---

← 索引に戻る: [`universal-rules.md`](universal-rules.md)（U マップ・適用範囲・改訂手順・関連リファレンス）
