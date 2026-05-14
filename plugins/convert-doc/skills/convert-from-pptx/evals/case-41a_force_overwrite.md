# Case 41a: `--force` フラグによる既存ファイル上書き

## 入力

- 入力 PPTX: 3 スライド構成の有効な PPTX
- 出力 MD: `<セッション>/output.md`（**既存ファイルが既に同パスに存在**）
- オプション: `--force`

## 期待動作

1. `_validate_pptx()` で入力 PPTX を検証
2. `convert()` 内で `_check_safe_output(self.output_path, self._force)` を呼ぶ
3. `self._force = True` のため、既存ファイルがあっても `ValueError` を raise せず通過
4. ただし既存ファイルが **シンボリックリンク** の場合は `--force` 有無に関わらず拒否（HR-A）
5. 新しい内容で `output.md` を上書き
6. 書込後 `_apply_safe_perm` で chmod 0o600 を試行（POSIX のみ）
7. 終了コード: 0

## 期待出力

- 既存 `output.md` が新しい内容で上書き
- 標準出力: `Wrote: <セッション>/output.md`
- 終了コード: 0

## 分岐の根拠

`convert_from_pptx.py:_check_safe_output()`:
```python
def _check_safe_output(path: Path, force: bool = False) -> None:
    if path.exists():
        if path.is_symlink():
            raise ValueError(f"Refusing to write through symlink: {path}")
        if not force:
            raise ValueError(f"Output already exists (use --force to overwrite): {path}")
```

`--force` 指定時の `force=True` 経路を検証する境界ケース（CWE-377 防御の opt-in 上書き）。

## 関連ケース

- [case-41b_symlink_output_rejected.md](case-41b_symlink_output_rejected.md): symlink 出力先の拒否
- [case-31_workspace_root_traversal.md](case-31_workspace_root_traversal.md): パストラバーサル拒否
