#!/usr/bin/env python3
"""convert_from_pptx.py - PPTX を Markdown に変換するスクリプト.

使い方:
    python convert_from_pptx.py <入力PPTX> [<出力MD>] [--images-dir DIR]
                                [--no-mermaid] [--include-notes]
                                [--include-hidden] [--no-first-slide-as-title]
                                [--max-image-size BYTES]
"""

from __future__ import annotations

import argparse
import re
import sys
import zipfile
from pathlib import Path
from typing import Iterable, List, Optional

try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

try:
    from pptx import Presentation
    from pptx.enum.shapes import MSO_SHAPE_TYPE
except ImportError as exc:
    print(f"Error: python-pptx is not installed: {exc}", file=sys.stderr)
    sys.exit(2)

try:
    from lxml import etree
except ImportError as exc:
    print(f"Error: lxml is not installed: {exc}", file=sys.stderr)
    sys.exit(2)


# ----------------------------------------------------------------------------- #
# 定数
# ----------------------------------------------------------------------------- #

MONOSPACE_FONTS = {
    "Consolas",
    "Courier",
    "Courier New",
    "Menlo",
    "Monaco",
    "Cascadia Code",
    "Cascadia Mono",
    "Fira Code",
    "Source Code Pro",
    "Lucida Console",
    "MS Gothic",
    "ＭＳ ゴシック",
    "MS Mincho",
    "ＭＳ 明朝",
}

PPTX_MAGIC = b"PK\x03\x04"
DEFAULT_MAX_IMAGE_BYTES = 5 * 1024 * 1024  # 5 MiB
MAX_TOTAL_UNCOMPRESSED_BYTES = 256 * 1024 * 1024  # 256 MiB (ZIP bomb 防御)
MAX_COMPRESSION_RATIO = 200  # compress_size に対する展開サイズ倍率上限

ALLOWED_IMAGE_EXTS = {"png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "emf", "wmf"}

NS_A = "http://schemas.openxmlformats.org/drawingml/2006/main"
NS_DGM = "http://schemas.openxmlformats.org/drawingml/2006/diagram"
NS_R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS_P = "http://schemas.openxmlformats.org/presentationml/2006/main"


def _hardened_xml_parser() -> "etree.XMLParser":
    """XXE / DTD / 巨大ツリー攻撃を遮断した lxml パーサを返す."""
    return etree.XMLParser(
        resolve_entities=False,
        no_network=True,
        load_dtd=False,
        huge_tree=False,
    )


# ----------------------------------------------------------------------------- #
# ユーティリティ
# ----------------------------------------------------------------------------- #


def _safe_text(value: Optional[str]) -> str:
    if not value:
        return ""
    return value.replace("\r", "").strip()


def _escape_md_pipe(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", "<br>")


def _is_monospace_font(font_name: Optional[str]) -> bool:
    if not font_name:
        return False
    return font_name in MONOSPACE_FONTS


def _mermaid_escape_label(text: str) -> str:
    text = (text or "").replace('"', "'")
    # 改行は <br/> として Mermaid に描画させたいので、HTML エスケープ後に復元する
    SENTINEL = "\x00BR\x00"
    text = text.replace("\n", SENTINEL)
    # Mermaid のメタ文字をエスケープ（後段 HTML 化時の XSS 対策含む）
    text = text.replace("<", "&lt;").replace(">", "&gt;")
    text = text.replace(SENTINEL, "<br/>")
    if len(text) > 80:
        text = text[:77] + "..."
    return text or " "


def _escape_md_link_text(text: str) -> str:
    """Markdown のリンクテキスト・alt 部分のメタ文字をエスケープ."""
    return (
        (text or "")
        .replace("\\", "\\\\")
        .replace("[", "\\[")
        .replace("]", "\\]")
        .replace("(", "\\(")
        .replace(")", "\\)")
        .replace("\n", " ")
    )


def _validate_pptx(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Input file not found: {path}")
    if path.suffix.lower() not in (".pptx", ".pptm"):
        raise ValueError(f"Input file is not PPTX/PPTM (extension): {path}")
    with open(path, "rb") as fh:
        magic = fh.read(4)
    if magic != PPTX_MAGIC:
        raise ValueError(f"Input file is not a valid PPTX (zip magic): {path}")
    try:
        with zipfile.ZipFile(path, "r") as zf:
            # ZIP bomb 検査: 総展開サイズ・圧縮率
            total_uncompressed = 0
            for info in zf.infolist():
                total_uncompressed += info.file_size
                if total_uncompressed > MAX_TOTAL_UNCOMPRESSED_BYTES:
                    raise ValueError(
                        f"Input PPTX exceeds uncompressed size limit "
                        f"({total_uncompressed} > {MAX_TOTAL_UNCOMPRESSED_BYTES}): {path}"
                    )
                if info.compress_size > 0:
                    ratio = info.file_size / info.compress_size
                    if ratio > MAX_COMPRESSION_RATIO:
                        raise ValueError(
                            f"Suspicious compression ratio ({ratio:.1f}x) "
                            f"for entry '{info.filename}' in {path}"
                        )
            content_types = zf.read("[Content_Types].xml").decode("utf-8", errors="ignore")
    except KeyError as exc:
        raise ValueError(f"Input file missing [Content_Types].xml: {path}") from exc
    if "presentationml" not in content_types.lower():
        raise ValueError(f"Input file is not a PresentationML document: {path}")


def _resolve_images_dir(output_md: Path, images_dir_opt: Optional[str]) -> Path:
    base = output_md.parent.resolve()
    if images_dir_opt:
        candidate = Path(images_dir_opt)
        if not candidate.is_absolute():
            candidate = output_md.parent / candidate
        candidate = candidate.resolve()
        try:
            candidate.relative_to(base)
        except ValueError as exc:
            raise ValueError(
                f"images-dir must be under output MD directory (path traversal blocked): {candidate}"
            ) from exc
        return candidate
    return (base / f"{output_md.stem}_images").resolve()


# ----------------------------------------------------------------------------- #
# Mermaid 生成（コネクタ駆動）
# ----------------------------------------------------------------------------- #


class FlowExtractor:
    """同一スライド内の図形群とコネクタからフロー図 Mermaid を生成する."""

    def __init__(self, shapes_meta: List[dict], connectors: List[dict]):
        self.shapes_meta = shapes_meta
        self.connectors = connectors
        self.used_node_ids: set = set()

    def build_mermaid(self) -> Optional[str]:
        self.used_node_ids = set()
        if not self.connectors or len(self.shapes_meta) < 2:
            return None
        id_to_label = {
            meta["shape_id"]: (meta["text"] or meta["name"] or f"shape{meta['shape_id']}")
            for meta in self.shapes_meta
        }
        edges = []
        for connector in self.connectors:
            begin = connector.get("begin")
            end = connector.get("end")
            if begin is None or end is None:
                continue
            if begin not in id_to_label or end not in id_to_label:
                continue
            edges.append((begin, end))
            self.used_node_ids.add(begin)
            self.used_node_ids.add(end)
        if not edges:
            return None
        direction = self._infer_direction()
        lines = [f"flowchart {direction}"]
        for nid in sorted(self.used_node_ids):
            meta = next((m for m in self.shapes_meta if m["shape_id"] == nid), None)
            label = _mermaid_escape_label(id_to_label.get(nid, f"shape{nid}"))
            open_b, close_b = self._bracket_for_shape(meta)
            lines.append(f'    N{nid}{open_b}"{label}"{close_b}')
        for src, dst in edges:
            lines.append(f"    N{src} --> N{dst}")
        return "\n".join(lines)

    def _infer_direction(self) -> str:
        xs = [m["left"] for m in self.shapes_meta if m.get("left") is not None]
        ys = [m["top"] for m in self.shapes_meta if m.get("top") is not None]
        if not xs or not ys:
            return "TD"
        x_range = max(xs) - min(xs)
        y_range = max(ys) - min(ys)
        if x_range > y_range * 1.5:
            return "LR"
        return "TD"

    @staticmethod
    def _bracket_for_shape(meta: Optional[dict]) -> tuple:
        if not meta:
            return ("[", "]")
        auto = (meta.get("auto_shape_type") or "").upper()
        if "OVAL" in auto or "ELLIPSE" in auto or "FLOWCHART_TERMINATOR" in auto:
            return ("((", "))")
        if "DIAMOND" in auto or "FLOWCHART_DECISION" in auto:
            return ("{", "}")
        if "PARALLELOGRAM" in auto or "FLOWCHART_DATA" in auto:
            return ("[/", "/]")
        return ("[", "]")


# ----------------------------------------------------------------------------- #
# 変換本体
# ----------------------------------------------------------------------------- #


class PPTXMarkdownConverter:
    """python-pptx で読んだプレゼンを Markdown に転記する."""

    def __init__(self, args: argparse.Namespace) -> None:
        self.input_path = Path(args.input).resolve()
        self.output_path = (
            Path(args.output).resolve() if args.output else self.input_path.with_suffix(".md")
        )
        self.images_dir = _resolve_images_dir(self.output_path, args.images_dir)
        self.no_mermaid = bool(args.no_mermaid)
        self.include_notes = bool(args.include_notes)
        self.include_hidden = bool(args.include_hidden)
        self.first_slide_as_title = not bool(args.no_first_slide_as_title)
        self.max_image_bytes = int(args.max_image_size)
        self._image_seq: dict[int, int] = {}
        self._template_texts: set[str] = set()
        self._current_title_shape_id: Optional[int] = None
        self._current_is_section_cover: bool = False
        self._current_repeated_texts: set[str] = set()
        self._slide_width_emu: Optional[int] = None
        self._slide_height_emu: Optional[int] = None
        self._current_max_font_pt: Optional[float] = None
        self._current_median_font_pt: Optional[float] = None
        self._current_decoration_shape_ids: set[int] = set()

    # ---------- エントリ ----------

    def convert(self) -> Path:
        _validate_pptx(self.input_path)
        presentation = Presentation(str(self.input_path))
        self.images_dir.mkdir(parents=True, exist_ok=True)

        self._template_texts = self._collect_template_texts(presentation)
        try:
            self._slide_width_emu = presentation.slide_width
            self._slide_height_emu = presentation.slide_height
        except Exception:
            self._slide_width_emu = None
            self._slide_height_emu = None

        markdown_chunks: List[str] = []
        emitted_slide_no = 0
        for slide in presentation.slides:
            if self._is_hidden(slide) and not self.include_hidden:
                continue
            emitted_slide_no += 1
            chunk = self._convert_slide(slide, emitted_slide_no)
            if chunk:
                markdown_chunks.append(chunk)

        self.output_path.parent.mkdir(parents=True, exist_ok=True)
        body = "\n\n".join(markdown_chunks)
        if not body.endswith("\n"):
            body += "\n"
        with open(self.output_path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(body)
        return self.output_path

    # ---------- スライド単位 ----------

    @staticmethod
    def _is_hidden(slide) -> bool:
        try:
            return slide.element.get("show") == "0"
        except Exception:
            return False

    def _convert_slide(self, slide, slide_no: int) -> str:
        # スライド単位のフォント・装飾統計を事前計算（視覚的役割推定の基礎データ）
        self._current_is_section_cover = self._is_section_cover_layout(slide)
        self._compute_slide_visual_stats(slide)

        title, title_shape_id = self._extract_title(slide)
        self._current_title_shape_id = title_shape_id
        # スライド内で同一テキストが複数回出現する shape を装飾とみなす集合
        self._current_repeated_texts = self._collect_repeated_slide_texts(slide)
        if slide_no == 1 and self.first_slide_as_title:
            heading = f"# {title or 'タイトル'}"
        else:
            heading = f"## {title or f'スライド{slide_no}'}"

        shapes_meta: List[dict] = []
        connectors: List[dict] = []
        collected: List[dict] = []  # 各要素 {"kind": str, "shape_id": Optional[int], "text": str}

        for shape in slide.shapes:
            self._collect_shape(shape, slide_no, shapes_meta, connectors, collected)

        mermaid_md: Optional[str] = None
        used_ids: set = set()
        if not self.no_mermaid:
            extractor = FlowExtractor(shapes_meta, connectors)
            mermaid_md = extractor.build_mermaid()
            used_ids = extractor.used_node_ids

        # 視覚順 (top → left) でコンテンツブロックを並べ替える。
        # PPTX 内部の Z 順序ではなく、読者が画面で目で追う順序に近づける。
        collected.sort(key=lambda it: (it.get("top") or 0, it.get("left") or 0))

        # Mermaid 化されたノードのテキストは本文側で除外（行マージ前に行うこと）
        title_text_norm = (title or "").strip()
        filtered: List[dict] = []
        for item in collected:
            if (
                item["kind"] == "text"
                and item.get("shape_id") is not None
                and item["shape_id"] in used_ids
            ):
                continue
            if title_text_norm and item["kind"] == "text":
                stripped = (item.get("text") or "").lstrip("- ").strip()
                if stripped == title_text_norm:
                    continue
            filtered.append(item)

        # 同一行 (top の差が小さい) の連続する text 要素は左→右で結合する。
        # PowerPoint で「番号 + 章名」のように水平に並ぶ shape を 1 行として扱う。
        filtered = self._merge_horizontal_text_rows(filtered)

        body_blocks: List[str] = []
        for item in filtered:
            text_block = item.get("text") or ""
            if not text_block:
                continue
            body_blocks.append(text_block)

        if mermaid_md:
            body_blocks.append(f"```mermaid\n{mermaid_md}\n```")

        if self.include_notes:
            notes = self._extract_notes(slide)
            if notes:
                body_blocks.append(notes)

        # タイトルも本文も空ならスライド見出しごと出力を抑制（テンプレ装飾のみで本体が無いスライド）
        if not title and not any(b.strip() for b in body_blocks):
            return ""

        parts = [heading] + [b for b in body_blocks if b]
        return "\n\n".join(parts)

    def _extract_title(self, slide) -> tuple:
        """タイトル文字列とその shape_id を返す。

        優先順位:
        1. slide.shapes.title （CENTER_TITLE / TITLE placeholder）
        2. スライド最上部の短文 placeholder / textbox（テキストボックスで描画されたタイトル対応）
        """
        try:
            title_shape = slide.shapes.title
            if (
                title_shape is not None
                and getattr(title_shape, "has_text_frame", False)
                and title_shape.has_text_frame
                and title_shape.text_frame.text.strip()
            ):
                return _safe_text(title_shape.text_frame.text), title_shape.shape_id
        except Exception:
            pass

        candidate = self._guess_title_shape(slide)
        if candidate is not None:
            return _safe_text(candidate.text_frame.text), candidate.shape_id

        return None, None

    def _guess_title_shape(self, slide):
        """slide.shapes.title 不在時の代替: 視覚的に最上部にあるタイトルらしい shape を推定.

        条件 (いずれかを満たす shape を候補化):
            A. スライド上端 (top <= 1.6cm) かつ薄い帯 (height <= 1.4cm) かつ短文 (<= 80字)
            B. スライド中央上部 (top <= 50%) かつ最大フォントサイズに近い (>=80%)
               フォント・短文（章扉スライド：中央に大きな章タイトル）
        どちらも、テンプレ装飾 / 装飾 shape は除外する。
        """
        TOP_THRESHOLD_EMU = 1_500_000
        HEIGHT_THRESHOLD_EMU = 1_400_000
        MAX_TITLE_LEN = 80

        slide_h = self._slide_height_emu or 0
        max_font = self._current_max_font_pt
        candidates = []  # (priority, top, left, shape)

        for shape in slide.shapes:
            if not (getattr(shape, "has_text_frame", False) and shape.has_text_frame):
                continue
            if self._is_template_placeholder(shape):
                continue
            try:
                shape_id = shape.shape_id
            except Exception:
                shape_id = None
            if shape_id is not None and shape_id in self._current_decoration_shape_ids:
                continue
            try:
                top = shape.top or 0
                left = shape.left or 0
                height = shape.height or 0
            except Exception:
                continue
            text = _safe_text(shape.text_frame.text)
            if not text or len(text) > MAX_TITLE_LEN:
                continue
            if text in self._template_texts:
                continue

            font_pt = self._extract_max_font_size_pt(shape)

            # A: 最上部・薄い帯・短文
            if top <= TOP_THRESHOLD_EMU and height <= HEIGHT_THRESHOLD_EMU:
                candidates.append((1, top, left, shape))
                continue

            # B: スライド上半分かつ最大フォントに近い大型テキスト（章扉中央タイトル等）
            if max_font and font_pt and font_pt >= max_font * 0.8 and slide_h and top <= slide_h * 0.5:
                candidates.append((2, top, left, shape))
                continue

        if not candidates:
            return None
        candidates.sort(key=lambda x: (x[0], x[1], x[2]))
        return candidates[0][3]

    @staticmethod
    def _collect_template_texts(presentation) -> set:
        """テンプレ装飾として除外するテキスト集合を構築する。

        収集対象:
            1. スライドマスタ / レイアウトに登場するテキスト
            2. 全スライドの 3 スライド以上に同テキストで出現する ASCII 短文
               (例: "Core Colors" / "Sub Colors" 等の凡例ラベル) のみ。
               日本語本文ワードや混合テキストは誤除外回避のため対象外。
        """
        texts: set = set()

        def _gather(container):
            try:
                shapes = container.shapes
            except Exception:
                return
            for shape in shapes:
                try:
                    if getattr(shape, "has_text_frame", False) and shape.has_text_frame:
                        t = _safe_text(shape.text_frame.text)
                        if t:
                            texts.add(t)
                except Exception:
                    continue

        try:
            for master in presentation.slide_masters:
                _gather(master)
                try:
                    for layout in master.slide_layouts:
                        _gather(layout)
                except Exception:
                    continue
        except Exception:
            return texts

        # ASCII 短文 (英数字 + 空白) の全スライド頻出パターンを凡例ラベルとして検出
        try:
            slides = list(presentation.slides)
        except Exception:
            return texts
        if len(slides) < 3:
            return texts

        def _iter_text_shapes(shape_iter):
            for shape in shape_iter:
                try:
                    if shape.shape_type == MSO_SHAPE_TYPE.GROUP:
                        yield from _iter_text_shapes(shape.shapes)
                        continue
                except Exception:
                    pass
                try:
                    if getattr(shape, "has_text_frame", False) and shape.has_text_frame:
                        yield shape
                except Exception:
                    continue

        appearance: dict = {}
        for slide in slides:
            seen: set = set()
            try:
                for shape in _iter_text_shapes(slide.shapes):
                    t = _safe_text(shape.text_frame.text)
                    if not t or len(t) > 25:
                        continue
                    # ASCII 範囲のみ（半角英数字 + 記号 + 空白）に限定
                    if not all((ord(c) < 128) for c in t):
                        continue
                    # 数字のみは章番号と紛らわしいので対象外
                    if t.isdigit():
                        continue
                    seen.add(t)
            except Exception:
                continue
            for t in seen:
                appearance[t] = appearance.get(t, 0) + 1

        # 3 スライド以上で出現する ASCII 短文を装飾ラベルとみなす
        for t, cnt in appearance.items():
            if cnt >= 3:
                texts.add(t)
        return texts

    @staticmethod
    def _is_template_placeholder(shape) -> bool:
        """FOOTER / SLIDE_NUMBER / DATE プレースホルダ判定。"""
        try:
            ph = shape.placeholder_format
            if ph is None:
                return False
            ph_type = ph.type
            if ph_type is None:
                return False
            type_str = str(ph_type)
            return any(kw in type_str for kw in ("FOOTER", "SLIDE_NUMBER", "DATE"))
        except Exception:
            return False

    def _matches_template_text(self, shape) -> bool:
        """マスタ/レイアウトに同一テキストで存在する shape を装飾扱いにする。"""
        if not self._template_texts:
            return False
        try:
            if not (getattr(shape, "has_text_frame", False) and shape.has_text_frame):
                return False
            text = _safe_text(shape.text_frame.text)
            if not text:
                return False
            return text in self._template_texts
        except Exception:
            return False

    def _compute_slide_visual_stats(self, slide) -> None:
        """スライド内全 shape の最大/中央値フォントサイズと装飾候補 shape を識別する。

        - 装飾候補: 薄いグレー色 / 極小フォント (中央値の 70% 未満) /
          スライド端 (右下) の極小 shape / 全 shape が小さい場合は除外。
        - decoration_shape_ids を集合に格納し、後段の _collect_shape で参照する。
        """
        self._current_max_font_pt = None
        self._current_median_font_pt = None
        self._current_decoration_shape_ids = set()

        # スライド寸法（基準）
        slide_w = self._slide_width_emu or 0
        slide_h = self._slide_height_emu or 0

        shapes_metrics: List[dict] = []
        try:
            self._gather_metrics_recursive(slide.shapes, shapes_metrics)
        except Exception:
            return

        font_sizes = [m["font_size_pt"] for m in shapes_metrics if m.get("font_size_pt")]
        if font_sizes:
            self._current_max_font_pt = max(font_sizes)
            sorted_sizes = sorted(font_sizes)
            mid = len(sorted_sizes) // 2
            if len(sorted_sizes) % 2 == 0 and len(sorted_sizes) >= 2:
                self._current_median_font_pt = (sorted_sizes[mid - 1] + sorted_sizes[mid]) / 2
            else:
                self._current_median_font_pt = sorted_sizes[mid]

        # 装飾判定
        median = self._current_median_font_pt
        for meta in shapes_metrics:
            shape_id = meta["shape_id"]
            text = (meta.get("text") or "").strip()
            if not text:
                continue
            font_pt = meta.get("font_size_pt")
            is_gray = meta.get("is_grayish", False)
            char_count = meta.get("char_count", 0)
            top = meta.get("top") or 0
            left = meta.get("left") or 0
            width = meta.get("width") or 0
            height = meta.get("height") or 0

            decoration_reasons = 0

            # 1) 極小フォント（スライド中央値の 70% 未満）かつ短文
            if font_pt is not None and median is not None and font_pt < median * 0.7 and char_count <= 30:
                decoration_reasons += 1

            # 2) フォント色が薄いグレー系
            if is_gray:
                decoration_reasons += 1

            # 3) shape が極端に小さい (面積がスライドの 0.3% 未満) かつ短文
            if slide_w and slide_h:
                area = (width or 0) * (height or 0)
                slide_area = slide_w * slide_h
                if slide_area > 0 and area > 0 and (area / slide_area) < 0.003 and char_count <= 20:
                    decoration_reasons += 1

            # 4) 右下の端 (top > 75%, left > 75%) に位置する短文
            if slide_w and slide_h and (top / slide_h) > 0.75 and (left / slide_w) > 0.55 and char_count <= 25:
                decoration_reasons += 1

            if decoration_reasons >= 2:
                self._current_decoration_shape_ids.add(shape_id)

    def _gather_metrics_recursive(self, shape_iter, out: list) -> None:
        """グループを再帰展開しながら全 shape のメタデータを集める."""
        for shape in shape_iter:
            try:
                if shape.shape_type == MSO_SHAPE_TYPE.GROUP:
                    self._gather_metrics_recursive(shape.shapes, out)
                    continue
            except Exception:
                pass
            try:
                if getattr(shape, "has_text_frame", False) and shape.has_text_frame:
                    out.append(self._shape_meta(shape))
            except Exception:
                continue

    @staticmethod
    def _is_section_cover_layout(slide) -> bool:
        """章扉スライド (innerCoverA / cover 系レイアウト) を判定."""
        try:
            name = (slide.slide_layout.name or "").lower()
        except Exception:
            return False
        if not name:
            return False
        return any(kw in name for kw in ("innercover", "cover", "section", "chapter", "扉"))

    @staticmethod
    def _is_decoration_number(shape) -> bool:
        """純数字 (1〜3 桁) のテキスト shape を装飾的章番号と判定."""
        try:
            if not (getattr(shape, "has_text_frame", False) and shape.has_text_frame):
                return False
            text = _safe_text(shape.text_frame.text)
        except Exception:
            return False
        if not text:
            return False
        return text.isdigit() and 1 <= len(text) <= 3

    @staticmethod
    def _collect_repeated_slide_texts(slide) -> set:
        """同一スライド内で 2 回以上出現する短いテキスト (<= 30 文字) を集める."""
        counts: dict = {}
        try:
            shapes = list(slide.shapes)
        except Exception:
            return set()

        def _walk(shape_iter):
            for shape in shape_iter:
                try:
                    if shape.shape_type == MSO_SHAPE_TYPE.GROUP:
                        _walk(shape.shapes)
                        continue
                except Exception:
                    pass
                try:
                    if getattr(shape, "has_text_frame", False) and shape.has_text_frame:
                        text = _safe_text(shape.text_frame.text)
                        if text and len(text) <= 30:
                            counts[text] = counts.get(text, 0) + 1
                except Exception:
                    continue

        _walk(shapes)
        # 凡例ラベル等の装飾は同一スライド内で 3 回以上繰り返される傾向にある。
        # 2 回出現の場合は組織図のように内容として意図的な重複の可能性が高いため対象外。
        return {t for t, c in counts.items() if c >= 3}

    def _matches_repeated_slide_text(self, shape) -> bool:
        """同一スライド内に重複出現するテキスト shape を装飾扱いにする."""
        repeated = getattr(self, "_current_repeated_texts", None)
        if not repeated:
            return False
        try:
            if not (getattr(shape, "has_text_frame", False) and shape.has_text_frame):
                return False
            text = _safe_text(shape.text_frame.text)
            if not text:
                return False
            return text in repeated
        except Exception:
            return False

    # ---------- シェイプ単位 ----------

    def _collect_shape(
        self,
        shape,
        slide_no: int,
        shapes_meta: list,
        connectors: list,
        collected: list,
    ) -> None:
        if self._is_title_shape(shape):
            return

        # 当該スライドのタイトルとして使用済みの shape は重複出力を避ける
        try:
            if self._current_title_shape_id is not None and shape.shape_id == self._current_title_shape_id:
                return
        except Exception:
            pass

        # フッタ / スライド番号 / 日付プレースホルダはテンプレ装飾として除外
        if self._is_template_placeholder(shape):
            return

        # マスタ / レイアウトに同じテキストで定義された装飾要素を除外
        if self._matches_template_text(shape):
            return

        # 章扉スライドの装飾的章番号 (純数字 1〜3 桁) を除外
        if self._current_is_section_cover and self._is_decoration_number(shape):
            return

        # 視覚統計ベースの装飾判定: 極小フォント・薄いグレー・極小サイズ・隅の短文を装飾扱い
        try:
            if shape.shape_id in self._current_decoration_shape_ids:
                return
        except Exception:
            pass

        if shape.shape_type == MSO_SHAPE_TYPE.GROUP:
            for sub in shape.shapes:
                self._collect_shape(sub, slide_no, shapes_meta, connectors, collected)
            return

        pos_top, pos_left = self._safe_position(shape)

        if shape.shape_type == MSO_SHAPE_TYPE.PICTURE:
            block = self._handle_picture(shape, slide_no)
            if block:
                collected.append({"kind": "image", "shape_id": shape.shape_id, "text": block, "top": pos_top, "left": pos_left})
            return

        if getattr(shape, "has_table", False) and shape.has_table:
            block = self._convert_table(shape.table)
            if block:
                collected.append({"kind": "table", "shape_id": shape.shape_id, "text": block, "top": pos_top, "left": pos_left})
            return

        if getattr(shape, "has_chart", False) and shape.has_chart:
            block = self._summarize_chart(shape.chart)
            collected.append({"kind": "chart", "shape_id": shape.shape_id, "text": block, "top": pos_top, "left": pos_left})
            return

        if shape.shape_type == MSO_SHAPE_TYPE.LINE or self._is_connector(shape):
            self._collect_connector(shape, connectors)
            return

        if self._is_smartart(shape):
            mermaid = None
            if not self.no_mermaid:
                mermaid = self._smartart_to_mermaid(shape)
            if mermaid:
                collected.append(
                    {"kind": "mermaid", "shape_id": shape.shape_id, "text": f"```mermaid\n{mermaid}\n```", "top": pos_top, "left": pos_left}
                )
            else:
                collected.append(
                    {"kind": "smartart", "shape_id": shape.shape_id, "text": self._smartart_fallback_text(shape), "top": pos_top, "left": pos_left}
                )
            return

        if getattr(shape, "has_text_frame", False) and shape.has_text_frame:
            # Mermaid 化に必要なメタ情報は重複テキストでも収集する
            shapes_meta.append(self._shape_meta(shape))
            # 同一スライド内で繰り返し出現する短文（凡例ラベル等）は本文化を抑制
            if self._matches_repeated_slide_text(shape):
                return
            default_bullet = self._is_body_placeholder(shape)
            text = self._convert_text_frame(shape.text_frame, default_bullet=default_bullet)
            if text:
                collected.append({"kind": "text", "shape_id": shape.shape_id, "text": text, "top": pos_top, "left": pos_left})
            return

    @staticmethod
    def _merge_horizontal_text_rows(items: list) -> list:
        """top が近い連続 text 要素を 1 行 (スペース区切り) として結合する。

        対象は kind == "text" のみ。画像・テーブル・mermaid 等は独立ブロックを維持。
        top の差が 250_000 EMU (約 0.25cm) 以内のものを同一行とみなす。
        """
        if not items:
            return items
        TOP_TOLERANCE = 250_000

        merged: list = []
        current_row: list = []
        for item in items:
            if item.get("kind") != "text":
                if current_row:
                    merged.append(PPTXMarkdownConverter._fuse_row(current_row))
                    current_row = []
                merged.append(item)
                continue
            if not current_row:
                current_row = [item]
                continue
            prev_top = current_row[-1].get("top") or 0
            cur_top = item.get("top") or 0
            if abs(cur_top - prev_top) <= TOP_TOLERANCE:
                current_row.append(item)
            else:
                merged.append(PPTXMarkdownConverter._fuse_row(current_row))
                current_row = [item]
        if current_row:
            merged.append(PPTXMarkdownConverter._fuse_row(current_row))
        return merged

    @staticmethod
    def _fuse_row(row_items: list) -> dict:
        """同一行に並ぶ複数 text item を 1 ブロックに結合."""
        if len(row_items) == 1:
            return row_items[0]
        row_items_sorted = sorted(row_items, key=lambda x: (x.get("left") or 0))
        joined = "　".join(
            (it.get("text") or "").replace("\n", " ").strip()
            for it in row_items_sorted
            if (it.get("text") or "").strip()
        )
        return {
            "kind": "text",
            "shape_id": None,
            "text": joined,
            "top": row_items_sorted[0].get("top"),
            "left": row_items_sorted[0].get("left"),
        }

    @staticmethod
    def _safe_position(shape) -> tuple:
        """shape の (top, left) を取得。取得失敗時は (0, 0) を返す."""
        try:
            top = shape.top or 0
        except Exception:
            top = 0
        try:
            left = shape.left or 0
        except Exception:
            left = 0
        return top, left

    @staticmethod
    def _is_title_shape(shape) -> bool:
        try:
            placeholder = shape.placeholder_format
            if placeholder is None:
                return False
            placeholder_type = placeholder.type
            type_str = str(placeholder_type) if placeholder_type is not None else ""
            if "SUBTITLE" in type_str:
                return False
            if placeholder.idx == 0:
                return True
            return "TITLE" in type_str
        except Exception:
            return False

    @staticmethod
    def _is_body_placeholder(shape) -> bool:
        try:
            placeholder = shape.placeholder_format
            if placeholder is None:
                return False
            placeholder_type = placeholder.type
            if placeholder_type is None:
                return False
            type_str = str(placeholder_type)
            return any(kw in type_str for kw in ("BODY", "OBJECT", "CONTENT"))
        except Exception:
            return False

    @staticmethod
    def _is_connector(shape) -> bool:
        try:
            return shape.element.tag.endswith("}cxnSp")
        except Exception:
            return False

    @staticmethod
    def _is_smartart(shape) -> bool:
        try:
            for child in shape.element.iter():
                if child.tag.endswith("}graphicData"):
                    uri = child.get("uri", "")
                    if "diagram" in uri:
                        return True
        except Exception:
            return False
        return False

    @staticmethod
    def _shape_meta(shape) -> dict:
        text = ""
        try:
            if shape.has_text_frame:
                text = _safe_text(shape.text_frame.text)
        except Exception:
            text = ""
        auto = ""
        try:
            auto = str(shape.auto_shape_type) if getattr(shape, "auto_shape_type", None) else ""
        except Exception:
            auto = ""
        font_size_max = PPTXMarkdownConverter._extract_max_font_size_pt(shape)
        font_color_hex = PPTXMarkdownConverter._extract_dominant_font_color(shape)
        return {
            "shape_id": shape.shape_id,
            "name": shape.name,
            "text": text,
            "auto_shape_type": auto,
            "left": shape.left,
            "top": shape.top,
            "width": shape.width,
            "height": shape.height,
            "font_size_pt": font_size_max,
            "font_color": font_color_hex,
            "is_grayish": PPTXMarkdownConverter._is_grayish_color(font_color_hex),
            "char_count": len(text),
        }

    @staticmethod
    def _extract_max_font_size_pt(shape) -> Optional[float]:
        """shape 内の最大フォントサイズ (pt) を返す。取得できない場合は None."""
        try:
            if not getattr(shape, "has_text_frame", False) or not shape.has_text_frame:
                return None
        except Exception:
            return None
        max_pt: Optional[float] = None
        try:
            for paragraph in shape.text_frame.paragraphs:
                # paragraph レベルのフォントサイズも見る
                try:
                    p_size = paragraph.font.size
                    if p_size is not None:
                        pt_val = p_size.pt
                        if max_pt is None or pt_val > max_pt:
                            max_pt = pt_val
                except Exception:
                    pass
                for run in paragraph.runs:
                    try:
                        size = run.font.size
                        if size is None:
                            continue
                        pt_val = size.pt
                        if max_pt is None or pt_val > max_pt:
                            max_pt = pt_val
                    except Exception:
                        continue
        except Exception:
            return max_pt
        return max_pt

    @staticmethod
    def _extract_dominant_font_color(shape) -> Optional[str]:
        """shape 内の最初に取得できた RGB 色を hex 文字列で返す."""
        try:
            if not getattr(shape, "has_text_frame", False) or not shape.has_text_frame:
                return None
        except Exception:
            return None
        try:
            for paragraph in shape.text_frame.paragraphs:
                for run in paragraph.runs:
                    try:
                        color = run.font.color
                        if color is None:
                            continue
                        rgb = color.rgb
                        if rgb is None:
                            continue
                        # rgb は RGBColor 型。str() で "RRGGBB" を返す
                        return str(rgb).upper()
                    except Exception:
                        continue
        except Exception:
            return None
        return None

    @staticmethod
    def _is_grayish_color(hex_color: Optional[str]) -> bool:
        """フォント色が薄いグレー / 装飾色っぽいかを判定."""
        if not hex_color or len(hex_color) != 6:
            return False
        try:
            r = int(hex_color[0:2], 16)
            g = int(hex_color[2:4], 16)
            b = int(hex_color[4:6], 16)
        except Exception:
            return False
        # 3 チャネルがいずれも 0x80 (128) 以上で、互いの差が小さい → 薄いグレー系
        if r < 0x80 or g < 0x80 or b < 0x80:
            return False
        max_c = max(r, g, b)
        min_c = min(r, g, b)
        return (max_c - min_c) <= 20

    def _collect_connector(self, shape, connectors: list) -> None:
        try:
            begin = None
            end = None
            for element in shape.element.iter():
                tag = element.tag
                if tag.endswith("}stCxn") and element.get("id"):
                    begin = int(element.get("id"))
                elif tag.endswith("}endCxn") and element.get("id"):
                    end = int(element.get("id"))
            if begin is not None and end is not None:
                connectors.append({"begin": begin, "end": end})
        except Exception:
            return

    # ---------- テキストフレーム ----------

    def _convert_text_frame(self, text_frame, *, default_bullet: bool = False) -> str:
        rendered_paragraphs: List[str] = []
        code_buffer: List[str] = []

        def flush_code():
            if code_buffer:
                rendered_paragraphs.append("```\n" + "\n".join(code_buffer) + "\n```")
                code_buffer.clear()

        for paragraph in text_frame.paragraphs:
            text = self._render_paragraph_runs(paragraph)
            if not text.strip():
                flush_code()
                continue

            level = paragraph.level or 0
            if self._is_monospace_paragraph(paragraph):
                # 装飾を取り除いた素のテキストを残す
                raw = "".join((run.text or "") for run in paragraph.runs)
                code_buffer.append(raw)
                continue

            flush_code()

            bullet_state = self._bullet_state(paragraph)
            is_bulleted = bullet_state is True or (bullet_state is None and default_bullet)

            if level > 0:
                indent = "  " * level
                rendered_paragraphs.append(f"{indent}- {text}")
            elif is_bulleted:
                rendered_paragraphs.append(f"- {text}")
            else:
                rendered_paragraphs.append(text)

        flush_code()
        return "\n".join(rendered_paragraphs)

    @staticmethod
    def _bullet_state(paragraph):
        """段落の bullet 設定を判定する。

        戻り値:
            True  -- 段落に明示的な bullet 指定がある (buChar / buAutoNum)
            False -- 段落に明示的な「bullet なし」指定がある (buNone)
            None  -- 段落側に指定がなく、レイアウト側のデフォルトに従う
        """
        try:
            p_pr = paragraph._pPr
            if p_pr is None:
                return None
            for child in p_pr.iter():
                tag = child.tag
                if tag.endswith("}buChar") or tag.endswith("}buAutoNum"):
                    return True
                if tag.endswith("}buNone"):
                    return False
        except Exception:
            return None
        return None

    @staticmethod
    def _render_paragraph_runs(paragraph) -> str:
        rendered_parts: List[str] = []
        for run in paragraph.runs:
            text = run.text or ""
            if not text:
                continue
            bold = bool(run.font.bold)
            italic = bool(run.font.italic)
            strike = False
            try:
                r_pr = run._r.find(f"{{{NS_A}}}rPr")
                if r_pr is not None:
                    strike_attr = r_pr.get("strike")
                    if strike_attr and strike_attr != "noStrike":
                        strike = True
            except Exception:
                strike = False
            wrapped = text
            if strike:
                wrapped = f"~~{wrapped}~~"
            if italic:
                wrapped = f"*{wrapped}*"
            if bold:
                wrapped = f"**{wrapped}**"
            rendered_parts.append(wrapped)
        return "".join(rendered_parts)

    @staticmethod
    def _is_monospace_paragraph(paragraph) -> bool:
        runs = list(paragraph.runs)
        if not runs:
            return False
        for run in runs:
            try:
                name = run.font.name
            except Exception:
                name = None
            if not _is_monospace_font(name):
                return False
        return True

    # ---------- 表 ----------

    def _convert_table(self, table) -> str:
        rows = list(table.rows)
        if not rows:
            return ""
        header_cells = [self._cell_text(cell) for cell in rows[0].cells]
        col_count = len(header_cells)
        if col_count == 0:
            return ""
        # 全セルが空のテーブルはレイアウト装飾とみなして抑制
        all_cells_empty = True
        for row in rows:
            for cell in row.cells:
                if self._cell_text(cell).strip():
                    all_cells_empty = False
                    break
            if not all_cells_empty:
                break
        if all_cells_empty:
            return ""
        lines = [
            "| " + " | ".join(_escape_md_pipe(c) for c in header_cells) + " |",
            "| " + " | ".join(["---"] * col_count) + " |",
        ]
        for row in rows[1:]:
            cells = [self._cell_text(cell) for cell in row.cells]
            while len(cells) < col_count:
                cells.append("")
            lines.append(
                "| " + " | ".join(_escape_md_pipe(c) for c in cells[:col_count]) + " |"
            )
        return "\n".join(lines)

    @staticmethod
    def _cell_text(cell) -> str:
        if cell is None:
            return ""
        return _safe_text(cell.text or "")

    # ---------- 画像 ----------

    def _handle_picture(self, shape, slide_no: int) -> Optional[str]:
        try:
            blob = shape.image.blob
        except Exception as exc:
            print(
                f"Warning: failed to extract image on slide {slide_no}: {exc}",
                file=sys.stderr,
            )
            return None

        size = len(blob)
        if size > self.max_image_bytes:
            print(
                f"Warning: image too large ({size} bytes > {self.max_image_bytes}); "
                f"slide {slide_no} shape '{shape.name}'",
                file=sys.stderr,
            )
            return (
                f"> 画像（サイズ超過のためバイナリ非保存）: slide={slide_no}, "
                f"name={shape.name}, size={size}B"
            )

        raw_ext = (shape.image.ext or "png").lower()
        ext = raw_ext if raw_ext in ALLOWED_IMAGE_EXTS else "bin"
        if ext != raw_ext:
            print(
                f"Warning: image extension '{raw_ext}' is not in allowlist; "
                f"normalized to 'bin' on slide {slide_no}",
                file=sys.stderr,
            )
        self._image_seq.setdefault(slide_no, 0)
        self._image_seq[slide_no] += 1
        img_no = self._image_seq[slide_no]
        filename = f"slide{slide_no}_img{img_no}.{ext}"
        out_path = self.images_dir / filename
        try:
            out_path.write_bytes(blob)
        except OSError as exc:
            print(f"Warning: failed to write image: {exc}", file=sys.stderr)
            return None

        alt = _escape_md_link_text(self._image_alt(shape, img_no))
        try:
            rel = out_path.relative_to(self.output_path.parent)
        except ValueError:
            rel = out_path
        return f"![{alt}]({rel.as_posix()})"

    @staticmethod
    def _image_alt(shape, img_no: int) -> str:
        try:
            descr = shape._element.xpath("string(.//@descr)")
            if descr:
                return descr
        except Exception:
            pass
        return shape.name or f"image{img_no}"

    # ---------- チャート ----------

    @staticmethod
    def _summarize_chart(chart) -> str:
        try:
            type_name = str(chart.chart_type)
        except Exception:
            type_name = "unknown"
        series_names: List[str] = []
        try:
            for series in chart.series:
                try:
                    series_names.append(series.name)
                except Exception:
                    continue
        except Exception:
            series_names = []
        return f"> チャート: {type_name} 系列={series_names}"

    # ---------- SmartArt ----------

    def _smartart_to_mermaid(self, shape) -> Optional[str]:
        try:
            ns = {"dgm": NS_DGM, "r": NS_R, "a": NS_A}
            rel_ids = shape.element.findall(".//dgm:relIds", namespaces=ns)
            if not rel_ids:
                return None
            rid_data = rel_ids[0].get(f"{{{NS_R}}}dm")
            if not rid_data:
                return None
            slide_part = shape.part
            rel = slide_part.rels.get(rid_data)
            if rel is None:
                return None
            data_xml = etree.fromstring(rel.target_part.blob, parser=_hardened_xml_parser())
            points: dict[str, str] = {}
            for point in data_xml.findall(".//dgm:pt", namespaces=ns):
                pid = point.get("modelId")
                if not pid:
                    continue
                texts = point.findall(".//a:t", namespaces=ns)
                value = " ".join((t.text or "") for t in texts).strip()
                points[pid] = value
            edges: List[tuple] = []
            for connection in data_xml.findall(".//dgm:cxn", namespaces=ns):
                src = connection.get("srcId")
                dst = connection.get("destId")
                ctype = connection.get("type", "parOf")
                if ctype not in ("parOf", "presOf"):
                    continue
                if src in points and dst in points:
                    edges.append((src, dst))
            if not edges:
                return None

            def safe_id(pid: str) -> str:
                cleaned = re.sub(r"[^A-Za-z0-9]", "", pid)
                return f"S{cleaned[:20]}" if cleaned else f"S{abs(hash(pid)) % 100000}"

            used = {src for src, _ in edges} | {dst for _, dst in edges}
            lines = ["flowchart TD"]
            for nid in sorted(used):
                label = _mermaid_escape_label(points.get(nid, "") or nid)
                lines.append(f'    {safe_id(nid)}["{label}"]')
            for src, dst in edges:
                lines.append(f"    {safe_id(src)} --> {safe_id(dst)}")
            return "\n".join(lines)
        except Exception as exc:
            print(f"Warning: failed to parse SmartArt: {exc}", file=sys.stderr)
            return None

    @staticmethod
    def _smartart_fallback_text(shape) -> str:
        try:
            text_nodes = shape.element.findall(f".//{{{NS_A}}}t")
            lines: List[str] = []
            for node in text_nodes:
                if node.text and node.text.strip():
                    lines.append(f"- {node.text.strip()}")
            if lines:
                return "> SmartArt（テキスト抽出）:\n" + "\n".join(lines)
        except Exception:
            pass
        return "> SmartArt（解析失敗・テキスト抽出不可）"

    # ---------- スピーカーノート ----------

    @staticmethod
    def _extract_notes(slide) -> Optional[str]:
        try:
            if not slide.has_notes_slide:
                return None
            text = _safe_text(slide.notes_slide.notes_text_frame.text)
        except Exception:
            return None
        if not text:
            return None
        lines = ["> [!NOTE]"]
        for line in text.split("\n"):
            lines.append(f"> {line}")
        return "\n".join(lines)


# ----------------------------------------------------------------------------- #
# エントリポイント
# ----------------------------------------------------------------------------- #


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert PPTX to Markdown.")
    parser.add_argument("input", help="Input PPTX file path")
    parser.add_argument(
        "output",
        nargs="?",
        default=None,
        help="Output MD file path (default: <input>.md)",
    )
    parser.add_argument(
        "--images-dir",
        default=None,
        help="Image extraction directory (default: <basename>_images/ next to output MD)",
    )
    parser.add_argument(
        "--no-mermaid",
        action="store_true",
        help="Disable flowchart/SmartArt Mermaid conversion",
    )
    parser.add_argument(
        "--include-notes",
        action="store_true",
        help="Include speaker notes",
    )
    parser.add_argument(
        "--include-hidden",
        action="store_true",
        help="Include hidden slides",
    )
    parser.add_argument(
        "--no-first-slide-as-title",
        action="store_true",
        help="Treat first slide as H2 instead of H1",
    )
    parser.add_argument(
        "--max-image-size",
        type=int,
        default=DEFAULT_MAX_IMAGE_BYTES,
        help="Maximum bytes per image (default 5 MiB)",
    )
    return parser.parse_args(list(argv))


def main(argv: Optional[Iterable[str]] = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input file not found: {input_path}", file=sys.stderr)
        return 1
    try:
        converter = PPTXMarkdownConverter(args)
        output_path = converter.convert()
        print(f"Wrote: {output_path}")
        print(f"Images dir: {converter.images_dir}")
        return 0
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    except Exception as exc:  # noqa: BLE001
        print(f"Error: unexpected failure: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
