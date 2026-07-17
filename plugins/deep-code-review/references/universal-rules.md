# Universal Rules（プラグイン内 SSOT・MANDATORY）

`deep-code-review` プラグイン配下の **全スキルが必ず満たすべき横断ルール** を本ファイル群に集約する。
プラグインを自己完結（self-contained）にするため、本ファイル群がプラグイン内 SSOT。

> **位置付け**: `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md`（プラグイン直下 references）。
> `skill-rules-matrix.md` の Universal セクション（U1〜U16）の **詳細定義は本ファイルおよび同ディレクトリの `universal-rules-*.md`（環境系 / プロセス系 / 品質系）** が持つ。
> 各スキルの `references/checklist.md` は本ファイルとマトリクスを片方向参照する。
>
> **本ファイルは索引（薄い親）**。U1〜U16 の規範本文・達成基準・整合性・詳細参照は、下記「U マップ」からリンクする 3 つのサブファイルに移設済み。外部からの `universal-rules.md U16` 等の参照は本索引の U マップ表で解決する。

---

## 0. 適用範囲

| 対象 | 適用 |
|------|------|
| プラグイン配下の全スキル | **必須**（code-review / pr-review / code-review-implementation / -testing / -security / -architecture / -frontend / code-review-spec-inference / env-setup） |
| プラグイン配下のカスタムコマンド | **必須**（code-review-standard / code-review-quick） |
| プラグイン配下のフック・スクリプト | **必須** |

---

## U マップ（U1〜U16 索引）

各ルールの規範本文・達成基準・整合性・詳細は、グループごとのサブファイルに移設済み。
ID 列のリンクから該当サブファイルへ遷移する（外部参照 `universal-rules.md UNN` は本表で解決する）。
新しい Universal ルールの追加・改廃時は、規範本文を該当グループのサブファイルに置き、本表に行を追加・更新する（手順は下記「1. 規範の改訂手順」）。

### 環境・セッション系（U1〜U6）

詳細ファイル: [`universal-rules-environment.md`](universal-rules-environment.md)

| ID | 規範（1 行要約） |
|----|----------------|
| [U1](universal-rules-environment.md) | スキル構成規約への準拠（SKILL.md 最小構成 + references/ 分離・scripts/ は業務単位分類・テンプレは references/template/） |
| [U2](universal-rules-environment.md) | ファイル文字コード・改行コードの維持（編集時に元のエンコーディング・改行・BOM を保持） |
| [U3](universal-rules-environment.md) | ローカルデータ領域の規約遵守（`.claude/.local/{category}/{name}/` 配下・公式 5 カテゴリ） |
| [U4](universal-rules-environment.md) | セッション作業領域の規約遵守（中間物・venv は workspace/・成果物はセッション直下・inputs/ は読取専用） |
| [U5](universal-rules-environment.md) | 進捗管理ルール（3 タスク以上 / マルチエージェント時に progress.md を作成・状態更新） |
| [U6](universal-rules-environment.md) | ポータブルパス記法の遵守（自己参照 `${CLAUDE_SKILL_DIR}` / プラグイン `${CLAUDE_PLUGIN_ROOT}`・ハードコード禁止） |

### プロセス系（U7〜U11）

詳細ファイル: [`universal-rules-process.md`](universal-rules-process.md)

| ID | 規範（1 行要約） |
|----|----------------|
| [U7](universal-rules-process.md) | PR 外への影響禁止（レビュー中は PR 自体への書き込み以外禁止・Work Item / Issue / 別 PR / Wiki / 通知等） |
| [U8](universal-rules-process.md) | 別 PR 推奨の禁止（「別 PR で対応」等の文言禁止・スコープ外は「スコープ外指摘」に分離） |
| [U9](universal-rules-process.md) | エージェント並列起動（独立観点は 1 メッセージ内で複数 Agent を並列発行・Independent 型） |
| [U10](universal-rules-process.md) | エージェント共通指示の付与（各プロンプト末尾に規約参照・必須項目・スコープ判定・別 PR 禁止） |
| [U11](universal-rules-process.md) | 重要度付与・重複統合の規範（Critical / High / Medium / Low 統一・同一指摘統合・衝突時は厳しい側） |

### 品質系（U12〜U16）

詳細ファイル: [`universal-rules-quality.md`](universal-rules-quality.md)

| ID | 規範（1 行要約） |
|----|----------------|
| [U12](universal-rules-quality.md) | 認証情報の取り扱い（外部接続の取得は connector に委譲・connector が credentials-manager ストアから解決・connector 接続時は credentials-manager を直接依存 / 呼び出ししない／値を出力 / コメント / ログに含めない・機密パターンは伏字化） |
| [U13](universal-rules-quality.md) | 動的検証の SKIPPED 明示（未実施の動的検証は理由付きで SKIPPED 記録・「未実施」を「問題なし」としない） |
| [U14](universal-rules-quality.md) | 提出コードの信頼性原則（提出コードは誤り前提・パターンを無断で規約類推しない） |
| [U15](universal-rules-quality.md) | 指摘への信頼度（Confidence）付与（各指摘に 0〜100 を付与・仮定 / 推測は 60 未満） |
| [U16](universal-rules-quality.md) | 防御コード削除の回帰検出（差分削除側の防御コード消失を回帰として指摘） |

---

## 1. 規範の改訂手順

新しい Universal ルールを追加する場合:

1. 該当グループのサブファイル（`universal-rules-*.md`）に次の連番（U17, ...）を採番してセクション追加し、本ファイルの U マップ表に行を追加する
2. `skill-rules-matrix.md` のテーブルに ID と SSOT パスを追加
3. **全スキル**の `references/checklist.md` に ID を追記（適用外スキルは「本スキル適用外」注記に ID を追加）
4. **同期検証（必須）**: `grep -rln "(U<新番号>)" skills/*/references/checklist.md` の件数が全スキル数と一致することを確認する。1 つでも欠けたまま改訂を完了してはならない（過去の U14 追加時に 7 スキルで追記漏れが発生した教訓）

ルールを廃止する場合:

1. 該当 ID は再利用しない（廃番）
2. 該当サブファイルに「DEPRECATED」と明記し、廃止理由を記載（本ファイルの U マップ表の該当行にも反映）
3. 各スキルの `checklist.md` から ID を削除（または廃止注記に変更）
4. 同期検証: 追加時と同様に grep で全スキルの追従を確認する

---

## 2. 関連リファレンス

- `${CLAUDE_PLUGIN_ROOT}/references/universal-rules-environment.md` — U1〜U6（環境・セッション系）の規範本文・達成基準
- `${CLAUDE_PLUGIN_ROOT}/references/universal-rules-process.md` — U7〜U11（プロセス系）の規範本文・達成基準
- `${CLAUDE_PLUGIN_ROOT}/references/universal-rules-quality.md` — U12〜U16（品質系）の規範本文・達成基準
- `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` — 全スキルのルール ID 体系・スキル別適用マトリクス
- `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` — 別 PR 推奨禁止 / PR 外への影響禁止（U7 / U8 の詳細）
- `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` — 機密文字列伏字化 / 予約文字エスケープ（U12 関連）
- `${CLAUDE_PLUGIN_ROOT}/references/agents.md` — エージェント選定・プロンプト構成（U9 / U10 の詳細）
- `${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` — 重要度付与・重複統合（U11 の詳細）
