<!-- TEST-ENVIRONMENT-EVAL-01-SENTINEL-v1 -->
# case-01 docker 資産なしの no-op（派生せず not-applicable + reason・従来前提を案内）

SUT に docker 資産（compose / Dockerfile）が存在しない対象に対し、派生を行わず **no-op マニフェスト**（`applicability: not-applicable` + `reason`）を出力して正常終了する非破壊分岐を検証する。ユーザー起動済み URL による従来前提のフローを壊さないことが目的。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=static-site project=./ base=<base> action=provision levels=functional` |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 1.7）/ 単独起動でも同一挙動 |
| 前提 | `project=` 配下に `compose.y*ml` / `docker-compose.y*ml` / `Dockerfile*` が存在しない。`analysis.yaml` は存在（target_type=web-app・外部ホスティング前提） |

## 分岐の根拠

SKILL.md「責務 1」（資産なしなら no-op）・「実行フロー」4（要否判定の no-op 分岐）・「重要な制約」（新ゲートを追加しない・ユーザー起動済み URL 優先）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 3 章（資産検出は有無のみ）・5 章（要否判定）・9 章縮退表 1 行目（docker 資産なし = not-applicable・run 側影響なし）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 12 章（applicability による縮退・理由の必須記録）。

## 期待動作

- `project=` 起点に compose / Dockerfile / `docker/` / `.env` 系を Glob で検出し、compose・Dockerfile とも不在を確認する（内容は読まない）
- 派生成果物（`environment/compose.test.yml` / `.env.test`）を**生成しない**（docker コマンドの試行も要否判定に必要な範囲に留める）
- `{base}/{target-slug}/environment.yaml` を `applicability: not-applicable` + `reason`（例: 「compose / Dockerfile が検出されないため派生対象外」）で出力する（推定で資産を捏造しない）
- 返却に「従来前提（ユーザー起動済み URL があればそのまま実行可能）」の案内を含め、フローを止めない（新ゲートを追加しない）
- SUT・`test-results.yaml` / `test-cases.yaml` / `analysis.yaml` / `fixtures.yaml` へは書き込まない
- no-op 判定（not-applicable）の理由の妥当性も env-architect に確認させてよい（`${CLAUDE_SKILL_DIR}/references/agents.md` 4 章。生成物が小さくても自己チェックを省略しない運用が望ましい）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{base}/{target-slug}/environment.yaml`（`applicability: not-applicable` + `reason`・`derived_artifacts` は生成なしの状態）のみ。`environment/` 配下の派生成果物は生成しない |
| 標準出力（要約） | 環境構築結果サマリ（applicability=not-applicable〔理由付き〕・派生なし・従来前提の案内・run 側 status への影響なし） |
| 終了状態 | 派生せず no-op マニフェスト + 理由を出力して正常終了（エラーではない・非破壊 no-op） |

## 関連ケース

- case-02: 資産はあっても levels=unit のみで環境不要となる対
- case-03: 資産はあるが docker 手段が使えない縮退（not-applicable と unavailable の使い分け）
- case-04: 資産あり・適用可で派生まで進んだ後の config 検証失敗
