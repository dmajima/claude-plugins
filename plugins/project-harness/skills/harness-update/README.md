# harness-update

構築済みの `.claude` ハーネスへ、開発・修正で生じたコード変更を差分反映するスキル。
最終同期コミットと HEAD の差分から影響ドキュメントを特定し、記載内容・索引・同期状態を最新化する。
`harness-define` で先行作成した未実装仕様（`status: draft` / `agreed`）への実装の紐付け（実装追随）も担う。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。

## 使い方

### トリガーフレーズ例

- 「ハーネスを更新して」
- 「変更をドキュメントに反映して」
- 「開発内容を .claude に同期して」
- 「実装を仕様に紐付けて」（spec-first で作成した仕様への実装追随）
- `/project-harness:update`
- SessionStart フックの鮮度通知（「乖離が閾値を超えています」）を受けた実行

### 入力 → 出力の流れ

1. `.sync-state.json` の最終同期コミットと HEAD の差分（変更ファイル一覧）を取得する
2. 各ドキュメントの frontmatter `sources` と照合し、影響を 5 分類（更新 / ソース移動 / 新規候補 / 整理候補 / ハーネス直接編集）する。どの `sources` にもマッチしない追加ファイル群は、新規候補とする前に未実装仕様（`status: draft` / `agreed`）との対応を照合する（実装追随）
3. 反映計画が提示され、対象を選択する（実装追随は `sources` 設定 + `implemented` 昇格を常に個別確認）
4. ドキュメント更新・新規作成・実装追随・索引同期が実行される
5. 検証スクリプトが実行され、`.sync-state.json` が HEAD へ更新される

用語集・規約など対応ソースを持たないドキュメントも棚卸しする場合は `/project-harness:update --full`（全量監査モード）を使う。

## 動作例

入力:

```text
/project-harness:update
```

出力（反映計画の例）:

```text
| 分類 | ドキュメント | 起因する変更 | 反映内容 |
|------|-------------|-------------|---------|
| 更新 | specs/login-screen.md | src/auth/（M） | バリデーション仕様の変更反映 |
| 実装追随 | specs/order-entry.md（agreed） | src/features/order/（A 群） | sources 設定 + 突合 + implemented 昇格 |
| 新規 | specs/report-export.md | src/report/（A 群） | 新機能の仕様書作成 |
| 整理候補 | flows/legacy-menu.md | src/menu/（D） | 対応ソース削除のためアーカイブ提案 |
```

## カスタマイズ・拡張

| 変更したいこと | 変更箇所 |
|--------------|---------|
| 差分検出・分類のルール・全量監査 | プラグイン共有 `references/sync-spec.md`（SSOT） |
| 記載の原則・秘匿情報の扱い・検証項目 | プラグイン共有 `references/authoring-spec.md`（SSOT） |
| 鮮度通知の閾値 | 対象プロジェクトの `.sync-state.json` の `threshold_commits` |
| 反映エージェントの構成 | `references/agents.md` |
| 実行手順の詳細 | `references/procedures.md` |

## ファイル構成

```text
skills/harness-update/
├── SKILL.md                   # スキル定義（Claude が実行時に読み込む）
├── README.md                  # 本ファイル（人間向け）
├── references/
│   ├── procedures.md          # Phase 1〜7 の詳細手順
│   └── agents.md              # 反映エージェントの運用定義
└── evals/
    ├── README.md
    └── case-*.md              # 動作分岐の期待挙動
```
