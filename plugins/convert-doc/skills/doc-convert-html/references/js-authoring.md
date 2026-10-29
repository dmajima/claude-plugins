# JS機能ファイル作成ガイド

## 基本構造

`assets/js/` 配下の各ファイルは **1機能1ファイル** とする。
すべてのファイルは **即時実行関数式（IIFE）** でラップし、グローバルスコープを汚染しないこと。

```javascript
(function  {
  'use strict';

  // ここに機能の実装

});
```

## 競合防止ルール

複数のJSファイルを同一HTMLに埋め込んでもエラーが起きないよう、以下を厳守する。

### 1. DOM要素IDに機能固有のプレフィックスをつける

| 機能名 | プレフィックス | 例 |
|---|---|---|
| ライトボックス | `lb-` | `lb-overlay`, `lb-box` |
| （新規機能例）スムーズスクロール | `ss-` | `ss-button` |
| （新規機能例）コピーボタン | `cb-` | `cb-tooltip` |

**同一プレフィックスを使わないこと**。プレフィックスは `features.json` の `dom_prefix` に登録して管理する。

### 2. 変数・関数をIIFEスコープ内に閉じ込める

```javascript
// NG: グローバル変数
var scale = 1;

// OK: IIFE内変数
(function  {
  var scale = 1;
});
```

### 3. 他の機能ファイルに依存しない

各ファイルは単独で動作すること。ファイル間でオブジェクトの受け渡しや関数呼び出しをしない。
共通処理が必要な場合はそれぞれのファイルに重複して記述する（ファイル間依存より重複の方が安全）。

### 4. DOMの存在確認を行う

別の機能が生成するDOM要素に依存しない。自分のIIFE内で生成したDOMのみ参照する。

```javascript
// OK: 自分で生成したDOMを参照
var overlay = document.createElement('div');
overlay.id = 'lb-overlay';

// NG: 他の機能が生成するかもしれないDOMを参照
var el = document.getElementById('other-feature-element');
```

## features.json への登録

新しいJSファイルを追加したら、`assets/js/features.json` に必ずエントリを追加する。

```json
{
  "features": [
    {
      "file": "新機能.js",
      "name": "表示名（日本語可）",
      "description": "ユーザーに見せる機能の説明",
      "dom_prefix": "xx-"
    }
  ]
}
```

- `file`: `assets/js/` 配下のファイル名
- `name`: スキルがユーザーに提示する選択肢の名称
- `description`: 機能の説明（1行）
- `dom_prefix`: このファイルが使用するDOM IDのプレフィックス（他と重複禁止）

## 埋め込み順序

`convert.py` は `features.json` の配列順にファイルを結合する。
機能間に依存がないため順序は基本的に自由だが、DOMContentLoaded後に動作する機能は
`document.readyState` を確認して遅延実行すること。

## 新機能ファイルのテンプレート

`references/template/js-feature-template.js` を `assets/js/<feature-name>.js` にコピーして実装を始める。
テンプレートには必要なIIFE骨格・TODO コメント・チェックリストが含まれている。

## 新機能追加チェックリスト

- [ ] ファイルをIIFEでラップしている
- [ ] `'use strict'` を先頭に記載している
- [ ] DOM IDに機能固有のプレフィックスを使用している
- [ ] 他のJSファイルへの依存がない
- [ ] `features.json` にエントリを追加した（`dom_prefix` が他と重複していないか確認）
- [ ] `assets/js/` 内の全機能ファイルと同時に埋め込み、ブラウザコンソールにエラーが出ないことを確認した
