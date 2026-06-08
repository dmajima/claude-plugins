# case-22 /update コマンドによるプロジェクト更新

/update コマンドで現在のプロジェクトのプラグインを更新する正例。

## 入力

| 項目 | 値 |
|-----|------|
| 起動フレーズ | "/update" |
| モード | 非対話 |

## 期待

- plugin-updater スキルが target=current-project mode=normal で起動する
- Phase A-0 から G の順序でプラグインを更新する
- 更新結果サマリが報告される

## 期待出力

| 出力 | 内容 |
|-----|------|
| 標準出力 | 更新されたプラグイン名・バージョン・結果のサマリ |

## 分岐の根拠

SKILL.md の実行モード判定で /update コマンド経由 → target=current-project に該当。

## 関連ケース

- case-02: target=current-project の基本ケース
