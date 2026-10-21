#!/usr/bin/env python3
"""Validate generated Power BI projects against bundled Microsoft schemas.

Requires Python >= 3.9 and jsonschema >= 4.18. No network requests are made.
The checks validate file structure and references, not DAX/M execution or visual
rendering. Power BI Desktop remains the integration and publication gate.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable

try:
    from jsonschema.validators import Draft7Validator, validator_for
    from referencing import Registry, Resource
    from referencing.jsonschema import DRAFT7
except ImportError:
    raise SystemExit("Install validation dependencies: python -m pip install 'jsonschema>=4.18'")


def walk(value: Any) -> Iterable[dict]:
    """Visit object nodes without assumptions about optional PBIR properties."""
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


class ProjectValidator:
    def __init__(self, root: Path, schemas: dict[str, Any]) -> None:
        self.root = root.resolve()
        self.schemas = schemas
        resources = {}
        for uri, schema in schemas.items():
            resource = Resource.from_contents(schema, default_specification=DRAFT7)
            resources[uri] = resource
            if schema.get("$id"):
                resources[schema["$id"]] = resource
        # Registry has no retrieval callback: unresolved references fail offline.
        self.registry = Registry().with_resources(resources.items())
        self.errors: list[str] = []
        self.documents: dict[Path, Any] = {}
        self.schema_count = 0
        self.visual_count = 0
        self.page_count = 0

    def fail(self, path: Path, message: str) -> None:
        try:
            label = path.relative_to(self.root).as_posix()
        except ValueError:
            label = str(path)
        self.errors.append(f"{label}: {message}")

    def load(self, path: Path) -> Any:
        if path in self.documents:
            return self.documents[path]
        if not path.is_file():
            self.fail(path, "required file is missing")
            return {}
        try:
            raw = path.read_bytes()
            if raw.startswith(b"\xef\xbb\xbf"):
                self.fail(path, "UTF-8 BOM is not permitted in PBIP project files")
            value = json.loads(raw.decode("utf-8-sig"))
            self.documents[path] = value
            return value
        except (OSError, UnicodeError, ValueError) as exc:
            self.fail(path, f"cannot read JSON: {exc}")
            return {}

    def target(self, parent: Path, reference: Any, origin: Path) -> Path | None:
        if not isinstance(reference, str) or not reference:
            self.fail(origin, "missing relative file reference")
            return None
        if "\\" in reference or re.match(r"^[A-Za-z]:", reference) or reference.startswith("/"):
            self.fail(origin, f"reference must use a relative forward-slash path: {reference!r}")
            return None
        result = (parent / reference).resolve()
        try:
            result.relative_to(self.root)
        except ValueError:
            self.fail(origin, f"reference escapes the project folder: {reference!r}")
            return None
        return result

    def validate_schema(self, path: Path, document: Any) -> None:
        if not isinstance(document, dict):
            self.fail(path, "document must be a JSON object")
            return
        uri = document.get("$schema")
        if not uri:
            core_names = {"report.json", "version.json", "pages.json", "page.json", "visual.json", "mobile.json"}
            if path.suffix in (".pbip", ".pbir", ".pbism") or (
                "definition" in path.parts and path.name in core_names
            ):
                self.fail(path, "required $schema declaration is missing")
            return
        schema = self.schemas.get(uri)
        if schema is None:
            self.fail(path, f"schema is not in the pinned offline registry: {uri}")
            return
        self.schema_count += 1
        try:
            validator = validator_for(schema, default=Draft7Validator)(schema, registry=self.registry)
            errors = sorted(validator.iter_errors(document), key=lambda item: str(list(item.path)))
            for error in errors:
                location = "/".join(str(part) for part in error.absolute_path) or "$"
                self.fail(path, f"schema at {location}: {error.message}")
        except Exception as exc:
            self.fail(path, f"schema resolution failed: {type(exc).__name__}: {exc}")

    def model_fields(self, model_dir: Path) -> dict[str, dict[str, set[str]]]:
        self.load(model_dir / "definition.pbism")
        model_path = model_dir / "model.bim"
        tmdl_path = model_dir / "definition"
        if model_path.is_file() == tmdl_path.is_dir():
            self.fail(model_dir, "keep exactly one of model.bim and definition/ (TMDL)")
            return {}
        if tmdl_path.is_dir():
            try:
                from tmdl_inventory import inventory
                document = inventory(tmdl_path)
            except (OSError, ValueError) as exc:
                self.fail(tmdl_path, f"TMDL inventory: {exc}")
                return {}
        else:
            document = self.load(model_path)
        model = document.get("model", {}) if isinstance(document, dict) else {}
        tables = model.get("tables", [])
        fields = {}
        folded = set()
        for table in tables:
            name = table.get("name", "")
            if not name or name.casefold() in folded:
                self.fail(model_path, f"empty or duplicate table name: {name!r}")
            folded.add(name.casefold())
            columns = [col.get("name", "") for col in table.get("columns", [])]
            measures = [measure.get("name", "") for measure in table.get("measures", [])]
            for kind, names in (("columns", columns), ("measures", measures)):
                if any(not item for item in names) or len({item.casefold() for item in names}) != len(names):
                    self.fail(model_path, f"table {name!r} has empty or duplicate {kind}")
            fields[name] = {"Column": set(columns), "Measure": set(measures)}
        for relationship in model.get("relationships", []):
            for end in ("from", "to"):
                table = relationship.get(f"{end}Table")
                column = relationship.get(f"{end}Column")
                if table not in fields or column not in fields[table]["Column"]:
                    self.fail(model_path, f"relationship references unknown field {table!r}[{column!r}]")
        return fields

    def check_fields(self, path: Path, document: Any, fields: dict) -> None:
        for node in walk(document):
            for kind in ("Column", "Measure"):
                ref = node.get(kind)
                if not isinstance(ref, dict):
                    continue
                source = ref.get("Expression", {}).get("SourceRef", {})
                # Filter definitions may reference a local Source alias. Those
                # require query-scope resolution and are covered by JSON schema.
                table = source.get("Entity")
                if table is None:
                    continue
                name = ref.get("Property")
                if table not in fields:
                    self.fail(path, f"field refers to unknown table {table!r}")
                elif name not in fields[table][kind]:
                    self.fail(path, f"unknown {kind.lower()} {table!r}[{name!r}]")

    def report(self, report_dir: Path) -> None:
        definition_path = report_dir / "definition.pbir"
        definition = self.load(definition_path)
        by_path = definition.get("datasetReference", {}).get("byPath", {})
        if not by_path:
            self.fail(definition_path, "self-contained projects must reference a local semantic model byPath")
            return
        model_dir = self.target(report_dir, by_path.get("path"), definition_path)
        fields = self.model_fields(model_dir) if model_dir is not None else {}
        metadata_path = report_dir / "definition/pages/pages.json"
        metadata = self.load(metadata_path)
        order = metadata.get("pageOrder", [])
        if len(order) != len(set(order)):
            self.fail(metadata_path, "pageOrder contains duplicate names")
        active = metadata.get("activePageName")
        if active and active not in order:
            self.fail(metadata_path, "activePageName is absent from pageOrder")
        actual = {p.parent.name for p in (report_dir / "definition/pages").glob("*/page.json")}
        if set(order) != actual:
            self.fail(metadata_path, f"pageOrder does not match page folders: {sorted(set(order) ^ actual)}")
        for page_dir in sorted((report_dir / "definition/pages").glob("*/")):
            page_path = page_dir / "page.json"
            if not page_path.exists():
                continue
            page = self.load(page_path)
            self.page_count += 1
            if page.get("name") != page_dir.name:
                self.fail(page_path, "page name differs from its directory name")
            visuals = {}
            for visual_path in sorted((page_dir / "visuals").glob("*/visual.json")):
                visual = self.load(visual_path)
                self.visual_count += 1
                name = visual.get("name")
                if name != visual_path.parent.name:
                    self.fail(visual_path, "visual name differs from its directory name")
                if name in visuals:
                    self.fail(visual_path, "duplicate visual name on page")
                visuals[name] = visual
                self.check_fields(visual_path, visual, fields)
                position = visual.get("position", {})
                for coordinate, extent, limit in (("x", "width", "width"), ("y", "height", "height")):
                    start, size, bound = position.get(coordinate), position.get(extent), page.get(limit)
                    if all(isinstance(x, (int, float)) for x in (start, size, bound)):
                        if start < 0 or size <= 0 or start + size > bound + 0.01:
                            self.fail(visual_path, f"{coordinate}/{extent} places visual outside the page")
            for interaction in page.get("visualInteractions", []):
                for end in ("source", "target"):
                    if interaction.get(end) not in visuals:
                        self.fail(page_path, f"interaction {end} references an unknown visual")
            self.check_fields(page_path, page, fields)
        report_path = report_dir / "definition/report.json"
        report = self.load(report_path)
        self.check_fields(report_path, report, fields)
        for package in report.get("resourcePackages", []):
            if package.get("type") != "RegisteredResources":
                continue
            resource_dir = report_dir / "StaticResources/RegisteredResources"
            for item in package.get("items", []):
                target = self.target(resource_dir, item.get("path"), report_path)
                if target is not None and not target.is_file():
                    self.fail(report_path, f"registered resource is missing: {item.get('path')}")

    def run(self) -> dict[str, Any]:
        for path in sorted(self.root.rglob("*")):
            if path.is_file() and path.suffix in (".json", ".pbip", ".pbir", ".pbism", ".bim"):
                document = self.load(path)
                self.validate_schema(path, document)
        projects = sorted(self.root.glob("*.pbip"))
        if not projects:
            self.fail(self.root, "no .pbip entry point found")
        reports = set()
        for path in projects:
            project = self.load(path)
            for artifact in project.get("artifacts", []):
                report = artifact.get("report", {})
                target = self.target(path.parent, report.get("path"), path)
                if target is not None:
                    reports.add(target)
        if not reports:
            self.fail(self.root, "no report artifact referenced by project")
        for report in sorted(reports):
            self.report(report)
        return {
            "project": str(self.root),
            "valid": not self.errors,
            "json_files": len(self.documents),
            "schema_validated_files": self.schema_count,
            "pages": self.page_count,
            "visuals": self.visual_count,
            "errors": self.errors,
            "scope": "Offline JSON schemas, cross-file references and generated-TMDL inventory only; no native TMDL parsing, M/DAX execution or rendering.",
        }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", type=Path, help="PBIP files, project folders, or a parent of project folders")
    parser.add_argument("--schemas", type=Path, default=Path(__file__).resolve().parents[1] / "inst/schemas/registry.json")
    parser.add_argument("--json", action="store_true", help="write machine-readable results")
    args = parser.parse_args()
    try:
        schemas = json.loads(args.schemas.read_text(encoding="utf-8"))
        theme_path = args.schemas.parent / "theme-schema.json"
        if theme_path.is_file():
            theme_uri = ("https://raw.githubusercontent.com/microsoft/powerbi-desktop-samples/"
                         "main/Report%20Theme%20JSON%20Schema/reportThemeSchema-2.159.json")
            schemas[theme_uri] = json.loads(theme_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        parser.error(f"cannot load schema registry: {exc}")
    roots = set()
    for path in args.paths:
        if path.is_file() and path.suffix == ".pbip":
            roots.add(path.parent.resolve())
        elif path.is_dir():
            roots.update(item.parent.resolve() for item in path.rglob("*.pbip"))
        else:
            parser.error(f"input is not a project file or folder: {path}")
    if not roots:
        parser.error("no .pbip projects found in the supplied paths")
    results = [ProjectValidator(root, schemas).run() for root in sorted(roots)]
    if args.json:
        print(json.dumps(results, indent=2))
    else:
        for result in results:
            status = "PASS" if result["valid"] else "FAIL"
            print(f"{status} {result['project']}: {result['schema_validated_files']} schema files, "
                  f"{result['pages']} pages, {result['visuals']} visuals")
            for error in result["errors"]:
                print(f"  {error}")
        print("Scope: offline schemas and references; Power BI Desktop rendering is a separate gate.")
    return 0 if all(result["valid"] for result in results) else 1


if __name__ == "__main__":
    sys.exit(main())
