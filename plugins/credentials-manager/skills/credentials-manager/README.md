# credentials-manager skill

Claude Code セッションをまたいで認証情報の **追加・編集・削除** を担う管理特化スキル。参照（取得・一覧・自動マッチ・プロアクティブ検出）は同梱の [`credentials-reader`](../credentials-reader/SKILL.md) スキルが担当する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 導入手順

### 前提

- Claude Code がインストール済み
- `credentials-manager` プラグイン（このスキル + `credentials-reader` スキル + フック群を含む）がインストール済み
- 依存プラグインなし

### 起動方法

以下のフレーズで自動起動します（書き込み系のみ）。

明示要求:

- 「OpenAI の API キー `sk-...` を保存して」
- 「保存済みの GitHub トークンを更新して」
- 「`openai-api-key` を削除して」
- 「JSON が壊れているので修復して」

引き継ぎ起動:

- `credentials-reader` から保存承諾を受けた場合（0 件マッチ後・プロアクティブ検出後）
- `credentials-reader` から JSON 破損の修復承諾を受けた場合
- `/credentials-manager:manage` コマンドのメニュー操作で「追加 / 編集 / 削除」が選択された場合

参照系（一覧表示・先ほどのキーで API 呼び出し・自動マッチ等）は `credentials-reader` が起動します。

## 利用方法

### 最小例

ユーザ:
> OpenAI の API キー `sk-proj-abcdefghij1234567890` を保存して

Claude（要約）:
> `openai-api-key` として保存しました（api_key）。値: `sk-p****7890` 保存先: `<repo>/.claude/.local/plugins/credentials-manager/credentials.json`（project-scoped）

### 応用例

| 目的 | フレーズ | 動作 |
|-----|---------|------|
| 新規保存 | 「OpenAI の API キー `sk-...` を保存して」 | save フローで識別名・URL/ドメインを推定して保存 |
| 編集 | 「openai-api-key の値を新しいキーに更新して」 | update フローで差分を提示し確認後に更新 |
| 削除 | 「`openai-api-key` を削除」 | 対話モードでは要確認 → エントリ削除 |
| 修復 | 「credentials.json を修復して」 | JSON 破損ファイルをバックアップ → 空ストア再初期化 |
| メニューUI | `/credentials-manager:manage` | AskUserQuestion で対話的に管理操作 |

## 動作要件

| 要件 | 内容 |
|-----|------|
| Claude Code | 任意の最新版 |
| 外部 CLI | 不要 |
| 外部プラグイン依存 | なし |

## カスタマイズ・拡張

| 観点 | 拡張ポイント |
|-----|------------|
| 保存先のスコープ | リポジトリ内の場合は project-scoped、外なら user-scoped を自動選択 |
| `auth_method` の既定 | `header:Authorization:Bearer`。サービス固有の方式が必要なら `header:X-API-Key:` 等を保存時に指定 |
| URL ワイルドカード | `urls[]` で末尾 `*` および中間 `*` を利用可能（`../credentials-reader/references/auto-match.md` 参照） |

## ファイル構成

```text
skills/credentials-manager/
├── SKILL.md                # スキル定義（Claude が読む。書き込み系特化）
├── README.md               # このファイル
├── references/
│   ├── operations.md       # save / update / delete / repair の詳細仕様
│   └── security.md         # セキュリティ注意・制約
└── evals/
    ├── README.md
    ├── case-01_save_with_url.md
    ├── case-07_delete_with_confirm.md
    ├── case-08_non_interactive.md
    ├── case-11_json_parse_error.md          # repair（reader 引き継ぎ）
    ├── case-12_user_scoped_save.md
    ├── case-13_gitignore_warning.md
    ├── case-14〜25                            # 同梱フック動作の評価（SessionStart / PreToolUse / UserPromptSubmit）
    ├── case-26_update_with_confirm.md       # update
    ├── case-27_manage_command.md            # /credentials-manager:manage コマンド経由
    └── case-28_handoff_from_reader.md       # reader 引き継ぎ受け入れ
```

## 関連ドキュメント

| 用途 | 参照先 |
|-----|------|
| プラグイン全体の概要 | `../../README.md` |
| 書き込み系操作詳細 | `references/operations.md` |
| セキュリティ注意 | `references/security.md` |
| 参照系スキル | `../credentials-reader/SKILL.md` |
| メニューUIコマンド | `../../commands/manage.md` |

## 設計上の特徴

- **責務分離**: 参照は `credentials-reader`、書き込みは本スキル。フック起動時のコンテキスト読み込みを軽量な reader に絞ることで効率化
- **install スコープ自動解決**: ワーキングディレクトリに `.git` があればプロジェクト単位、無ければユーザー単位を自動選択
- **平文保存（ローカル開発用途）**: 本番秘匿情報運用は対象外。`references/security.md` 参照
