# ライセンスポリシー（SSOT）

`extension-toolkit` が生成・改修・公開する **すべてのプラグイン** に対するライセンス必須化ルール（ADR-029 準拠）。

## 1. 基本方針

| 観点 | 内容 |
|-----|------|
| **採用ライセンス** | **MIT ライセンス（SPDX: `MIT`）固定** |
| **適用範囲** | `extension-toolkit` が生成・改修・公開支援するすべてのプラグイン |
| **担当スキル** | `mit-license-toolkit`（情報の保存・取得・選択・LICENSE 生成・plugin.json 更新） |
| **省略可否** | **省略不可**（公開フローは `LICENSE` 不在を fail-closed で停止） |

MIT 以外の OSS ライセンスを使いたい場合、利用者は `LICENSE` ファイルを手動で差し替え、`plugin.json` の `license` を更新する。`mit-license-toolkit` の自動生成・検証フローからは外れる。

## 2. 必須項目

### 2.1 配置物

| 配置先 | 内容 | 必須 |
|-------|------|------|
| `plugins/{plugin-name}/LICENSE` | MIT 標準文 + `Copyright (c) <year> <holder>` 行 | **必須** |
| `plugins/{plugin-name}/.claude-plugin/plugin.json` の `license` フィールド | `"MIT"` 固定 | **必須** |
| `README.md` の「ライセンス」セクション | `LICENSE` への参照 | **必須**（[`readme-policy.md`](readme-policy.md) 節 3 セクション 12） |

### 2.2 LICENSE ファイルの本文

```text
MIT License

Copyright (c) {year} {copyright_holder}

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

`{year}` と `{copyright_holder}` は `mit-license-toolkit` がライセンス情報から差し込む。原文は OSI / SPDX 公開の MIT 標準文と一字一句一致させる。

### 2.2.1 LICENSE テンプレートの SSOT

| 配置 | 役割 | 更新方針 |
|-----|------|---------|
| `skills/mit-license-toolkit/references/template/LICENSE` | **SSOT（正規）** | 本ファイルが MIT 標準文の正典。本ポリシー節 2.2 と完全一致させる |
| `references/templates/plugin/LICENSE` | スキル固有 SSOT のミラー（横断テンプレートとして配布） | `mit-license-toolkit` の SSOT を **コピー** したもの。SSOT を更新したら本ミラーも同期する（人間レビューで一致確認）|

ADR-003（テンプレートの 2 階層管理）は通常「横断 → スキル固有派生」だが、本件はスキル `mit-license-toolkit` が LICENSE 生成・検証の責務を持つため例外的に **スキル固有を SSOT** とする。`plugin-toolkit` がプラグイン外形作成時に横断テンプレートをコピーする経路で `LICENSE` を初期配置できるようにするためのミラーとして `references/templates/plugin/LICENSE` を保持する。両者の本文が一致しないと `mit-license-toolkit` が後段で上書きするため動作には支障しないが、テンプレート読み手の混乱を避けるため一致を維持すること。

### 2.3 plugin.json の license フィールド

```json
{
  "name": "{plugin-name}",
  "version": "1.0.0",
  "description": "...",
  "license": "MIT",
  "author": { "name": "..." }
}
```

| キー | 値 |
|-----|---|
| `license` | `"MIT"` 固定（SPDX 識別子） |

## 3. ライセンス情報の保持

### 3.1 保存先

利用者はプロジェクトごとに著作権者・年・別名等のライセンス情報を保持できる。保存先は次の優先順位で決定する。

| 優先 | 条件 | パス |
|-----|------|------|
| 1（優先） | 現在のワーキングディレクトリがリポジトリ（`.git` を含む）配下 | `<repo_root>/.claude/.local/plugins/extension-toolkit/license-info.json` |
| 2（フォールバック） | リポジトリ外での作業 | `~/.claude/.local/plugins/extension-toolkit/license-info.json` |

`.claude/.local/` はグローバルルール（`local-data-directory.md`）の `plugins/{name}/` カテゴリに準拠。`.gitignore` 登録対象でリポジトリには **コミットされない**。

### 3.2 ファイル形式（JSON）

```json
{
  "version": 1,
  "licenses": [
    {
      "id": "personal",
      "type": "MIT",
      "copyright_year": "2026",
      "copyright_holder": "Taro Yamada",
      "author": "Taro Yamada",
      "label": "個人プロジェクト用"
    },
    {
      "id": "company",
      "type": "MIT",
      "copyright_year": "2026",
      "copyright_holder": "Acme Corporation",
      "author": "Acme Corporation",
      "label": "Acme 社プロジェクト用"
    }
  ]
}
```

| フィールド | 必須 | 内容 |
|-----------|------|------|
| `version` | 必須 | 形式バージョン（現在 `1`） |
| `licenses[]` | 必須 | ライセンス情報の配列（1 件以上） |
| `licenses[].id` | 必須 | エントリ識別子（kebab-case 推奨、配列内で一意） |
| `licenses[].type` | 必須 | SPDX 識別子（現在 `"MIT"` のみ） |
| `licenses[].copyright_year` | 必須 | 著作年（4 桁または `"2024-2026"` のような範囲） |
| `licenses[].copyright_holder` | 必須 | 著作権者（個人名または法人名） |
| `licenses[].author` | 任意 | プラグイン作者名（`plugin.json` の `author.name` への転記候補。`copyright_holder` と同一なら省略可） |
| `licenses[].label` | 推奨 | UI 上の選択肢ラベル（人間可読） |

### 3.3 不在時・複数存在時の動作

| 状況 | 動作 |
|-----|------|
| `license-info.json` が **存在しない** | `AskUserQuestion` で `copyright_year` `copyright_holder` `author` `label` を順次収集。完了後、新規エントリを `license-info.json` に保存（`AskUserQuestion` で「保存する / 一時利用のみ」を確認）|
| `licenses[]` に **1 件のみ** 存在 | 自動適用（適用したエントリのラベルをユーザに通知）|
| `licenses[]` に **複数** 存在 | `AskUserQuestion` で利用するエントリを選択（`label` を選択肢ラベル、`copyright_holder` + `copyright_year` を description）|
| 利用者が「新規追加」を選択 | 新規エントリ収集 → 保存 → そのエントリを適用 |

`AskUserQuestion` の利用は [`user-interaction.md`](user-interaction.md) に従う。**重要なライセンス選択** を伴うため、テキスト対話で行ってはならない。

## 4. 公開フローでの検証（fail-closed）

`marketplace-publisher` はプラグイン公開前に以下を **fail-closed**（不合格なら停止）で検証する。

| 検証項目 | 重大度 | 不合格時の動作 |
|---------|-------|--------------|
| `plugins/{name}/LICENSE` が存在 | Critical | 公開停止、`mit-license-toolkit` への接続を案内 |
| `LICENSE` の本文が MIT 標準文と一致 | Critical | 公開停止、本ポリシー節 2.2 の本文を提示 |
| `LICENSE` の `Copyright (c) <year> <holder>` 行に `<year>` `<holder>` が埋まっている | Critical | 公開停止、`mit-license-toolkit` で再生成を案内 |
| `plugin.json` の `license == "MIT"` | Critical | 公開停止、フィールド追加を案内 |
| `README.md` の「ライセンス」セクションが存在 | High | 警告、`readme-toolkit` で追加を案内 |

## 5. README の「ライセンス」セクション

プラグイン README の末尾に必ず以下を含める（[`readme-policy.md`](readme-policy.md) 節 3 セクション 12）:

```markdown
## ライセンス

[MIT License](LICENSE) の下で配布されています。
```

スキル README ではライセンス記載は任意（プラグイン直下の `LICENSE` がスキルにも適用される）。

## 6. mit-license-toolkit との連携

| 連携元 | 連携内容 |
|-------|--------|
| `plugin-toolkit`（新規外形作成・既存追加） | プラグイン外形生成直前または直後に `mit-license-toolkit` を Skill ツール経由で呼び出し、`LICENSE` 配置 + `plugin.json.license` 設定 |
| `readme-toolkit` | プラグイン README 生成時に「ライセンス」セクションを差し込み（本ポリシー節 5 の定型文）|
| `marketplace-publisher` | 公開前検証で `LICENSE` / `plugin.json.license` を fail-closed 検証。不備時は `mit-license-toolkit` への接続を案内 |
| `extension-reviewer` | レビュー対象プラグインの LICENSE 整備状況を機械チェック項目として確認 |

`mit-license-toolkit` の起動方法・引数仕様・実行フロー詳細は [`../skills/mit-license-toolkit/SKILL.md`](../skills/mit-license-toolkit/SKILL.md) を参照。

## 7. 検証

ライセンス関連の生成・更新後に以下を確認:

- [ ] `plugins/{name}/LICENSE` が存在する
- [ ] `LICENSE` の本文が本ポリシー節 2.2 の MIT 標準文と一致する
- [ ] `Copyright (c) <year> <holder>` の `<year>` `<holder>` が空でない
- [ ] `plugin.json` の `license` フィールドが `"MIT"` である
- [ ] README に「ライセンス」セクションが存在する
- [ ] `license-info.json` を新規保存した場合、`.claude/.local/` 配下に正しく配置されている
- [ ] `license-info.json` は `.gitignore` 対象である（リポジトリにコミットされない）

## 8. 禁止事項

- プラグイン直下に `LICENSE` を配置せず公開すること（マーケットプレイス公開時に fail-closed）
- `plugin.json` の `license` フィールドを欠落させること
- `LICENSE` の本文を MIT 標準文以外に書き換えること（MIT 以外を使う場合は本スキル管轄外）
- `Copyright (c) <year> <holder>` 行を空のまま、またはプレースホルダ `{year}` `{holder}` のまま公開すること
- `license-info.json` をリポジトリにコミットすること（`.gitignore` 対象）
- ライセンス選択をテキスト対話で済ませること（重要選択は AskUserQuestion 必須）
- `mit-license-toolkit` を介さずに `LICENSE` / `plugin.json.license` を場当たり的に編集すること（生成と検証の SSOT が崩れる）

## 9. 関連ファイル

| 用途 | ファイル |
|-----|---------|
| ADR | [`architecture-decisions.md`](architecture-decisions.md) ADR-029 |
| README 規約（ライセンスセクション必須化） | [`readme-policy.md`](readme-policy.md) |
| 検証ルール（プラグイン LICENSE 検証） | [`validation-rules.md`](validation-rules.md) 節 2.2 |
| 命名・配置（`LICENSE` 許可リスト追加） | [`conventions.md`](conventions.md) 節 2.1 |
| ユーザ対話（AskUserQuestion 優先） | [`user-interaction.md`](user-interaction.md) |
| 担当スキル | [`../skills/mit-license-toolkit/SKILL.md`](../skills/mit-license-toolkit/SKILL.md) |
| MIT 標準文の出典 | https://opensource.org/licenses/MIT / https://spdx.org/licenses/MIT.html |
