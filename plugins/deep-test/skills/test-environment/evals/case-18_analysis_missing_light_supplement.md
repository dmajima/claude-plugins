<!-- TEST-ENV-EVAL-R2-18-SENTINEL-v1 -->
# case-18 単独起動 provision × analysis.yaml 不在（Read/Glob/Grep で軽量補完・analysis_consumed: false）

単独起動の `action=provision` で `{base}/{target-slug}/analysis.yaml` が存在しない場合に、対象を本格再解析せず Read/Glob/Grep による**軽量補完**で派生方針を組み立て、`meta.analysis_consumed: false` を environment.yaml に記録する分岐を検証する。`external_dependencies[]`（analysis.yaml 由来）が得られず本番誤爆突合の材料が不足することを認識し、疑義・判断のつかない外部接続は保守的（安全側）に扱う（case-10〔analysis 消費あり〕の対）。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | `/deep-test:test-environment action=provision target=orderapp-web project=./`（または「compose からテスト環境を派生して」） |
| 起動形態 | 単独（コマンド → スキル・対話。test-analyze 未実行の単独運用） |
| 前提 | `project=` 配下に `docker-compose.yml`・`Dockerfile` が存在。`docker compose version` 成功（v2）。`{base}/orderapp-web/analysis.yaml` が**存在しない**。派生後の `config --quiet` は exit 0 |

## 分岐の根拠

SKILL.md「責務 2」（analysis.yaml 非存在時は軽量補完〔`analysis_consumed: false`〕）・「前提」（存在すれば材料に消費・無ければ Read/Glob/Grep で軽量補完）・「実行フロー」3、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 4 章（非存在時は Read/Glob/Grep で compose 内サービス構成から軽量補完し `meta.analysis_consumed: false` を記録する〔推定を確定情報として書かない〕）・1 章フロー図（analysis.yaml 非存在 → 軽量補完）、`${CLAUDE_SKILL_DIR}/references/compose-derivation.md` 6 章（本番誤爆突合の一覧は `analysis.yaml` の `external_dependencies[]` 由来。疑義はモック差替 / 明示確認〔対話〕とし、非対話で差替不能な疑義が残る場合は up へ進まない安全側）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md`（`meta.analysis_consumed` は必須 boolean・非存在時の軽量補完では `false`）。

## 期待動作

- `{base}/{target-slug}/analysis.yaml` の Read を試みて非存在を確認する（`test-analyze` を呼び出さない・対象の本格再解析をしない〔逆呼び出し禁止・重複解析の回避〕）
- Read/Glob/Grep で SUT compose のサービス構成（services・ports・depends_on・healthcheck の有無・interpolation 変数名）を**軽量補完**し、派生方針（分離対象・`wait_timeout_sec` の当たり付け・endpoints の候補）の材料とする（`.env` の値は読まない）
- environment.yaml に `meta.analysis_consumed: false` を記録する（推定を確定情報として書かず、推定に基づく判断は notes / reason に根拠を残す）
- 本番誤爆突合は `external_dependencies[]` が得られず材料不足となるため、SUT compose の interpolation 変数名・`.env.test` に書く URL / ホスト名からの突合に縮小されることを認識し、**本番らしき接続先の疑義・判断のつかない外部接続は安全側に扱う**（対話: AskUserQuestion で明示確認する。疑義を未解消のまま進めない）
- 疑義がない（または解消済みの）場合は派生生成 → `config --quiet` 検証 → environment.yaml 出力 → env-architect 自己チェック → 返却まで case-10 と同じ主経路で完了する
- 返却サマリ（SKILL.md「引き渡し」）に `analysis_consumed: false` を明記する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `environment/compose.test.yml`・`environment/.env.test`・`{base}/{target-slug}/environment.yaml`（`applicability: applicable`・`meta.analysis_consumed: false`・`config_validated: true`） |
| 標準出力（要約） | 環境構築結果サマリ（`analysis_consumed: false` の明記・軽量補完で推定した構成とその根拠・外部接続の突合結果〔材料不足時の扱いを含む〕） |
| 終了状態 | provision 完了（analysis.yaml を生成・編集しない。up は実行しない） |

## 関連ケース

- case-10: analysis.yaml 存在時の provision 主成功経路（`analysis_consumed: true` の対）
- case-12 / case-13: 本番誤爆疑義が検出された場合の対話 / 非対話の扱い（本ケースは突合材料が不足した状態での保守的取り扱い）
