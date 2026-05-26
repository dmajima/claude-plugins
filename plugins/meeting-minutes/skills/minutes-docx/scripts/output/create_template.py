"""議事録テンプレート docx を生成するユーティリティスクリプト"""
import sys
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

import argparse
from pathlib import Path

from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.style import WD_STYLE_TYPE


def create_template(output_path: str):
    doc = Document()

    style = doc.styles["Normal"]
    font = style.font
    font.name = "Yu Gothic UI"
    font.size = Pt(10.5)

    for level, size in [(0, 18), (1, 14), (2, 12)]:
        heading_style = doc.styles[f"Heading {level}" if level > 0 else "Title"]
        heading_font = heading_style.font
        heading_font.name = "Yu Gothic UI"
        heading_font.size = Pt(size)
        heading_font.color.rgb = RGBColor(0x1A, 0x1A, 0x2E)

    for style_name in ["List Bullet", "List Number"]:
        try:
            ls = doc.styles[style_name]
            ls.font.name = "Yu Gothic UI"
            ls.font.size = Pt(10.5)
        except KeyError:
            pass

    section = doc.sections[0]
    section.top_margin = Cm(2)
    section.bottom_margin = Cm(2)
    section.left_margin = Cm(2.5)
    section.right_margin = Cm(2.5)

    doc.save(output_path)
    print(f"Template created: {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Create minutes docx template")
    parser.add_argument("--output", required=True, help="Output template path")
    args = parser.parse_args()
    create_template(args.output)


if __name__ == "__main__":
    main()
