# mit-license-toolkit

Claude Code プラグインに MIT ライセンス（`LICENSE` ファイル + `plugin.json` の `license` フィールド）を付与・更新するスキル。プロジェクトごとのライセンス情報（著作権者・年・別名）を `license-info.json` で管理し、複数あれば AskUserQuestion で選択する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 導入手順

### 前提

- Claude Code がインストール済み
- `extension-toolkit` プラグインがインストール済み（本スキルは同プラグイン同梱）

### 起動方法

以下のフレーズで自動起動します:

- 「`{plugin}` プラグインに LICENSE を追加」
- 「MIT ライセンスを設定」
- 「`license-info.json` を編集」

または `/extension license {plugin-name}` 経由で起動できます。`plugin-toolkit` / `marketplace-publish` / `readme-toolkit` から Skill ツール経由で自動的に呼び出されます。

## 利用方法

### 最小例

ユーザ:
> `dev-toolkit` プラグインに MIT ライセンスを追加して

Claude（要約）:
> `license-info.json` を確認 → 1 件のみあれば自動適用、複数あれば選択 UI、不在なら新規収集 →
> `plugins/dev-toolkit/LICENSE` 生成 → `plugins/dev-toolkit/.claude-plugin/plugin.json` の `license: "MIT"` 設定 →
> `readme-toolkit` への接続を案内します。

### 応用例

| 目的 | フレーズ | 動作 |
|-----|---------|------|
| 既存プラグインへの LICENSE 追加 | "`foo` に MIT ライセンスを追加" | `LICENSE` 配置 + `plugin.json.license` 設定 |
| ライセンス情報の新規登録 | "ライセンス情報を登録" | `license-info.json` に新規エントリ追加 |
| 複数登録から選択 | "`foo` に LICENSE を追加" | AskUserQuestion で利用エントリを選択 |
| 既存 LICENSE の検証・修正 | "`foo` の LICENSE を確認" | MIT 標準文との照合、不一致なら修正提案 |

### 非対話モード

```text
/extension license <plugin-name> --non-interactive --license-id <id>
/extension license <plugin-name> --non-interactive --copyright-year 2026 --copyright-holder "Acme Corp"
```

| フラグ | 内容 |
|-------|------|
| `--non-interactive` | 対話を抑制、引数で全パラメータ確定 |
| `--license-id <id>` | `license-info.json` の特定エントリを直接適用 |
| `--copyright-year <year>` | 著作年を指定 |
| `--copyright-holder <name>` | 著作権者を指定 |
| `--author <name>` | プラグイン作者名を指定（省略時 holder と同値） |
| `--save` / `--no-save` | 新規収集時にストアへ保存するか |

## ライセンス情報の保持

| 優先 | パス |
|-----|------|
| 1（リポジトリ配下） | `<repo_root>/.claude/.local/plugins/extension-toolkit/license-info.json` |
| 2（フォールバック） | `~/.claude/.local/plugins/extension-toolkit/license-info.json` |

`.claude/.local/` は `.gitignore` 対象。リポジトリにはコミットされません（`credentials-manager` と同じ運用方針）。

### ファイル形式

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
    }
  ]
}
```

## カスタマイズ・拡張

| やりたいこと | 編集対象 |
|------------|---------|
| LICENSE 本文の調整 | `references/template/LICENSE`（MIT 標準文と一致必須） |
| 適用ロジックの変更 | `references/scripts/license/apply_license.py` |
| 実行手順の追加・改修 | `references/procedures.md` |
| 動作例の追加 | `evals/` |

MIT 以外のライセンス対応は本スキルの責務外です。利用者が `LICENSE` を手動で差し替え、`plugin.json` の `license` を更新してください。

## ファイル構成

```text
plugins/extension-toolkit/skills/mit-license-toolkit/
├── SKILL.md
├── README.md
├── references/
│   ├── procedures.md                       # 実行手順詳細
│   ├── scripts/
│   │   └── license/
│   │       ├── apply_license.py            # LICENSE 配置 + plugin.json 更新
│   │       └── verify_license.py           # LICENSE 検証（公開前 fail-closed 用）
│   └── template/
│       └── LICENSE                         # MIT 標準文テンプレート（SSOT）
└── evals/
    ├── case-01_apply_single_entry.md       # 1 件のみ自動適用
    ├── case-02_select_among_multiple.md    # 複数あり AskUserQuestion 選択
    ├── case-03_collect_when_absent.md      # 不在時の新規収集 + 保存
    └── case-04_non_interactive.md          # 非対話モード
```

## 関連スキル

| スキル | 関係 |
|-------|------|
| `plugin-toolkit` | プラグイン外形作成時に本スキルを呼び出す |
| `marketplace-publish` | 公開前に LICENSE / `plugin.json.license` を fail-closed 検証、不備時に本スキルへ接続 |
| `readme-toolkit` | プラグイン README に「ライセンス」セクションを挿入 |
| `extension-review` | レビュー対象プラグインの LICENSE 整備状況を確認 |

## 関連リンク

- ADR-029: [`../../references/architecture/decisions-001-010.md`](../../references/architecture/decisions-001-010.md)
- ライセンスポリシー: [`../../references/policies/license-policy.md`](../../references/policies/license-policy.md)
- MIT 標準文の出典: https://opensource.org/licenses/MIT / https://spdx.org/licenses/MIT.html

## ライセンス

[MIT License](../../../LICENSE) の下で配布されています。
