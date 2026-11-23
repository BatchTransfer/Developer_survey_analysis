"""Latest classifier (erc_classifier.classify) over all 3.8M contracts at a chosen threshold.
Usage: python new_classifier_census.py CLASSIFIER_DIR THRESHOLD OUT_DIR   (POLYGON_CSV env var overrides the Polygon path, NO_OVERLAP=1 turns off the ERC-721 overlap rule)
Output per contract: chain, address, chunk, flagged standards, compliant standards."""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import sys, os, time
WS, THR, OUT = sys.argv[1], float(sys.argv[2]), sys.argv[3]; sys.path.insert(0, WS)
from erc_classifier import load_spec, classify
from multiprocessing import Pool
spec, dist = load_spec(WS + '/erc_specification_v5.json')
H = EVM_DATA
SRC = {'ethereum': H + 'ethereum_deduplicated_results.csv', 'bnb': H + 'evm_data_source/deduplicated_results.csv',
       'avalanche': H + 'evm_data_source/avalanche/deduplicated_avalanche.csv',
       'polygon': os.environ.get('POLYGON_CSV', H + 'polygon/deduplicated_polygon.csv')}
SZ = 128 * 2**20
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
            try: F, C = classify(c, spec, dist, THR, overlap=not os.environ.get('NO_OVERLAP'))
            except Exception: continue
            w.write(f"{ch}\t{x[0].decode()}\t{idx}\t{'|'.join(sorted(F))}\t{'|'.join(sorted(C))}\n")
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
