#!/usr/bin/env python3
"""Normalize Lark Sheet test cases into a queue JSON file."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import re
import sys
from pathlib import Path
from typing import Any


HEADER_ALIASES = {
    "case_id": ["case id", "case_id", "id", "tc id", "用例id", "用例编号", "编号", "序号"],
    "title": ["title", "case", "name", "用例名称", "测试点", "测试目标", "目标", "测试用例", "标题"],
    "module": ["module", "feature", "模块", "功能", "端"],
    "platform": ["platform", "平台", "设备平台", "系统平台"],
    "priority": ["priority", "severity", "优先级", "严重程度"],
    "preconditions": ["precondition", "preconditions", "前置条件", "前置条件/测试数据", "真实服务与测试数据", "测试数据", "准备条件"],
    "steps": ["steps", "step", "操作步骤", "测试步骤", "步骤"],
    "expected": ["expected", "expected result", "expect", "预期", "预期结果"],
    "actual": ["actual", "actual result", "实际", "实际结果"],
    "notes": ["notes", "remark", "remarks", "备注", "说明"],
}


def norm_header(value: Any) -> str:
    text = str(value or "").strip().lower()
    text = re.sub(r"[\s\-_]+", " ", text)
    return text


def pick(row: dict[str, Any], field: str) -> str:
    normalized_row = {norm_header(key): value for key, value in row.items()}
    for alias in HEADER_ALIASES[field]:
        value = normalized_row.get(norm_header(alias))
        if value is not None:
            return str(value).strip()
    return ""


def row_has_content(row: dict[str, Any]) -> bool:
    return any(str(value or "").strip() for value in row.values())


def payload_data(payload: dict[str, Any]) -> dict[str, Any]:
    if "ok" in payload:
        if not payload.get("ok", False):
            raise ValueError("input JSON is not an ok lark-cli envelope")
        return payload.get("data", {})
    return payload


def load_table_get(data: dict[str, Any]) -> list[dict[str, Any]]:
    sheets = data.get("sheets", [])
    rows: list[dict[str, Any]] = []
    for sheet in sheets:
        columns = [str(column or "").strip() for column in sheet.get("columns", [])]
        start_row = 1
        match = re.match(r"^[A-Z]+(\d+):", str(sheet.get("range", "")))
        if match:
            start_row = int(match.group(1))
        for offset, values in enumerate(sheet.get("data", []), start=1):
            raw = dict(zip(columns, values))
            raw["_sheet_name"] = sheet.get("name", "")
            raw["_row"] = start_row + offset
            rows.append(raw)
    return rows


def load_csv_get(data: dict[str, Any]) -> list[dict[str, Any]]:
    annotated = data.get("annotated_csv", "")
    logical_rows: list[tuple[int | None, list[str]]] = []
    for parsed in csv.reader(annotated.splitlines()):
        if not parsed:
            continue
        first = parsed[0]
        match = re.match(r"^\[row=(\d+)\]\s?(.*)$", first)
        row_number = int(match.group(1)) if match else None
        parsed[0] = match.group(2) if match else first
        logical_rows.append((row_number, parsed))
    if not logical_rows:
        return []
    headers = [value.strip() for value in logical_rows[0][1]]
    rows = []
    for row_number, values in logical_rows[1:]:
        raw = dict(zip(headers, values))
        raw["_row"] = row_number
        rows.append(raw)
    return rows


def normalize_case(raw: dict[str, Any], index: int) -> dict[str, Any]:
    title = pick(raw, "title")
    case_id = pick(raw, "case_id") or f"ROW-{raw.get('_row') or index + 1}"
    platform = pick(raw, "platform")
    if not platform:
        suffix = case_id.rsplit("-", 1)[-1].upper()
        platform = {"A": "Android Emulator", "I": "iOS Simulator"}.get(suffix, "")
    return {
        "case_id": case_id,
        "row": raw.get("_row"),
        "title": title or case_id,
        "module": pick(raw, "module"),
        "platform": platform,
        "priority": pick(raw, "priority"),
        "preconditions": pick(raw, "preconditions"),
        "steps": pick(raw, "steps"),
        "expected": pick(raw, "expected"),
        "actual": pick(raw, "actual"),
        "status": "pending",
        "evidence": "",
        "notes": pick(raw, "notes"),
        "raw": {key: value for key, value in raw.items() if not key.startswith("_")},
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_json", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--sheet-url", default="")
    parser.add_argument("--sheet-id", default="")
    args = parser.parse_args()

    payload = json.loads(args.input_json.read_text())
    try:
        data = payload_data(payload)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    if data.get("sheets") is not None:
        raw_rows = load_table_get(data)
    else:
        raw_rows = load_csv_get(data)

    cases = [
        normalize_case(row, index)
        for index, row in enumerate(raw_rows)
        if row_has_content({key: value for key, value in row.items() if not key.startswith("_")})
    ]
    queue = {
        "source": {
            "sheet_url": args.sheet_url,
            "sheet_id": args.sheet_id,
            "read_at": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
        },
        "test_queue": cases,
        "fix_queue": [],
    }
    args.out.write_text(json.dumps(queue, ensure_ascii=False, indent=2) + "\n")
    print(f"wrote {len(cases)} cases to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
