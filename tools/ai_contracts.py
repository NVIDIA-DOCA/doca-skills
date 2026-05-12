import json
from pathlib import Path


CATALOG_PATH = Path('contracts/capability-catalog.json')


def read_json(path):
    with Path(path).open('r', encoding='utf-8') as fd:
        return json.load(fd)


def render_json(payload):
    return json.dumps(payload, indent=2, sort_keys=True) + '\n'


def print_json(payload):
    print(render_json(payload), end='')
