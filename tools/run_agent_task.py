#!/usr/bin/python3

"""Run package-safe DOCA AI task helpers."""

import argparse
import json
import sys
from pathlib import Path


DISCOVERY_TASK_ID = 'discover-doca-environment'
BUILD_TASK_ID = 'build-sdk-sample'


def read_json(path):
    """Load a JSON file, or return an empty mapping when it is absent."""
    if not path.is_file():
        return {}
    with open(path, 'r', encoding='utf-8') as fd:
        return json.load(fd)


def package_prefix(repo_root):
    """Return the package layout prefix that contains AI contracts."""
    if (repo_root / 'contracts' / 'agent-manifest.json').is_file():
        return Path('')
    return Path('docs') / 'ai'


def prefixed(prefix, *parts):
    """Join path parts under the prefix unless the prefix is empty."""
    path = Path(*parts)
    return path if not prefix.parts else prefix / path


def manifest_payload(repo_root):
    """Load the task manifest from a package or source checkout."""
    prefix = package_prefix(repo_root)
    return read_json(repo_root / prefixed(prefix, 'contracts/agent-manifest.json'))


def task_entries(manifest):
    """Return task manifest entries keyed by task ID."""
    return {
        task.get('id'): task
        for task in manifest.get('tasks', [])
        if isinstance(task, dict) and task.get('id')
    }


def capability_ids(manifest):
    """Return sorted capability IDs visible in the manifest."""
    return sorted(
        capability.get('id')
        for capability in manifest.get('capabilities', [])
        if isinstance(capability, dict) and capability.get('id')
    )


def base_result(task_id, task=None):
    """Create the common blocked task-result shape."""
    return {
        'task_id': task_id,
        'status': 'blocked',
        'risk_class': task.get('risk_class', 'unknown') if task else 'unknown',
        'command_kind': task.get('command_kind', 'unknown') if task else 'unknown',
        'outputs': {},
        'errors': [],
        'observations': [],
        'recovery': [],
        'metadata': {},
    }


def add_error(result, code, message, recovery):
    """Append one structured error and its matching recovery hint."""
    result['errors'].append({
        'code': code,
        'message': message,
        'recovery': recovery,
    })
    result['recovery'].append(recovery)


def source_version(repo_root):
    """Read the package source version when VERSION is present."""
    path = repo_root / 'VERSION'
    if not path.is_file():
        return None
    lines = path.read_text(errors='ignore').splitlines()
    return lines[0].strip() if lines else None


def public_header_roots(repo_root):
    """Return roots that may contain SDK headers in the source view."""
    roots = []
    for rel_path in (
            Path('libs'),
            Path('include'),
    ):
        path = repo_root / rel_path
        if path.is_dir():
            roots.append(path)
    return roots


def experimental_api_summary(repo_root):
    """Count DOCA_EXPERIMENTAL markers in visible SDK headers."""
    marker = 'DOCA_EXPERIMENTAL'
    header_count = 0
    marker_count = 0
    headers = []
    for root in public_header_roots(repo_root):
        for path in sorted(root.rglob('*.h')):
            rel_path = path.relative_to(repo_root)
            if 'private' in rel_path.parts:
                continue
            text = path.read_text(errors='ignore')
            count = text.count(marker)
            header_count += 1
            marker_count += count
            if count:
                headers.append({
                    'path': rel_path.as_posix(),
                    'experimental_marker_count': count,
                })
    return {
        'status': 'measured',
        'marker': marker,
        'header_count': header_count,
        'headers_with_experimental': len(headers),
        'experimental_marker_count': marker_count,
        'headers': headers,
    }


def discover(repo_root, task, manifest):
    """Build a read-only discovery result for source metadata and contracts."""
    result = base_result(DISCOVERY_TASK_ID, task)
    version = source_version(repo_root)
    result['outputs'] = {
        'source_version': version,
        'available_capabilities': capability_ids(manifest),
        'experimental_api_summary': experimental_api_summary(repo_root),
    }
    if version is None:
        add_error(
            result,
            'missing_source_metadata',
            'VERSION is absent or empty in this source view.',
            'Run from a complete DOCA source view or report that source metadata is unavailable.',
        )
        return result
    result['status'] = 'success'
    result['outputs']['source_version'] = version
    return result


def existing_relpaths(repo_root, relpaths):
    """Return existing package-relative files from a candidate path list."""
    found = []
    for relpath in relpaths:
        if (repo_root / relpath).is_file():
            found.append(relpath.as_posix())
    return found


def build_sample(repo_root, task, focus_path):
    """Plan sample or application build evidence without running a build."""
    result = base_result(BUILD_TASK_ID, task)
    if not focus_path:
        add_error(
            result,
            'invalid_focus_path',
            'A sample or application focus path is required.',
            'Pass --focus-path with one package-relative sample or application path.',
        )
        return result

    rel_focus = Path(focus_path)
    if rel_focus.is_absolute() or '..' in rel_focus.parts:
        add_error(
            result,
            'invalid_focus_path',
            'The focus path must stay inside the package root.',
            'Pass a package-relative sample or application path.',
        )
        return result

    full_focus = repo_root / rel_focus
    if not full_focus.exists():
        add_error(
            result,
            'invalid_focus_path',
            'The focus path does not exist in this source view.',
            'Run from a DOCA source package that contains the selected sample or application.',
        )
        return result

    target_dir = rel_focus if full_focus.is_dir() else rel_focus.parent
    package_build_files = existing_relpaths(repo_root, [
        target_dir / 'meson.build.public',
        target_dir / 'meson.build',
    ])
    package_dependency_files = existing_relpaths(repo_root, [
        target_dir / 'dependencies' / 'meson.build',
        target_dir.parent / 'dependencies' / 'meson.build',
    ])
    result['status'] = 'success'
    result['outputs'] = {
        'target_path': rel_focus.as_posix(),
        'target_dir': target_dir.as_posix(),
        'configured': False,
        'built_targets': [],
        'build_dir': '',
        'package_build_files': package_build_files,
        'package_dependency_files': package_dependency_files,
        'commands': [],
        'unmet_prerequisites': [],
    }
    result['observations'].append(
        'Planner-only result; no build output, package install, runtime command, or device action was run.'
    )
    return result


def unsupported(task_id, manifest):
    """Return a structured error for a task absent from the package."""
    result = base_result(task_id)
    available = sorted(task_entries(manifest))
    add_error(
        result,
        'unsupported_task',
        'The requested task is not available in this package.',
        'Use one of the task IDs listed in contracts/agent-manifest.json.',
    )
    result['outputs']['available_tasks'] = available
    return result


def main(argv):
    """Parse command-line arguments and print one task result as JSON."""
    parser = argparse.ArgumentParser(description='Run packaged DOCA AI tasks')
    parser.add_argument('--task', required=True)
    parser.add_argument('--repo-root', default='.')
    parser.add_argument('--focus-path')
    args = parser.parse_args(argv)

    repo_root = Path(args.repo_root).resolve()
    manifest = manifest_payload(repo_root)
    if not manifest:
        result = base_result(args.task)
        add_error(
            result,
            'missing_manifest',
            'The package does not contain an agent manifest.',
            'Run from the package root or from a DOCA source package with AI contracts.',
        )
    else:
        tasks = task_entries(manifest)
        task = tasks.get(args.task)
        if task is None:
            result = unsupported(args.task, manifest)
        elif args.task == DISCOVERY_TASK_ID:
            result = discover(repo_root, task, manifest)
        elif args.task == BUILD_TASK_ID:
            result = build_sample(repo_root, task, args.focus_path)
        else:
            result = unsupported(args.task, manifest)

    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write('\n')
    return 0 if result.get('status') == 'success' else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
