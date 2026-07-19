<!-- TEST-ENVIRONMENT-README-SENTINEL-v1 -->
# test-environment スキル

deep-test プラグインの Phase 1.7（テスト用派生環境の生成 → ライフサイクル管理 → マニフェスト出力）を担うスキル。
SUT の docker 資産（compose / Dockerfile / `.env` 系）を**一切変更せず**、deep-test のデータ領域にテスト用の派生ファイル（`environment/compose.test.yml` / `environment/.env.test`）を生成し、`docker compose` の分離プロジェクト（`-p {slug}-test`）として起動・撤収する。
生成・更新される機械可読マニフェスト `environment.yaml` は、`test-design`（環境前提の材料）・browser 系実行スキル（`endpoints[]` の base URL）・オーケストレータ `test`（`start-run --environment` の材料・up / down の呼出）が単方向に消費する。本スキルは**環境の用意に徹し、テストの実行はしない**。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 何をするか

| action | フェーズ位置 | 内容 |
|--------|------------|------|
| `provision`（既定） | Phase 1.7（test-fixture の後・test-design の前） | docker 資産の検出（有無のみ）→ `analysis.yaml` 消費 → 要否判定 → 派生生成（`ports: !override` + 127.0.0.1 バインド・`.env.test` はダミー値 / credentials-manager 参照形）→ `config --quiet` 静的検証 → `environment.yaml` 出力 → env-architect 自己チェック |
| `up` | 全ゲート通過後・start-run 直前（Phase 5 手順 0） | `docker version` 疎通 → `up --wait --wait-timeout {N}` → healthcheck 未定義サービスのみ curl（127.0.0.1）補助ポーリング → endpoints / exec_forms 確定 → status 更新 |
| `down` | Phase 6 判定後（PASS 時） | サービス別 logs 保存（マスキング適用）→ `down -v --remove-orphans`（up と同一 `-f` 群 + `-p`）→ `ps` 残存確認 → status 更新 |
| `status` | 任意（resume / retest・単独確認） | `ps` + health 再確認で status のみ更新（健全なら再 up 不要） |

## 使い方

### トリガーフレーズ例

```
このアプリのテスト用コンテナ環境を作って
テスト用コンテナ環境を起動して
テスト用コンテナ環境を片付けて
compose からテスト環境を派生して
```

### 起動経路

| 経路 | 説明 |
|------|------|
| test オーケストレータ経由 | フルフローの Phase 1.7（provision）・Phase 5 手順 0（up）・Phase 6 判定後（down）として Skill ツール経由で委譲される |
| 単独起動 | 上記トリガーフレーズ、または `/deep-test:test-environment` コマンドで本スキルのみを直接実行する（中断後の残存確認・手動 down に有用） |

### 引数

| 引数 | 内容 |
|------|------|
| `target=`（別名 `target-slug=`） | データ配置先の target-slug（委譲時にオーケストレータが渡す） |
| `base=<パス>` | 基準ディレクトリ（委譲時に受領） |
| `project=<パス>` | SUT のプロジェクトルート（docker 資産探索の起点） |
| `action=<provision\|up\|down\|status>` | 実行する操作（既定 `provision`） |
| `levels=<CSV>` | 見込みテストレベル（unit のみなら環境不要 = no-op） |
| `run-id=<id>` | up / down 時に任意で受領（logs 保存先と `status.last_run_id`） |
| `--non-interactive` | 非対話モード（up は down までのワンサイクル完結を条件に許可） |

## 動作例

入力: 「このアプリのテスト用コンテナ環境を作って」（SUT に `docker-compose.yml`・`.env` あり・analysis.yaml あり）

1. `project=` 起点で compose / Dockerfile / `.env` 系の有無を Glob 検出し、`docker compose version` で v2 疎通を確認
2. `{base}/{target-slug}/analysis.yaml` を Read し、`build_run`・外部依存（決済 API）・target_type=web-app を派生方針の材料化
3. `environment/compose.test.yml` を生成（`ports: !override` で `127.0.0.1:18080:80` に全置換・uploads bind を `ro` 化・モック系サービスを profiles 配下に）
4. `environment/.env.test` を生成（ダミー値 / credentials-manager 参照形のみ。開発 `.env` の値は読まない）
5. `docker compose -f docker-compose.yml -f environment/compose.test.yml -p {slug}-test --env-file environment/.env.test config --quiet` で静的検証
6. `{base}/{target-slug}/environment.yaml` を生成（endpoints の health は `unknown`）→ env-architect 自己チェック → 指摘反映 → 結果サマリを返却
7. （後日・全ゲート通過後）`action=up` で起動し health 確認 → テスト実行 → Phase 6 判定後に `action=down` で撤収・残存確認

## 出力

- `{base}/{target-slug}/environment.yaml` — テスト用派生環境マニフェスト（機械可読。スキーマは plugin references の `yaml-schema-environment.md`）
- `{base}/{target-slug}/environment/compose.test.yml`・`environment/.env.test` — 派生成果物（SUT 外の分離ディレクトリ）
- コンテナログ — down 前に `evidence/{run_id}/environment/{service}.log`（run 外の単独 down 時は `environment/logs/{timestamp}/`）へ保存
- 環境構築結果サマリ（applicability・派生内容・services / endpoints / exec_forms・status・env-architect 所見・残存確認）

配置規約は plugin references の `data-locations.md`。SUT の docker 資産は read-only であり、SUT 側へは一切書き込まない。`test-results.yaml` / `test-cases.yaml` / `analysis.yaml` / `fixtures.yaml` にも書き込まない。

## カスタマイズ・拡張

| 変更したいこと | 変更箇所 |
|--------------|---------|
| environment.yaml のフィールド・enum を追加 / 変更する | plugin references の `yaml-schema-environment.md`（唯一の SSOT）を改訂する。本スキルは参照のみ |
| 派生パターン（ports 付替・volume・profiles・`.env.test` の書き方）を調整する | `references/compose-derivation.md` |
| 検出 → 消費 → 派生 → 検証 → up / down / status の手順・縮退動作を調整する | `references/environment-procedures.md` |
| 自己チェックの起動フェーズ・エージェント構成を変更する | `references/agents.md` と plugin references の `agents.md` |
| 待機タイムアウト（`--wait-timeout` の秒数）を変更する | environment.yaml の `lifecycle.wait_timeout_sec`（既定 120。生成時に調整） |

## ファイル構成

```
plugins/deep-test/skills/test-environment/
├── SKILL.md                          # Claude が実行時に読むスキル定義（200 行以下）
├── README.md                         # 本ファイル（人間向け）
├── references/
│   ├── environment-procedures.md     # 検出 → 消費 → 派生 → 検証 → up / down / status の詳細手順・縮退表・resume・ハンドオフ
│   ├── compose-derivation.md         # 派生パターン集（ports !override・volume・network・profiles・.env.test・本番誤爆突合）
│   └── agents.md                     # フェーズ定義（env-architect の起動フェーズ）
└── evals/                            # 動作分岐検証ケース（case-01〜19 + README・19 ケース）
```

> Python は同梱しない（venv 構築も不要）。docker 操作は Bash 直実行（docker CLI の単発呼出）で完結し、`environment.yaml` と派生成果物は LLM が Write で直接生成する。起動待機は `up --wait --wait-timeout`（公式フラグ）と条件付き curl ポーリングで行い、独自の待機スクリプトを持たない。

## スコープ外

- テストの実行（up した環境上での実走は `test-run-*`。本スキルは `endpoints[]` / `exec_forms[]` の提供形を記録するまで）
- テストツールチェーンの検証（Playwright MCP 登録・ランナー検出・venv は `test-setup`。本スキルは SUT が動く環境を担う）
- 対象アプリの一次解析（`test-analyze`。本スキルは analysis.yaml を消費するのみ）
- フィクスチャ・seed コードの生成（`test-fixture`。seed が使うテスト用接続情報は environment.yaml で提供する）
- 認証情報のフル値の保存・取得（`credentials-manager`。本スキルは `.env.test` に参照形を書くまで）
- SUT イメージ・アプリ自体の品質保証（ビルド失敗・起動即死はそのまま理由として返す）

## 関連スキル

- `test` — オーケストレータ（Phase 1.7 / up / down の委譲元。`start-run --environment` の材料消費先）
- `test-analyze` — Phase 1.5。`analysis.yaml` の生成元（本スキルの材料供給元）
- `test-fixture` — Phase 1.6。seed が参照するテスト用接続情報（env var 名・endpoints）の提供先
- `test-design` — Phase 2。environment.yaml を preconditions / 環境前提の材料に消費する
- `test-run-functional` ほか browser 系 5 スキル — `endpoints[]` の base URL を受領する実行スキル
- `test-run-unit` — `exec_forms[]`（コンテナ内ランナー実行形）の記録提供先（実走組み込みは follow-on）
