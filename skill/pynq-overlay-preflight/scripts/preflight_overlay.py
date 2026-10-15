#!/usr/bin/env python3
"""Offline PYNQ bit/HWH preflight. No PYNQ import, download or register access."""
import argparse
import hashlib
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bit', required=True); p.add_argument('--hwh', required=True)
    p.add_argument('--require-ip', nargs='*', default=[])
    a = p.parse_args()
    try:
        bit, hwh = Path(a.bit).resolve(), Path(a.hwh).resolve()
        for f in [bit, hwh]:
            if not f.is_file() or not f.stat().st_size:
                raise ValueError('Missing or empty file: ' + str(f))
        if bit.suffix.lower() != '.bit' or hwh.suffix.lower() != '.hwh':
            raise ValueError('Expected .bit and .hwh suffixes')
        if bit.parent != hwh.parent or bit.stem != hwh.stem:
            raise ValueError('Place matching basenames in the same directory')
        if hwh.stat().st_size > 16*1024*1024:
            raise ValueError('HWH exceeds supported 16 MiB parser limit')
        content = hwh.read_bytes()
        if b'<!DOCTYPE' in content.upper() or b'<!ENTITY' in content.upper():
            raise ValueError('DTD and entity declarations are unsupported')
        root = ET.fromstring(content)
        names = set()
        for e in root.iter():
            if e.tag.rsplit('}', 1)[-1].upper() == 'MODULE':
                name = e.attrib.get('FULLNAME') or e.attrib.get('INSTANCE')
                if name:
                    names.add(name.lstrip('/'))
        if not names:
            raise ValueError('No recognizable MODULE names; unsupported HWH schema')
        missing = sorted({name.lstrip('/') for name in a.require_ip} - names)
        hashes = {}
        for f in [bit, hwh]:
            h = hashlib.sha256()
            with f.open('rb') as inp:
                for chunk in iter(lambda: inp.read(1024*1024), b''):
                    h.update(chunk)
            hashes[f.name] = h.hexdigest()
        print(json.dumps({'static_checks_passed': not missing, 'module_names': sorted(names),
                          'missing_required_ip': missing, 'sha256': hashes,
                          'hardware_validated': False,
                          'limits': ['Does not prove bit/HWH originate from the same build.',
                                     'Does not validate bitstream format, device part or board compatibility.',
                                     'Does not exercise PYNQ parsers, clocks, DMA, MMIO or functionality.']}, indent=2))
        return 1 if missing else 0
    except (OSError, ValueError, ET.ParseError) as e:
        print(json.dumps({'error': str(e)}), file=sys.stderr); return 2


if __name__ == '__main__':
    sys.exit(main())
