#!/usr/bin/env python3
"""モック HTML のスクリーンショットを生成する。

design-bridge の design-push から呼び出される。Playwright (chromium) で
ローカルの HTML を開き、PNG として出力する。

安全性:
    モック HTML は design-pull 経由で他の利用者が書いたものが入りうる。
    `.claude/design-bridge.json` もリポジトリ同梱＝第三者が支配しうる入力。
    そのため次の多層の制限を置く。

    1. `--project-root` を必須とし、`--mocks-dir` / `--out-dir` がその配下に
       あることを検証する（ディレクトリ粒度）
    2. 対象 HTML の実体（symlink 解決後）も root 配下にあることを検証する
       （ファイル粒度）。これが無いと `mocks/leak.html -> ~/.ssh/id_rsa` の
       ような symlink で任意ファイルを画像化できる
    3. JavaScript を無効化する。静的なモックの撮影に JS は不要で、
       `location.href='file:///etc/passwd'` のような遷移を防げる
    4. `--mocks-dir` 配下以外へのリクエストを全て中断する。iframe や img に
       よる他ファイルの読み出し、外部へのビーコン送信、SSRF を防ぐ
    5. オフラインコンテキストで描画する（4 の多重化）

使用例:
    python capture.py --project-root . --mocks-dir mocks --out-dir specs/assets
    python capture.py --project-root . --mocks-dir mocks --out-dir specs/assets --only S001_login

終了コード:
    0 = 全件成功（対象 0 件も成功扱い）
    1 = 1 件以上の撮影に失敗
    2 = 引数エラー・封じ込め違反・Playwright / Chromium 未導入・--only の空振り
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

EXIT_OK = 0
EXIT_PARTIAL_FAILURE = 1
EXIT_ABORT = 2


class ContainmentError(Exception):
    """入出力パスがプロジェクトルートの外を指している。"""


def bounded_int(low: int, high: int):
    def _parse(value: str) -> int:
        try:
            parsed = int(value)
        except ValueError as exc:
            raise argparse.ArgumentTypeError(f"整数で指定してください: {value}") from exc
        if parsed < low or parsed > high:
            raise argparse.ArgumentTypeError(
                f"{low}〜{high} の範囲で指定してください: {value}"
            )
        return parsed

    return _parse


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
    parser.add_argument(
        "--width", type=bounded_int(1, 10000), default=1280, help="ビューポート幅"
    )
    parser.add_argument(
        "--height", type=bounded_int(1, 10000), default=800, help="ビューポート高さ"
    )
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
        type=bounded_int(0, 10000),
        default=200,
        help="描画安定のための待機ミリ秒（既定 200）",
    )
    parser.add_argument(
        "--timeout-ms",
        type=bounded_int(1000, 60000),
        default=10000,
        help="1 ページあたりの読み込みタイムアウト（既定 10000）",
    )
    return parser.parse_args()


def resolve_inside(root: Path, target: str, label: str) -> Path:
    """target を解決し、root 配下にあることを保証する。"""
    candidate = Path(target)
    path = candidate.resolve() if candidate.is_absolute() else (root / candidate).resolve()
    try:
        path.relative_to(root)
    except ValueError:
        raise ContainmentError(
            f"{label} がプロジェクトルートの外を指しています。\n"
            f"  project-root: {root}\n"
            f"  {label}: {path}"
        )
    return path


def is_inside(root: Path, path: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def collect_targets(
    root: Path, mocks_dir: Path, only: list[str] | None, skip_partials: bool
) -> tuple[list[Path], list[str], list[str]]:
    """対象 HTML、--only の未一致名、root 外を指すため除外した名前を返す。"""
    available = sorted(mocks_dir.glob("*.html"))
    if skip_partials:
        available = [p for p in available if not p.name.startswith("_")]

    # symlink 等で実体が root の外にあるものを落とす。ディレクトリ単位の
    # 検証だけでは、mocks/ 内に置かれた外部へのリンクを防げない。
    inside: list[Path] = []
    escaped: list[str] = []
    for p in available:
        try:
            real = p.resolve()
        except OSError:
            escaped.append(p.name)
            continue
        if is_inside(root, real):
            inside.append(p)
        else:
            escaped.append(p.name)

    if not only:
        return inside, [], escaped

    wanted = {name[:-5] if name.endswith(".html") else name for name in only}
    found = [p for p in inside if p.stem in wanted]
    missing = sorted(wanted - {p.stem for p in found})
    return found, missing, escaped


def read_png_height(path: Path) -> int | None:
    """PNG の IHDR から高さを読む（撮影結果の検証用）。"""
    try:
        with open(path, "rb") as f:
            head = f.read(24)
    except OSError:
        return None
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return int.from_bytes(head[20:24], "big")


def main() -> int:
    args = parse_args()

    root = Path(args.project_root).resolve()
    if not root.is_dir():
        print(f"エラー: project-root が見つかりません: {root}", file=sys.stderr)
        return EXIT_ABORT

    # root が広すぎる指定（/ など）だと封じ込めが意味を失う。design-bridge の
    # プロジェクトであることを要求して下限を設ける。
    if not (root / ".claude" / "design-bridge.json").is_file():
        print(
            "エラー: project-root が design-bridge のプロジェクトではありません"
            "（.claude/design-bridge.json が見つかりません）: "
            f"{root}",
            file=sys.stderr,
        )
        return EXIT_ABORT

    try:
        mocks_dir = resolve_inside(root, args.mocks_dir, "mocks-dir")
        out_dir = resolve_inside(root, args.out_dir, "out-dir")
    except ContainmentError as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        return EXIT_ABORT

    if not mocks_dir.is_dir():
        print(f"エラー: モックディレクトリが見つかりません: {mocks_dir}", file=sys.stderr)
        return EXIT_ABORT

    targets, missing, escaped = collect_targets(
        root, mocks_dir, args.only, args.skip_partials
    )

    if escaped:
        print(
            "警告: 実体がプロジェクト外を指すため対象から除外しました: "
            + ", ".join(escaped),
            file=sys.stderr,
        )

    if missing:
        # --only で明示指定したのに見つからないのは、画面 ID の誤りか
        # モックの削除・改名。黙って 0 件成功にすると、古い画像参照のまま
        # 設計書が更新されるため、明示的に知らせる。
        print(
            "エラー: 指定された画面に対応するモックが見つかりません: "
            + ", ".join(missing),
            file=sys.stderr,
        )
        return EXIT_ABORT

    if not targets:
        # 撮るものが無いなら Playwright は要らない。pending が空のまま
        # design-push が呼ばれるケースで、venv 未構築でも正常終了させる。
        print("対象のモック HTML はありません。")
        return EXIT_OK

    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print(
            "エラー: playwright が未導入です。"
            "setup_venv.sh を実行して venv を構築してください。",
            file=sys.stderr,
        )
        return EXIT_ABORT

    out_dir.mkdir(parents=True, exist_ok=True)
    allowed_prefix = mocks_dir.as_uri()
    full_page = not args.no_full_page

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
            return EXIT_ABORT

        try:
            try:
                context = browser.new_context(
                    viewport={"width": args.width, "height": args.height},
                    offline=True,
                    java_script_enabled=False,
                )
                context.set_default_timeout(args.timeout_ms)

                def _guard(route):
                    # モックディレクトリ配下以外は全て遮断する。
                    if route.request.url.startswith(allowed_prefix):
                        route.continue_()
                    else:
                        route.abort()

                context.route("**/*", _guard)
                page = context.new_page()
            except Exception as exc:  # noqa: BLE001
                print(
                    "エラー: ブラウザコンテキストを初期化できません。\n"
                    f"  詳細: {exc.__class__.__name__}: {exc}",
                    file=sys.stderr,
                )
                return EXIT_ABORT

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

                    page.screenshot(path=str(png_path), full_page=full_page)

                    if full_page:
                        height = read_png_height(png_path)
                        if height is not None and height > MAX_FULL_PAGE_HEIGHT:
                            # clip だけでは full_page 扱いにならずビューポート内に
                            # 制限されるため、full_page と併せて指定する。
                            page.screenshot(
                                path=str(png_path),
                                full_page=True,
                                clip={
                                    "x": 0,
                                    "y": 0,
                                    "width": args.width,
                                    "height": MAX_FULL_PAGE_HEIGHT,
                                },
                            )
                            print(
                                f"生成: {png_path.name} <- {html_path.name} "
                                f"（高さ {height}px を {MAX_FULL_PAGE_HEIGHT}px で切り詰め）"
                            )
                            continue
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
        return EXIT_PARTIAL_FAILURE
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
