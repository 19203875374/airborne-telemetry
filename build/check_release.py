#!/usr/bin/env python3
"""Check declared release bytes, paths, dependency presence and local Markdown links."""
import hashlib
import json
import re
import sys
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[1]
    files = sorted(p for p in root.rglob('*') if p.is_file()
                   and '.git' not in p.relative_to(root).parts
                   and '__pycache__' not in p.relative_to(root).parts)
    errors = []
    required = {'src/rtl':16, 'src/mem':7, 'board/ip':4,
                'data/iq_wave':4, 'data/f_wave':4}
    for directory, expected in required.items():
        count = len([p for p in (root/directory).iterdir() if p.is_file()])
        if count != expected:
            errors.append(f'{directory}: expected {expected} files, got {count}')
    conventions = {'README.md','SKILL.md','LICENSE','.gitignore','.gitattributes'}
    for p in files:
        relative = p.relative_to(root)
        for part in relative.parts:
            if part not in conventions and not re.fullmatch('[a-z0-9_-]+(?:[.][a-z0-9_-]+)*',part):
                errors.append('Invalid path component: '+relative.as_posix())
        if p.stat().st_size >= 25*1024*1024:
            errors.append('Above browser single-file limit: '+relative.as_posix())
        if p.suffix == '.md':
            text = p.read_text(encoding='utf-8')
            for link in re.findall(r'\]\(([^)]+)\)', text):
                if re.match(r'[a-zA-Z]+:',link) or link.startswith('#'):
                    continue
                target = link.split('#',1)[0]
                if target and not (p.parent/target).exists():
                    errors.append('Broken link: '+relative.as_posix()+' -> '+link)
    manifest = json.loads((root/'validation/input_manifest.json').read_text(encoding='utf-8'))
    for entry in manifest['files']:
        p = (root/entry['path']).resolve()
        if not p.is_relative_to(root) or not p.is_file():
            errors.append('Missing or unsafe input: '+entry['path'])
        elif hashlib.sha256(p.read_bytes()).hexdigest() != entry['sha256']:
            errors.append('Fingerprint mismatch: '+entry['path'])
    if not (root/'LICENSE').read_text(encoding='utf-8').startswith('MIT License'):
        errors.append('Expected the existing MIT license')
    result = {'passed':not errors, 'files':len(files),
              'largest_file_bytes':max(p.stat().st_size for p in files),
              'errors':errors, 'scope':'Release bytes, file layout and links only.',
              'vivado_executed':False,'matlab_executed':False,'hardware_validated':False}
    print(json.dumps(result,ensure_ascii=False,indent=2))
    return 1 if errors else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError,ValueError,KeyError) as error:
        print(str(error),file=sys.stderr)
        sys.exit(2)
