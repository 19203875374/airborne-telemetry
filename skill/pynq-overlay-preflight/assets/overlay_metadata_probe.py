#!/usr/bin/env python3
"""Template for a real PYNQ environment; not run in the submission build."""
import argparse
import json

def main():
    p = argparse.ArgumentParser()
    p.add_argument('bitfile')
    a = p.parse_args()
    from pynq import Overlay
    ol = Overlay(a.bitfile, download=False)
    print(json.dumps({'metadata_only': True,
                      'ip_names': sorted(ol.ip_dict.keys()),
                      'hardware_validated': False}, indent=2))
    # No download(), MMIO, register writes or DMA operations here.

if __name__ == '__main__':
    main()

