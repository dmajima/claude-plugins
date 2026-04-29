# 外部依存スキルの利用方法

`skill-toolkit` が活用する外部プラグインのスキル群と、その参照方法。

## 1. 対象プラグイン

| プラグイン | マーケットプレイス | 主な内容 |
|----------|-----------------|---------|
| `example-skills` | `anthropic-agent-skills` | スキル雛形のベストプラクティス例 |
| `document-skills` | `anthropic-agent-skills` | ドキュメント生成系スキル（PDF / DOCX / PPTX 等） |

## 2. 利用シナリオ

| シナリオ | 利用するプラグイン |
|---------|------------------|
| 新規スキルの参考実装が欲しい | `example-skills` |
| ドキュメント生成系スキル（PDF・DOCX 等）を作る | `document-skills` |
| プロンプトキャッシュ・思考機能などの API 利用例 | `example-skills:claude-api` |
| Frontend/UI 系スキル | `document-skills:frontend-design` |

## 3. 利用前の確認

`skill-toolkit` は外部プラグインを利用する前に以下を確認する:

| 確認項目 | 確認方法 |
|---------|---------|
| ユーザの環境にインストール済みか | `~/.claude/settings.json` の `extraKnownMarketplaces` で `anthropic-agent-skills` を確認 |
| 該当スキルが利用可能か | `Skill` ツールの利用可能スキル一覧から確認 |

未インストールの場合、ユーザにインストール手順を提示する:

```text
/plugin marketplace add anthropic/skills
/plugin install example-skills@anthropic-agent-skills
/plugin install document-skills@anthropic-agent-skills
```

## 4. 利用方法（推奨パターン）

### 4.1 Skill ツール経由（第一推奨）

外部プラグインのスキルを直接呼び出す:

```text
Skill(skill: "example-skills:skill-creator", args: "...")
```

`skill-toolkit` 自身が外部スキル（`example-skills` プラグイン同梱の `skill-creator`）を呼び出すことで、知見を取り入れた生成物を得る。なお、外部プラグイン側のスキル名は当該プラグイン作成者が定義する識別子であり、本プラグインの命名規則とは独立して維持する。

### 4.2 参照のみ（推奨）

外部スキルの構造・テンプレートを参考にしつつ、生成物には外部依存を持ち込まない。

| 参考にするもの | 使い方 |
|--------------|-------|
| frontmatter の書き方 | 自スキルの SKILL.md に反映 |
| references の分割粒度 | 自スキルの references 設計に反映 |
| evals のフォーマット | 自スキルの evals に反映 |

### 4.3 生成スキル内での Skill 呼び出し（任意）

生成するスキルの中で外部スキルを呼ぶ場合、生成スキルの `SKILL.md` に明示する:

```markdown
## 依存外部スキル

| スキル | マーケットプレイス | 用途 |
|-------|-----------------|------|
| `{external-skill}` | `{marketplace}` | {用途} |
```

利用パターンは `Skill` ツール経由を第一推奨とする。直接スクリプト呼び出しは避ける（インストール形態に依存するため）。

## 5. 利用時の注意

| 注意 | 内容 |
|-----|------|
| バージョン依存 | 外部プラグインのバージョン更新で挙動が変わる可能性。生成スキルが特定バージョンに依存する場合は明記する |
| ライセンス | 外部スキルのライセンスを確認し、生成スキル側で互換性を保つ |
| 障害時のフォールバック | 外部スキルが利用不可な環境向けに、最低限のフォールバック動作を生成スキルに組み込む |

## 6. 利用しない判断

以下の場合は外部依存を持たない:

- スキルの目的が単純で外部知見不要
- ユーザが外部依存を避けたいと明示
- 生成スキルが配布対象環境で外部プラグイン非対応

## 7. 利用記録

外部スキルを利用した場合、生成スキルの README に記録する:

```markdown
## 依存外部スキル（任意参照）

| 依存先 | 用途 | 任意/必須 |
|-------|------|----------|
| `example-skills:skill-creator` | スキル雛形参照 | 任意 |
```
