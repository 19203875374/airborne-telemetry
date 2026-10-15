#!/usr/bin/env python3
"""Record or verify explicit deliverable hashes, not completeness or build success."""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


def within(root, name):
    p = Path(name)
    if p.is_absolute() or '..' in p.parts:
        raise ValueError('Manifest paths must be relative without traversal')
    full = (root/p).resolve()
    if not full.is_relative_to(root):
        raise ValueError('Path or symlink escapes root')
    if not full.is_file():
        raise ValueError('Missing file: ' + name)
    return full


def fingerprint(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024*1024), b''):
            h.update(chunk)
    return {'size_bytes': path.stat().st_size, 'sha256': h.hexdigest()}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=['record', 'verify'])
    p.add_argument('--root', required=True); p.add_argument('--manifest', required=True)
    p.add_argument('--files', nargs='+')
    a = p.parse_args(); root = Path(a.root).resolve(); target = Path(a.manifest).resolve()
    try:
        if a.action == 'record':
            if not a.files or len(a.files) != len(set(a.files)):
                raise ValueError('Supply distinct --files explicitly')
            if target.exists():
                raise ValueError('Refuse to overwrite existing manifest; use a new version path')
            items = []
            for name in a.files:
                full = within(root, name)
                if full == target:
                    raise ValueError('Manifest cannot hash itself')
                items.append({'path': name, **fingerprint(full)})
            report = {'schema_version': 1, 'files': items,
                      'limits': 'Explicit-file identity only. No dependency discovery or rebuild proof.'}
            target.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
            print(json.dumps({'recorded': len(items), 'manifest': str(target)})); return 0
        data = json.loads(target.read_text(encoding='utf-8'))
        if data.get('schema_version') != 1 or not data.get('files'):
            raise ValueError('Unsupported or empty manifest')
        seen, issues = set(), []
        for item in data['files']:
            name = item['path']
            if name in seen or not re.fullmatch('[0-9a-f]{64}', item['sha256']):
                raise ValueError('Duplicate path or invalid hash')
            seen.add(name)
            try:
                actual = fingerprint(within(root, name))
                if any(actual[k] != item[k] for k in ['sha256', 'size_bytes']):
                    issues.append({'path': name, 'issue': 'content mismatch'})
            except ValueError as e:
                issues.append({'path': name, 'issue': str(e)})
        print(json.dumps({'passed': not issues, 'checked_files': len(seen), 'issues': issues}, indent=2))
        return 1 if issues else 0
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as e:
        print(json.dumps({'error': str(e)}), file=sys.stderr); return 2


if __name__ == '__main__':
    sys.exit(main())
