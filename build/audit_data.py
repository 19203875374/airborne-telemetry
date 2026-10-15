#!/usr/bin/env python3
"""Recompute archived or newly simulated statistics without MATLAB graphics."""
import argparse
import csv
import hashlib
import json
import math
import sys
from pathlib import Path


def load_baseband(path,fs):
    lines=path.read_text(encoding='utf-8-sig').splitlines()
    columns=lines[0].split()
    required=['sample','active_mode','i','q']
    if not all(k in columns for k in required):raise ValueError('Missing baseband header')
    index={k:columns.index(k) for k in required};data=[]
    for line in lines[1:]:
        if not line.strip():continue
        values=line.split()
        if len(values)!=len(columns):raise ValueError('Baseband column count mismatch')
        data.append(tuple(int(values[index[k]]) for k in required))
    if any(b[0]<=a[0] for a,b in zip(data,data[1:])):raise ValueError('Non-increasing sample index')
    result=[]
    for mode in range(4):
        segments=[];part=[]
        for row in data:
            if row[1]==mode:
                if part and row[0]!=part[-1][0]+1:segments.append(part);part=[]
                part.append(row)
            elif part:segments.append(part);part=[]
        if part:segments.append(part)
        if not segments:raise ValueError('Missing mode '+str(mode))
        seg=max(segments,key=len)
        nz=[i for i,r in enumerate(seg) if r[2] or r[3]]
        if not nz:raise ValueError('All-zero mode')
        # Match the archived steady-segment endpoint-zero policy, no hidden gain correction.
        seg=seg[nz[0]:nz[-1]+1]
        power=[r[2]**2+r[3]**2 for r in seg]
        papr=10*math.log10(max(power)/(math.fsum(power)/len(power)))
        result.append({'mode':mode,'selected_samples':len(seg),'sample_first':seg[0][0],
                       'sample_last':seg[-1][0],'duration_ms':len(seg)/fs*1000,'papr_db':papr})
    return {'raw_rows':len(data),'iq_fs_hz':fs,'selection':'longest contiguous mode segment; trim zero endpoints only',
            'modes':result}


def load_iq(path):
    rows=list(csv.reader(path.open(encoding='utf-8-sig',newline='')))
    header=next((i for i,r in enumerate(rows) if r and r[0].strip()=='MeasResult0'),None)
    if header is None:raise ValueError('Unsupported IQ CSV header')
    values=[]
    for row in rows[header+1:]:
        if not row or not row[0].strip():continue
        x=float(row[0])
        if not math.isfinite(x):raise ValueError('Non-finite IQ')
        values.append(x)
    if len(values)%2:raise ValueError('Odd number of alternating I/Q values')
    dt=float(rows[header+1][1])
    if not 1e-10<dt<1e-3:raise ValueError('IQ interval absent or unsupported')
    power=[values[i]**2+values[i+1]**2 for i in range(0,len(values),2)]
    avg=math.fsum(power)/len(power)
    return {'samples':len(power),'iq_fs_hz':1/dt,'papr_db':10*math.log10(max(power)/avg),
            'amplitude_units':'original CSV voltage convention; no output-port calibration applied'}


def instrument_obw(path):
    rows=list(csv.reader(path.open(encoding='utf-8-sig',newline='')))
    idx=next((i for i,r in enumerate(rows) if r and r[0].strip()=='MeasResult1'),None)
    if idx is None:raise ValueError('Unsupported spectrum CSV header')
    return float(rows[idx+1][0])/1e6


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--workspace',required=True)
    p.add_argument('--baseband',choices=['archived','new'],default='archived')
    p.add_argument('--baseband-fs',type=float,default=30.72e6)
    a=p.parse_args();w=Path(a.workspace).resolve()
    if not math.isfinite(a.baseband_fs) or a.baseband_fs<=0:raise ValueError('Invalid sample rate')
    bb=w/'data'/('baseband_archived' if a.baseband=='archived' else 'baseband')/'pcm_net_mode_switch_iq.txt'
    report={'baseband_source':a.baseband,'baseband':load_baseband(bb,a.baseband_fs),'rf':[]}
    for mode in ['pcm_fm','soqpsk','bpsk','qpsk']:
        iq=w/f'data/iq_wave/iq_{mode}.csv';sp=w/f'data/f_wave/f_{mode}.csv'
        report['rf'].append({'mode':mode,**load_iq(iq),'instrument_obw_mhz':instrument_obw(sp)})
    report['limits']='Offline replay and statistics only. No new RF acquisition or Vivado/MATLAB execution.'
    report['baseband_sha256']=hashlib.sha256(bb.read_bytes()).hexdigest()
    out=w/'output'/('audit_'+a.baseband+'.json')
    out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))
    print('Saved '+str(out),file=sys.stderr)


if __name__=='__main__':
    try:main()
    except (OSError,ValueError,IndexError,StopIteration) as e:
        print(str(e),file=sys.stderr);sys.exit(2)
