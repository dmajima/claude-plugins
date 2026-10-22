#!/usr/bin/env python3
"""モック HTML のスクリーンショットを生成する。

design-bridge の design-push から呼び出される。Playwright (chromium) で
ローカルの HTML を開き、PNG として出力する。

使用例:
    python capture.py --mocks-dir mocks --out-dir specs/assets
    python capture.py --mocks-dir mocks --out-dir specs/assets --only S001_login

終了コード:
    0 = 全件成功（対象 0 件も成功扱い）
    1 = 1 件以上失敗
    2 = 引数エラー・Playwright 未導入
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# エンコーディング必須設定（Windows の既定 CP932 による文字化け・例外を防ぐ）
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="モック HTML のスクリーンショットを生成する"
    )
    parser.add_argument(
        "--mocks-dir", required=True, help="モック HTML のあるディレクトリ"
    )
    parser.add_argument(
        "--out-dir", required=True, help="PNG の出力先ディレクトリ"
    )
    parser.add_argument(
        "--only",
        action="append",
        default=None,
        help="対象を限定する（拡張子なしのファイル名。複数指定可）",
    )
    parser.add_argument("--width", type=int, default=1280, help="ビューポート幅")
    parser.add_argument("--height", type=int, default=800, help="ビューポート高さ")
    parser.add_argument(
        "--skip-partials",
        action="store_true",
        help="アンダースコアで始まるファイル（部品）を対象外にする",
    )
    parser.add_argument(
        "--no-full-page",
        action="store_true",
        help="ページ全体ではなくビューポート範囲のみを撮影する",
    )
    return parser.parse_args()


def collect_targets(
    mocks_dir: Path, only: list[str] | None, skip_partials: bool
) -> list[Path]:
    targets = sorted(mocks_dir.glob("*.html"))
    if skip_partials:
        targets = [p for p in targets if not p.name.startswith("_")]
    if only:
        wanted = {name.removesuffix(".html") for name in only}
        targets = [p for p in targets if p.stem in wanted]
    return targets


def main() -> int:
    args = parse_args()

    mocks_dir = Path(args.mocks_dir).resolve()
    out_dir = Path(args.out_dir).resolve()

    if not mocks_dir.is_dir():
        print(f"エラー: モックディレクトリが見つかりません: {mocks_dir}", file=sys.stderr)
        return 2

    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print(
            "エラー: playwright が未導入です。venv で "
            "`python -m pip install -r requirements.txt` と "
            "`python -m playwright install chromium` を実行してください。",
            file=sys.stderr,
        )
        return 2

    targets = collect_targets(mocks_dir, args.only, args.skip_partials)
    if not targets:
        print("対象のモック HTML はありません。")
        return 0

    out_dir.mkdir(parents=True, exist_ok=True)

    failed: list[str] = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        try:
            context = browser.new_context(
                viewport={"width": args.width, "height": args.height}
            )
            page = context.new_page()
            for html_path in targets:
                png_path = out_dir / f"{html_path.stem}.png"
                try:
                    page.goto(html_path.as_uri(), wait_until="load")
                    page.wait_for_timeout(200)
                    page.screenshot(
                        path=str(png_path), full_page=not args.no_full_page
                    )
                    print(f"生成: {png_path.name} <- {html_path.name}")
                except Exception as exc:  # noqa: BLE001 - 1 件の失敗で全体を止めない
                    failed.append(html_path.name)
                    print(
                        f"失敗: {html_path.name} ({exc.__class__.__name__}: {exc})",
                        file=sys.stderr,
                    )
            context.close()
        finally:
            browser.close()

    total = len(targets)
    print(f"完了: 成功 {total - len(failed)} 件 / 失敗 {len(failed)} 件")
    if failed:
        print("失敗したファイル: " + ", ".join(failed), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
