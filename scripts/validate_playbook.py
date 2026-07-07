from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path
from typing import Any

import yaml


DEFAULT_ROOT = Path(__file__).resolve().parents[1]
ROOT = DEFAULT_ROOT
CONFIG_DIR = ROOT / "src" / "Configuration"
IMAGES_DIR = ROOT / "src" / "Images"
LINE_COMMENT_RE = re.compile(r"(?m)^\s*//.*$")
TRAILING_COMMA_RE = re.compile(r",(\s*[}\]])")


class PlaybookLoader(yaml.SafeLoader):
    pass


def construct_unknown(loader: PlaybookLoader, node: yaml.Node) -> Any:
    tag = node.tag.removeprefix("!")
    if isinstance(node, yaml.MappingNode):
        value = loader.construct_mapping(node, deep=True)
        value["__tag__"] = tag
        return value
    if isinstance(node, yaml.SequenceNode):
        return {"__tag__": tag, "items": loader.construct_sequence(node, deep=True)}
    return {"__tag__": tag, "value": loader.construct_scalar(node)}


PlaybookLoader.add_multi_constructor("!", lambda loader, suffix, node: construct_unknown(loader, node))


def iter_nodes(value: Any) -> Any:
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from iter_nodes(child)
    elif isinstance(value, list):
        for child in value:
            yield from iter_nodes(child)


def parse_yaml(path: Path, errors: list[str]) -> Any:
    try:
        return yaml.load(path.read_text(encoding="utf-8"), Loader=PlaybookLoader)
    except yaml.YAMLError as exc:
        errors.append(f"{path.relative_to(ROOT)}: invalid YAML: {exc}")
        return None


def parse_json_or_jsonc(path: Path) -> None:
    text = path.read_text(encoding="utf-8-sig")
    try:
        json.loads(text)
        return
    except json.JSONDecodeError:
        jsonc = LINE_COMMENT_RE.sub("", text)
        jsonc = TRAILING_COMMA_RE.sub(r"\1", jsonc)
        json.loads(jsonc)


def validate_structured_files(errors: list[str]) -> dict[Path, Any]:
    parsed_yaml: dict[Path, Any] = {}
    for path in sorted(ROOT.rglob("*")):
        if ".git" in path.parts or not path.is_file():
            continue
        suffix = path.suffix.lower()
        if suffix in {".yml", ".yaml"}:
            parsed_yaml[path] = parse_yaml(path, errors)
        elif suffix == ".json":
            try:
                parse_json_or_jsonc(path)
            except json.JSONDecodeError as exc:
                errors.append(f"{path.relative_to(ROOT)}: invalid JSON/JSONC: {exc}")
        elif suffix == ".xml" or path.name == "playbook.conf":
            try:
                ET.parse(path)
            except ET.ParseError as exc:
                errors.append(f"{path.relative_to(ROOT)}: invalid XML: {exc}")
    return parsed_yaml


def validate_task_references(parsed_yaml: dict[Path, Any], errors: list[str]) -> None:
    for source, document in parsed_yaml.items():
        if document is None:
            continue

        seen_tasks: dict[str, int] = {}
        for node in iter_nodes(document):
            if node.get("__tag__") != "task":
                continue
            task_path = node.get("path")
            if not isinstance(task_path, str) or not task_path.strip():
                errors.append(f"{source.relative_to(ROOT)}: !task action missing path")
                continue

            normalized = task_path.replace("\\", "/")
            if normalized in seen_tasks:
                errors.append(
                    f"{source.relative_to(ROOT)}: duplicate !task reference {task_path!r}"
                )
            seen_tasks[normalized] = seen_tasks.get(normalized, 0) + 1

            target = CONFIG_DIR / Path(*normalized.split("/"))
            if not target.is_file():
                errors.append(
                    f"{source.relative_to(ROOT)}: referenced task does not exist: {task_path}"
                )


def validate_playbook_conf(errors: list[str]) -> None:
    conf_path = ROOT / "src" / "playbook.conf"
    tree = ET.parse(conf_path)
    root = tree.getroot()

    option_names: dict[str, int] = {}
    for option in root.findall(".//Name"):
        if option.text is None:
            continue
        name = option.text.strip()
        if not name:
            continue
        if name in option_names:
            errors.append(f"src/playbook.conf: duplicate option/package name {name!r}")
        option_names[name] = option_names.get(name, 0) + 1

    for icon in root.findall(".//Icon"):
        if icon.text is None:
            continue
        icon_name = icon.text.strip()
        if icon_name and not (IMAGES_DIR / icon_name).is_file():
            errors.append(f"src/playbook.conf: missing icon file {icon_name!r}")


def collect_registry_duplicate_warnings(parsed_yaml: dict[Path, Any]) -> list[str]:
    warnings: list[str] = []
    for source, document in parsed_yaml.items():
        if document is None:
            continue

        seen: dict[tuple[Any, ...], int] = defaultdict(int)
        for node in iter_nodes(document):
            if node.get("__tag__") != "registryValue":
                continue
            key = (
                str(node.get("path", "")).lower(),
                str(node.get("value", "")).lower(),
                str(node.get("operation", "set")).lower(),
                str(node.get("option", "")),
            )
            seen[key] += 1

        duplicates = [key for key, count in seen.items() if count > 1]
        for key in duplicates:
            warnings.append(
                f"{source.relative_to(ROOT)}: duplicate registryValue path={key[0]!r} value={key[1]!r} option={key[3]!r}"
            )
    return warnings


def configure_root(root: Path) -> None:
    global ROOT, CONFIG_DIR, IMAGES_DIR

    ROOT = root.resolve()
    CONFIG_DIR = ROOT / "src" / "Configuration"
    IMAGES_DIR = ROOT / "src" / "Images"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate ReviOS playbook assets.")
    parser.add_argument(
        "--root",
        type=Path,
        default=DEFAULT_ROOT,
        help="Playbook root to validate. Defaults to the repository root.",
    )
    args = parser.parse_args(argv)
    configure_root(args.root)

    errors: list[str] = []
    parsed_yaml = validate_structured_files(errors)

    if not errors:
        validate_task_references(parsed_yaml, errors)
        validate_playbook_conf(errors)

    warnings = collect_registry_duplicate_warnings(parsed_yaml)
    for warning in warnings:
        print(f"warning: {warning}")

    if errors:
        print("Playbook validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(
        f"Validated {len(parsed_yaml)} YAML files plus JSON/XML assets; {len(warnings)} duplicate registry warnings."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
