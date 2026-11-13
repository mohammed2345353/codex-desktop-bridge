"""Local metadata only. No network, model calls, imports of scanned code, or secrets."""
import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import tomllib


def metadata(path):
    # Basic frontmatter extraction, not a full YAML parser. Keep unsupported forms unknown.
    raw = path.read_bytes()
    text = raw.decode('utf-8-sig')
    match = re.match(r'^---\s*\r?\n(.*?)\r?\n---(?:\r?\n|$)', text, re.S)
    fields = {}
    if match:
        for key in ('name', 'description'):
            found = re.search(r'^' + key + r':\s*(.*?)\s*$', match[1], re.M)
            if found and found[1] not in ('', '|', '>', '|-', '>-'):
                fields[key] = found[1].strip('\"\'')
    return {**fields, 'path': str(path), 'sha256': hashlib.sha256(raw).hexdigest(),
            'presence': 'local-file', 'readiness': 'unverified',
            'requirements': 'uninspected', 'cost': 'unknown',
            'metadata_status': 'basic-fields' if len(fields) == 2 else 'needs-inspection'}


def collect(roots, config=None):
    rows, errors, coverage = [], [], []
    seen = set()
    for root in roots:
        root = Path(root)
        if not root.is_dir():
            errors.append({'source': str(root), 'error': 'missing-or-inaccessible-root'})
            continue
        count = 0
        # Never follow symlinks/junctions outside the declared roots.
        def walk(directory):
            try:
                for child in directory.iterdir():
                    if child.is_symlink() or child.is_junction():
                        continue
                    if child.is_dir():
                        yield from walk(child)
                    elif child.name == 'SKILL.md':
                        yield child
            except OSError as exc:
                errors.append({'source': str(directory), 'error': type(exc).__name__})
        for path in walk(root):
            identity = str(path.resolve()).casefold()
            if identity in seen:
                continue
            seen.add(identity)
            try:
                row = metadata(path)
                row['root'] = str(root)
                rows.append(row)
                count += 1
            except (OSError, UnicodeError) as exc:
                errors.append({'source': str(path), 'error': type(exc).__name__})
        coverage.append({'root': str(root), 'skill_files': count})
    groups = defaultdict(list)
    for row in rows:
        groups[row['sha256']].append(row['path'])
    mcp, plugins = [], []
    if config:
        try:
            data = tomllib.loads(Path(config).read_text(encoding='utf-8-sig'))
            # Explicit allowlist: do not return commands, URLs, args, headers, or env values.
            mcp = [{'name': name, 'enabled': value.get('enabled', 'unspecified'),
                    'connection': 'unverified'} for name, value in data.get('mcp_servers', {}).items()]
            plugins = [{'name': name, 'enabled': value.get('enabled', 'unspecified')}
                       for name, value in data.get('plugins', {}).items()]
        except (OSError, ValueError) as exc:
            errors.append({'source': str(config), 'error': type(exc).__name__})
    return {'schema_version': 1, 'checked_at': datetime.now(timezone.utc).isoformat(),
            'scope': 'local metadata only; not installed-account or session inventory',
            'coverage': coverage, 'skill_files': len(rows), 'skills': rows,
            'exact_duplicate_groups': [paths for paths in groups.values() if len(paths) > 1],
            'same_name_counts': dict(Counter(r.get('name', '(unparsed)') for r in rows)),
            'configured_mcp': mcp, 'configured_plugins': plugins, 'errors': errors}


def markdown(data):
    def cell(value):
        return str(value).replace('|', '\\|').replace('\n', ' ').replace('\r', ' ')
    lines = ['# Local tool metadata inventory', '', data['scope'], '',
             'Checked: ' + data['checked_at'], '',
             '| Name | Description | Presence / readiness / cost | Path |',
             '|---|---|---|---|']
    for row in data['skills']:
        lines.append('| ' + ' | '.join(map(cell, [row.get('name', '(needs inspection)'),
                     row.get('description', '(needs inspection)'),
                     'local file / unverified / unknown', row['path']])) + ' |')
    lines += ['', '## Coverage and errors', '', '```json',
              json.dumps({k: data[k] for k in ('coverage', 'errors', 'configured_mcp', 'configured_plugins')},
                         ensure_ascii=False, indent=2), '```']
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', action='append', required=True, help='Explicit skill/plugin root; repeatable')
    parser.add_argument('--config', help='Optional Codex TOML; only server/plugin names and enabled flags returned')
    parser.add_argument('--out-dir', help='Authorized export destination; refuses to overwrite existing reports')
    args = parser.parse_args()
    data = collect(args.root, args.config)
    if args.out_dir:
        target = Path(args.out_dir)
        if any((target / name).exists() for name in ('inventory.json', 'inventory.md')):
            parser.error('Report already exists; choose a new output directory')
        target.mkdir(parents=True, exist_ok=True)
        (target / 'inventory.json').write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
        (target / 'inventory.md').write_text(markdown(data), encoding='utf-8')
    print(json.dumps({k: data[k] for k in ('scope', 'skill_files', 'coverage', 'errors')}, ensure_ascii=False))


if __name__ == '__main__':
    main()
