"""構造化議事録データ（JSON）から docx ファイルを生成する"""
import sys
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

import argparse
import json
from pathlib import Path

from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH


def set_cell(cell, text, bold=False, font_size=Pt(9)):
    cell.paragraphs[0].clear()
    run = cell.paragraphs[0].add_run(str(text))
    run.bold = bold
    run.font.size = font_size


def add_metadata_table(doc, metadata):
    rows = [
        ("日時", f"{metadata.get('date', '')} {metadata.get('startTime', '')} - {metadata.get('endTime', '')}（{metadata.get('durationMinutes', '')}分）"),
        ("場所/方式", metadata.get("location", "")),
        ("参加者", ", ".join(p["name"] + (f"（{p.get('organization', '')}）" if p.get("organization") else "") for p in metadata.get("participants", []))),
        ("議事録作成者", metadata.get("createdBy", "AI")),
    ]
    table = doc.add_table(rows=len(rows), cols=2, style="Table Grid")
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    for i, (label, value) in enumerate(rows):
        set_cell(table.cell(i, 0), label, bold=True)
        set_cell(table.cell(i, 1), value)
    for row in table.rows:
        row.cells[0].width = Cm(3)
        row.cells[1].width = Cm(13)
    doc.add_paragraph()


def add_agenda_list(doc, agendas):
    doc.add_heading("議題一覧", level=1)
    for agenda in agendas:
        doc.add_paragraph(
            f"{agenda['id']}. {agenda['title']}", style="List Number"
        )
    doc.add_paragraph()


def add_agenda_details(doc, agendas):
    doc.add_heading("議事内容", level=1)
    for agenda in agendas:
        doc.add_heading(
            f"{agenda['id']}. {agenda['title']}", level=2
        )
        if agenda.get("summary"):
            p = doc.add_paragraph()
            run = p.add_run("概要: ")
            run.bold = True
            run.font.size = Pt(10)
            run2 = p.add_run(agenda["summary"])
            run2.font.size = Pt(10)

        discussions = agenda.get("discussions", [])
        if discussions:
            p_label = doc.add_paragraph()
            run_label = p_label.add_run("議論内容:")
            run_label.bold = True
            run_label.font.size = Pt(10)
            for disc in discussions:
                doc.add_paragraph(disc.get("point", ""), style="List Bullet")
                for detail in disc.get("details", []):
                    p_detail = doc.add_paragraph(style="List Bullet 2")
                    p_detail.text = detail

        confirmations = agenda.get("confirmations", [])
        if confirmations:
            p_conf = doc.add_paragraph()
            run_conf = p_conf.add_run("確認事項:")
            run_conf.bold = True
            run_conf.font.size = Pt(10)
            for conf in confirmations:
                doc.add_paragraph(conf, style="List Bullet")


def add_decisions_table(doc, decisions):
    doc.add_heading("決定事項", level=1)
    if not decisions:
        doc.add_paragraph("なし")
        return
    table = doc.add_table(rows=1 + len(decisions), cols=4, style="Table Grid")
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    headers = ["#", "決定内容", "関連議題", "備考"]
    for i, h in enumerate(headers):
        set_cell(table.cell(0, i), h, bold=True)
        table.cell(0, i).paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.CENTER
    for row_idx, dec in enumerate(decisions, 1):
        set_cell(table.cell(row_idx, 0), dec.get("id", row_idx))
        set_cell(table.cell(row_idx, 1), dec.get("content", ""))
        set_cell(table.cell(row_idx, 2), dec.get("relatedAgendaId", ""))
        set_cell(table.cell(row_idx, 3), dec.get("conditions", ""))
    table.columns[0].width = Cm(1)
    table.columns[1].width = Cm(9)
    table.columns[2].width = Cm(2)
    table.columns[3].width = Cm(4)
    doc.add_paragraph()


def add_action_items_table(doc, items):
    doc.add_heading("アクションアイテム", level=1)
    if not items:
        doc.add_paragraph("なし")
        return
    table = doc.add_table(rows=1 + len(items), cols=5, style="Table Grid")
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    headers = ["#", "タスク", "担当者", "期限", "関連議題"]
    for i, h in enumerate(headers):
        set_cell(table.cell(0, i), h, bold=True)
        table.cell(0, i).paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.CENTER
    for row_idx, item in enumerate(items, 1):
        set_cell(table.cell(row_idx, 0), item.get("id", row_idx))
        set_cell(table.cell(row_idx, 1), item.get("task", ""))
        assignee = item.get("assignee", "")
        org = item.get("organization", "")
        set_cell(table.cell(row_idx, 2), f"{assignee}（{org}）" if org else assignee)
        set_cell(table.cell(row_idx, 3), item.get("deadline", ""))
        set_cell(table.cell(row_idx, 4), item.get("relatedAgendaId", ""))
    table.columns[0].width = Cm(1)
    table.columns[1].width = Cm(6)
    table.columns[2].width = Cm(3)
    table.columns[3].width = Cm(3)
    table.columns[4].width = Cm(2)
    doc.add_paragraph()


def add_next_meeting(doc, next_meeting):
    doc.add_heading("次回予定", level=1)
    if not next_meeting:
        doc.add_paragraph("未定")
        return
    rows = []
    if next_meeting.get("date"):
        rows.append(("日時", next_meeting["date"]))
    agendas = next_meeting.get("plannedAgendas", [])
    if agendas:
        rows.append(("議題（予定）", ", ".join(agendas)))
    preps = next_meeting.get("preparations", [])
    if preps:
        prep_text = "\n".join(f"- {p.get('task', '')}（{p.get('assignee', '')}）" for p in preps)
        rows.append(("準備事項", prep_text))
    if rows:
        table = doc.add_table(rows=len(rows), cols=2, style="Table Grid")
        for i, (label, value) in enumerate(rows):
            set_cell(table.cell(i, 0), label, bold=True)
            set_cell(table.cell(i, 1), value)
        table.columns[0].width = Cm(3)
        table.columns[1].width = Cm(13)


def generate(input_path: str, template_path: str | None, output_path: str):
    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    if template_path and Path(template_path).exists():
        doc = Document(template_path)
    else:
        doc = Document()

    metadata = data.get("metadata", {})
    doc.add_heading(metadata.get("title", "議事録"), level=0)
    doc.add_heading("会議情報", level=1)
    add_metadata_table(doc, metadata)

    agendas = data.get("agendas", [])
    add_agenda_list(doc, agendas)
    add_agenda_details(doc, agendas)
    add_decisions_table(doc, data.get("decisions", []))
    add_action_items_table(doc, data.get("actionItems", []))
    add_next_meeting(doc, data.get("nextMeeting"))

    notes = data.get("notes")
    if notes:
        doc.add_heading("補足", level=1)
        doc.add_paragraph(notes)

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
