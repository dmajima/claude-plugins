"""構造化議事録データ（JSON v2.0）から docx ファイルを生成する"""
import sys
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

import argparse
import json
from pathlib import Path

from docx import Document
from docx.shared import Pt, Cm
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH


def set_cell(cell, text, bold=False, font_size=Pt(9)):
    cell.paragraphs[0].clear()
    run = cell.paragraphs[0].add_run(str(text))
    run.bold = bold
    run.font.size = font_size


def add_title_block(doc, metadata):
    doc.add_heading(f"【会議議事録】{metadata.get('title', '')}", level=0)

    p_date = doc.add_paragraph()
    p_date.add_run(f"日時: {metadata.get('date', '')}").font.size = Pt(11)

    p_loc = doc.add_paragraph()
    p_loc.add_run(f"場所: {metadata.get('location', 'オンライン会議')}").font.size = Pt(11)

    p_att = doc.add_paragraph()
    run_att = p_att.add_run("出席者:")
    run_att.font.size = Pt(11)
    for p in metadata.get("participants", []):
        name = p.get("name", "")
        org = p.get("organization", "")
        label = f"{org} / {name}" if org else name
        doc.add_paragraph(label, style="List Bullet")

    doc.add_paragraph()


def add_agenda_section(doc, agenda):
    doc.add_heading(f"{agenda['id']}. {agenda['title']}", level=1)

    bg = agenda.get("background", "")
    if bg:
        doc.add_heading("背景・目的:", level=2)
        doc.add_paragraph(bg)

    specs = agenda.get("specifications", [])
    if specs:
        doc.add_heading("仕様・機能詳細:", level=2)
        for s in specs:
            doc.add_paragraph(s, style="List Bullet")

    discussions = agenda.get("discussions", [])
    if discussions:
        doc.add_heading("議論の内容:", level=2)
        for d in discussions:
            doc.add_paragraph(d, style="List Bullet")

    concerns = agenda.get("concerns", [])
    if concerns:
        doc.add_heading("懸念点:", level=2)
        for c in concerns:
            doc.add_paragraph(c, style="List Bullet")

    conclusions = agenda.get("conclusions", [])
    if conclusions:
        doc.add_heading("結論・合意事項:", level=2)
        for c in conclusions:
            doc.add_paragraph(c, style="List Bullet")


def add_action_items(doc, items):
    doc.add_heading("アクションまとめ", level=1)
    if not items:
        doc.add_paragraph("なし")
        return
    for item in items:
        idx = item.get("id", "")
        label = item.get("label", "")
        p_title = doc.add_paragraph()
        run_title = p_title.add_run(f"{idx}. {label}")
        run_title.bold = True
        run_title.font.size = Pt(10.5)

        p_assignee = doc.add_paragraph()
        p_assignee.paragraph_format.left_indent = Cm(1)
        p_assignee.add_run(f"担当: {item.get('assignee', '')}").font.size = Pt(10)

        p_deadline = doc.add_paragraph()
        p_deadline.paragraph_format.left_indent = Cm(1)
        p_deadline.add_run(f"期限: {item.get('deadline', '')}").font.size = Pt(10)

        p_content = doc.add_paragraph()
        p_content.paragraph_format.left_indent = Cm(1)
        p_content.add_run(f"内容: {item.get('content', '')}").font.size = Pt(10)

        doc.add_paragraph()


def add_next_meeting(doc, next_meeting):
    doc.add_heading("次回予定", level=1)
    if not next_meeting:
        doc.add_paragraph("未定")
        return
    if next_meeting.get("date"):
        doc.add_paragraph(f"日時: {next_meeting['date']}")
    agendas = next_meeting.get("plannedAgendas", [])
    if agendas:
        doc.add_paragraph(f"議題（予定）: {', '.join(agendas)}")
    preps = next_meeting.get("preparations", [])
    if preps:
        doc.add_paragraph("準備事項:")
        for p in preps:
            doc.add_paragraph(
                f"{p.get('task', '')}（{p.get('assignee', '')}）",
                style="List Bullet",
            )


def generate(input_path: str, template_path: str | None, output_path: str):
    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    if template_path and Path(template_path).exists():
        doc = Document(template_path)
    else:
        doc = Document()

    metadata = data.get("metadata", {})
    add_title_block(doc, metadata)

    agendas = data.get("agendas", [])
    for agenda in agendas:
        add_agenda_section(doc, agenda)

    add_action_items(doc, data.get("actionItems", []))
    add_next_meeting(doc, data.get("nextMeeting"))

    doc.save(output_path)
    print(f"Generated: {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Generate meeting minutes docx")
    parser.add_argument("--input", required=True, help="Path to minutes.json")
    parser.add_argument("--template", default=None, help="Path to template.docx")
    parser.add_argument("--output", required=True, help="Output docx path")
    args = parser.parse_args()
    generate(args.input, args.template, args.output)


if __name__ == "__main__":
    main()
