#!/usr/bin/python3

"""Inspect DOCA AI capability contracts and source-backed SDK evidence."""

import argparse
import json
import re
import sys
from pathlib import Path

from ai_contracts import CATALOG_PATH, print_json, read_json


MAX_API_SYMBOLS_PER_FILE = 80
MAX_API_INDEX_FILES = 80
MAX_API_INDEX_ITEMS = 40
DOCA_SYMBOL_RE = re.compile(r"\b(doca_[A-Za-z0-9_]+)\s*\(")
DOCA_VERSION_SYMBOL_RE = re.compile(r"\b(doca_[A-Za-z0-9_]+)\b")
DOCA_DEP_RE = re.compile(r"dependency\(\s*['\"]([^'\"]*doca[^'\"]*)['\"]")
DOCA_INCLUDE_RE = re.compile(r"^\s*#\s*include\s+[<\"]([^>\"]*doca[^>\"]*\.h)[>\"]", re.MULTILINE)


def load_catalog(repo_root):
    """Load the capability catalog from a source package or repository root."""
    return read_json(Path(repo_root) / CATALOG_PATH)


def _find_capability(catalog, capability_id):
    """Return the catalog entry for one capability ID."""
    for capability in catalog.get("capabilities", []):
        if capability.get("id") == capability_id:
            return capability
    raise KeyError(capability_id)


def _matches_filter(value, symbol_filter):
    """Return whether a value should be kept for the optional text filter."""
    if not symbol_filter:
        return True
    return symbol_filter.lower() in value.lower()


def _read_text(path):
    """Read source text while tolerating non-UTF-8 bytes."""
    return path.read_text(encoding="utf-8", errors="ignore")


def _unique_sorted(values):
    """Return a sorted list with duplicate values removed."""
    return sorted(dict.fromkeys(values))


def _iter_files_for_capability(repo_root, capability):
    """Yield package-relative files matched by a capability's source globs."""
    seen = set()
    for pattern in capability.get("source_globs", []):
        matches = sorted(repo_root.glob(pattern))
        if not matches and not any(char in pattern for char in "*?["):
            matches = [repo_root / pattern]
        for path in matches:
            if not path.is_file():
                continue
            try:
                rel_path = path.relative_to(repo_root).as_posix()
            except ValueError:
                continue
            if rel_path in seen:
                continue
            seen.add(rel_path)
            yield rel_path, path


def _collect_public_headers(repo_root, capability, symbol_filter):
    """Collect SDK header paths and exported-looking symbols for a capability."""
    headers = []
    for rel_path, path in _iter_files_for_capability(repo_root, capability):
        if path.suffix != ".h" or "/include/public/" not in f"/{rel_path}":
            continue
        symbols = _unique_sorted(
            symbol
            for symbol in DOCA_SYMBOL_RE.findall(_read_text(path))
            if _matches_filter(symbol, symbol_filter)
        )
        if symbol_filter and not symbols and not _matches_filter(rel_path, symbol_filter):
            continue
        headers.append({
            "path": rel_path,
            "symbol_count": len(symbols),
            "symbols": symbols[:MAX_API_SYMBOLS_PER_FILE],
            "truncated_symbols": max(0, len(symbols) - MAX_API_SYMBOLS_PER_FILE),
        })
        if len(headers) >= MAX_API_INDEX_FILES:
            break
    return headers


def _collect_version_maps(repo_root, capability, symbol_filter):
    """Collect version-map symbols for ABI-facing SDK evidence."""
    version_maps = []
    for rel_path, path in _iter_files_for_capability(repo_root, capability):
        if path.name != "version.map":
            continue
        symbols = _unique_sorted(
            symbol
            for symbol in DOCA_VERSION_SYMBOL_RE.findall(_read_text(path))
            if _matches_filter(symbol, symbol_filter)
        )
        if symbol_filter and not symbols and not _matches_filter(rel_path, symbol_filter):
            continue
        version_maps.append({
            "path": rel_path,
            "symbol_count": len(symbols),
            "symbols": symbols[:MAX_API_SYMBOLS_PER_FILE],
            "truncated_symbols": max(0, len(symbols) - MAX_API_SYMBOLS_PER_FILE),
        })
        if len(version_maps) >= MAX_API_INDEX_ITEMS:
            break
    return version_maps


def _collect_build_dependencies(repo_root, capability, symbol_filter):
    """Collect DOCA dependency names from nearby Meson build files."""
    dependencies = []
    for rel_path, path in _iter_files_for_capability(repo_root, capability):
        if path.name not in {"meson.build"}:
            continue
        deps = _unique_sorted(DOCA_DEP_RE.findall(_read_text(path)))
        if symbol_filter:
            deps = [
                dep
                for dep in deps
                if _matches_filter(dep, symbol_filter) or _matches_filter(rel_path, symbol_filter)
            ]
        if not deps:
            continue
        dependencies.append({
            "path": rel_path,
            "dependencies": deps,
        })
        if len(dependencies) >= MAX_API_INDEX_ITEMS:
            break
    return dependencies


def _collect_sample_references(repo_root, capability, symbol_filter):
    """Collect sample and application includes or symbols for local examples."""
    references = []
    for rel_path, path in _iter_files_for_capability(repo_root, capability):
        if not rel_path.startswith(("samples/", "applications/")):
            continue
        if path.suffix not in {".c", ".cc", ".cpp", ".h", ".hpp"}:
            continue
        text = _read_text(path)
        includes = _unique_sorted(DOCA_INCLUDE_RE.findall(text))
        symbols = _unique_sorted(
            symbol
            for symbol in DOCA_SYMBOL_RE.findall(text)
            if _matches_filter(symbol, symbol_filter)
        )
        if symbol_filter and not symbols and not _matches_filter(rel_path, symbol_filter):
            continue
        if not includes and not symbols:
            continue
        references.append({
            "path": rel_path,
            "doca_includes": includes[:MAX_API_SYMBOLS_PER_FILE],
            "referenced_symbols": symbols[:MAX_API_SYMBOLS_PER_FILE],
            "truncated_symbols": max(0, len(symbols) - MAX_API_SYMBOLS_PER_FILE),
        })
        if len(references) >= MAX_API_INDEX_ITEMS:
            break
    return references


def build_api_index(repo_root, capability, symbol_filter=None):
    """Build a compact SDK API evidence bundle for one capability."""
    return {
        "id": capability["id"],
        "summary": capability["summary"],
        "source_globs": capability.get("source_globs", []),
        "load_next": capability.get("load_next", []),
        "symbol_filter": symbol_filter,
        "sdk_headers": _collect_public_headers(repo_root, capability, symbol_filter),
        "version_maps": _collect_version_maps(repo_root, capability, symbol_filter),
        "build_dependencies": _collect_build_dependencies(repo_root, capability, symbol_filter),
        "sample_references": _collect_sample_references(repo_root, capability, symbol_filter),
        "response_contract": {
            "api_lookup_outputs": [
                "library_name",
                "key_functions",
                "required_packages",
                "code_snippet",
            ],
            "lifecycle_outputs": [
                "lifecycle_steps",
                "code_skeleton",
                "error_handling_notes",
            ],
        },
    }


def build_lookup_payload(catalog, mode, capability_id=None, repo_root=None, symbol_filter=None):
    """Build the JSON payload for one lookup CLI mode."""
    if mode == "list":
        capabilities = []
        for capability in catalog.get("capabilities", []):
            entry = {
                "id": capability["id"],
                "summary": capability["summary"],
            }
            persona_routes = capability.get("persona_routes", {})
            if persona_routes:
                entry["personas"] = sorted(persona_routes)
            capabilities.append(entry)
        return {
            "capabilities": capabilities,
        }

    capability = _find_capability(catalog, capability_id)
    if mode == "summary":
        return {
            "id": capability["id"],
            "summary": capability["summary"],
            "tasks": capability["tasks"],
            "load_next": capability["load_next"],
        }
    if mode == "detail":
        return capability
    if mode == "api-index":
        if repo_root is None:
            raise ValueError("repo_root is required for api-index")
        return build_api_index(Path(repo_root), capability, symbol_filter)
    raise ValueError(f"Unsupported lookup mode: {mode}")


def main(argv):
    """Parse command-line arguments and print one JSON lookup result."""
    parser = argparse.ArgumentParser(description="Lookup DOCA AI capability guidance")
    parser.add_argument("--repo-root", default=".", help="Repository root or packaged source root")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--list", action="store_true", help="List available capabilities")
    group.add_argument("--summary", help="Print a compact capability summary")
    group.add_argument("--detail", help="Print full capability catalog entry")
    group.add_argument("--api-index", help="Build a source-backed SDK API inventory for a capability")
    parser.add_argument(
        "--symbol-filter",
        help="Limit API inventory to symbols, files, or dependencies containing this text",
    )
    args = parser.parse_args(argv)

    try:
        catalog = load_catalog(Path(args.repo_root))
        if args.list:
            payload = build_lookup_payload(catalog, "list")
        elif args.summary:
            payload = build_lookup_payload(catalog, "summary", args.summary)
        elif args.api_index:
            payload = build_lookup_payload(
                catalog,
                "api-index",
                args.api_index,
                Path(args.repo_root),
                args.symbol_filter,
            )
        else:
            payload = build_lookup_payload(catalog, "detail", args.detail)
    except (OSError, json.JSONDecodeError, KeyError, ValueError) as error:
        print(f"Capability lookup failed: {error}", file=sys.stderr)
        return 1

    print_json(payload)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
