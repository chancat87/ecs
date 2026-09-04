#!/usr/bin/env python3
"""Embed the validated basics DoH catalog into standalone shell entrypoints."""

from __future__ import annotations

import argparse
import ipaddress
import json
from pathlib import Path
from urllib.parse import urlparse


BEGIN = "## DOH_BOOTSTRAP_CATALOG_BEGIN"
END = "## DOH_BOOTSTRAP_CATALOG_END"


def parse_catalog(path: Path) -> list[tuple[str, str, str, list[str], list[str]]]:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != "goecs.resolver-endpoints/v1":
        raise ValueError("unexpected basics resolver catalog schema")
    entries: list[tuple[str, str, str, list[str], list[str]]] = []
    seen: set[tuple[str, str]] = set()
    for item in manifest.get("endpoints", []):
        name = str(item.get("name", "")).strip()
        endpoint = str(item.get("url", "")).strip()
        parsed = urlparse(endpoint)
        if not name or parsed.scheme != "https" or not parsed.hostname:
            continue
        key = (name, endpoint)
        if key in seen:
            continue
        seen.add(key)
        addresses: list[str] = []
        for value in item.get("addresses", []):
            try:
                normalized = str(ipaddress.ip_address(str(value).strip()))
            except ValueError:
                continue
            if normalized not in addresses:
                addresses.append(normalized)
        ipv4 = [value for value in addresses if ipaddress.ip_address(value).version == 4]
        if ipv4:
            entries.append((name, parsed.hostname, endpoint, addresses, ipv4))
    if len(entries) < 2:
        raise ValueError("basics catalog did not provide enough usable DoH endpoints")
    return entries


def render(entries: list[tuple[str, str, str, list[str], list[str]]]) -> str:
    lines = [BEGIN, "DOH_BOOTSTRAP_SPECS=("]
    for name, host, endpoint, addresses, ipv4 in entries:
        if "|" in name:
            raise ValueError(f"unsupported provider name: {name!r}")
        lines.append(f'    "{name}|{host}|{endpoint}|{",".join(addresses)}|{",".join(ipv4)}"')
    lines.extend([")", END])
    return "\n".join(lines)


def update_script(path: Path, block: str, check: bool) -> bool:
    contents = path.read_text(encoding="utf-8")
    start, end = contents.find(BEGIN), contents.find(END)
    if start < 0 or end < 0 or end < start:
        raise ValueError(f"{path}: catalog markers are missing or malformed")
    end += len(END)
    updated = contents[:start] + block + contents[end:]
    changed = updated != contents
    if changed and not check:
        path.write_text(updated, encoding="utf-8")
    return changed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True, help="basics endpoints_embed.json")
    parser.add_argument("--script", type=Path, action="append", required=True, help="shell script to update")
    parser.add_argument("--check", action="store_true", help="fail if generated content differs")
    args = parser.parse_args()
    block = render(parse_catalog(args.input))
    changed = [path for path in args.script if update_script(path, block, args.check)]
    if args.check and changed:
        raise SystemExit("embedded DoH catalog is stale in: " + ", ".join(map(str, changed)))
    print(("updated " if changed else "verified ") + "embedded DoH catalog" + (" in " + ", ".join(map(str, changed)) if changed else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
