#!/usr/bin/env python3
"""Read canonical CSV only; never alter samples or claim hardware compliance."""
import argparse
import csv
import json
import math
import sys
from pathlib import Path


def positive(s):
    x = float(s)
    if not math.isfinite(x) or x <= 0:
        raise argparse.ArgumentTypeError('must be finite and positive')
    return x


def analyze(args):
    rows = []
    with Path(args.input).open(encoding='utf-8-sig', newline='') as f:
        reader = csv.DictReader(f)
        required = [args.i, args.q]
        required += [x for x in [args.sample, args.inc, args.mode_column, args.valid_column] if x]
        if not reader.fieldnames or any(k not in reader.fieldnames for k in required):
            raise ValueError('Missing explicit columns: ' + ','.join(required))
        if len(set(reader.fieldnames)) != len(reader.fieldnames):
            raise ValueError('Duplicate CSV column names')
        previous_sample = None
        for line, r in enumerate(reader, 2):
            if None in r:
                raise ValueError(f'Unexpected extra fields at line {line}')
            if args.mode_column and r[args.mode_column] != args.mode:
                continue
            if args.valid_column and r[args.valid_column] != args.valid_value:
                continue
            i, q = float(r[args.i]), float(r[args.q])
            sample = int(r[args.sample]) if args.sample else None
            inc = float(r[args.inc]) if args.inc else None
            if not all(math.isfinite(x) for x in [i, q] + ([inc] if inc is not None else [])):
                raise ValueError(f'Non-finite sample at line {line}')
            if sample is not None:
                if previous_sample is not None and sample <= previous_sample:
                    raise ValueError('Sample index must strictly increase in selected rows')
                previous_sample = sample
            rows.append((sample, i, q, inc))
    if not rows:
        raise ValueError('No selected rows')
    powers = [i*i + q*q for _, i, q, _ in rows]
    average = math.fsum(powers) / len(powers)
    if not math.isfinite(average) or not all(math.isfinite(x) for x in powers):
        raise ValueError('Power overflow; rescale explicitly and retain its scale factor')
    freqs = []
    breaks = 0
    if args.sample:
        for a, b in zip(rows, rows[1:]):
            if b[0] - a[0] != 1:
                breaks += 1
                continue
            if (a[1] == 0 and a[2] == 0) or (b[1] == 0 and b[2] == 0):
                continue
            angle = math.atan2(b[2]*a[1] - b[1]*a[2], b[1]*a[1] + b[2]*a[2])
            freqs.append(angle * args.fs / (2*math.pi))
    result = {
        'input': str(Path(args.input).resolve()), 'rows': len(rows),
        'iq_fs_hz': args.fs, 'zero_rows': sum(x == 0 for x in powers),
        'power_mean': average, 'power_min': min(powers), 'power_max': max(powers),
        'papr_db': 10*math.log10(max(powers)/average) if average else None,
        'sample_index_breaks': breaks if args.sample else None,
        'phase_difference_pairs': len(freqs),
        'phase_frequency_min_hz': min(freqs) if freqs else None,
        'phase_frequency_max_hz': max(freqs) if freqs else None,
        'phase_frequency_mean_hz': math.fsum(freqs)/len(freqs) if freqs else None,
        'selection': {'mode_column': args.mode_column, 'mode': args.mode,
                      'valid_column': args.valid_column, 'valid_value': args.valid_value},
        'limits': ['No hidden normalization, interpolation, ideal-point projection or zero removal.',
                   'Phase differences use consecutive indices only and lie in the principal interval.',
                   'No assertion of unaliased carrier, BER, RF power or standards compliance.']}
    if args.inc:
        if args.inc_fs is None:
            result['inc_frequency_hz'] = None
            result['limits'].append('inc column present; accumulator update rate not supplied.')
        else:
            x = [r[3]*args.inc_fs/(2**args.phase_bits) for r in rows]
            result['inc_frequency_hz'] = {'min': min(x), 'max': max(x)}
            result['accumulator_update_hz'] = args.inc_fs
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('input'); p.add_argument('--fs', type=positive, required=True)
    p.add_argument('--i', default='i'); p.add_argument('--q', default='q')
    p.add_argument('--sample', help='Consecutive index of the exported IQ stream, not a different clock')
    p.add_argument('--inc'); p.add_argument('--inc-fs', type=positive)
    p.add_argument('--phase-bits', type=int, choices=range(1, 65), default=16)
    p.add_argument('--mode-column'); p.add_argument('--mode')
    p.add_argument('--valid-column'); p.add_argument('--valid-value', default='1')
    a = p.parse_args()
    if bool(a.mode_column) != (a.mode is not None):
        p.error('--mode-column and --mode must be used together')
    if a.inc_fs and not a.inc:
        p.error('--inc-fs requires --inc')
    try:
        print(json.dumps(analyze(a), ensure_ascii=False, indent=2, allow_nan=False))
    except (OSError, ValueError, KeyError, TypeError) as e:
        print(json.dumps({'error': str(e)}, ensure_ascii=False), file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
