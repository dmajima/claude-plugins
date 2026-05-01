# Case 06: --non-interactive モード（質問なしで生成）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "コード品質評価用のエージェント `code-quality-reviewer` を作って" |
| 引数 | `code-quality-reviewer --non-interactive --domain "code-quality" --placement global` |
| フラグ | `--non-interactive` |
| 既存状態 | 同名エージェント未存在 |

## 期待動作

### Phase 1: モード判定

`--non-interactive` 検出 → 非対話モード。
`--domain` `--placement` 等の必須情報がフラグで明示的に指定されているため、ユーザ確認をスキップ。

### Phase 2: 既存エージェント確認

`~/.claude/agents/code-quality-reviewer.md` 未存在を確認（処理は同じ）。

### Phase 3: 評価観点設計（自動）

ドメイン `code-quality` のデファクトスタンダード（Clean Code / SOLID / SonarSource Quality Profile 等）から
評価観点を **質問せず自動的に** 3 つ以上選定。

| 自動選定される観点 | 根拠 |
|----------------|-----|
| 正確性 | コード品質の基礎 |
| パフォーマンス | 一般的なドメイン要件 |
| 可読性 | Clean Code 起点 |
| テスト容易性 | SOLID 起点 |

### Phase 4: テンプレート展開 + 充填（自動）

テンプレート（`${CLAUDE_PLUGIN_ROOT}/references/templates/agent/agent.md`）を展開し、
ドメインに応じたデフォルト値を埋める。`AskUserQuestion` は **一切呼び出さない**。

### Phase 5: 検証 + 引き渡し

検証チェックリスト合格後、生成ファイルパスのみを標準出力に提示。
不合格項目があった場合は標準エラー出力に提示し、対話なしで終了。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `~/.claude/agents/code-quality-reviewer.md` |
| 標準出力 | 「`code-quality-reviewer` エージェント作成完了」+ ファイルパス |
| 終了状態 | 成功 |
| ユーザ対話 | 発生しない |

## 分岐の根拠

`--non-interactive` フラグ → 自動化スクリプト・CI からの呼び出しを想定し、対話ゲートを全て省略。
必須情報がフラグで明示されていない場合は **エラー終了**（対話のかわりにエラーメッセージ）。

## 関連ケース

- `case-01_single_agent.md`（対話モード、観点をユーザ確認）
- `case-03_existing_update.md`（既存エージェントの改修）
