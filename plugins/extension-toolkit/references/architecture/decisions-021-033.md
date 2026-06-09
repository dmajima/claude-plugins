# アーキテクチャ決定記録（ADR-021〜033）

ADR-001〜010 は `decisions-001-010.md`、ADR-011〜020 は `decisions-011-020.md` を参照。

## ADR-021: レビュータスクのフレッシュ実行原則（先入観排除）

| 項目 | 内容 |
|------|------|
| 決定 | `extension-review` のレビュー起動および各 `*-toolkit` の自己検証以外の **第三者レビュー** は、**フレッシュな Agent インスタンス**（過去の議論履歴・修正実装履歴を持たないインスタンス）で起動することを義務付ける。修正実装と同一セッション内のメインコンテキストでレビューを行ってはならない。レビュー時には目的 / 役割 / ユーザー指摘 / 対象ファイル / レビュー観点を **スポーンプロンプトで適切に引き継ぐ** ことで、コンテキスト不足を防ぎつつ先入観を排除する |
| 理由 | (1) 修正実装者と同一インスタンスがレビューすると、自身の判断を肯定する確証バイアスが働き、客観的評価が成立しない。(2) 過去のレビュー結果や修正履歴を踏襲すると「前回 OK だった」という慣性で重大な指摘を見落とす。(3) フレッシュなインスタンスは仕様書・コードを白紙で読むため、指示書の曖昧性・整合性も同時に評価できる。(4) 必要情報をスポーンプロンプトで引き継げば、コンテキスト不足は回避できる |
| トレードオフ | (1) スポーンプロンプトに引き継ぐべき情報の取捨選択が必要（過剰引き継ぎは先入観の温存、不足は誤評価を招く）。(2) 都度新規インスタンスのためトークン消費は増える。重要判断（公開前レビュー・セキュリティ審議）では許容コストとする |
| 必須引き継ぎ事項 | (a) レビュー目的（何のためのレビューか）、(b) 役割（どの観点を担当するか）、(c) ユーザー指摘・要件（直近のユーザーからの明示要求）、(d) 対象ファイル/コミット範囲、(e) レビュー観点と出力フォーマット |
| 引き継いではならない事項 | (i) 修正実装者の主観・自己評価、(ii) 過去レビューの結論（前回 APPROVE 等）、(iii) 「修正済み」「対応完了」等のメタ評価、(iv) 修正コミットメッセージ本文（要約のみ可）、(v) 「軽微」「重要でない」等の重大度予断 |
| 適用範囲 | `extension-review` の全チーム起動 / フォールバック並列起動 / 第三者レビュー全般。`*-toolkit` 内部の自己検証チェックリストは対象外（自分の生成物の自己点検は対象外） |
| プラグイン内ルールとして配布する理由 | 利用者環境（`~/.claude/rules/` の有無等）に依存させず、誰がインストールしても同じレビュー品質を保証するため、グローバル化せずプラグイン内 SSOT として配布する |
| 詳細実装 | [`review-freshness.md`](../checklists/review-freshness.md) を参照（運用ガイドライン・スポーンプロンプト骨格・反復実行ルール） |
| 代替案 | (1) 同一インスタンスでレビュー → 確証バイアスにより不合格、却下。(2) 完全白紙のレビュー（情報引き継ぎなし）→ 文脈不足で評価不能、却下。(3) 修正者と無関係な人間レビュアー → 自動化の意義が失われる、却下。(4) グローバルルールとして `~/.claude/rules/` に置く → 利用者環境に依存し動作が一貫しない、却下 |

## ADR-022: プラグイン自己完結性・利用者環境非依存・再現性の原則

| 項目 | 内容 |
|------|------|
| 決定 | `extension-toolkit` および本プラグインが生成するすべてのスキル・プラグインは、**利用者環境に依存しない自己完結性** を最優先設計原則とする。具体的には (1) グローバルルール（`~/.claude/rules/`）に依存しない、(2) グローバルエージェント（`~/.claude/agents/`）への依存は最小化し、必要なものはプラグインに同梱する、(3) グローバル設定（`~/.claude/settings.json` の特定キー）を前提としない、(4) 外部ツール（git / python / gh 等）への依存は README に明示し、不在時の動作を定義する、(5) ローカル絶対パスを書かず `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_SKILL_DIR}` を使う |
| 理由 | (1) プラグインを **インストールするだけで動作する** ことを保証することで、利用者ごとの動作差異を排除する。(2) 利用者環境のセットアップ状況に依存すると「特定環境では動くが別環境では動かない」事象が発生し、サポート工数が爆発する。(3) `extension-toolkit` 自身がプラグイン生成支援ツールであるため、生成されたプラグインも自己完結であるべきであり、本プラグインがその規範を体現する必要がある。(4) 再現性は品質保証・トラブルシュート・自動テストの基盤 |
| トレードオフ | (1) 完全自己完結化はプラグインサイズが大きくなる（共通エージェント等の同梱）。(2) グローバル既存リソースを再利用できないため重複が発生しうる。(3) 過剰な同梱はメンテナンスコストを上げる。これらは「利用者環境非依存性」の優先度に応じて取捨選択する |
| 適用範囲 | 本プラグインおよび本プラグインが生成するすべてのスキル・プラグイン |
| 必須項目 | (a) ルール参照は **プラグイン内 `references/`** から行う、(b) スポーン対象のエージェントが利用者環境に存在しない可能性がある場合は同梱するか、フォールバック設計を明示、(c) 外部ツール前提は README の「動作要件」「依存関係」に明記、(d) パスはすべて `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_SKILL_DIR}` 起点、(e) 利用者環境の設定変更を前提とする機能はインストール手順で明示 |
| 詳細実装 | [`self-containment.md`](../policies/self-containment.md) を参照（依存箇所棚卸しガイド・自己検証項目・段階的同梱戦略） |
| 代替案 | (1) グローバルルール / グローバルエージェントに依存 → 利用者環境差異で動作不一致、却下。(2) すべて利用者がセットアップ → サポート工数が爆発、却下。(3) 完全に自己完結化を最初から強制 → 既存資産が活かせない、現実的でない、却下。**段階的に自己完結度を上げる方針** を採用する |

## ADR-023: スラッシュコマンドの `argument-hint` frontmatter 必須化

| 項目 | 内容 |
|------|------|
| 決定 | スラッシュコマンドファイル（`commands/{name}.md`）が引数を受け取る場合（本文で `$ARGUMENTS` を参照する、または引数ベースのルーティング表を持つ）、frontmatter に **`argument-hint` を必ず記載する**。引数を一切受け取らないコマンドは省略可。`argument-hint` は Claude Code が `/` 補完時に表示する 1 行の引数仕様文字列で、`<必須引数> [省略可引数] [--flag 値]` 形式で書く |
| 理由 | (1) Claude Code の `/` 補完 UI は `argument-hint` を表示する公式メカニズムであり、利用者は **`description` を見ても引数の与え方が分からない**。(2) `description` は 60 文字以内かつ「引数仕様を含めない」と規定しており（[`description-guide.md`](../guides/description-guide.md) 節 4）、引数仕様の置き場所は `argument-hint` が SSOT となる。(3) 本文に `$ARGUMENTS` を書いただけでは利用者には伝わらず、誤った引数で呼び出されるサポート負荷が発生する。(4) 既存の `convert-doc` プラグインの全コマンドは既に `argument-hint` を採用しており、整合性を取る |
| トレードオフ | (1) `argument-hint` の文字列設計が必要になるが、本文の引数解釈と二重管理になる。SSOT は `argument-hint` 側とし、本文では参照のみとする。(2) 既存コマンドへの遡及適用が必要 |
| 適用範囲 | 本プラグインおよび本プラグインが生成するすべてのスラッシュコマンド。`commands/{name}.md` 形式のファイル全般（プロジェクト用 / グローバル / プラグイン同梱を問わない） |
| 必須項目 | (a) frontmatter `argument-hint` の有無を `command-toolkit` 生成時の検証項目に組み込む、(b) `references/templates/command/command.md` テンプレートに `argument-hint` プレースホルダを含める、(c) [`validation-rules.md`](../checklists/validation-rules.md) 節 2.3 に検証項目として追加、(d) `extension-review` の `automated-checks.md` で機械チェック対象に含める |
| 表記規則 | (i) 必須引数は `<...>`、省略可は `[...]`、フラグは `[--flag 値]` または `[--flag]`、(ii) 60 文字以内を目安、(iii) 改行禁止、(iv) `description` の文末で重複しない（引数仕様は `argument-hint` 側に集約） |
| 代替案 | (1) 引数仕様を `description` 内に含める → `description` 60 文字制約で詰まる・SSOT 違反、却下。(2) 本文の `## 引数` セクションに任せる → `/` 補完 UI に表示されないため利用時に見えない、却下。(3) 任意項目に留める → 既存 `convert-doc` との整合が崩れ、利用者ごとの体験差異が発生、却下 |

## ADR-024: プラグイン単位 venv 採用と `references/scripts/` 配置（ADR-010 の更新）

| 項目 | 内容 |
|------|------|
| 決定 | Python venv は **プラグイン単位で 1 つ** とし、関連スクリプト（`setup_venv.sh` / `teardown_venv.sh` / `requirements.txt`、shell-preference.md と整合して PowerShell 実装）を **プラグイン直下** の `references/scripts/setup/` に配置する。複数スキルが Python を利用する場合も同一 venv を共有する。スキル固有のスクリプトはスキル直下 `references/scripts/{業務単位}/` に配置するが、依存パッケージ（`requirements.txt`）はプラグイン直下に統合する。`environment-setup-toolkit` はプラグイン直下スクリプトの **オーケストレータ** に役割変更する（自前の setup 実装を持たず、プラグイン直下スクリプトの起動を案内する）。Python を一切使用しないプラグインでは venv 関連スクリプトの設置は不要 |
| 理由 | (1) スキル単位 venv は同じプラグイン内で重複構築を引き起こし、複数スキル協業時にどの venv を使うか判断ロジックが必要になる。(2) `requirements.txt` がスキルごとに分散すると依存解決の競合・重複が発生する。(3) プラグインは「インストール単位 = 配布単位 = 環境単位」とすべき設計原則と整合する。(4) `environment-setup-toolkit` がスキル配下に setup スクリプトを保有していると、利用側スキルから「どの setup を呼ぶか」が曖昧になる。プラグイン直下を SSOT にすることで参照経路を一意にできる |
| トレードオフ | (1) `requirements.txt` を全スキル分マージするため、特定スキルしか使わない依存も常にインストールされる。これは venv 共有の代償として許容する（不要時はプラグインを分割する）。(2) スキル固有のスクリプトと依存リストが別階層に分かれるため、新規スキル作成時に「依存はプラグイン直下、スクリプトはスキル直下」という配置を周知する必要がある |
| 適用範囲 | 本プラグインおよび本プラグインが生成・レビューするすべてのプラグイン |
| 必須項目 | (a) プラグインに `.py` ファイルが 1 つでもあり、かつ標準ライブラリ以外の `import` を含む場合、`references/scripts/setup/setup_venv.sh` `teardown_venv.sh` `requirements.txt` をプラグイン直下に置く、(b) スキル直下に `references/scripts/setup/setup_venv.sh` 等を置かない、(c) スキルごとの個別 `requirements.txt` を作らない（全依存をプラグイン直下にマージ）、(d) `environment-setup-toolkit` はプラグイン直下スクリプトの呼び出し方を案内する役割に限定する |
| 詳細実装 | [`scripts-policy.md`](../policies/scripts-policy.md) 節 5 を参照 |
| 代替案 | (1) スキル単位 venv 維持（ADR-010） → 重複構築・依存競合、却下。(2) `environment-setup-toolkit` のスキル配下スクリプトを SSOT として維持 → 「どこを呼ぶか」が曖昧になり、ADR-022 の自己完結性原則と整合しない、却下。(3) ホーム配下に共有 venv → セッション独立性破壊、却下 |

## ADR-025: 実行スクリプトのインライン記載禁止と `references/scripts/` 配置義務化

| 項目 | 内容 |
|------|------|
| 決定 | `references/`・`SKILL.md`・`README.md` 等の Markdown ファイルに、**実行を意図したスクリプト**（Python・Bash・PowerShell・Node 等）をコードブロックで直接記載することを禁止する。実行可能スクリプトは必ず `references/scripts/{業務単位}/{name}.{py,sh,ps1,js}` に切り出してファイル化し、md からはパス参照と呼び出し例（5 行以下）のみを記載する。単発のシェルコマンド（`mkdir` `git status` 等、5 行以下・1 責務・制御構造なし）は例外として md 直接記載を許可する。スクリプトの配置はプラグイン直下（`plugins/{name}/references/scripts/`）が共通リソース、スキル直下（`plugins/{name}/skills/{skill}/references/scripts/`）がスキル固有 |
| 理由 | (1) インラインスクリプトは「Claude が毎回 workspace に書き出して実行」する運用になり、トークン消費・実行時間・再現性すべてに悪影響。(2) インラインだとレビュー対象（テスト・lint・型チェック）から外れ、品質保証ができない。(3) PowerShell + chcp 65001 + on-the-fly Python の組み合わせで文字化けが再発した（`extension-review` の旧実装、ADR-024 と同じ文脈）。(4) スクリプトを `references/scripts/` 配下に集約することで「ナレッジとスクリプトを同階層で管理」「許可リストの簡素化（プラグイン/スキル直下のトップレベルディレクトリ最小化）」が実現できる。(5) 設定ファイル例・出力例・ディレクトリ構造図は表示専用で本ルールの対象外（誤解を防ぐため [`scripts-policy.md`](../policies/scripts-policy.md) に明記）|
| トレードオフ | (1) スクリプトファイル数が増え、ディレクトリ構造が複雑化する。これは業務単位サブフォルダ化（`references/scripts/setup/`・`references/scripts/checks/` 等）で吸収する。(2) インライン記載の方が「ドキュメントを読むだけで実装が分かる」という利点を失う。これは `references/scripts/` への明示的なリンク・呼び出し例で補う。(3) [`conventions-structure.md`](../policies/conventions-structure.md) 節 2.1 / 3.1 のプラグイン直下・スキル直下の許可リストから `scripts/` を削除する必要がある（互換性破壊）|
| 適用範囲 | 本プラグインおよび本プラグインが生成・レビューするすべての拡張要素（スキル・コマンド・エージェント・フック）|
| 必須項目 | (a) `references/` 配下の md は実行ロジックを直接持たない、(b) 実行スクリプトは `references/scripts/{業務単位}/` 配下にファイル化、(c) md には `references/scripts/` 内ファイルの呼び出し例（最大 5 行）のみ記載、(d) [`scripts-policy.md`](../policies/scripts-policy.md) の OK/NG 例に従う、(e) `extension-review` の `run_checks.py` で違反を機械検出する、(f) トップレベル `scripts/`（プラグイン直下・スキル直下とも）に実スクリプトを置かない |
| 判定基準 | 行数 6 行以上 / 制御構造（if/for/while/function） / 引数を取る / 複数責務 / 例外処理を含む — のいずれかで NG。詳細は [`scripts-policy.md`](../policies/scripts-policy.md) 節 3 を参照 |
| 例外 | (a) YAML / JSON 設定ファイルのサンプル（`description:` `name:` 等）、(b) エラーメッセージ・出力フォーマットの例、(c) 構造ツリー（ディレクトリ図）、(d) 動作の解説に必要な短い疑似コード（`# pseudocode:` 等の明示要） |
| 既存プラグインの移行猶予 | 本 ADR 制定前から存在する既存プラグイン（`convert-doc` 等）に対しては、`extension-review` の機械チェックは **検出のみ** を実施し（重大度 High で報告）、移行は別 PR として段階的に行う。本プラグイン（`extension-toolkit`）自身は本 ADR 制定と同時に完全準拠する。移行未完了プラグインの公開（マーケットプレイス更新）は、scripts-policy.md の指摘を解消した上で実施する |
| 代替案 | (1) インラインを許可（旧運用）→ 文字化け再発・トークン消費増・レビュー対象外、却下。(2) 全コードブロック禁止 → 設定例・出力例まで失われ、ドキュメント機能が損なわれる、却下。(3) 言語別（python のみ禁止 / bash 許可）→ 同じ問題が bash でも発生する、却下。(4) スクリプトをプラグイン/スキル直下 `scripts/` に置く（旧 ADR-015 の許可リストに沿う） → トップレベル許可リストが肥大化し、references / scripts の責務が分散、却下 |

## ADR-026: 経由促進・バージョン更新検証の 2 段フック構成

| 項目 | 内容 |
|------|------|
| 決定 | `extension-toolkit` プラグイン同梱の `hooks/hooks.json` で 2 種類のフックを登録する。**(1) PreToolUse Edit/Write/MultiEdit フック（警告型）**: `plugins/{name}/` 配下への直接編集を検知して、対応する `*-toolkit` スキル名を stderr に提示する。**ブロックはせず exit 0 で通過** させ、Claude の自律判断に委ねる。**(2) Stop フック（バージョン更新検証）**: Claude のターン終了時に `plugins/{name}/` の未コミット変更を検知し、対応する `plugin.json` の `version` が main から更新されていない場合に stderr で警告する（fail-open、exit 0）。実スクリプトはいずれも ADR-025 に従い `references/scripts/hooks/` 配下に配置する |
| 理由 | (1) ハードブロック型は **過剰制約** であり、(a) extension-toolkit 自身のセルフレビュー反復を阻害、(b) 軽微な編集（typo・1 行修正等）にも重い toolkit 起動を強制、(c) bypass フラグ運用が常態化して形骸化、というデメリットがある。(2) ハードブロックの本来の目的だった「バージョン更新漏れ防止」は **編集時ではなくコミット時の問題** であり、Stop フック / git pre-commit による事後検証の方が直接的に効く。(3) PreToolUse 警告でスキル候補を提示することで、Claude は編集規模に応じて自律的に toolkit 起動の要否を判断できる。(4) 軽微な編集を阻害しないことで、開発体験と AI 自動レビューサイクルの両立が可能 |
| トレードオフ | (1) PreToolUse 警告型は「必ず toolkit を通す」という強制力を持たない。Claude が警告を無視して直接編集することがあり得る。これは (a) スキル description / 規約教育、(b) 開発者向けドキュメントでの周知、(c) extension-review の事後レビュー、で補完する。(2) Stop フックは「すでに変更したあと」の検出のため、変更直後に修正が必要になる。これは「コミット直前」のタイミングで動くため、コミット作業の手戻りは最小限 |
| 適用範囲 | 本プラグインがインストールされた環境全体。本プラグイン自体および本プラグインがレビュー対象とするすべてのプラグイン |
| 必須項目 | (a) `hooks/hooks.json` で `PreToolUse Edit/Write/MultiEdit` と `Stop` をそれぞれルーティング、(b) 実スクリプトは `references/scripts/hooks/` 配下（ADR-025 配置義務）、(c) PreToolUse は **常に exit 0**（fail-open）、(d) Stop は git 利用不可・リポジトリ外で **無音 exit 0**、(e) `.claude/.local/` / `.git/` / `/tmp/` 配下は無条件に通過、(f) Stop フック検出ロジックは `plugin.json` の `version` フィールドを sed で抽出し main ブランチと比較 |
| 推奨ルーティング | SKILL.md → `skill-toolkit` / commands/*.md → `command-toolkit` / agents/*.md → `agent-toolkit` / hooks/* → `hook-toolkit` / README.md → `readme-toolkit` / plugin.json → `plugin-toolkit` / references/scripts/setup/ → `environment-setup-toolkit` / 公開 → `marketplace-publish` / レビュー → `extension-review` |
| 代替案 | (1) PreToolUse ハードブロック型 → 過剰制約・bypass 常態化、却下（旧設計）。(2) PreToolUse フック完全廃止 + Stop のみ → 軽微編集には適合するが、新規大規模変更時のスキル誘導も失う、却下。(3) git pre-commit のみで検証 → Claude のターン中に気付けず、コミット時点で大きな手戻りになる、却下。(4) settings.json でユーザ環境ごとに登録 → プラグイン同梱の自己完結性（ADR-022）に反する、却下 |

## ADR-027: バージョン更新検証を Stop に加え PreToolUse Bash でも実施（ADR-026 の補強）

| 項目 | 内容 |
|------|------|
| 決定 | ADR-026 の Stop フック単独構成を **PreToolUse Bash + Stop の二重実行** に変更する。`hooks/hooks.json` の `PreToolUse` に `matcher: "Bash"` を追加し、`references/scripts/hooks/check_version_bump_on_commit.sh` を呼ぶ。スクリプトは tool_input.command を sed で抽出し `git commit` を含む場合のみ既存 `check_version_bump.sh` に委譲して同一検査を実施する。Stop フックは保持する（後方互換 + 委譲先の信頼性確保） |
| 理由 | (1) Stop フックの stderr が **環境/タイミングによっては Claude の会話 context に届かない事例が確認された**（編集を 30 回以上行ったセッションで PreToolUse Edit / Stop どちらの警告も到達しなかった）。(2) PreToolUse の `additionalContext` 経路は仕様上確実に Claude へ届くため、コミット直前の最後の防衛線として有効。(3) Stop と PreToolUse Bash の両方で同じ検査スクリプトを呼ぶことで、片方の経路が機能しない環境でも警告が漏れない。(4) スクリプトロジック自体の重複は避け、PreToolUse 用ラッパーは git commit 検知後に既存 check_version_bump.sh を呼ぶだけの薄い委譲層とする |
| トレードオフ | (1) 同じ警告が Stop と PreToolUse Bash の両方で発火し得る → 警告内容は同一なので重複しても害は小さい（Claude が一度判断すれば足りる）。(2) Bash 全件で発火するため処理コストが微増 → 早期に tool_name / command を sed で判定して非対象は exit 0 で即離脱、git status / git diff の重い処理は git commit 検出時のみ実行 |
| 適用範囲 | 本プラグインがインストールされたすべての環境 |
| 必須項目 | (a) `hooks/hooks.json` の `PreToolUse` に `matcher: "Bash\|PowerShell"` エントリを追加、(b) `references/scripts/hooks/check_version_bump_on_commit.sh` を新設し ADR-025 配置義務に準拠、(c) ラッパーは tool_name == "Bash" or "PowerShell" かつ command に `git commit` を含む場合のみ既存 `check_version_bump.sh` に委譲、(d) Stop フックは削除せず保持、(e) どちらも fail-open（exit 0） |
| 代替案 | (1) Stop フックのみ維持 → 環境によって届かない事例があるため不採用。(2) PreToolUse Bash のみに移行 → Stop が機能する環境での冗長性を失う、却下。(3) PreToolUse Bash で check_version_bump.sh を直接呼ぶ → 全 Bash 呼び出しで git status を実行することになりコスト過大、却下。(4) PostToolUse で検査 → コミット完了後の警告となり手戻りが発生、却下 |

## ADR-028: 外部マーケットプレイス依存時の `extraKnownMarketplaces` 登録テンプレート同梱義務

| 項目 | 内容 |
|------|------|
| 決定 | クロスマーケットプレイス依存（`plugin.json` の `dependencies` 配列に **自プラグインの所属マーケ名と異なる** `marketplace` フィールド値を含むエントリが 1 件以上ある状態）を持つプラグインは、当該 README の「導入手順」に、(a) 依存マーケットプレイスを `/plugin marketplace add` で追加するコマンド、(b) `~/.claude/settings.json` の `extraKnownMarketplaces` に依存マーケットプレイスを `autoUpdate: true` で登録する JSON テンプレート、(c) 依存プラグインを `/plugin install` で個別追加するコマンド、の 3 点を **必須記載** する。テンプレートは `references/templates/plugin/README.md` の「D. 依存関係のインストール」セクションに反映する。同一マーケットプレイス依存のみ・依存なしのプラグインには本要件は適用しない |
| 理由 | (1) Claude Code の公式仕様では、未追加のマーケットプレイスからの依存は **自動解決されず未解決のまま放置される**（`Dependencies from a marketplace you have not added are left unresolved.`）。`marketplace.json` の `allowCrossMarketplaceDependenciesOn` で許可していても、利用者側でその依存マーケットプレイスを `/plugin marketplace add` していなければインストールが完了しない。(2) `plugin.json` には依存マーケットプレイスを **自動追加させる仕組みが存在しない** ため、利用者向け手順書（README）で補完するしかない。(3) 単に追加コマンドだけ案内しても、`extraKnownMarketplaces` への登録を行わないと自動更新されず、グローバルルール `plugin-auto-update.md`（`autoUpdate: true` 必須・週 1 更新ポリシー）と整合しない。(4) 自プラグインの `extraKnownMarketplaces` 登録（[`readme-policy.md`](../policies/readme-policy.md) 5.1 C / ADR-018 (C) 由来）と整合させるため、依存マーケットプレイスについても同形式で示すのが学習負荷が低い |
| トレードオフ | (1) README 記述量が増える → 依存ありプラグイン限定で適用、依存なしプラグインは無影響。(2) 依存マーケットプレイスの URL / `source` 情報を README 作成者が把握する必要がある → [`dependencies-policy.md`](../policies/dependencies-policy.md) のクロスマーケットプレイス依存判断時に同時に確認する運用とする。(3) 利用者が `extraKnownMarketplaces` 登録を行わなくてもインストール自体は成立する（`/plugin install` で済む）→ 自動更新は機能しないが、ハードエラーにはならないので警告型として許容 |
| 適用範囲 | クロスマーケットプレイス依存を持つプラグイン（`plugin.json` の `dependencies` 配列に **自プラグインの所属マーケ名と異なる** `marketplace` フィールド値を含むエントリが 1 件以上ある場合）。同一マーケットプレイス依存のみ・依存なしのプラグインには適用しない |
| 必須項目 | (a) [`readme-policy.md`](../policies/readme-policy.md) 5.1 D に依存マーケ `extraKnownMarketplaces` 登録ブロックを必須化、(b) `references/templates/plugin/README.md` のテンプレートに該当ブロックを反映、(c) [`dependencies-policy.md`](../policies/dependencies-policy.md) から本 ADR への参照を追加、(d) クロスマーケットプレイス依存時の README 検証チェックリスト項目を追加（[`readme-policy.md`](../policies/readme-policy.md) セクション 10）、(e) クロスマーケットプレイス依存判定は `marketplace` フィールド値 ≠ 自プラグイン所属マーケ名 で行う（自マーケ内依存で `marketplace` を冗長記載するケースの誤検知防止） |
| 代替案 | (1) `plugin.json` 側で依存マーケットプレイスの `source` を持たせて自動追加 → 公式仕様に存在しない、却下。(2) `marketplace.json` の `allowCrossMarketplaceDependenciesOn` 拡張で利用者側 `extraKnownMarketplaces` を強制 → マーケットプレイス側は依存先をホストできず、利用者の `~/.claude/settings.json` を書き換える権限もない、却下。(3) README に追加コマンドだけ書き `extraKnownMarketplaces` は省略 → 自動更新ポリシーと不整合、却下。(4) postinstall フック相当で `extraKnownMarketplaces` を自動登録 → Claude Code にそうした機構なし、却下。(5) Claude Code 公式に依存マーケ自動追加機構を機能要望として提出（短期は本 ADR で運用、公式機能実装後に本 ADR を deprecate）→ 中長期的には推奨経路だが本 ADR 採否とは独立、本 ADR は **公式機能が登場するまでの暫定対応** と位置付ける。(6) 中長期で `marketplace.json` の `allowCrossMarketplaceDependenciesOn` をオブジェクト形式（`{ "name": "...", "source": {...} }`）へ拡張し、README 生成時に `source` を構造化保持 → 将来検討、本 ADR では現運用を維持 |

## ADR-029: プラグインの MIT ライセンス必須化と専用 `mit-license-toolkit` 配備

| 項目 | 内容 |
|------|------|
| 決定 | `extension-toolkit` が生成・改修・公開する **すべてのプラグイン** に **MIT ライセンス（SPDX: `MIT`）** の付与を必須化する。具体的には (a) プラグイン直下に `LICENSE` ファイルを配置（許可リストに追加）、(b) `plugin.json` の `license` フィールドに `"MIT"` を設定、(c) `LICENSE` の copyright 行（`Copyright (c) <year> <holder>`）と本文末尾の MIT 標準文を [`license-policy.md`](../policies/license-policy.md) のテンプレートで生成、(d) 上記の管理（情報の保存・取得・選択・LICENSE 生成・plugin.json 更新）は専用スキル `mit-license-toolkit` が担当する。プラグイン公開フロー（`marketplace-publish`）はライセンス未整備のプラグインの公開を **fail-closed** で停止し、`mit-license-toolkit` への接続を案内する |
| 理由 | (1) マーケットプレイス公開を前提とするプラグインは、利用者が自由に複製・改変・再配布できる **明示的なライセンス宣言が必須**。ライセンス不在のコードはデフォルトで「全権利留保」となり、利用者は安全に利用できない。(2) Claude Code エコシステムの既存プラグイン（`anthropic-agent-skills` 等）は MIT を採用しており、MIT に統一することで再配布・派生作成時の互換性が最も高い。(3) GPL 等の copyleft 系を採用すると、本プラグインを依存に含む下流プラグインの選択肢を狭める。MIT は最も寛容で互換性が高い OSS ライセンスである。(4) ライセンス情報（著作権者・年・別名）はプロジェクトごとに異なるため、`plugin-toolkit` 等の既存スキルに混在させると責務が肥大化する。専用スキル `mit-license-toolkit` に切り出すことで SRP を維持する。(5) 同一リポジトリで複数の作者・組織のプラグインを管理する場合があるため、ライセンス情報は **複数登録可能** とし、利用時に `AskUserQuestion` で選択できるようにする（[`user-interaction.md`](../guides/user-interaction.md) 準拠） |
| トレードオフ | (1) MIT 以外の OSS ライセンス（Apache-2.0 / BSD / GPL 等）を選びたい利用者には強制となる。本 ADR は **`extension-toolkit` が生成・公開を支援する範囲** に限定するため、利用者が手動で `LICENSE` を差し替えれば他ライセンスは利用可能（ただし `mit-license-toolkit` の自動生成・検証フローからは外れる）。(2) ライセンス情報を保持する `license-info.json` は機密情報ではないが、`.claude/.local/` 配下（`.gitignore` 対象）に保存されるため、リポジトリ複製時には別途の入力が必要。これは `credentials-manager` と同じ運用方針で許容する。(3) `plugin-toolkit` / `marketplace-publish` / `readme-toolkit` / `extension-review` への連携追加が必要（既存スキルの軽微な更新で対応） |
| 適用範囲 | `extension-toolkit` が生成・改修・公開する **すべてのプラグイン**。本プラグイン（`extension-toolkit`）自身も対象 |
| 必須項目 | (a) プラグイン直下に `LICENSE` ファイル（MIT 標準文 + `Copyright (c) <year> <holder>` 行）を必ず配置する、(b) `plugin.json` の `license` フィールドに `"MIT"` を必ず設定する、(c) `conventions-structure.md` 節 2.1 の許可リストに `LICENSE` を追加する、(d) [`validation-rules.md`](../checklists/validation-rules.md) 節 2.2（プラグイン）に `LICENSE` 存在 + `plugin.json.license == "MIT"` の機械チェック項目を追加する、(e) `plugin-toolkit` の実行フローに `mit-license-toolkit` の事前呼び出しを組み込む、(f) `marketplace-publish` の公開前検証で `LICENSE` 不在・`license != "MIT"` を fail-closed で検出する、(g) `readme-toolkit` の README 検証に「ライセンス」セクションの存在チェックを追加する、(h) `references/templates/plugin/` の `LICENSE` テンプレートを追加する |
| ライセンス情報の保持 | (i) 保存先は `<repo_root>/.claude/.local/plugins/extension-toolkit/license-info.json` を優先、リポジトリ外なら `~/.claude/.local/plugins/extension-toolkit/license-info.json` にフォールバック（`local-data-directory.md` のグローバルルール `plugins/{name}/` カテゴリに準拠）、(ii) 形式は `{ "version": 1, "licenses": [ { "id": <unique-id>, "type": "MIT", "copyright_year": <year>, "copyright_holder": <name>, "author": <name>, "label": <人間可読の説明> } ] }`、(iii) 1 件のみ存在する場合は **自動適用**、複数存在する場合は `AskUserQuestion` で利用するエントリを選択させる、(iv) 不在の場合は `AskUserQuestion` で著作権者・年・別名を収集して新規エントリを保存する（重要なライセンス選択を伴うため Claude UI 優先、テキスト対話では行わない）|
| 代替案 | (1) ライセンス選択を利用者の手動配置に任せる（自動化なし）→ 公開時に LICENSE 不在のままマーケットプレイスに配信される事故が発生する、却下。(2) `plugin-toolkit` 内部にライセンス処理を組み込む → SRP 違反、`plugin-toolkit` の責務が肥大化、却下。(3) ライセンス候補を複数選択可能にする（MIT / Apache-2.0 / BSD-3-Clause 等を切替可）→ 互換性問題が複雑化し下流影響が読めなくなる、却下（MIT に統一）。(4) ライセンス情報をリポジトリに直接コミット（`license-info.json` を `.gitignore` 外）→ 著作権者氏名等の個人情報が混入し得る、却下（`credentials-manager` と同じく `.local/` に保存）。(5) `readme-toolkit` を流用 → README は人間向け、LICENSE は法的文書で性質が異なるため、専用スキルが妥当 |

## ADR-030: プラグイン直下・スキル直下の `assets/` 許可（実行時共通リソース配置のため）

| 項目 | 内容 |
|------|------|
| 決定 | プラグイン直下およびスキル直下に `assets/` ディレクトリを置き、複数スキル・スクリプトから参照される **実行時の静的リソース**（CSS / HTML テンプレート / 画像 / フォント等）を格納できることを認める。`references/template/` は AI と開発者が編集の参考にする「人間向けひな形」、`assets/` は実行時にスクリプトから直接読み込まれる「成果物用素材」として用途を区別する。プラグイン直下 `assets/` は複数スキルの共通リソース、スキル直下 `assets/` はそのスキル固有のリソースで、同名ファイルが両方にある場合はスキル直下が優先される（オーバーライド規則） |
| 理由 | (1) 複数スキル（例: `convert-html` / `convert-pdf`）で同じ CSS / HTML テンプレートを共有する場合に DRY 原則を保つ手段が必要。(2) `references/template/` は AI 可読性目的の参考資料という意味合いが強く、実行時にスクリプトが直接読み込む静的アセットとは責務が異なる（テンプレートは「コピー元」、アセットは「直接参照対象」）。(3) `references/scripts/` は実行可能スクリプト用であり、静的ファイル置き場としては語義が外れる。(4) Claude Code 公式仕様の許可リスト（`commands/` `agents/` `hooks/` `mcp/` `skills/`）は機能カテゴリで分かれており、独自カテゴリの `assets/` を追加しても構造の予見可能性は維持される |
| トレードオフ | (1) プラグイン直下・スキル直下のトップレベルディレクトリが増えるため、許可リストの判定ロジックが増える。(2) `references/template/` との使い分けを利用者に伝える必要がある（テンプレートはコピー元・アセットは実行時参照） |
| 適用範囲 | (a) プラグイン直下 `assets/`: 複数スキルから参照される共通の CSS / HTML / 画像等を配置。(b) スキル直下 `assets/`: そのスキル固有のリソース（同名ファイルがプラグイン直下にあれば上書き）|
| 制約 | (1) `assets/` 配下は **静的ファイルのみ**（実行可能スクリプト・コード本体は置かない、それは `references/scripts/` の責務）。(2) サブフォルダは種別ごとに切る（`css/` `html/` `js/` `img/` `fonts/` 等）|
| 必須項目 | (a) `conventions-structure.md` 節 2.1（プラグイン直下）の許可リストに `assets/` を追加、(b) `conventions-structure.md` 節 3.1（スキル直下）の許可リストに `assets/` を追加、(c) `conventions-structure.md` 節 2.2 / 3.2 の許可リスト根拠に `assets/` の項目を追加 |
| 代替案 | (1) `references/template/css/` 等への配置 → `template/` の語義（コピー元のひな形）から外れる、却下。(2) `references/scripts/assets/` への配置 → `scripts/` は実行可能スクリプト用、却下。(3) スキル直下のみ許可してプラグイン直下は禁止 → 共有リソースの DRY 違反、却下。(4) プラグイン直下のみ許可してスキル直下は禁止 → スキル固有の上書きが不可能、却下 |

## ADR-031: コミット粒度・分割ルールの明文化（[`commit-granularity.md`](../policies/commit-granularity.md)）

| 項目 | 内容 |
|------|------|
| 決定 | `extension-toolkit` が生成・改修・公開するすべてのプラグイン・スキル・コマンド・ドキュメント変更について、**「1 作業単位 = 1 コミット」** を既定とするコミット分割ルールを [`commit-granularity.md`](../policies/commit-granularity.md) として SSOT 化する。ディレクトリリネーム・ファイル移管・内容更新・ADR 追加・README/marketplace 同期・移行手順記載・evals 追加・lint 修正・依存更新・バージョン昇格を必須分割対象として列挙し、Conventional Commits（`feat:` `fix:` `refactor:` `docs:` `test:` `chore:` `perf:` `style:`）形式の prefix を統一適用する。各コミットは `git bisect` が機能する単位で完結すること（コミット間で意図的に壊しておかない）|
| 理由 | (1) 2026-05-18 の maintenance プラグイン統合コミット（53 ファイル / +327/-625 行）で「改名」「統合」「ADR 追加」「README 更新」「移行手順記載」が単一コミットに混在し、レビュー困難・部分ロールバック困難の課題が顕在化した。(2) 改善バックログ A-3 で「スコープ・作業単位の細かいコミット分割ルール」を High 相当と判断するエントリとして登録された（経緯は git 履歴を参照）。(3) Conventional Commits は Claude Code エコシステム外でも標準として広く採用されており、prefix 統一により履歴のスキャナビリティが上がる。(4) `git bisect` で問題コミットを二分探索する際、混在コミットだと再現範囲を絞れないため、原因コミット特定の所要時間が増大する |
| トレードオフ | (1) コミット数が増え、レビュー対象 PR でコミットチェーンが長くなる。これは「PR を機能単位に分割する」運用と組み合わせることで緩和される。(2) 大規模リファクタリング時に「ADR 追加 → 実装 → README 同期」を別々にコミットする手間が増えるが、レビュー容易性・部分ロールバック容易性とのトレードオフとして許容する。(3) 改名と相互参照更新を 1 コミットで行いたい場合があるが、コミットメッセージ上は同一コミットとして含めてよい（節 3「同梱可」）|
| 適用範囲 | `extension-toolkit` が生成・改修・公開するすべてのプラグイン・スキル・コマンド・エージェント・フック・マーケットプレイス・ドキュメント・スクリプト変更。本プラグイン（`extension-toolkit`）自身の改修も対象 |
| 必須項目 | (a) [`commit-granularity.md`](../policies/commit-granularity.md) を `references/policies/` 配下に配置、(b) 必須分割対象 10 項目（節 2 (a)〜(j)）を文書化、(c) Conventional Commits 8 種 prefix を文書化、(d) 同梱許可ケース 3 種（節 3）を限定列挙、(e) ADR 追加と実装の同梱可否（節 5）を 1 対 1 / 1 対 N で判別、(f) **当面は `extension-review` の専門家レビュー（人間 / Agent）による検出に委ね、機械検出は将来実装する**（commit-granularity.md 節 7 参照、git log 解析を伴う検査スクリプト追加が前提のため、ADR-031 初版では実装スコープ外） |
| 例外 | (a) 緊急セキュリティ修正、(b) 自動生成物の同期（marketplace.json 等）、(c) 利用者の明示的指示（「全部 1 コミットで」）の 3 ケースのみ免責される。これら以外で本ルールを破る場合は `extension-review` のレビュー指摘対象 |
| 代替案 | (1) 分割なし（現状維持）→ レビュー困難・部分ロールバック困難の課題が継続、却下。(2) 厳格な機械検出 + 違反時のコミット強制リバート → 利用者の git 履歴に対する裁量を侵害、却下。(3) 大規模変更時のみ分割を必須化（小規模は同梱可）→ 「大規模/小規模」の定義が曖昧で運用がぶれる、却下。本案は「常に分割」を既定としつつ、節 3「同梱可」を限定列挙する明示形式を採用 |

## ADR-032: 動作デモ + ユーザ承認フローの必須化（[`completion-checklist.md`](../checklists/completion-checklist.md) 節 2.4）

| 項目 | 内容 |
|------|------|
| 決定 | `extension-toolkit` 配下のすべてのスキル・コマンドは、作業完了報告の前に **ユーザ向け動作デモ実施 + AskUserQuestion による承認取得** を必須とする。デモ最低要件は (a) 代表的な正常系 / (b) 主要分岐 1 件以上 / (c) AskUserQuestion 実発火 / (d) エラーパス 1 件 / (e) 副作用の事前提示 の 5 項目。免責ケースは (i) README/コメントのみ変更 / (ii) ADR/SSOT のみ変更 / (iii) 緊急セキュリティ修正 / (iv) 利用者の明示スキップ指示 の 4 ケースに限定 |
| 理由 | (1) 2026-05-18 のセッションで maintenance プラグインに対し 6 サイクルの専門家レビュー（Critical/High 全解消）を経て push したが、その後のデモ実行で `sync-settings/sync.sh` の `TrimStart` char 変換 Critical バグが発見された。静的解析・自己検証では実行時バグを検出できないことが実証された。(2) `extension-review` の機械チェック（行数 / description 文字数 / JSON valid 等）は PowerShell スクリプトの API シグネチャ齟齬を検出できない（B-1 で PSScriptAnalyzer 統合予定だが、それでも実機実行に勝る検証はない）。(3) ユーザ承認を取らないままリリースに到達すると、利用者全員に不具合が配信されるリスクがある |
| トレードオフ | (1) デモ実施分の所要時間が増える（軽微変更でも数分）。(2) AskUserQuestion での承認ステップが対話往復を 1 回増やす。これらは免責ケース 4 種で緩和（純粋ドキュメント変更は対象外）。(3) デモシナリオ設計の手間が増えるが、B-3 の `evals/demo.sh` テンプレート化で再現性を担保 |
| 適用範囲 | `extension-toolkit` 配下の 9 個の `*-toolkit` スキル + `extension-review` + `marketplace-publish` の計 11 スキル。各スキルの SKILL.md「引き渡し」セクションに本フローを参照する追記を実施 |
| 必須項目 | (a) [`completion-checklist.md`](../checklists/completion-checklist.md) 節 2.4 にデモ実施・承認取得を必須項目として追加、(b) 各 SKILL.md の引き渡しセクションに節 2.4 への参照を追加、(c) デモシナリオ最低 5 要件を文書化、(d) 4 種の免責ケースを限定列挙、(e) `progress.md` にデモ実施記録（実行コマンド・結果・承認結果）を残す責務を明示 |
| 例外 | 免責ケース 4 種のみ。それ以外で本フローを省略する場合は `extension-review` の指摘対象（Critical 相当） |
| 代替案 | (1) 自動テスト（evals 実行）のみで承認とする → AskUserQuestion 等の UI 系・実機固有挙動を検証できない、却下。(2) 承認なしのデモ通知のみ → ユーザが見落とすリスク、却下。(3) すべての変更にデモ必須（免責なし）→ ドキュメント変更でもデモを強いるのは過剰、却下。本案は「実コード変更には必須、純粋ドキュメントは免責」のバランスを採用 |

## ADR-033: `references/` への CLAUDE.md 必須配置（README.md との責務分離）

| 項目 | 内容 |
|------|------|
| 決定 | `references/` ディレクトリが存在するプラグインでは `references/CLAUDE.md`（Claude エージェント向け原則・ナビゲーション文書）を必須配置し、`references/README.md`（人間向けインデックス）と責務を分離する。`README.md` は人間向け説明資料であり、Claude エージェントの動作時には参照禁止。`CLAUDE.md` は原則とナビゲーションのみを記載し、詳細ルールは `policies/` 等の分離済みファイルを参照させる |
| 理由 | (1) `README.md` は人間向けに「利用方法・動作例・拡張手順」を網羅するが、エージェントには冗長で、かつトリガー判定・手順実行の指示としては不適切。(2) エージェントが `references/` 配下の多数のファイルを効率的にナビゲートするには、タスク駆動型の参照表が必要。(3) 既存の `SKILL.md` は個別スキルの定義に限定されるため、プラグイン横断の原則を記述する場所がなかった |
| トレードオフ | (1) ファイル数が 1 つ増える。(2) README.md と CLAUDE.md の記載内容が部分的に重複する可能性があるが、CLAUDE.md はナビゲーション表と原則の箇条書きに限定し、詳細は分離ファイルを参照させることで重複を抑制。(3) 既存プラグインすべてに CLAUDE.md を追加する移行コストが発生する |
| 適用範囲 | `extension-toolkit` プラグインの `references/`（必須）、各スキルの `references/`（推奨、3 ファイル以上時） |
| 必須項目 | (a) [`claude-md-policy.md`](../policies/claude-md-policy.md) にポリシーを策定、(b) [`conventions-structure.md`](../policies/conventions-structure.md) 節 4.1 の推奨構造に `CLAUDE.md` を追加、(c) `extension-review` の [`checklists/plugin.md`](../../skills/extension-review/references/checklists/plugin.md) に P-8.5 確認項目を追加 |
| 代替案 | (1) SKILL.md に references/ のナビゲーションを記載 → 200 行制約を圧迫、却下。(2) README.md 自体を AI 対応にする → 人間の可読性が低下、却下。(3) references/ 配下に index.md を置く → 既存の README.md と役割が曖昧になる、却下 |

## ADR の追加・更新

新たな設計判断が発生した際は、本ファイルに ADR-XXX 形式で追記する。既存 ADR を変更する場合は **最新の決定のみを記載** する（変更前の判断・変更経緯は Git コミット履歴を参照する）。ADR-010（スキル単位 venv）は ADR-024 で更新されたため、ADR-024 の内容が現行決定。ADR-026（フック構成）は ADR-027 で補強されたため、両方を併読する。ADR-018（README 4 要素）は ADR-028（クロスマーケットプレイス依存時の D セクション詳細）で詳細化されたため、両方を併読する。