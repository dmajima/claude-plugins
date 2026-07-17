# Universal Rules — 品質系（U12〜U16）

`deep-code-review` プラグイン内 SSOT [`universal-rules.md`](universal-rules.md) の詳細サブファイル。
U12〜U16（認証情報の取り扱い / 動的検証の SKIPPED 明示 / 提出コードの信頼性原則 / 指摘への信頼度付与 / 防御コード削除の回帰検出）の規範本文・達成基準・詳細参照を保持する。

> **親（索引）**: [`universal-rules.md`](universal-rules.md) の「U マップ（U1〜U16 索引）」を参照。
> 本ファイルは MANDATORY。適用範囲・改訂手順・関連リファレンスは親ファイルが持つ。

---

## U12. 認証情報の取り扱い（MANDATORY）

### 規範

- 外部接続（PR API・外部 URL fetch 等）の認証情報取得は **`connector` プラグインに委譲**する。connector が credentials-manager プラグインの認証情報ストア（`.claude/.local/plugins/credentials-manager/credentials.json`。リポジトリ優先 → ホーム。後方互換で従来パス `~/.claude/credentials.json` も参照）を含む複数ソース（gh / az CLI・環境変数等）から解決する
- **connector に接続している場合、deep-code-review は credentials-manager を直接依存・直接呼び出ししない**（connector が抽象化層のため）。外部接続の **認証情報の値の取得** を目的として deep-code-review 自身が `credentials.json` を直接参照しない（値の取得は connector に委譲する）。ただし SSRF 防御（`safe-external-fetch.md`）が許可ホスト判定のために credentials-manager ストアの `domains` / `urls` メタデータを参照するのは、認証情報の値取得ではない防御機構のため許容する
- 認証情報の **保存・登録** が必要な場合は credentials-manager プラグイン（credentials-manager skill）に委ねる（deep-code-review 自身は認証情報を保存しない）
- 認証情報の **値そのもの** をユーザー出力・PR コメント・ログに含めない
- レビュー対象コードに認証情報パターンが含まれている場合は伏字化する

### 達成基準

```
[ ] 外部接続の認証情報の値取得を connector に委譲している（deep-code-review 自身が値取得目的で credentials.json を直接読まない。SSRF allowlist の domains/urls メタデータ参照は防御機構のため除く）
[ ] connector が解決する認証情報ストアは credentials-manager プラグインの標準ストアを前提としている
[ ] connector 接続時に credentials-manager を直接依存・直接呼び出ししていない
[ ] 認証情報の値そのものがユーザー出力に含まれていない
[ ] 機密文字列パターン（Bearer / GHP / JWT / AWS / GCP / Slack 等）が伏字化されている
[ ] 認証情報の保存・登録は credentials-manager skill 経由で行う（deep-code-review 自身は保存しない）
```

### 詳細

- 認証情報取得の委譲先: `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/credentials-precheck.md`（connector 委譲・credentials-manager ストア前提）
- ユーザーグローバル規約 `~/.claude/rules/security/credentials-management.md`
- 機密文字列パターン: `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` セクション 3〜4

---

## U13. 動的検証の SKIPPED 明示（MANDATORY）

### 規範

ビルド・Linter・テスト・CVE スキャン等の動的検証が未実施の場合は、**SKIPPED として記録** し、SKIPPED 理由（権限なし・コマンド未導入・タイムアウト・依存差分なし等）を明記する。
「未実施」を「問題なし」と書き換えない。

### 達成基準

```
[ ] 動的検証エージェント（linter / runner / dep）の実行可否を明示している
[ ] SKIPPED 時に理由（権限なし・コマンド未導入・タイムアウト・依存差分なし等）を記載している
[ ] 未確認事項・制約セクションで「未実施」を「問題なし」と書き換えていない
```

### 詳細

`${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/output/output-format.md` セクション 4 を参照。

---

## U14. 提出コードの信頼性原則（MANDATORY）

### 規範

レビュー対象の提出コードは **誤りがあることを前提** として評価する。
提出コード内に存在するパターン・命名規則・設計判断を、プロジェクトのルール・規約・慣例として類推してはならない。

### 許可される情報源

- **無条件で参照可**: `CLAUDE.md` / `.claude/rules/` / `.editorconfig` 等の明文化された規約、inputs フォルダの仕様書、OWASP / CWE 等の外部標準
- **ユーザー承認が必要**: 差分外の既存コードベースからの規約類推、提出コード内のパターンからの規約類推
- **禁止**: 提出コードのパターンを無断で規約として類推すること

### ユーザー承認の記録

承認結果は state.yaml の `code_as_reference_decisions` に記録し、再レビュー時に同一パターンの承認を再利用する。

### 達成基準

```
[ ] 提出コードのパターンをユーザー承認なしで規約として類推していない
[ ] 類推が必要な場合に AskUserQuestion で承認を取得している
[ ] 承認結果を state.yaml に記録している
[ ] 明文化された規約が存在する場合に提出コードのパターンを優先していない
```

### 詳細

`${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/state/code-trustworthiness.md` を参照。

---

## U15. 指摘への信頼度（Confidence）付与（MANDATORY）

### 規範

レビュー指摘を生成するすべてのスキル・エージェントは、各指摘に **信頼度 0〜100** を付与する。
信頼度は「その指摘が実際の問題である確からしさ」を表し、誤検知（false positive）によるレビューノイズの抑制に使用する。

### 付与基準

| レンジ | 意味 |
|-------|------|
| 90〜100 | コード上の事実として直接確認できる / 動的検証で実証済み |
| 70〜89 | 問題である可能性が非常に高いが、実行文脈への依存が残る |
| 60〜69 | 状況によっては問題。前提の確認が望ましい |
| 0〜59 | 推測・憶測を含む。誤検知の可能性が高い |

- 根拠がレビュー対象コード上で直接確認できない指摘（呼び出し元挙動・データ量等の仮定を含む）は 60 未満とする
- 統合時の足切り（信頼度 60 未満は Issues / Suggestions に記載しない）はオーケストレーターの責務（C24）

### 達成基準

```
[ ] すべての指摘に信頼度（0〜100）が付与されている
[ ] 仮定・推測に基づく指摘の信頼度が 60 未満になっている
[ ] 動的検証で実証された指摘の信頼度が 90 以上になっている
```

### 詳細

`${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` セクション 7 を参照。

---

## U16. 防御コード削除の回帰検出（MANDATORY）

### 規範

差分の **削除側（`-` 行）** で、既存の **防御コード** が失われていないかを確認し、失われていれば **回帰（regression）** として指摘する。silent-failure 観点（U 系・言語プロファイル 3.2）が「新規コードでの握りつぶし」を扱うのに対し、本ルールは「リファクタで既存の防御が削られる」ケースを扱う（別物）。

### 対象とする防御コード

- 例外処理（`try/catch` / `except` / `.catch()` / エラーハンドラ）
- 入力検証・境界チェック・ガード節（null チェック・範囲検証・型ガード）
- リソース解放（`using` / `with` / `AbortController` / クリーンアップ関数 / `finally`）
- アクセシビリティ属性（`role` / `aria-*` / `alt` / `label` 関連付け）
- 認可・認証チェック（`[Authorize]` / 権限確認 / CSRF トークン検証）
- エラー表示 UI・フォールバック（`role="alert"` の表示・エラー state・デフォルト値）

### 判定

- 差分の削除行に上記防御コードが含まれ、追加行で **同等の防御が再導入されていない** 場合、回帰として指摘する
- 意図的な削除（防御が不要になった正当な理由がある）と区別できない場合は、信頼度を中程度にし「回帰の可能性・意図確認」として提示する

### 達成基準

```
[ ] 差分の削除側（- 行）の防御コード消失を確認している
[ ] 消失した防御が追加側で再導入されていない場合に回帰として指摘している
[ ] 意図的削除と区別できない場合は意図確認として提示している
```

### 詳細

言語別の具体例は `${CLAUDE_PLUGIN_ROOT}/references/languages/typescript.md` / `javascript.md`（error state / cleanup 保持）等の各プロファイルを参照。

---

← 索引に戻る: [`universal-rules.md`](universal-rules.md)（U マップ・適用範囲・改訂手順・関連リファレンス）
