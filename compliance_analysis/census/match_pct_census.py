"""Same decision as erc_classifier.classify (threshold 70, NO_OVERLAP, i.e. the run behind tab:non-compliance), but also writes, for every
standard a contract matches (compliant or flagged), the number of dispatched and mandatory functions, for the match-% distribution.
Usage: [SPEC=erc_specification_v6.json] python match_pct_census.py OUT_DIR   (default spec: erc_specification_v5.json)
Output per contract: chain, address, chunk, STD:k/n entries for matched standards (| separated), best match % over the standards that pass
the distinctive-function rule (0 if none), best match % over all standards without that rule."""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import sys, os, time
R = CLASSIFIER; sys.path.insert(0, R)
from erc_classifier import load_spec, dispatcher_selectors
from multiprocessing import Pool
OUT = sys.argv[1]; THR = 70
spec, dist = load_spec(R + '/' + os.environ.get('SPEC', 'erc_specification_v5.json'))
H = EVM_DATA
SRC = {'ethereum': H + 'ethereum_deduplicated_results.csv', 'bnb': H + 'evm_data_source/deduplicated_results.csv',
       'avalanche': H + 'evm_data_source/avalanche/deduplicated_avalanche.csv', 'polygon': H + 'polygon/deduplicated_polygon.csv'}
SZ = 128 * 2**20
def match(code):
    ex = dispatcher_selectors(code); m = []; best = raw = 0.0
    for e, sels in spec.items():                       # overlap rule off, as in the NO_OVERLAP run
        k = sum(x in ex for x in sels); p = 100 * k / len(sels); raw = max(raw, p)
        if dist[e] and 2 * len(dist[e] & ex) < len(dist[e]): continue
        best = max(best, p)
        if p > THR: m.append(f'{e}:{k}/{len(sels)}')
    return m, best, raw
def job(a):
    ch, p, st, en, idx = a; o = f'{OUT}/{ch}_{idx}.tsv'
    if os.path.exists(o): return
    with open(p, 'rb') as f, open(o + '.tmp', 'w') as w:
        f.seek(st)
        if st: f.readline()
        while f.tell() <= en:
            l = f.readline()
            if not l: break
            if l.startswith(b'address,'): continue
            x = l.split(b',', 2)
            if len(x) < 3: continue
            c = x[1].decode('ascii', 'ignore').strip('"').lower()
            if len(c) <= 2: continue
            try: m, bp, rp = match(c)
            except Exception: continue
            w.write(f"{ch}\t{x[0].decode()}\t{idx}\t{'|'.join(m)}\t{bp:.2f}\t{rp:.2f}\n")
    os.rename(o + '.tmp', o)
if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True); J = []
    for ch, p in SRC.items():
        s = os.path.getsize(p)
        for i, st in enumerate(range(0, s, SZ)): J.append((ch, p, st, min(st + SZ - 1, s), i))
    T = time.time()
    with Pool(10) as P:
        for k, _ in enumerate(P.imap_unordered(job, J), 1):
            if k % 50 == 0: print(k, len(J), int(time.time() - T), flush=True)
    print('DONE', int(time.time() - T), flush=True)
