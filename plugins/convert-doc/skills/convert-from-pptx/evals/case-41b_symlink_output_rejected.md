# Case 41b: 出力先がシンボリックリンクなら `--force` 有無を問わず拒否

## 入力

- 入力 PPTX: 任意の有効な PPTX
- 出力 MD: `<セッション>/output.md`（このパスが既に **シンボリックリンク** として配置されている、例えば `/etc/cron.d/payload` 等の攻撃対象を指す）
- オプション: `--force`（有効でも拒否される）

## 期待動作

1. `_validate_pptx` で入力 PPTX を検証
2. `convert` 内で `_check_safe_output(self.output_path, self._force)` を呼ぶ
3. `self.output_path.exists` が True、`self.output_path.is_symlink` が True のため、`--force` の値に関わらず `ValueError` を raise
4. メッセージ: `Refusing to write through symlink: <絶対パス>`
5. python-pptx での読み込みは行われるが、書き込み直前で停止（fail-closed）
6. 終了コード: 1

## 期待出力

- 標準エラー: `Error: Refusing to write through symlink: /etc/cron.d/payload`
- 終了コード: 1
- 攻撃対象ファイルは上書きされない

## 分岐の根拠

`convert_from_pptx.py:_check_safe_output`:
```python
if path.exists:
    if path.is_symlink:
        raise ValueError(f"Refusing to write through symlink: {path}")
    if not force:
        raise ValueError(f"Output already exists (use --force to overwrite): {path}")
```

シンボリックリンクは `--force` より優先される（CWE-59 / CWE-367 TOCTOU 対策）。
共有環境や CI 上で攻撃者がシンボリックリンクを差し込んで任意ファイル上書きを狙う攻撃を防御する。

## 関連ケース

- [case-41a_force_overwrite.md](case-41a_force_overwrite.md): 通常の `--force` 上書き
- [case-10_path_traversal_images_dir.md](case-10_path_traversal_images_dir.md): images-dir のパストラバーサル拒否
