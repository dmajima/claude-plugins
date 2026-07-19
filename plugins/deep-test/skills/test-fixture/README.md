<!-- TEST-FIXTURE-README-SENTINEL-v1 -->
# test-fixture スキル

deep-test プラグインの Phase 1.6（フィクスチャ基盤の構築 → マニフェスト生成）を担うスキル。
`test-analyze` が生成した `analysis.yaml` を材料に、再現可能テスト（Playwright Test = `.spec.ts` + フィクスチャ）の**下地**を SUT のテストディレクトリへ作成・拡充し、機械可読の `fixtures.yaml` を出力する。
後段の `test-design` がこの `fixtures.yaml` を消費してケースの `fixtures:` 参照と `automation: playwright-test` を決定する。本スキルは**下地作りに徹し、ケースの定義・実行・記録はしない**。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 何をするか

| ステップ | 内容 |
|---------|------|
| 材料消費 | `analysis.yaml` の `entry_points`（auth）→ 認証、`external_dependencies` → モック、`attack_surface_summary` → 認証切替、`meta.target_type` → 要否判定の材料に用いる |
| 要否判定（no-op） | 非 web / unit のみ / 認証も外部依存もなしなら SUT に何も書かず空 `fixtures.yaml` + 理由で正常終了する（非破壊 no-op） |
| 既存基盤検出 | `playwright.config.ts` / `{tests}/fixtures/` / `auth.setup.ts` / storageState を Glob/Grep で検出し、新規作成か拡充かを分岐する |
| 生成 or 拡充 | 認証(storageState)/モック(route.fulfill)/シード/base(test.extend) を生成、既存があれば不足分を非破壊マージする |
| マニフェスト出力 | 作成・拡充結果を `fixtures.yaml`（`playwright-test.md` スキーマ）に出力する |
| 自己チェック | `fixture-architect` エージェントで設計の妥当性・再利用性・分離・書き込み境界・認証情報ハードコードを単独レビューし、重大指摘を反映する |

## 使い方

### トリガーフレーズ例

```
このアプリのフィクスチャ基盤を作って
認証済みでテストするための storageState を用意して
決済 API のモックフィクスチャを追加して
テストの下地（fixture）を拡充して
```

### 起動経路

| 経路 | 説明 |
|------|------|
| test オーケストレータ経由 | フルフローの Phase 1.6（fixture 有効判定時）として Skill ツール経由で委譲される |
| 単独起動 | 上記トリガーフレーズ、または `/deep-test:test-fixture` コマンドで本スキルのみを直接実行する |

### 引数

| 引数 | 内容 |
|------|------|
| `target-slug=`（別名 `target=`） | 解決済み slug（委譲時にオーケストレータが渡す） |
| `base=<パス>` | 基準ディレクトリ（委譲時に受領） |
| `project=<パス>` | SUT のプロジェクトルート（テストコード生成先の基準・既存 config 検出の起点） |
| `対象説明=` または位置引数 | テスト対象（アプリ URL・リポジトリパス・対象名） |
| `--non-interactive` | 非対話モード |

## 動作例

入力: 「この web アプリのフィクスチャ基盤を作って」（既存の Playwright 基盤なし・認証あり・決済 API 依存あり）

1. `{base}/{target-slug}/analysis.yaml` を Read し、認証 EP・外部依存（決済 API）・target_type=web-app を材料化
2. `project=` 起点で既存 `playwright.config.ts` / fixtures を Glob → 無し → 新規作成に分岐
3. `auth.setup.ts`（ログイン → storageState 保存）と `playwright.config.ts`（projects で storageState 再利用）を生成
4. 決済 API を `route.fulfill` で差し替える `payment.fixture.ts` を生成
5. `authenticatedPage` などの base フィクスチャ（`test.extend`）を合成
6. `.auth` を `.gitignore` へ追記提案（実トークンをコミットしない）
7. `{base}/{target-slug}/fixtures.yaml` を生成 → `fixture-architect` 自己チェック → 指摘反映 → 結果サマリを返却

## 出力

- `{base}/{target-slug}/fixtures.yaml` — フィクスチャ基盤マニフェスト（機械可読・`test-design` が単方向に消費する。スキーマは plugin references の `playwright-test.md`）
- SUT テストコード — `playwright.config.ts` / `{tests}/fixtures/*.ts` / `auth.setup.ts` / seed（SUT 側のテストディレクトリに配置。deep-test の管理データ領域とは別）
- フィクスチャ構築結果サマリ（対象種別・判定〔生成/拡充/no-op〕・type 別件数・fixture-architect 所見・.gitignore 追記提案）

配置規約は plugin references の `data-locations.md`。SUT テストコード本体は deep-test の管理対象外（書き込み境界は `playwright-test.md`）。`test-results.yaml` / `test-cases.yaml` / `analysis.yaml` には一切書き込まない。

## カスタマイズ・拡張

| 変更したいこと | 変更箇所 |
|--------------|---------|
| fixtures.yaml のフィールド・enum を追加 / 変更する | plugin references の `playwright-test.md`（唯一の SSOT）を改訂する。本スキルは参照のみ |
| フィクスチャのパターン（認証/モック/シード/base の実装方針）を調整する | `references/fixture-patterns.md` |
| 消費 → 検出 → 生成/拡充 → 出力の手順を調整する | `references/fixture-procedures.md` |
| 自己チェックの起動フェーズ・エージェント構成を変更する | `references/agents.md` と plugin references の `agents.md` |
| 実ログインフロー探索に Playwright MCP を使う | SKILL.md frontmatter の `allowed-tools` に `mcp__playwright__*` を追加する（既定は追加しない・R11 設計 11 章 Q2(a)） |

## ファイル構成

```
plugins/deep-test/skills/test-fixture/
├── SKILL.md                    # Claude が実行時に読むスキル定義（200 行以下）
├── README.md                   # 本ファイル（人間向け）
├── references/
│   ├── fixture-procedures.md   # 入力解決 → 消費 → 既存検出 → 生成/拡充 → 出力 → 自己チェックの詳細手順
│   ├── fixture-patterns.md     # 認証/モック/シード/base のパターン集と最小コード例
│   └── agents.md               # フェーズ定義（fixture-architect の起動フェーズ）
└── evals/                      # 動作分岐検証ケース（case-01〜06 + README・6 ケース）
```

> Python は同梱しない（環境構築 setup 不要）。フィクスチャコードは LLM が Write/Edit で直接生成し、SUT のテストディレクトリのみへ書き込む。Playwright のインストール確認や雛形生成に read-only の `npx playwright` を用いる場合がある。

## スコープ外

- テストケース設計・テストレベル / 技法 / 優先度の決定・テスト計画（`test-design` が担当。本スキルはフィクスチャ下地まで）
- テストの実行・カバレッジの実測（`test-run-*`。本スキルは実走しない）
- 実行環境の構築（Playwright MCP 登録・ランナー検出・venv は `test-setup`。Docker は `test-environment`〔将来〕）
- 対象アプリの一次解析（`test-analyze`。本スキルは analysis.yaml を消費するのみ）
- 認証情報のフル値の保存・取得（`credentials-manager`。本スキルは取得方法のみ記述する）

## 関連スキル

- `test` — オーケストレータ（Phase 1.6 の委譲元）
- `test-analyze` — Phase 1.5。`analysis.yaml` の生成元（本スキルの材料供給元）
- `test-design` — Phase 2。`fixtures.yaml` を材料に `fixtures:` と `automation: playwright-test` を決定する消費先
- `test-setup` — Phase 1。既存フィクスチャ基盤の有無検出情報の供給元
