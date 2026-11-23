"""Which standards give the 66.67% best match (419,522 contracts)? Recomputes, for every contract with best match 66.67 in a set of chunks,
the standards at that share (after the distinctive-function rule), and counts them. Usage: python best67_check.py N_CHUNKS_PER_CHAIN"""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import sys, os, glob, json
from collections import Counter
R = CLASSIFIER; sys.path.insert(0, R)
from erc_classifier import load_spec, dispatcher_selectors
spec, dist = load_spec(R + '/erc_specification_v5.json')
H = EVM_DATA; M = H + 'match_pct_70_no_overlap/'
SRC = {'ethereum': H + 'ethereum_deduplicated_results.csv', 'bnb': H + 'evm_data_source/deduplicated_results.csv',
       'avalanche': H + 'evm_data_source/avalanche/deduplicated_avalanche.csv', 'polygon': H + 'polygon/deduplicated_polygon.csv'}
SZ = 128 * 2**20; K = int(sys.argv[1]); C = Counter(); fn = Counter(); n = 0
NAME = {s: f for e in json.load(open(R + '/erc_specification_v5.json')).values() for f, s in (e.get('functions') or {}).items()}
for ch, p in SRC.items():
    for idx in range(K):
        if not os.path.exists(f'{M}{ch}_{idx}.tsv'): continue
        want = {l.split('\t')[1].strip('"').lower() for l in open(f'{M}{ch}_{idx}.tsv') if l.rstrip('\n').split('\t')[4] == '66.67'}
        with open(p, 'rb') as f:
            f.seek(idx * SZ)
            if idx: f.readline()
            while f.tell() <= idx * SZ + SZ - 1:
                l = f.readline()
                if not l: break
                x = l.split(b',', 2)
                if len(x) < 3: continue
                a = x[0].decode('ascii', 'ignore').strip('"').lower()
                if a not in want: continue
                ex = dispatcher_selectors(x[1].decode('ascii', 'ignore').strip('"').lower()); n += 1
                hit = []
                for e, sels in spec.items():
                    if dist[e] and 2 * len(dist[e] & ex) < len(dist[e]): continue
                    k = sum(s in ex for s in sels)
                    if abs(100 * k / len(sels) - 66.67) < 0.01:
                        hit.append(f'{e} {k}/{len(sels)}')
                        if e in ('ERC173', 'ERC20'): fn[e + ': ' + ' + '.join(NAME.get(s, s) for s in sels if s in ex)] += 1
                C[' & '.join(sorted(hit))] += 1
print('contracts checked', n); [print(f'  {c:>7}  {k}') for k, c in C.most_common(8)]
print('matched functions:'); [print(f'  {c:>7}  {k}') for k, c in fn.most_common(6)]
