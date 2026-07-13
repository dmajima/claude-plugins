# connector references/rendering/

投稿先サービス別のレンダリングルール（render-check スキルが検証に使用する SSOT）。

## 目的と範囲

Backlog / Azure DevOps へ投稿する本文が、投稿先の記法で意図どおり表示されるかを判定するためのルール集。`render-check` スキルがターゲット指定（`backlog-notation` / `backlog-markdown` / `ado-markdown` / `ado-workitem-html`）に応じて参照する。

## 原則

1. **1 ファイル 1 記法**: 各ファイルは対象サービス・記法単位で完結させる
2. **判定の根拠を明記**: FAIL / WARN の判定基準は実際のレンダリング挙動（実績由来）に基づき、根拠を記載する
3. **新サービス追加時**: render-check SKILL.md の適用判断基準（独自記法の有無）に従い、適用対象の場合のみ本ディレクトリへルールを追加する

## ナビゲーション

| ターゲット | ファイル |
|-----------|---------|
| Backlog 独自記法 | [backlog-notation.md](backlog-notation.md) |
| Backlog Markdown | [backlog-markdown.md](backlog-markdown.md) |
| Azure DevOps（PR / 作業項目） | [azure-devops-markdown.md](azure-devops-markdown.md) |
