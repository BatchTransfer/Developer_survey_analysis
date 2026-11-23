"""For the seed-2046 sample of 100 from all 12,673 flagged contracts (3,808,540 set): per contract, whether any reported-missing selector
is dispatched in a form the EQ reader misses (SUB or XOR compare, from dispatch_forms_census.forms), whether the contract has Vyper metadata,
whether it is in the 30,778 non-EQ set, and whether each missing selector occurs anywhere in the bytecode text.
Usage: python check_nonEQ_2046.py  -> new_classifier_70_no_overlap/check_nonEQ_seed2046.csv"""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import sys, os, csv, json, glob
R = ROOT; HERE = os.path.dirname(os.path.abspath(__file__)) + '/new_classifier_70_no_overlap'
sys.path.insert(0, CENSUS); sys.argv = ['x', '/dev/null']
from dispatch_forms_census import forms, VY
sys.path.insert(0, CLASSIFIER); from erc_classifier import dispatcher_selectors
SPEC = json.load(open(CLASSIFIER + '/erc_specification_v5.json'))
H = EVM_DATA
SRC = {'ethereum': H + 'ethereum_deduplicated_results.csv', 'bnb': H + 'evm_data_source/deduplicated_results.csv',
       'avalanche': H + 'evm_data_source/avalanche/deduplicated_avalanche.csv', 'polygon': H + 'polygon/deduplicated_polygon.csv'}
SZ = 128 * 2**20; SKIP = {'ERC173', 'ERC4906', ''}
NONEQ = set()
for p in glob.glob(H + 'dispatch_forms/*.tsv'):
    for l in open(p):
        x = l.rstrip('\n').split('\t')
        if x[0] != '#TOTAL' and (x[3] != '0' or x[4] != '0' or x[5] == '1'): NONEQ.add((x[0], x[1]))
S = list(csv.DictReader(open(HERE + '/sample_100_seed2046.csv')))
want = {}
for r in S: want.setdefault((r['chain'], int(r['chunk'])), {})[r['address']] = r['i']
code = {}
for (ch, idx), m in want.items():
    with open(SRC[ch], 'rb') as f:
        f.seek(idx * SZ)
        if idx: f.readline()
        while f.tell() <= min(idx * SZ + SZ - 1, os.path.getsize(SRC[ch])):
            l = f.readline()
            if not l: break
            x = l.split(b',', 2)
            if len(x) < 3: continue
            a = x[0].decode('ascii', 'ignore').strip('"').lower()
            if a in m: code[m[a]] = x[1].decode('ascii', 'ignore').strip('"').lower()
rows = []
for r in S:
    c = code[r['i']]; h = c[2:] if c.startswith('0x') else c; b = bytes.fromhex(h); d = dispatcher_selectors(c)
    E, Sx, X = forms(b); vy = VY in b
    miss = sorted({s for e in set(r['flagged'].split('|')) - SKIP for s in SPEC[e]['selectors'] if s not in d})
    rows.append([r['i'], r['chain'], r['address'], r['flagged'], (r['chain'], r['address']) in NONEQ, int(vy),
                 ' '.join(s for s in miss if s in Sx | X), ' '.join(s for s in miss if s in h), ' '.join(miss)])
with open(HERE + '/check_nonEQ_seed2046.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['i', 'chain', 'address', 'flagged', 'in_30778_set', 'vyper', 'missing_dispatched_SUB_XOR', 'missing_in_code_text', 'missing']); w.writerows(rows)
print('in 30,778 set:', sum(x[4] for x in rows), ' vyper:', sum(x[5] for x in rows), ' missing selector dispatched by SUB/XOR:', sum(bool(x[6]) for x in rows),
      ' missing selector in code text:', sum(bool(x[7]) for x in rows))
for x in rows:
    if x[4] or x[6] or x[7]: print(x)
