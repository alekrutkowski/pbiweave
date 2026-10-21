"""Inventory the generated TMDL subset without claiming native grammar validation.

This intentionally only extracts object names and relationship references. Use
Microsoft TmdlSerializer for full TMDL acceptance (tools/validate-tmdl.ps1).
Expressions enclosed by fences are opaque and cannot inject declarations.
"""
from pathlib import Path
import re

NAME = r"(?:'(?:[^']|'')*'|[^\s=]+)"


def unquote(value: str) -> str:
    value = value.strip()
    return value[1:-1].replace("''", "'") if value.startswith("'") and value.endswith("'") else value


def declarations(path: Path):
    inside = False
    for number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if inside:
            if re.fullmatch(r"\s*```\s*", line):
                inside = False
            continue
        yield number, line
        if re.search(r"=\s*```\s*$", line):
            inside = True
    if inside:
        raise ValueError(f"{path}: unclosed expression fence")


def inventory(folder: Path) -> dict:
    for name in ("database.tmdl", "model.tmdl"):
        if not (folder / name).is_file():
            raise ValueError(f"missing {name}")
    tables = []
    for path in sorted((folder / "tables").glob("*.tmdl")):
        table = None
        for number, line in declarations(path):
            header = re.fullmatch(r"table\s+(" + NAME + r")\s*", line)
            if header:
                if table is not None:
                    raise ValueError(f"{path}:{number}: multiple tables; this inventory supports generated one-table files")
                table = {"name": unquote(header[1]), "columns": [], "measures": []}
                continue
            # Object children are one tab deep in generated output.
            field = re.match(r"\t(column|measure)\s+(" + NAME + r")(?:\s*=.*)?\s*$", line)
            if field and table is not None:
                table["columns" if field[1] == "column" else "measures"].append({"name": unquote(field[2])})
        if table is None:
            raise ValueError(f"{path}: missing root table")
        tables.append(table)
    if not tables:
        raise ValueError("missing TMDL table definitions")
    relationships = []
    rel_path = folder / "relationships.tmdl"
    current = None
    if rel_path.exists():
        for number, line in declarations(rel_path):
            header = re.fullmatch(r"relationship\s+(" + NAME + r")\s*", line)
            if header:
                current = {"name": unquote(header[1])}
                relationships.append(current)
            endpoint = re.match(r"\t(from|to)Column:\s*(" + NAME + r")\.(" + NAME + r")\s*$", line)
            if endpoint and current is not None:
                current[endpoint[1] + "Table"] = unquote(endpoint[2])
                current[endpoint[1] + "Column"] = unquote(endpoint[3])
    return {"model": {"tables": tables, "relationships": relationships}}
