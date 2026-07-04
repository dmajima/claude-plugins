# CSS / JS の対話選択ルール

`convert-html` スキル実行時の CSS テンプレート選択と JS 機能選択の詳細ルール。

## CSSファイルの選択

スキル実行前に `${CLAUDE_SKILL_DIR}/assets/css/` とフォールバック先の `${CLAUDE_PLUGIN_ROOT}/assets/css/` の `.css` ファイルを合算して確認し、**2 つ以上存在する場合**は `AskUserQuestion` ツールで選択させる。同名ファイルはスキル側を優先する。

### 呼び出し方針

- `question`: `"適用するCSSを選択してください。"`
- `header`: `"CSS"`
- `multiSelect`: `false`（1つだけ選択）
- `options`: 検出した `.css` ファイルを `{ label: ファイル名, description: "<由来> の <ファイル名> を使用。<用途の一言説明>" }` で列挙（由来は「スキル」または「プラグイン共通」）
  - 既知テンプレートの用途説明: `template.css` = 「ドキュメント型（Wiki スタイルの縦長資料・サイドバー目次付き）」、`executive.css` = 「Web ページ型（経営者向け。ネイビー×ゴールドの LP 風レイアウト・ヒーロー/アジェンダ自動生成）」
  - ユーザーの依頼に「経営者向け」「役員向け」「LP 風」等が含まれる場合は `executive.css` を推奨（label 末尾に「(Recommended)」を付け先頭に配置）

### 回答の処理

- 選択されたファイルの **絶対パス** を `--css-template "<絶対パス>"` として渡す（由来に応じて `${CLAUDE_SKILL_DIR}/assets/css/...` または `${CLAUDE_PLUGIN_ROOT}/assets/css/...` を解決した結果）
- 「Other」（カスタム指示）が入力された場合は、入力内容を指示として解釈して処理する
- 選択された CSS に対の HTML 骨格がある場合は後述「CSS と HTML 骨格のペアリング」を適用する
- **回答受け取り後、確認なしでそのまま処理を続行する**

## CSS と HTML 骨格のペアリング

CSS テンプレートには対になる HTML 骨格・追加フラグ・JS 除外が定義されているものがある。
選択された CSS が下表に該当する場合、**行内のすべての列を必ず適用** する。

| CSS | HTML 骨格（`--html-template`） | 追加フラグ | JS の扱い | 形態 |
|-----|------------------------------|-----------|----------|------|
| `template.css` | 指定不要（既定の `template.html` が解決される） | なし | 既定どおり | ドキュメント型（縦長 + サイドバー目次） |
| `executive.css` | `${CLAUDE_PLUGIN_ROOT}/assets/html/executive.html` の絶対パス | `--split-sections` | 既定どおり全機能（`toc-toggle.js` = サイドバー/ドロワー目次、`lightbox.js` = 画像拡大、`scroll-reveal.js` = セクションのフェードイン演出。いずれも executive トンマナのスタイルが当たる） | Web ページ型（LP 風。ネイビーのヒーローヘッダー + 章番号付き全幅セクション + スリムフッター・経営者向け） |

上表にない CSS でも、同名の `.html` が `assets/html/`（スキル → プラグイン共通の順）に存在する場合は、それを `--html-template` として渡す。

### Web ページ型テンプレート選択時の注意

- 目次はプラグイン標準の `toc-toggle.js` 機能が提供する（デスクトップ: ダークネイビーの右サイドバーパネル + 開閉トグル / モバイル: 右上のフローティングボタン + ダークドロワー。バー内タイトルはヒーローと重複するため CSS で非表示）。目次が不要な場合は通常の JS 除外選択で `toc-toggle.js` を外せばよい
- 通常の Web ページとして縦スクロールで閲覧する体裁（印刷も通常のドキュメントフロー）。スライド枠やページ番号は持たない
- 同じトンマナの PPTX（スライド）版は `convert-pptx` スキルの `--theme executive` で生成できる

### 制約

- `AskUserQuestion` の options は最大 4 件（「Other」は自動付与のため実質 3 件）。CSS ファイルが 4 件以上の場合はテキストベースの選択に切り替える
- `${CLAUDE_SKILL_DIR}/assets/css/` と `${CLAUDE_PLUGIN_ROOT}/assets/css/` の合算で `.css` ファイルが 1 つだけの場合は選択肢を提示せずにそのまま使用する（同名ファイルがある場合はスキル側を優先）

### 仕様の正規化（同名ファイル時）

合算ロジックは以下の通り:

1. プラグイン共通 (`${CLAUDE_PLUGIN_ROOT}/assets/css/`) と スキル固有 (`${CLAUDE_SKILL_DIR}/assets/css/`) を**和集合**として扱う
2. 同名ファイルが両方に存在する場合は **スキル側を優先**（プラグイン共通側は選択肢から除外）
3. ユーザーが選択しなかった経路（`--css-template` 未指定）でも、`convert.py` 内の `_resolve_asset` がスキル → プラグイン共通の順に first-existing 解決を行う

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

- `AskUserQuestion` の options は最大 4 件（「全て不要」を含む）。features.json の機能が 3 件以上になる場合はテキストベースの選択に切り替える
- **別スキルからの呼び出しなど対話が難しい場合は `--js-features` を省略して全機能を導入する**

JS 機能ファイルの作成・追加ルールは [`js-authoring.md`](js-authoring.md) を参照。
