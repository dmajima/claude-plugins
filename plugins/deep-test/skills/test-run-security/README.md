# test-run-security スキル

セキュリティテスト（`security` / TC-SEC）のケースを、Playwright MCP + Bash による OWASP 観点の動的チェックとして実行する実行スキル。
承認済みケースに記載された範囲でのみ確認し、結果を中間データとしてオーケストレータ `test` に返却する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下、および `${CLAUDE_PLUGIN_ROOT}/references/` の共通 SSOT です。

## 担当テストレベル

| テストレベル | level 値 | ケース ID | 実行アプローチ |
|------------|---------|----------|--------------|
| セキュリティテスト | `security` | TC-SEC | Playwright MCP + Bash による OWASP 観点の動的チェック |

## チェック観点（対象）

| 観点 | 確認内容 |
|------|---------|
| 認証 | 未認証アクセス制御・認証エラー時の情報露出 |
| セッション管理 | ログアウト後のセッション無効化・Cookie 属性（Secure / HttpOnly / SameSite） |
| 入力検証 | XSS 反射確認（無害ペイロード）・SQL エラーメッセージ露出・パストラバーサル基礎 |
| セキュリティヘッダ | CSP・X-Frame-Options・HSTS 等（`browser_network_requests` / `curl -I`） |
| 情報露出 | エラーページのスタックトレース・コメント内機密・ディレクトリリスティング |

- fail 時は `defect.extras.owasp_category` を記録し、severity は OWASP 対応表（`${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md` 4.2）で判定
- エビデンスの機微情報（トークン・パスワード・個人情報）はマスキング（保管時は可能な限り・報告転載時は必須）

## 対象外・禁止（重要）

| 区分 | 内容 |
|------|------|
| 対象外 | ペネトレーションテスト（攻撃連鎖・エクスプロイト実証）・SCA（依存脆弱性スキャン）・SAST（静的解析）の代替ではない |
| 禁止 | 破壊的攻撃（実データ改変・削除・DoS・総当たり）の実行 |
| 範囲 | 承認済みケース（test-cases.yaml）記載の範囲=対象システム所有者の合意範囲内でのみ実行 |
| 環境 | 本番環境への実行は既定で禁止 |

対象外領域は「未確認」として扱い、「問題なし」とは結論しません（`${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` 8 章）。

## 位置付け（デリゲーション）

- 本スキルは **実行と結果返却のみ**を担い、`test-results.yaml` への書き込みは行わない（オーケストレータが一元実行）
- 実行スキルはブラウザセッション共有のため逐次起動が前提

## 使い方

### トリガーフレーズ例（通常はオーケストレータ経由）

```
セキュリティテストを実行して
OWASP 観点で動的チェックして
セキュリティヘッダ・セッション・入力検証を確認して
```

## カスタマイズ・拡張

| 拡張対象 | 方法 |
|---------|------|
| チェック観点・確認手順の追加・変更 | `references/security-execution.md`（2 章 観点別チェック手順）を更新する（実行してよい操作/禁止操作の境界〔0 章〕は維持する） |
| 機微情報マスキング手順の調整 | `references/security-execution.md` 5 章を更新する（プラグイン共通の `evidence-policy.md` と整合させる） |
| 動作分岐の検証ケース追加 | `evals/` に `case-NN_<slug>.md` を追加し、`evals/README.md` の一覧表を更新する |

## ファイル構成

```
plugins/deep-test/skills/test-run-security/
├── SKILL.md                        # Claude が実行時に読むスキル定義
├── README.md                       # 本ファイル（人間向け）
├── references/
│   └── security-execution.md       # 観点別チェック手順・確認コマンド例・マスキング手順・実行してよい操作/禁止操作の境界・達成チェックリスト
└── evals/                          # 動作分岐検証ケース（case-01〜13 + README・13 ケース）
```

## スコープ外

- unit / functional / integration / system / uat / performance レベルの実行（各 `test-run-*` が担当）
- `test-results.yaml` の更新・報告書生成（オーケストレータ / `test-report`）
- ペネトレーションテスト・SCA・SAST の代替、破壊的攻撃（対象外・禁止）

## 関連スキル

- `test`（オーケストレータ） — ライフサイクル制御・実績記録・ゲート判定
- `test-run-functional` / `test-run-scenario` — 機能・シナリオレベルの Playwright 実行
- `test-report` — 実績 YAML からの報告書生成
