# Architecture Decision Records (plugins-update)

`plugins-update` プラグイン固有の設計判断記録。プラグイン横断の規約は親マーケットプレイス側
（`extension-toolkit/references/architecture-decisions.md`）を参照。

| 番号 | タイトル | 状態 |
|------|---------|------|
| ADR-PU-001 | 単一プラグイン化（vs marketplace-toolkit への統合 / vs スキル化） | Accepted |
| ADR-PU-002 | 公式 CLI 委譲（vs 低レベル git 操作 / vs 内部実装） | Accepted |
| ADR-PU-003 | Phase A〜G 固定順序 + exit code 一次判定 | Accepted |

---

## ADR-PU-001: 単一プラグイン化

### Context

プラグイン更新の手動トリガー機能を Claude Code 上で提供するにあたり、以下の配置選択肢があった。

1. **単一プラグイン化**: `plugins-update` として独立したプラグインとして提供
2. **`extension-toolkit:marketplace-toolkit` への統合**: マーケットプレイス本体管理スキルに更新機能を含める
3. **スキル化**: `extension-toolkit` 配下のスキルとして実装

### Decision

**選択肢 1（単一プラグイン化）** を採用する。

### Rationale

- **責務分離（SRP）**: 更新メンテナンスは「マーケットプレイス本体管理」「公開ワークフロー」と
  独立した運用関心事である。エンドユーザーが日常的に呼び出す手動メンテナンスコマンドであり、
  開発時のみ使う `marketplace-toolkit` / `marketplace-publisher` とライフサイクルが異なる。
- **配布単位の独立性**: `extension-toolkit` をインストールしないユーザーでも、本プラグイン単独で
  インストール・利用可能にすることで、配布範囲を最大化できる。
- **依存関係の最小化**: 他プラグインへの依存を持たず（`dependencies: []`）、Claude Code CLI のみを
  要件とすることでインストール障壁を下げる。

### Trade-offs

- `marketplace-toolkit` との連携は README リンクに留まり、自動同期はしない。
- 機能追加時に `extension-toolkit` 側のテンプレート資産は流用できない（独自実装が必要）。

### Alternatives Considered

- **`marketplace-toolkit` への統合**: 開発時スキルに運用コマンドを混在させると SRP 違反になり、
  `extension-toolkit` のサイズが肥大化する。却下。
- **スキル化**: スキルは AI が自動起動する単位だが、本機能は明示的なユーザートリガー
  （`/update-all`）が前提のため、スラッシュコマンドが適切。却下。

---

## ADR-PU-002: 公式 CLI 委譲

### Context

マーケットプレイスとプラグインの更新を実装するにあたり、以下の選択肢があった。

1. **公式 CLI 委譲**: `claude plugin marketplace update` / `claude plugin update <name>@<mp> --scope <scope>`
   を呼び出す
2. **低レベル git 操作**: 各マーケットプレイスのインストールディレクトリで `git fetch + reset --hard origin/HEAD`
   を直接実行する
3. **内部実装複製**: Claude Code CLI の更新ロジックを本プラグイン内に複製する

### Decision

**選択肢 1（公式 CLI 委譲）** を採用する。

### Rationale

- **破壊的操作の回避**: `git reset --hard` はローカルコミット・stash・detached HEAD・独自ブランチ等の
  ユーザ作業を意図せず破壊するリスクがある。CLI は内部でロック制御と状態管理を行い、これらを安全に
  扱う責務を負う。
- **認証情報の透過的扱い**: Git credential helper / SSH キーの取り扱いを CLI に委譲することで、
  本プラグインが認証情報に直接触れない（情報漏洩リスクの最小化）。
- **CLI 機能改善の自動取り込み**: CLI バージョンアップで新機能（並列更新・JSON 出力等）が追加された場合、
  本プラグイン側の修正なしに恩恵を受けられる（拡張ポイントを残してある）。
- **責務委譲によるシンプル化**: ロック・ロールバック・ネットワーク制御の責務を持たないため、
  本プラグインは「順序制御 + 結果集約 + ユーザ対話」に専念できる。

### Trade-offs

- **CLI 仕様変更への追従**: CLI 出力フォーマット変更時、本プラグインの結果分類ロジックが影響を受ける。
  これに対しては (a) exit code 一次判定 + 出力解析を補助に降格、(b) Unknown 区分の導入、
  (c) 将来の `--output json` への移行余地を残す、で対処する。
- **CLI 依存**: Claude Code CLI が PATH に存在しない環境では動作しない。
  ただし Claude Code 自体が起動できないので実質的問題は発生しない。
- **CLI 内部の挙動が不透明**: 並列処理・ロック粒度・タイムアウト等が CLI 実装に依存する。
  本プラグイン側で全体タイムアウト（30 分）を設定して暴走を防ぐ。

### Alternatives Considered

- **低レベル git 操作**: 旧版（v1.x）の実装方式。security レビューで Critical（破壊操作の事前同意欠如）/
  High（stash・detached HEAD 未対応）/ Medium（パストラバーサル）等の指摘多数。却下。
- **内部実装複製**: CLI のロジックを複製する保守コストが高く、CLI バージョン追従が困難。却下。

### Future Direction

CLI が `--output json` 等の構造化出力モードを提供したら、文字列パターンマッチからの脱却を計画する。
実装時には ADR-PU-002a として補記する。

外部 CLI 依存を `plugin.json` で機械可読に宣言する手段が公式仕様に追加された場合は速やかに対応する。

---

## ADR-PU-003: Phase A〜G 固定順序 + exit code 一次判定

### Context

複数のマーケットプレイスと複数スコープのプラグインを更新する処理を、どう構造化するかを決定する必要があった。

### Decision

以下の **Phase A〜G の固定順序** で逐次処理する。

| Phase | 内容 |
|-------|------|
| A | 対象収集（`marketplace list` + `enabledPlugins` 抽出） |
| A-1 | プラグイン名・MP 名・スコープ名の入力検証（XR-1） |
| A-2 | マーケットプレイス整合性検証（`enabledPlugins` の MP が `marketplace list` に存在するか） |
| B | マーケットプレイス更新（`--scope` 指定でも常に実行） |
| C | User スコープのプラグイン更新 |
| D | Project スコープのプラグイン更新 |
| E | Local スコープのプラグイン更新 |
| F | 結果報告（サマリ + マーケットプレイス詳細 + スコープ別詳細） |
| G | 失敗対応の確認 + 限定リトライ + 再描画 |

CLI の成否は **exit code を一次判定** とし、出力テキストの解析は補助情報に降格する。
判定不能ケースは "Unknown（要手動確認）" 区分として残す。

### Rationale

- **順序の根拠**:
  - **MP → User → Project → Local** の固定順は、(a) マーケットプレイス本体が SSOT のため最新化を
    プラグイン更新より先に行う必要があり、(b) スコープは上書き優先順位（より狭いスコープが優先）の
    逆順で更新することで「広いスコープから順に最新化される」ためユーザの認知モデルに合致する。
  - **Phase B を `--scope` 指定でも常に実行** する理由: マーケットプレイスは全プラグインの SSOT であり、
    スコープ限定更新でも最新の MP インデックスが必要なため。

- **exit code 一次判定の根拠**:
  - CLI の出力フォーマットはバージョン間で変わりうるため、出力テキストの正規表現マッチに依存すると
    CLI バージョン変更時に静かに誤分類が発生する。
  - exit code は POSIX 慣習として安定したインターフェースであり、CLI バージョン非依存性が高い。
  - 出力解析が失敗した場合に "Unknown" 区分として残すことで、ユーザに「要手動確認」のシグナルを
    届けられる（誤った成功・失敗判定よりも安全）。

- **冪等性**: 同一 (plugin, marketplace) を複数スコープで処理しても CLI 側で冪等性が保証される
  （`enabledPlugins` がスコープごとに独立 SSOT であるため）。

### Trade-offs

- **直列処理**: 並列実行による I/O 待ち短縮の余地を放棄している。CLI のロック競合リスクを避けるため
  当面は直列を維持する。将来的に `update-one(scope, plugin, marketplace) → result` 抽象を導入し、
  Strategy パターンで並列化への切り替え可能にすることを検討。
- **Phase G の質問数**: 失敗が多い場合に AskUserQuestion 連鎖が UX を損なうため、5 件超は個別判断モードを
  スキップ（一括対応のみ）するという閾値で妥協する。

### Alternatives Considered

- **並列実行**: CLI の内部ロック挙動が公式に保証されていないため、現時点では却下。
- **キーワードマッチ一次判定**: 出力解析を一次にすると CLI バージョン変更時の壊れ方が静かで気付きにくい。却下。

### Future Direction

CLI が JSON 出力モードを提供したら、Phase B-1 / C-1 の結果分類ロジックを構造化判定に移行する
（拡張ポイントは現コマンド本文に明記してある）。
