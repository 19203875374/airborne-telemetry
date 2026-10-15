#!/usr/bin/env python3
"""Compare finite numeric CSV columns by row; never auto-align or replace data."""
import argparse
import csv
import json
import math
import sys


def load(path, cols):
    with open(path, encoding='utf-8-sig', newline='') as f:
        r = csv.DictReader(f)
        if not r.fieldnames or any(c not in r.fieldnames for c in cols):
            raise ValueError('Missing selected columns in ' + path)
        data = []
        for row in r:
            if None in row:
                raise ValueError('Unexpected extra fields in ' + path)
            values = [float(row[c]) for c in cols]
            if not all(math.isfinite(x) for x in values):
                raise ValueError('Non-finite value in ' + path)
            data.append(values)
        if not data:
            raise ValueError('Empty CSV: ' + path)
        return data


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('golden'); p.add_argument('actual')
    p.add_argument('--columns', nargs='+', required=True)
    p.add_argument('--atol', type=float, default=0.0)
    p.add_argument('--rtol', type=float, default=0.0)
    a = p.parse_args()
    if not all(math.isfinite(x) and x >= 0 for x in [a.atol, a.rtol]):
        p.error('tolerances must be finite and nonnegative')
    try:
        g, x = load(a.golden, a.columns), load(a.actual, a.columns)
        if len(g) != len(x):
            raise ValueError('Row count mismatch; establish alignment explicitly')
        errors, max_error, failures = [], 0.0, 0
        for n, (gr, xr) in enumerate(zip(g, x), 2):
            for c, expected, actual in zip(a.columns, gr, xr):
                err = abs(actual - expected); max_error = max(max_error, err)
                if err > a.atol + a.rtol*abs(expected):
                    failures += 1
                    if len(errors) < 20:
                        errors.append({'csv_line': n, 'column': c, 'expected': expected,
                                       'actual': actual, 'absolute_error': err})
        print(json.dumps({'passed': failures == 0, 'rows': len(g), 'columns': a.columns,
                          'failures': failures, 'max_absolute_error': max_error,
                          'first_failures': errors, 'atol': a.atol, 'rtol': a.rtol}, indent=2))
        return 1 if failures else 0
    except (OSError, ValueError, KeyError, TypeError) as e:
        print(json.dumps({'error': str(e)}), file=sys.stderr); return 2


if __name__ == '__main__':
    sys.exit(main())
