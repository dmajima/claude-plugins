# harness-update 実行手順詳細

## Phase 1: 前提確認・差分取得

| 検査 | 方法 | NG 時の動作 |
|------|------|------------|
| ハーネス存在 | `.claude/references/.sync-state.json` の存在 | `harness-init`（`/project-harness:init`）への切替を提案して終了 |
| state 妥当性 | valid JSON + `last_synced_commit` 保持 | 破損時: HEAD での state 再初期化を提案（承認後、全ドキュメントの sources 照合による全量整合チェックへ切替） |
| SHA 到達可能性 | `git cat-file -e <sha>` | rebase 等で到達不能時: 直近の到達可能な基準（`git merge-base` / ユーザ指定コミット）を `AskUserQuestion` で確認 |
| 乖離有無 | `git rev-list --count <sha>..HEAD` | 0 件なら「同期済み（最終同期日時）」を報告して終了（未コミット変更があれば件数のみ通知） |

差分取得:

```bash
git diff --name-status <last_synced_commit>..HEAD
```

## Phase 2: 影響分析

1. `references/` 配下全ドキュメント（`CLAUDE.md` / `.sync-state.json` を除く）の frontmatter `sources` を収集する
2. 変更ファイルをグロブ照合し、[sync-spec.md](../../../references/sync-spec.md) 節 2 の 4 分類（既存更新 / 新規候補 / 整理候補 / ハーネス直接編集）へ仕分ける
3. 新規候補は「まとまった機能単位」でグルーピングする（1 ファイルの追加ごとに 1 ドキュメントを乱造しない。既存ドキュメントの `sources` 拡張で足りる場合はそちらを優先）

### コミットメッセージの活用

`git log --oneline <sha>..HEAD` を取得し、変更の意図（feat / fix / refactor）を反映内容の判断材料にする。refactor のみでアプリ動作に変化がない場合、specs は据え置きで system-designs のみ更新する等の判断を行う。

## Phase 3: 反映計画の確認

提示フォーマット:

| 分類 | ドキュメント | 起因する変更ファイル | 反映内容の見込み |
|------|-------------|---------------------|-----------------|
| 更新 | `specs/login-screen.md` | `src/auth/...`（M） | バリデーション仕様の変更反映 |
| 新規 | `specs/{新機能名}.md`（提案） | `src/report/...`（A 群） | 新機能の仕様書作成 |
| 整理候補 | `flows/legacy-menu.md` | `src/menu/...`（D） | 対応ソース全削除のためアーカイブ提案 |

| モード | 確認方法 |
|-------|---------|
| 対話 | `AskUserQuestion`（全反映 / 更新のみ / 個別選択）。整理候補は削除・アーカイブ・保持を個別確認 |
| 非対話 | 更新・新規を全反映。整理候補は **実施せず** 報告のみ |

## Phase 4: 反映実行

### 更新の原則

- diff を読み、記載と実装の乖離箇所のみを更新する（ドキュメント全体の書き直しはしない）
- 動作・仕様の変更 → `specs/` / `flows/`、実装構造の変更 → `system-designs/` / `architecture/`、コマンド・設定の変更 → `environments/` / `conventions/` へ反映する
- 既存の `TODO:` が今回の変更で確認可能になった場合は解消する
- 新規ドキュメントはテンプレート（`${CLAUDE_PLUGIN_ROOT}/references/template/`）から生成し、frontmatter `sources` を必ず設定する

### エージェント委譲（更新対象 5 件超過時）

[agents.md](agents.md) の構成でドキュメント単位に並列委譲する。1 ドキュメント = 1 エージェントとし、ファイル競合を防ぐ。メインが全結果の frontmatter / 索引整合を最終確認する。

## Phase 5: 索引・同期状態の更新

1. ファイル追加・削除・title 変更のあったフォルダの `CLAUDE.md` 索引を実体と一致させる
2. `references/CLAUDE.md`・`.claude/CLAUDE.md` に影響（技術スタック変更・主要コマンド変更等）があれば反映する
3. 更新した各ドキュメントの frontmatter `updated` を更新する
4. `.sync-state.json` を更新する:

```json
{
  "last_synced_commit": "<git rev-parse HEAD>",
  "last_synced_at": "<現在時刻 ISO 8601>"
}
```

（`initialized_at` / `threshold_commits` は保持）

## Phase 6-7: 検証・報告

SKILL.md の検証チェックリスト実施後、以下を報告する:

- 反映結果表（更新 / 新規 / 整理提案の各件数と一覧）
- スキップしたもの（非対話時の整理候補等）とその理由
- `TODO:` の解消数・新規発生数
- 未コミット変更の有無（あれば「コミット後の再実行で反映される」旨）
