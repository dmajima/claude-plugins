# テンプレート（推奨構成の明示管理）

`extension-toolkit` の各スキルが拡張要素を生成する際に使用する **推奨構成テンプレート**。生成物のムラを抑制するため、推奨構成は本ディレクトリで一元管理する。

## このドキュメントについて

このファイルは人間向けのリファレンス。Claude Code がスキル動作中に参照することはあるが、テンプレート本体への参照はスキルの SKILL.md / references で行う。

## テンプレートファイル取り扱い注意

本ディレクトリ配下の各テンプレート（`skill/SKILL.md` 等）は、生成先にコピーされた **後に** 解決される相対パス（例: `../../references/...`）を含む。
テンプレート単独で見ると相対パスが解決不能に見えるが、それは仕様であり broken link ではない。
レビューや自動チェックでは `references/templates/` 配下のリンク到達可能性を必須項目から除外すること。

## テンプレート一覧

| テンプレート | パス | 利用スキル |
|-------------|------|----------|
| スキル一式 | `skill/` | `skill-toolkit` |
| プラグイン外形 | `plugin/` | `plugin-toolkit` |
| スラッシュコマンド | `command/command.md` | `command-toolkit` |
| サブエージェント | `agent/agent.md` | `agent-toolkit` |
| エージェントチーム | `agent/team.md` | `agent-toolkit` |
| フック | `hook/hooks.json` | `hook-toolkit` |
| README | `readme/README.md` | `readme-toolkit` |
| マーケットプレイス一式 | `marketplace/` | `marketplace-toolkit` |

## 利用方針

| 項目 | 値 |
|-----|---|
| 配置場所 | プラグイン直下 `references/templates/` で全スキル共有 |
| プレースホルダ | `{kebab-case}` 形式の文字列 |
| 置換タイミング | スキル実行時に値を埋める |
| バージョン管理 | このディレクトリのテンプレートが正典 |

## スキル固有のテンプレートが必要な場合

各スキルは本テンプレートをコピーして `skills/{skill-name}/references/template/` に派生版を作成し、そこから読み込む。本ディレクトリのテンプレートを直接編集すると、全スキルに影響するため注意する。

## プレースホルダ命名規則

| プレースホルダ | 意味 |
|--------------|------|
| `{plugin-name}` | プラグイン名（kebab-case） |
| `{skill-name}` | スキル名（kebab-case） |
| `{command-name}` | コマンド名（kebab-case） |
| `{agent-name}` | エージェント名（kebab-case） |
| `{team-name}` | チーム名（kebab-case） |
| `{author-name}` | 作者名 |
| `{marketplace-name}` | マーケットプレイス名 |
| `{...}` 内のその他 | 文脈で意味が明らかな自由記述 |
