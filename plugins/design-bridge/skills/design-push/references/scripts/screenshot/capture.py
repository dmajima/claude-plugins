#!/usr/bin/env python3
"""モック HTML のスクリーンショットを生成する。

design-bridge の design-push から呼び出される。Playwright (chromium) で
ローカルの HTML を開き、PNG として出力する。

安全性:
    --project-root を必須とし、--mocks-dir / --out-dir がその配下にあることを
    検証する。設定ファイルはリポジトリ同梱＝第三者が支配しうる入力なので、
    ここを検証しないと任意ディレクトリの HTML を画像化して外部へ持ち出せる。

    レンダリングはオフラインコンテキストで行う。モック HTML は design-pull で
    他の利用者が書いたものが入りうるため、外部へのビーコン送信や社内サービス
    への到達（SSRF）を防ぐ。

使用例:
    python capture.py --project-root . --mocks-dir mocks --out-dir specs/assets
    python capture.py --project-root . --mocks-dir mocks --out-dir specs/assets --only S001_login

終了コード:
    0 = 全件成功（対象 0 件も成功扱い）
    1 = 1 件以上失敗
    2 = 引数エラー・封じ込め違反・Playwright / Chromium 未導入
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# エンコーディング必須設定（Windows の既定 CP932 による文字化け・例外を防ぐ）
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

# full_page 撮影の高さ上限。巨大な height を持つモックでメモリとディスクを
# 食い潰さないためのクランプ。
MAX_FULL_PAGE_HEIGHT = 20000


def positive_int(value: str) -> int:
    try:
        parsed = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"整数で指定してください: {value}") from exc
    if parsed <= 0 or parsed > 10000:
        raise argparse.ArgumentTypeError(f"1〜10000 の範囲で指定してください: {value}")
    return parsed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="モック HTML のスクリーンショットを生成する"
    )
    parser.add_argument(
        "--project-root",
        required=True,
        help="プロジェクトルート。入出力はこの配下に限定される",
    )
    parser.add_argument(
        "--mocks-dir", required=True, help="モック HTML のあるディレクトリ"
    )
    parser.add_argument("--out-dir", required=True, help="PNG の出力先ディレクトリ")
    parser.add_argument(
        "--only",
        action="append",
        default=None,
        help="対象を限定する（拡張子なしのファイル名。複数指定可）",
    )
    parser.add_argument("--width", type=positive_int, default=1280, help="ビューポート幅")
    parser.add_argument("--height", type=positive_int, default=800, help="ビューポート高さ")
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
    parser.add_argument(
        "--settle-ms",
        type=int,
        default=200,
        help="描画安定のための待機ミリ秒（既定 200）",
    )
    parser.add_argument(
        "--timeout-ms",
        type=int,
        default=10000,
        help="1 ページあたりの読み込みタイムアウト（既定 10000）",
    )
    return parser.parse_args()


def resolve_inside(root: Path, target: str, label: str) -> Path:
    """target を解決し、root 配下にあることを保証する。"""
    path = (root / target).resolve() if not Path(target).is_absolute() else Path(target).resolve()
    try:
        path.relative_to(root)
    except ValueError:
        raise SystemExit(
            f"エラー: {label} がプロジェクトルートの外を指しています。\n"
            f"  project-root: {root}\n"
            f"  {label}: {path}"
        )
    return path


def collect_targets(
    mocks_dir: Path, only: list[str] | None, skip_partials: bool
) -> tuple[list[Path], list[str]]:
    """対象 HTML と、--only で指定されたが見つからなかった名前を返す。"""
    available = sorted(mocks_dir.glob("*.html"))
    if skip_partials:
        available = [p for p in available if not p.name.startswith("_")]
    if not only:
        return available, []

    wanted = {name[:-5] if name.endswith(".html") else name for name in only}
    found = [p for p in available if p.stem in wanted]
    missing = sorted(wanted - {p.stem for p in found})
    return found, missing


def main() -> int:
    args = parse_args()

    root = Path(args.project_root).resolve()
    if not root.is_dir():
        print(f"エラー: project-root が見つかりません: {root}", file=sys.stderr)
        return 2

    mocks_dir = resolve_inside(root, args.mocks_dir, "mocks-dir")
    out_dir = resolve_inside(root, args.out_dir, "out-dir")

    if not mocks_dir.is_dir():
        print(f"エラー: モックディレクトリが見つかりません: {mocks_dir}", file=sys.stderr)
        return 2

    targets, missing = collect_targets(mocks_dir, args.only, args.skip_partials)

    if missing:
        # --only で明示指定したのに見つからないのは、画面 ID の誤りか
        # モックの削除・改名。黙って 0 件成功にすると、古い画像参照のまま
        # 設計書が更新されるため、明示的に知らせる。
        print(
            "エラー: 指定された画面に対応するモックが見つかりません: "
            + ", ".join(missing),
            file=sys.stderr,
        )
        return 2

    if not targets:
        # 撮るものが無いなら Playwright は要らない。pending が空のまま
        # design-push が呼ばれるケースで、venv 未構築でも正常終了させる。
        print("対象のモック HTML はありません。")
        return 0

    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print(
            "エラー: playwright が未導入です。"
            "setup_venv.sh を実行して venv を構築してください。",
            file=sys.stderr,
        )
        return 2

    out_dir.mkdir(parents=True, exist_ok=True)

    failed: list[str] = []
    with sync_playwright() as playwright:
        try:
            browser = playwright.chromium.launch()
        except Exception as exc:  # noqa: BLE001 - 未導入と起動失敗をまとめて案内する
            print(
                "エラー: Chromium を起動できません。"
                "`python -m playwright install chromium` を実行してください。\n"
                f"  詳細: {exc.__class__.__name__}: {exc}",
                file=sys.stderr,
            )
            return 2

        try:
            # offline=True でネットワーク送信を遮断する。モック HTML は
            # 信頼できない出所のものが混ざりうるため、外部へのビーコンや
            # 社内サービスへの到達を防ぐ。file:// の読み込みは影響を受けない。
            context = browser.new_context(
                viewport={"width": args.width, "height": args.height},
                offline=True,
            )
            context.set_default_timeout(args.timeout_ms)
            page = context.new_page()
            for html_path in targets:
                png_path = out_dir / f"{html_path.stem}.png"
                try:
                    page.goto(
                        html_path.as_uri(),
                        wait_until="load",
                        timeout=args.timeout_ms,
                    )
                    if args.settle_ms > 0:
                        page.wait_for_timeout(args.settle_ms)

                    full_page = not args.no_full_page
                    if full_page:
                        doc_height = page.evaluate(
                            "document.documentElement.scrollHeight"
                        )
                        if isinstance(doc_height, (int, float)) and doc_height > MAX_FULL_PAGE_HEIGHT:
                            page.screenshot(
                                path=str(png_path),
                                clip={
                                    "x": 0,
                                    "y": 0,
                                    "width": args.width,
                                    "height": MAX_FULL_PAGE_HEIGHT,
                                },
                            )
                            print(
                                f"生成: {png_path.name} <- {html_path.name} "
                                f"（高さ {int(doc_height)}px を {MAX_FULL_PAGE_HEIGHT}px で切り詰め）"
                            )
                            continue
                    page.screenshot(path=str(png_path), full_page=full_page)
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
