<!-- TEST-ENVIRONMENT-DERIVATION-SENTINEL-v1 -->
# compose 派生パターン集（ports !override・volume・network・profiles・.env.test・本番誤爆突合）

`test-environment` が生成する派生成果物（`environment/compose.test.yml` / `environment/.env.test`）の実装パターン。SKILL.md・`environment-procedures.md` 6 章から参照される。
スキーマ・コマンド規約形の SSOT は `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md`（特に 10.1）であり、本書はその**派生ファイル側の書き方**を補完する（規範本文は複製しない）。

- 各例は**最小の骨子**であり、SUT の compose 構成（`analysis.yaml` の `build_run` / `external_dependencies`）に合わせて調整する
- 派生ファイルは deep-test データ領域（`{base}/{target-slug}/environment/`）に置き、SUT の既存 docker 資産は一切変更しない（read-only 境界）
- 全ファイルを明示 `-f` で渡す（SUT 内に `compose.override.y*ml` があっても、明示 `-f` 指定時は自動読込されないため混入しない）
- コマンド規約形（共通プレフィクス）: `docker compose -f <SUT compose> -f environment/compose.test.yml -p {slug}-test --env-file environment/.env.test <verb>`

---

## 1. ports の付替（`!override` + 127.0.0.1 バインド）

**ports は後勝ち置換ではなく連結（concatenate）される multi-value option** である。派生側に ports を書くだけでは開発側の公開ポートが**残存**し、ポート衝突・LAN 露出が解消しない。付替には `!override` タグによる**属性の完全置換**を必須とする。

```yaml
# environment/compose.test.yml（抜粋）
services:
  web:
    ports: !override
      - "127.0.0.1:18080:80"   # HOST 側は 127.0.0.1 バインド固定（LAN 露出防止）・開発側と衝突しない番号へずらす
```

- `127.0.0.1:HOST:CONTAINER` の short syntax で **ループバック限定公開**にする（`0.0.0.0` バインド禁止）
- HOST ポートは開発側と重ならない番号（例: 8080 → 18080）を選ぶ。テスト実行中に開発環境が並走しても衝突しない
- `!override` タグの受理可否は環境の compose 版数に依存し得るため、`config --quiet`（procedures 6 章）で必ず静的検証する
- 参考: `!reset` は属性の削除（空化）、`!override` は置換。ports の付替は `!override` を使う

## 2. volume の分離（bind mount の `ro` 化 / named volume 再定義）

volumes は**連想マージ**（同一コンテナパスは派生側優先）のため、同一 target の再定義で置換できる（ports と挙動が異なる点に注意）。

```yaml
# environment/compose.test.yml（抜粋）
services:
  web:
    volumes:
      - ./uploads:/app/uploads:ro        # 開発側 bind を同一コンテナパスで ro 再定義（SUT 実データへの書き込み防止）
  db:
    volumes:
      - db-data:/var/lib/mysql           # named volume は project 名で自動分離される（開発側の実体と別物になる）
volumes:
  db-data: {}
```

- **書き込みが要らない bind mount は `ro` 化**する（テストが SUT の実ファイルを汚さない）
- **書き込みが要るデータ領域は named volume に再定義**する。named volume は `-p {slug}-test` の名前空間で開発環境から自動分離され、`down -v` で削除される（external volume は削除されない）
- bind mount のホスト側パスは**最初の `-f`（SUT compose）基準で解決される**（7 章）。派生側に新たな相対 bind パスを増やさない

## 3. network の分離（project name による自動分離）

`-p {slug}-test` を渡すと、コンテナ・default ネットワーク・named volume が project 名の名前空間で分離される。**派生側でネットワークを再定義する必要は原則ない**（compose の既定挙動に委ねる）。

- project 名の規約形は `{slug}-test`（小文字英数・ダッシュ・アンダースコアのみ・先頭は小文字英数。kebab-case の slug は適合）
- SUT compose に `external: true` のネットワークがある場合は分離されない（開発側資産に接続してしまう）。テスト用に内部ネットワークへ差し替えるか、疑義として 6 章の突合に回す

## 4. profiles によるモック系サービスの切替

コアサービスは profiles 無印（常時有効）、モック / スタブ系サービスを profiles 配下に定義し、派生時に選択的に有効化する。

```yaml
# environment/compose.test.yml（抜粋）
services:
  payment-mock:
    image: wiremock/wiremock:latest      # 例: 決済 API のモック
    profiles: ["mock"]
    ports: !override
      - "127.0.0.1:18081:8080"
```

- 有効化する profiles は environment.yaml の `project.profiles`（例: `["mock"]`）に記録し、up 時に `--profile` / `COMPOSE_PROFILES` で有効化する
- モック対象は `analysis.yaml` の `external_dependencies[]` から選定する（本番誤爆疑義のある外部依存を優先的にモックへ差し替える）
- SUT 側アプリの接続先切替は `.env.test` の環境変数（5 章）で行う（SUT のソース・compose は変更しない）

## 5. `.env.test` の書き方（ダミー値 / credentials-manager 参照形）

**開発 `.env` の値は読まず複製しない**（検出は有無のみ）。`.env.test` は変数名を SUT compose の interpolation（`${VAR}`）から逆引きし、値は次の 2 形のみとする。

```bash
# environment/.env.test（例）
# 1) ダミー値（テスト専用のプレースホルダ。実在の秘匿値を書かない）
DB_HOST=db
DB_USER=testuser
DB_PASSWORD=dummy
# 2) credentials-manager 参照形（実値が必要な場合。フル値は書かずに取得方法を示す）
# EXTERNAL_API_KEY は credentials-manager から取得して実行時に注入する（保存名: <name>）
EXTERNAL_API_KEY=
APP_ENV=test
EXTERNAL_API_URL=http://127.0.0.1:18081   # モックへ差替（profiles: mock と対）
```

- 実在の認証情報・トークン・パスワードのフル値を書かない（credentials-management ルール MANDATORY。実値の管理は credentials-manager の責務）
- 変数名の網羅は `config --quiet` の警告（未定義変数）で確認する（値を stdout に展開しないこと）
- `--env-file environment/.env.test` の明示指定で既定 `.env` の読込位置を差し替える（interpolation〔`${VAR}`〕の解決元の差替）
- **【必須の区別】CLI の `--env-file` は interpolation 用であり、サービス定義の `env_file:` 属性によるコンテナへの読込は無効化しない**。SUT compose がサービスに `env_file: .env` を直指定している場合、`--env-file` 差替だけでは SUT の `.env` の実値（本番接続先・秘匿値）がテストコンテナへ読み込まれる。派生 compose で必ず遮断する:

```yaml
# 派生 compose（env_file 直指定 SUT への遮断パターン）
services:
  web:
    env_file: !reset []          # SUT の .env のコンテナ読込を遮断（属性の完全リセット）
    environment:                 # テストに必要な変数のみ .env.test から interpolation で注入
      APP_ENV: ${APP_ENV}
      DB_PASSWORD: ${DB_PASSWORD}
```

  - 注入する変数名は SUT の `.env` 系ファイルへの**値を読まないキー名限定の走査**（6 章 2）で得る。`environment:` はサービスの `env_file` より常に優先されるため、注入した変数はこの遮断と独立に有効

## 6. 本番誤爆突合の手順

派生環境から**本番資源へ誤接続しない**ことを config 検証前に確認する。

1. `analysis.yaml` の `dependency_summary.external_dependencies[]` から外部接続（API・DB・メール・キュー等）の一覧を得る
2. SUT compose の interpolation 変数名・`.env.test` に書いた URL / ホスト名と突合し、**本番らしき接続先**（本番ドメイン・SaaS 実 URL・社内本番 DB ホスト等）がコンテナへ渡る疑義を洗い出す
   - compose が interpolation を使わず `env_file:` 直指定の場合、変数名が compose 本文に現れない。この場合は SUT の `.env` 系ファイルに対し **値を読まないキー名限定の走査**（例: `grep -oE '^[A-Za-z0-9_]+' <.env>`）で外部接続系キー（`*_URL` / `*_HOST` / `*_ENDPOINT` 等）の存在を検出してよい（「.env の値は読まない・複製しない」規約の範囲内と明確化する。値の表示・取得は引き続き禁止）
3. 疑義への対処:
   - **モック差替**: profiles のモックサービス（4 章）+ `.env.test` の接続先差替（5 章）で外部接続を遮断する
   - **env_file 遮断**: SUT がサービスに `env_file:` を直指定している場合は派生側で `env_file: !reset []` + `environment:` 注入（5 章の遮断パターン）により SUT `.env` の実値到達そのものを断つ
   - **明示確認（対話時）**: 差替できない・判断がつかない接続はユーザーへ AskUserQuestion で確認する
   - **非対話時**: ダミー値 / モックへ差替する。差替不能な疑義が残る場合は up へ進まず理由を返す（安全側。`execution-policy.md` 6 章の本番既定禁止に整合）
4. 突合の結果（差替した接続・残した接続と根拠）を environment.yaml の `services[].overrides` / `status.notes` に記録する

## 7. 相対パス解決の基準（最初の `-f`）

複数 `-f` のマージでは、**compose 内のすべての相対パスが最初の `-f`（SUT compose）基準で解決される**。

- 派生ファイル（`environment/compose.test.yml`）内に相対 bind パスを新設しない（SUT ルート基準で解決され、意図しない場所を指すため）
- `.env.test` は compose 内の相対参照ではなく、コマンドラインの `--env-file` に**明示パス**で渡す
- `-f` の順序は「SUT の元 compose 群 → 派生」で固定する（後勝ちマージで派生側が優先される。ports のみ連結のため 1 章の `!override` が必要）

## 8. シェル環境変数の優先順位の注意

変数解決の優先順位は **shell 環境変数 > `--env-file` > `.env`** である。シェル側に同名変数が定義されていると `.env.test` の値が**上書きされない**。

- CI 等でシェルに `DB_PASSWORD` 等が定義済みの環境では、`.env.test` のダミー値より**シェル側の実値が優先**されてしまう（本番誤爆・秘匿値混入の経路になり得る）
- up 前に疑義のある変数名がシェルに存在しないかを確認し、存在する場合は `status.notes` に警告を記録してユーザーへ案内する（環境変数の削除・変更は行わない）
