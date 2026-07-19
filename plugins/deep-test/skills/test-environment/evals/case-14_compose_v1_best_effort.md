<!-- TEST-ENV-EVAL-R2-14-SENTINEL-v1 -->
# case-14 compose v1 のみ検出（警告付き docker-compose 形 best-effort・試行失敗時は unavailable 扱い）

`docker compose version`（v2）が失敗し `docker-compose --version`（v1）のみ成功する環境で、`compose_command: "docker-compose"` を**警告付きで記録**して best-effort 続行し、試行が失敗した場合は unavailable と同じ縮退として扱う分岐を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=orderapp-web project=./ base=<base> action=provision levels=functional` |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 1.7）/ 単独起動でも同一挙動 |
| 前提 | docker 資産あり。`docker compose version` が失敗し `docker-compose --version` のみ成功する（v1 のみ検出。v1 は EOL 済み） |

## 分岐の根拠

SKILL.md「前提」（compose は v2 系前提。v1 のみ検出時は警告付き best-effort・`compose_command: "docker-compose"` を記録）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 3 章手順 2（v1 のみ検出: `compose_command: "docker-compose"` + `status.notes` に警告を記録し best-effort で続行・試行失敗時は unavailable と同じ縮退）・9 章縮退表 4 行目、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 3 章（compose_command の enum）・12 章縮退表（compose v1 のみ検出行: 試行失敗時は unavailable と同じ = run 側 skipped 材料）。

## 期待動作

- v2 → v1 の順にコマンド疎通を実測し、v1 のみ利用可能であることを確認する（v2 の成功を装わない）
- `compose_command: "docker-compose"` を記録し、`status.notes` に警告（v1 は EOL 済み・best-effort 試行である旨）を残す
- 派生生成 → config 検証・lifecycle のコマンド組み立てを `docker-compose` 形で行い、best-effort で続行する
- 試行（config 検証・up 等）が v1 非対応（例: `ports: !override` タグ・`up --wait` の非受理）で失敗した場合は、成功を装わず **unavailable と同じ縮退**として扱う（従来前提へのフォールバック案内・ユーザー URL なしの browser レベルは実行時 skipped 材料）
- 返却サマリに compose_command と警告を明示する（v2 導入の推奨を案内に含めてよい）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | environment.yaml（`compose_command: "docker-compose"`・notes に警告。試行成功時は通常の provision 成果物・試行失敗時は unavailable 相当の縮退記録 + 理由） |
| 標準出力（要約） | 環境構築結果サマリ（v1 best-effort の旨・警告・試行失敗時はフォールバック案内と skipped 材料になる旨） |
| 終了状態 | best-effort 続行（試行成功時）または unavailable 相当の縮退（試行失敗時）。いずれも実測に基づき偽装しない |

## 関連ケース

- case-03: v1 も含めて手段が使えない縮退（unavailable・`compose_command: null` との使い分け）
- case-10: v2 疎通が成功する主成功経路の対
- case-04: config 検証失敗（v1 の `!override` 非受理はここと同型の検出になる）
