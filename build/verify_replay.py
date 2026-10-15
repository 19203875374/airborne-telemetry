#!/usr/bin/env python3
"""Compare the archived-data replay with the included numerical reference."""
import argparse
import json
import math
import sys
from pathlib import Path


def compare(reference, actual, path='root'):
    if isinstance(reference, dict):
        if not isinstance(actual, dict) or reference.keys() != actual.keys():
            return [path+': keys differ']
        return [error for key in reference for error in compare(reference[key], actual[key], path+'.'+key)]
    if isinstance(reference, list):
        if not isinstance(actual, list) or len(reference) != len(actual):
            return [path+': length differs']
        return [error for i, pair in enumerate(zip(reference,actual))
                for error in compare(*pair, path+f'[{i}]')]
    if isinstance(reference, (int,float)) and not isinstance(reference, bool):
        passed = isinstance(actual, (int,float)) and math.isfinite(actual) and math.isclose(reference,actual,rel_tol=1e-10,abs_tol=1e-9)
    else:
        passed = reference == actual
    return [] if passed else [path+': value differs']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('actual', type=Path)
    args = parser.parse_args()
    reference = Path(__file__).resolve().parents[1]/'data/reference/audit_archived.json'
    errors = compare(json.loads(reference.read_text(encoding='utf-8')),
                     json.loads(args.actual.read_text(encoding='utf-8')))
    print(json.dumps({'passed':not errors, 'errors':errors,
                      'scope':'Same archived input and numerical selection rules; no hardware verdict.'}, indent=2))
    return 1 if errors else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, TypeError) as error:
        print(str(error),file=sys.stderr)
        sys.exit(2)
