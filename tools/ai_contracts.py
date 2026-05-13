"""Common JSON helpers for package-local DOCA AI tools."""

import json
from pathlib import Path


CATALOG_PATH = Path('contracts/capability-catalog.json')


def read_json(path):
    """Load a JSON document from a filesystem path."""
    with Path(path).open('r', encoding='utf-8') as fd:
        return json.load(fd)


def render_json(payload):
    """Render a payload as stable, newline-terminated JSON."""
    return json.dumps(payload, indent=2, sort_keys=True) + '\n'


def print_json(payload):
    """Print a payload using the package JSON formatting convention."""
    print(render_json(payload), end='')
