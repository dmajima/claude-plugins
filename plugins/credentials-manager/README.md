# credentials-manager

Claude Code セッションをまたいで認証情報（API キー、トークン、パスワード等）を管理するプラグイン。
URL/ドメイン関連付けによる自動適用にも対応する。

> 本ドキュメントは人間向けリファレンスであり、Claude のスキル動作では使用されない。
> Claude が読み込むのは `skills/credentials-manager/SKILL.md` のみ。

## 主な機能

- 認証情報の保存・取得・一覧・削除
- URL / ドメイン関連付けによる自動マッチング
- 値の自動マスキング（先頭4文字 + `***` + 末尾4文字）
- API キーパターン（`sk-...`, `ghp_...`, `xoxb-...` 等）のプロアクティブ検出

## 認証情報ファイルの保存先

セッション開始時のワーキングディレクトリに応じて、以下の優先順位で解決される。

| 優先順位 | 条件 | パス |
|---------|------|------|
| 1（優先） | 現在のディレクトリ（または祖先）に `.git` がある | `{repo_root}/.claude/.local/plugins/credentials-manager/credentials.json` |
| 2（フォールバック） | リポジトリ外での作業 | `~/.claude/.local/plugins/credentials-manager/credentials.json` |

### インストール形態との対応

| インストール形態 | 解決パス |
|---------------|---------|
| ユーザー単位（user）— リポジトリ外で利用 | `~/.claude/.local/plugins/credentials-manager/credentials.json` |
| プロジェクト単位（project）— リポジトリ内で利用 | `{repo_root}/.claude/.local/plugins/credentials-manager/credentials.json` |
| ローカル単位（local） | プロジェクト単位と同様 |

プロジェクト単位で保存された認証情報はそのリポジトリ専用となり、他のプロジェクトには共有されない。
リポジトリ外で保存された認証情報はユーザー全体で共有される。

## 使い方

トリガーフレーズ例:

- 「OpenAI の API キー `sk-...` を保存して」
- 「保存してある認証情報を一覧表示して」
- 「GitHub のトークンを覚えておいて」
- 「`https://api.example.com` にアクセスして。API キーは XXX」（自動的に保存提案）
- 「先ほど保存した API キーを使って `https://api.example.com/v1/users` を叩いて」（自動マッチ）

## ファイル構成

```
plugins/credentials-manager/
├── .claude-plugin/
│   └── plugin.json                            # プラグイン定義
├── README.md                                  # 本ファイル
└── skills/
    └── credentials-manager/
        ├── SKILL.md                           # スキル定義（Claude が読む）
        └── evals/
            └── evals.json                     # スキル評価定義
```

## セキュリティ注意

- 認証情報はローカルファイルに **平文** で保存される。本番秘匿情報の運用には適さない。
- 値は会話出力では常にマスクされる（フル値は表示しない）。
- リポジトリ内に保存される場合、`.claude/.local/` が `.gitignore` に登録されていることを確認する。
- `credentials.json` をコミットしてはならない。
