#!/usr/bin/env python3
"""Create a new work copy from the open-source tree; never overwrite a workspace."""
import argparse
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace', required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    work = Path(args.workspace).resolve()
    if not re.fullmatch(r'[A-Za-z0-9_:/.-]+', work.as_posix()):
        raise ValueError('Use an ASCII workspace path without spaces or Tcl special characters')
    if work == repo or work.is_relative_to(repo):
        raise ValueError('Choose a workspace outside the source repository')
    if work.exists():
        raise ValueError('Workspace already exists; choose a new path')
    manifest = json.loads((repo/'validation/input_manifest.json').read_text(encoding='utf-8'))
    for entry in manifest['files']:
        path = (repo/entry['path']).resolve()
        if not path.is_relative_to(repo) or not path.is_file() or sha(path) != entry['sha256']:
            raise ValueError('Release input mismatch: '+entry['path'])
    # No extraction of vendor binaries. All FPGA input files are visible in the repository.
    work.mkdir(parents=True)
    for source, destination in [('src/rtl','rtl'), ('src/mem','mem'),
                                ('board/constraints','constraints'), ('board/ip','ip'),
                                ('data','data'), ('src/matlab','matlab_rf')]:
        shutil.copytree(repo/source, work/destination)
    for folder in ('scripts','logs','output/baseband','output/rf','output/build','data/baseband'):
        (work/folder).mkdir(parents=True, exist_ok=True)
    tb = (repo/'sim/tb_pcm_net_mode_switch.v').read_text(encoding='utf-8-sig')
    old = 'E:/TX/matlab/baseband_signal/'
    if tb.count(old) < 4:
        raise ValueError('Unexpected testbench export path contract')
    (work/'scripts/tb_pcm_net_mode_switch.v').write_text(
        tb.replace(old, (work/'data/baseband').as_posix()+'/'), encoding='utf-8')
    loader = work/'matlab_rf/load_rf_data.m'
    text = loader.read_text(encoding='utf-8-sig')
    for key, folder in [('specDir','f_wave'), ('iqDir','iq_wave')]:
        text, count = re.subn(rf"^{key}\s*=\s*'[^']*';",
            lambda _: f"{key} = '{(work/'data'/folder).as_posix()}';",
            text, count=1, flags=re.M)
        if count != 1:
            raise ValueError('Unexpected RF loader assignment: '+key)
    loader.write_text(text, encoding='utf-8')
    shutil.copy2(repo/'build/audit_data.py', work/'scripts/audit_data.py')
    shutil.copy2(repo/'src/matlab/reproduce_results.m', work/'scripts/reproduce_results.m')
    for name, template in [('run_baseband.tcl','sim/run_baseband.tcl'),
                           ('build_hardware.tcl','build/build_hardware.tcl')]:
        template_text = (repo/template).read_text(encoding='utf-8')
        (work/'scripts'/name).write_text(template_text, encoding='utf-8')
    record = {'release_manifest_sha256':sha(repo/'validation/input_manifest.json'),
              'changes':['Copied visible RTL, memory and XCI configuration inputs.',
                         'Changed only output paths in the testbench work copy.',
                         'Changed only specDir/iqDir in the MATLAB loader work copy.'],
              'simulation_executed':False, 'vivado_build_executed':False,
              'matlab_executed':False, 'hardware_validated':False}
    (work/'preparation.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
    print(json.dumps({'workspace':str(work), 'prepared':True,
                      'next':'Run scripts/audit_data.py, then optionally the generated Tcl scripts.'}, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
