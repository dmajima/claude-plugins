"""議事録テンプレート docx を生成するユーティリティスクリプト"""
import sys
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

import argparse
from docx import Document
from docx.shared import Pt, Cm, RGBColor, Emu
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn, nsdecls
from docx.oxml import parse_xml


FONT_NAME = 'Meiryo'
COLOR_PRIMARY = RGBColor(0x1B, 0x3A, 0x5C)
COLOR_HEADING1 = RGBColor(0x1B, 0x3A, 0x5C)
COLOR_HEADING2 = RGBColor(0x2C, 0x5F, 0x8A)
COLOR_HEADING3 = RGBColor(0x3D, 0x7E, 0xAA)
COLOR_BODY = RGBColor(0x33, 0x33, 0x33)
COLOR_LIGHT_BG = 'E8EEF4'


def set_style_font(style):
    style.font.name = FONT_NAME
    rPr = style.element.find(qn('w:rPr'))
    if rPr is None:
        rPr = parse_xml(f'<w:rPr {nsdecls("w")}/>')
        style.element.append(rPr)
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = parse_xml(f'<w:rFonts {nsdecls("w")}/>')
        rPr.insert(0, rFonts)
    rFonts.set(qn('w:ascii'), FONT_NAME)
    rFonts.set(qn('w:hAnsi'), FONT_NAME)
    rFonts.set(qn('w:eastAsia'), FONT_NAME)


def configure_styles(doc):
    style = doc.styles['Normal']
    set_style_font(style)
    style.font.size = Pt(10.5)
    style.font.color.rgb = COLOR_BODY
    style.paragraph_format.space_after = Pt(4)
    style.paragraph_format.line_spacing = 1.15

    title_style = doc.styles['Title']
    set_style_font(title_style)
    title_style.font.size = Pt(20)
    title_style.font.bold = True
    title_style.font.color.rgb = COLOR_PRIMARY
    title_style.paragraph_format.space_before = Pt(0)
    title_style.paragraph_format.space_after = Pt(6)

    for level, (size, color, bold) in {
        1: (14, COLOR_HEADING1, True),
        2: (12, COLOR_HEADING2, True),
        3: (10.5, COLOR_HEADING3, True),
    }.items():
        hs = doc.styles[f'Heading {level}']
        set_style_font(hs)
        hs.font.size = Pt(size)
        hs.font.color.rgb = color
        hs.font.bold = bold
        hs.paragraph_format.space_before = Pt(12 if level == 1 else 8)
        hs.paragraph_format.space_after = Pt(4)

        if level == 1:
            pBdr = parse_xml(
                f'<w:pBdr {nsdecls("w")}>'
                f'  <w:bottom w:val="single" w:sz="8" w:space="2" w:color="1B3A5C"/>'
                f'</w:pBdr>'
            )
            hs.element.find(qn('w:pPr')).append(pBdr)

    for style_name in ['List Bullet', 'List Number']:
        try:
            ls = doc.styles[style_name]
            set_style_font(ls)
            ls.font.size = Pt(10.5)
            ls.font.color.rgb = COLOR_BODY
            ls.paragraph_format.space_after = Pt(2)
        except KeyError:
            pass

    section = doc.sections[0]
    section.top_margin = Cm(2)
    section.bottom_margin = Cm(2)
    section.left_margin = Cm(2.5)
    section.right_margin = Cm(2.5)


def create_template(output_path: str):
    doc = Document()
    configure_styles(doc)
    doc.save(output_path)
    print(f"Template created: {output_path}")


def main():
    parser = argparse.ArgumentParser(description='Create minutes docx template')
    parser.add_argument('--output', required=True, help='Output template path')
    args = parser.parse_args()
    create_template(args.output)


if __name__ == '__main__':
    main()
