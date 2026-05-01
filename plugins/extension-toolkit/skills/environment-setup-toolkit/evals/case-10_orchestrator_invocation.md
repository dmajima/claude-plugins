# Case 10: 他スキルからのオーケストレータ起点呼び出し（ADR-024）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 他スキル（例: `extension-reviewer`）から `Skill(skill: "environment-setup-toolkit", args: "setup ...")` で呼ばれる |
| 引数 | `setup --work-dir .claude/.local/work/20260501_03_self_review/workspace --requirements ${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt` |
| フラグ | なし |
| 既存状態 | `extension-toolkit` プラグインがインストール済 / プラグイン直下 `references/scripts/setup/{setup_venv.sh,teardown_venv.sh,requirements.txt}` が配置済 |

## 期待動作

### Phase 1: 委譲先スクリプトの解決

`environment-setup-toolkit` は **自前で setup ロジックを保持しない**（ADR-024）。`${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh` の存在を確認する。

| 状況 | アクション |
|-----|---------|
| 存在 | そのまま起動 |
| 不存在 | プラグイン直下に setup スクリプトが未配置 → ADR-024 準拠雛形の作成案内（後述 Phase 4） |

### Phase 2: 起動

```bash
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh" \
  "$WORK_DIR" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt"
```

スクリプト内部で:
- work_dir 安全装置（`.claude/.local/` 配下チェック）
- python 検出（`python` → `python3` → `py`、`-m venv --help` で実体検証）
- venv 構築 + pip / setuptools / wheel 最新化
- requirements.txt から依存インストール

### Phase 3: 結果中継

スクリプトの stdout / stderr を呼び出し元スキルへ中継する。venv パスと python バイナリ位置（`$WORK_DIR/.venv/Scripts/python` または `$WORK_DIR/.venv/bin/python`）を返す。

### Phase 4: setup スクリプトが未配置の場合（ADR-024 雛形作成案内）

| 状況 | 提示内容 |
|-----|---------|
| プラグイン直下 `references/scripts/setup/` 不在 | 「対象プラグインに ADR-024 準拠の setup スクリプトが配置されていません。`extension-toolkit` 自身の `references/scripts/setup/` を雛形として作成しますか?」を `AskUserQuestion` で確認 |
| 雛形作成承認 | `setup_venv.sh` / `teardown_venv.sh` / `requirements.txt`（空）をプラグイン直下に作成 |
| 拒否 | 中断、ユーザに手動作成を案内 |

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 中継 stdout | `[setup_venv]` プレフィックス付きの ASCII ログ |
| venv 実体 | `$WORK_DIR/.venv/` |
| 呼び出し元への返却 | venv python パス（`$WORK_DIR/.venv/Scripts/python`）+ pip list サマリ |
| 終了状態 | 成功 |

## 分岐の根拠

ADR-024 で `environment-setup-toolkit` は「自前 setup を持たないオーケストレータ」役割に変更されたため、case-01〜09（自前 setup 前提のケース）とは異なり、**プラグイン直下スクリプトの起動経由** が新しい正規ルートとなる。本ケースはこの新正規ルートの動作を例示する。

## teardown 経路（オーケストレータ経由）

setup と対称に、teardown も他スキルから本スキル経由でプラグイン直下スクリプトを起動する:

```text
Skill(skill: "environment-setup-toolkit", args: "teardown --work-dir <work_dir>")
```

```bash
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/teardown_venv.sh" "$WORK_DIR"
```

| 観点 | 内容 |
|-----|------|
| 安全装置 | teardown_venv.sh 内 3 段ガード（realpath 正規化 + `.claude/.local/` 限定 + システムパス除外）が常に動作 |
| 失敗時の振る舞い | 安全装置に引っかかった場合は exit 1 で fail-closed、venv は削除されない |
| プラグイン直下スクリプト不在時 | setup と同じく ADR-024 雛形作成案内（Phase 4）を提示 |

## 関連ケース

- case-01（旧: 自前 setup 直接起動）→ ADR-024 後はオーケストレータ経由に変わるが、互換のため case-01 自体は残置
- case-03（旧: 自前 teardown 直接起動）→ オーケストレータ経由は本ケース内 teardown 節を参照
- case-09（python 未インストール環境のエラー系、新パスに更新済み）
