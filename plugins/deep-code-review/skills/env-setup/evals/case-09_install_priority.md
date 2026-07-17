# case-09 インストール優先順位（winget → ツール固有サブコマンド → MSI/EXE・E4）

複数ツールのインストールで、各ツールに E4 の優先順位（winget → ツール固有サブコマンド → MSI/EXE）を適用し、winget 非対応ツールはサブコマンドへフォールバックする分岐を検証するケース。単一ツールの winget 導入（case-02）や委譲経由（case-03）に対し、優先順位の適用順そのものを見る。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "node と csharp-ls と typescript-language-server をインストールして"（winget 利用可） |
| モード | 対話 |

## 分岐の根拠

references/skill-rules-matrix.md E4「winget → ツール固有サブコマンド → MSI/EXE の順」、SKILL.md「実行モード判定」2「Windows でのインストール優先順位」（1. winget 最優先 → 2. ツール固有サブコマンド（dotnet tool install / npm install -g / az extension add）→ 3. 上記が使えない場合のみ MSI/EXE インストーラ（事前にユーザー確認））、`${CLAUDE_SKILL_DIR}/references/tools-catalog.md`。単一ツールの winget 導入（case-02）や委譲経由のサブコマンド導入（case-03）に対し、優先順位の適用順そのものを検証する。

## 期待動作

- インストールモードに入り、AskUserQuestion でまとめて承認を取得する（E2）
- 各ツールについて E4 の優先順位を適用する:
  - node: winget（`winget install --id OpenJS.NodeJS.LTS ...`）を最優先で使用する（優先順位 1）
  - csharp-ls: winget パッケージが存在しないため、ツール固有サブコマンド `dotnet tool install --global csharp-ls` を使用する（優先順位 2）
  - typescript-language-server: 同様にツール固有サブコマンド `npm install --global typescript-language-server typescript` を使用する（優先順位 2）
- MSI/EXE インストーラは、winget もツール固有サブコマンドも使えない場合の最終手段とし、実行前に必ずユーザー確認を取る（優先順位 3）
- ツール固有サブコマンドの前提（csharp-ls は dotnet、typescript-language-server は node/npm）を満たしてから実行する（依存順序。tools-catalog.md）
- 管理者昇格が必要でも自動昇格せず、ユーザーへ手動実行を案内する（E3）
- インストール後に各確認コマンド（`node --version` / `csharp-ls --version` / `typescript-language-server --version`）で再確認する（実行フロー 6）
- 完了報告は「## env-setup 結果」フォーマットで、各ツールに使用した導入手段を明記する

## 関連ケース

- case-02: winget 最優先での単一導入（優先順位 1 の正常系）
- case-03: 委譲経由でのツール固有サブコマンド導入（優先順位 2 の隣接分岐）
- case-05: ツールインストール依頼での起動
