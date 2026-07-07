# CSS / JS の対話選択ルール

`convert-html` スキル実行時の CSS テンプレート（デザイン）選択と JS 機能選択の詳細ルール。
デザインの配置場所・命名の共通規約は [`../../../references/design-locations.md`](../../../references/design-locations.md) を参照。

## CSSファイル（デザイン）の選択

スキル実行前に以下 3 箇所の `.css` ファイルを合算して確認し、**2 つ以上存在する場合**は `AskUserQuestion` ツールで選択させる。

| 順序 | 場所 | 由来表示 |
|-----|------|---------|
| 1 | `${CLAUDE_SKILL_DIR}/assets/css/` | スキル |
| 2 | `${CLAUDE_PLUGIN_ROOT}/assets/css/` | プラグイン共通 |
| 3 | ローカルデザインディレクトリ `<designs>/css/`（`design-locations.md` 節 3: リポジトリ内なら `<repo_root>/.claude/.local/plugins/convert-doc/designs/`、無ければ `~/.claude/.local/plugins/convert-doc/designs/`） | ローカルデザイン |

### 呼び出し方針

- `question`: `"適用するCSSを選択してください。"`
- `header`: `"CSS"`
- `multiSelect`: `false`（1つだけ選択）
- `options`: 検出した `.css` ファイルを `{ label: ファイル名, description: "<由来> の <ファイル名> を使用" }` で列挙（由来は「スキル」「プラグイン共通」「ローカルデザイン」）

### 回答の処理

- 選択されたファイルの **絶対パス** を `--css-template "<絶対パス>"` として渡す（由来に応じて上表の各ディレクトリを解決した結果）
- **同名 HTML テンプレートのペア解決**: 選択された CSS と同じベース名の `.html` が、同由来の `html/` ディレクトリ（`${CLAUDE_SKILL_DIR}/assets/html/` / `${CLAUDE_PLUGIN_ROOT}/assets/html/` / `<designs>/html/`）に存在する場合は、その絶対パスを `--html-template "<絶対パス>"` として併せて渡す。存在しない場合は `--html-template` を渡さない（デフォルト `template.html` が使われる）
- 「Other」（カスタム指示）が入力された場合は、入力内容を指示として解釈して処理する
- **回答受け取り後、確認なしでそのまま処理を続行する**

### 制約

- `AskUserQuestion` の options は最大 4 件（「Other」は自動付与のため実質 3 件）。CSS ファイルが 4 件以上の場合はテキストベースの選択に切り替える
- 3 箇所の合算で `.css` ファイルが 1 つだけの場合は選択肢を提示せずにそのまま使用する（同名ファイルは上表の順で優先）

### 仕様の正規化（同名ファイル時）

合算ロジックは以下の通り:

1. スキル固有 (`${CLAUDE_SKILL_DIR}/assets/css/`)、プラグイン共通 (`${CLAUDE_PLUGIN_ROOT}/assets/css/`)、ローカルデザイン (`<designs>/css/`) を**和集合**として扱う
2. 同名ファイルが複数箇所に存在する場合は **スキル > プラグイン共通 > ローカルデザイン** の順で優先（下位は選択肢から除外）
3. ユーザーが選択しなかった経路（`--css-template` 未指定）でも、`convert.py` 内の `_resolve_asset` がスキル → プラグイン共通の順に first-existing 解決を行う（ローカルデザインは `--css-template` 明示指定でのみ使われる）

## JS機能の選択

スキル実行前に `${CLAUDE_SKILL_DIR}/assets/js/features.json` を読み込み、**1 つ以上の機能が登録されている場合**は `AskUserQuestion` ツールで確認する。機能を省くことでファイルサイズを削減できるため、1 機能のみでも必ず確認する。

### 呼び出し方針

デフォルトは全機能有効のため、**除外したい機能を選択する方式**で質問する。

- `question`: `"除外するJS機能を選択してください。（何も選択しない → 全機能有効）"`
- `header`: `"JS機能"`
- `multiSelect`: `true`
- `options`: features.json の各機能を `{ label: 機能名, description: 説明文 }` で列挙したあと、末尾に以下を追加する
  - `{ label: "全て不要", description: "JSを一切埋め込まない" }`

### 回答の処理

1. 回答文字列を `,` で分割し、各要素を trim して **空文字・空白のみの要素は除外** する
2. 「全て不要」が含まれる場合は `--js-features ""` を渡して処理を続行する
3. それ以外は残った要素を除外対象の機能名リストとし、features.json の全機能から差し引いた機能のファイル名をカンマ結合して `--js-features` に渡す
4. **回答受け取り後、確認なしでそのまま処理を続行する**

### 制約

- `AskUserQuestion` の options は最大 4 件（「Other」は自動付与のため、「全て不要」を含めて実質 3 件）。features.json の機能が 3 件以上になる場合はテキストベースの選択に切り替える
- **別スキルからの呼び出しなど対話が難しい場合は `--js-features` を省略して全機能を導入する**

JS 機能ファイルの作成・追加ルールは [`js-authoring.md`](js-authoring.md) を参照。
