---
name: mit-license-toolkit
description: Claude Code プラグイン直下に MIT LICENSE と plugin.json の license を付与するスキル。「foo に LICENSE 追加」「MIT 設定」「license-info.json 編集」等で起動。Use when adding MIT LICENSE to a plugin dir. SKIP for readme section (readme-toolkit), verify only (marketplace-publisher), non-MIT, or plugin shell (plugin-toolkit).
---

# MIT License Toolkit

Claude Code プラグインに **MIT ライセンス** を付与・更新するスキル。`LICENSE` ファイルの生成、`plugin.json` の `license` フィールド設定、ライセンス情報（著作権者・年・別名）の保存・取得・選択を一括管理する（ADR-029 / [`../../references/license-policy.md`](../../references/license-policy.md) 準拠）。

## 責務

- 対象プラグインへの `LICENSE` ファイル配置（MIT 標準文 + `Copyright (c) <year> <holder>`）
- `plugin.json` の `license` フィールド設定（`"MIT"` 固定）
- ライセンス情報ストア `license-info.json` の管理（読み取り・新規追加・選択）
- 複数エントリ存在時の `AskUserQuestion` による選択 UI 提供
- 不在時の `AskUserQuestion` による新規収集 + 保存
- 既存 `LICENSE` の検証（MIT 標準文との一致 + プレースホルダ未残存）

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| プラグイン外形生成（plugin.json 全体・README・ディレクトリ） | `plugin-toolkit`（本スキルを Skill ツール経由で呼ぶ） |
| README の「ライセンス」セクション挿入・更新 | `readme-toolkit` |
| 公開前のライセンス検証（fail-closed） | `marketplace-publisher` |
| MIT 以外の OSS ライセンス（Apache-2.0 / BSD / GPL 等）対応 | **対応外**（手動配置に委ねる） |
| ライセンス互換性レビュー（依存プラグインとの整合） | `extension-reviewer` |

## トリガー条件

- 「`{plugin}` プラグインに LICENSE を追加」「MIT ライセンスを設定」
- 「ライセンス情報を登録 / 更新」「`license-info.json` を編集」
- `plugin-toolkit` / `marketplace-publisher` / `readme-toolkit` からの Skill ツール経由呼び出し

このスキルを起動しないケース:

- 「Apache-2.0 / GPL を使いたい」（→ 対応外、手動配置）
- 「プラグイン外形を作って」（→ `plugin-toolkit` が呼び出し元になる）
- 「README にライセンス節を追加」（→ `readme-toolkit`）

## 前提

呼び出し時に以下が決まっている、または対話で確定可能:

1. 対象プラグインのパス（`plugins/{plugin-name}/`）
2. ライセンス情報（既存ストアから取得 or 新規収集）

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり、または引数で全パラメータ指定 | 非対話 | デフォルト値・引数値で確定し進行 |
| 上記以外 | 対話 | 不足パラメータを `AskUserQuestion` で確認 |

非対話モードでは `--copyright-year` `--copyright-holder` `--author` `--license-id` のいずれかを引数で指定する。`license-info.json` から `--license-id` 指定でエントリを直接選択できる。

## 実行フロー

### 1. 対象プラグインの確認

引数で指定されたプラグインパス（または対話で確認したパス）を確認し、`plugins/{plugin-name}/.claude-plugin/plugin.json` の存在を検証する。不在なら `plugin-toolkit` への接続を案内して終了。

### 2. ライセンス情報ストアの解決

[`references/procedures.md`](references/procedures.md) 節 2 の手順で `license-info.json` を解決する:

| 優先 | パス |
|-----|------|
| 1 | `<repo_root>/.claude/.local/plugins/extension-toolkit/license-info.json` |
| 2 | `~/.claude/.local/plugins/extension-toolkit/license-info.json` |

### 3. ライセンス情報の選択

| 状況 | 動作 |
|-----|------|
| ストア不在 or `licenses[]` 空 | `AskUserQuestion` で `copyright_year` `copyright_holder` `author` `label` を順次収集（対話モード）、または引数で確定（非対話モード） |
| `licenses[]` に 1 件のみ | 自動適用（適用したエントリの `label` をユーザに通知） |
| `licenses[]` に複数 | `AskUserQuestion` で利用エントリを選択（`label` を選択肢ラベル、`copyright_holder` + `copyright_year` を description）+ 「新規追加」選択肢 |
| `--license-id` 引数あり（非対話） | 該当 `id` を持つエントリを直接適用、不在ならエラーで終了 |

詳細は [`references/procedures.md`](references/procedures.md) 節 3 を参照。

### 4. 新規エントリ収集（不在時 or「新規追加」選択時）

各フィールドはテキスト対話で順次収集する（`AskUserQuestion` は選択 UI のため自由入力には使わない）。

| 項目 | 取得方法 | デフォルト |
|-----|---------|-----------|
| `copyright_holder` | テキスト対話（自由記述）| なし（必須）|
| `copyright_year` | テキスト対話 | 現在年（`date +%Y`） |
| `author` | テキスト対話 | `copyright_holder` と同値で初期化 |
| `label` | テキスト対話 | `<copyright_holder>用` |
| `id` | 自動生成（kebab-case 化、配列内一意）| なし |

収集後、**保存可否は重要選択** のため `AskUserQuestion` で「保存する / 一時利用のみ」を確認し、保存選択時のみ `license-info.json` に追記する。

### 5. LICENSE ファイル生成

`plugins/{plugin-name}/LICENSE` を生成または更新する。本文は [`references/template/LICENSE`](references/template/LICENSE) のテンプレートを使用し、`{year}` と `{copyright_holder}` を置換する。

既存 `LICENSE` がある場合は **MIT 標準文と一致するか** 検証し、不一致なら `AskUserQuestion` で「MIT に置換 / キャンセル」を確認する。

実装スクリプトは [`references/scripts/license/apply_license.py`](references/scripts/license/apply_license.py) を呼び出す。

### 6. plugin.json の license 設定

`plugins/{plugin-name}/.claude-plugin/plugin.json` の `license` フィールドに `"MIT"` を設定する。既存値が `"MIT"` 以外（例: `"Apache-2.0"`）の場合は `AskUserQuestion` で「MIT に変更 / キャンセル」を確認する。

`plugin.json` 編集時は `versioning.md` のバージョン更新ルールに従い、`plugin-toolkit` 連携時または直接呼び出し時にバージョンバンプを判断する（**bug fix 扱いで patch バンプ**）。

### 7. 検証

- [ ] `plugins/{name}/LICENSE` が存在する
- [ ] `LICENSE` の本文が `references/template/LICENSE` のテンプレート（MIT 標準文）と一致する
- [ ] `Copyright (c) <year> <holder>` の `<year>` `<holder>` が空でなく、プレースホルダ `{year}` `{holder}` が残存していない
- [ ] `plugin.json` の `license == "MIT"`
- [ ] `license-info.json` を新規保存した場合、`.claude/.local/plugins/extension-toolkit/` 配下に配置されている
- [ ] `license-info.json` の `version` が `1`、`licenses[]` が valid JSON
- [ ] パスポータビリティチェック合格（[`../../references/path-portability.md`](../../references/path-portability.md)）

### 8. 引き渡し

**作業完了報告の前に必須**: [`../../references/completion-checklist.md`](../../references/completion-checklist.md) 節 2.4 に従い、LICENSE 生成内容のプレビュー + `plugin.json.license` の値確認を実施し、`AskUserQuestion` で承認を取得する（ADR-032）。法的文書のため軽微変更でも省略不可。

生成・変更したファイル一覧を提示する。

| 次のアクション | 接続先 |
|--------------|-------|
| README に「ライセンス」セクション追加 | `readme-toolkit` |
| プラグイン公開 | `marketplace-publisher` |
| 全体レビュー | `extension-reviewer` |

## 重要な制約

- MIT 以外の OSS ライセンス対応は **責務外**（利用者が手動で `LICENSE` を差し替え、`plugin.json.license` を更新する）
- `LICENSE` の本文は MIT 標準文と一字一句一致させる（OSI / SPDX 準拠、[`references/template/LICENSE`](references/template/LICENSE) を SSOT とする）
- `license-info.json` をリポジトリにコミットしない（`.gitignore` 対象）
- ライセンス選択は `AskUserQuestion` を必ず使用する（重要選択、テキスト対話禁止）
- 既存ファイル更新時はエンコーディング・改行コード維持（`~/.claude/rules/common/file-encoding.md` 不在時は UTF-8 / 元の改行コードを既定維持）
- `plugin.json` 編集時は `versioning.md` のバージョン更新を実施
- パスポータビリティチェック必須
- 利用者環境非依存性の維持（[`../../references/self-containment.md`](../../references/self-containment.md)、ADR-022）
- 第三者レビュー起動時はフレッシュ Agent インスタンスで起動（[`../../references/review-freshness.md`](../../references/review-freshness.md)、ADR-021）
- `git commit` 以降の操作は実行しない
- 作業完了報告前に [`../../references/completion-checklist.md`](../../references/completion-checklist.md) に基づく自己検証（ルール順守 + 要件適合 + 結果完全性）を実施

## 参照

| 用途 | ファイル |
|-----|---------|
| ライセンスポリシー（SSOT） | [`../../references/license-policy.md`](../../references/license-policy.md) |
| 命名・配置規約 | [`../../references/conventions.md`](../../references/conventions.md) |
| AI 誤認回避 | [`../../references/ai-readability.md`](../../references/ai-readability.md) |
| ポータブルパス | [`../../references/path-portability.md`](../../references/path-portability.md) |
| ユーザ対話 | [`../../references/user-interaction.md`](../../references/user-interaction.md) |
| 検証ルール | [`../../references/validation-rules.md`](../../references/validation-rules.md)（節 1 + 2.2） |
| バージョン管理 | [`../../references/versioning.md`](../../references/versioning.md) |
| 詳細手順 | [`references/procedures.md`](references/procedures.md) |
| LICENSE テンプレート | [`references/template/LICENSE`](references/template/LICENSE) |
| 動作例 | [`evals/`](evals/) |
