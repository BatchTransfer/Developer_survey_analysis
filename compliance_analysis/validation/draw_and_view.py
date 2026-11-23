"""Random sample from all contracts the new classifier (erc_classifier.py, 3.8M set) flags on any standard except ERC-173 and ERC-4906
(ERC-4906 repeats ERC-721, ERC-173 flags are 2-of-3 ownership matches),
then a labelling view per contract.
Usage: python draw_and_view.py CENSUS_OUT_DIR N SEED
Writes, next to this script: sample_N_seedSEED.csv (chain, address, chunk, flags) and view_N_seedSEED.txt (per contract: flagged core
standard, its missing functions, whether each missing selector occurs anywhere in the bytecode, code size, DELEGATECALL present, and the
names of all dispatcher functions, from the 4byte list)."""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import sys, os, glob, csv, random, json
HERE = os.path.dirname(os.path.abspath(__file__)) + '/' + os.path.basename(sys.argv[1].rstrip('/')); R = ROOT
sys.path.insert(0, CLASSIFIER); from erc_classifier import dispatcher_selectors
SPEC = json.load(open(CLASSIFIER + '/erc_specification_v5.json'))
FB = json.load(open(os.environ.get('FOURBYTE_JSON', EVM_DATA + '4byte.json')))
NAME = {s: f for e in SPEC.values() for f, s in (e.get('functions') or {}).items()}
SKIP = {'ERC173', 'ERC4906'}
H = EVM_DATA
SRC = {'ethereum': H + 'ethereum_deduplicated_results.csv', 'bnb': H + 'evm_data_source/deduplicated_results.csv',
       'avalanche': H + 'evm_data_source/avalanche/deduplicated_avalanche.csv', 'polygon': H + 'polygon/deduplicated_polygon.csv'}
SZ = 128 * 2**20
OUT, N, SEED = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
pop = []
for p in glob.glob(OUT + '/*.tsv'):
    for l in open(p):
        ch, ad, idx, fl, co = l.rstrip('\n').split('\t')
        if set(fl.split('|')) - SKIP - {''}: pop.append((ch, ad.strip('"').lower(), int(idx), fl, co))
pop.sort(); os.makedirs(HERE, exist_ok=True); print('population', len(pop))
S = random.Random(SEED).sample(pop, N)
with open(f'{HERE}/sample_{N}_seed{SEED}.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['i', 'chain', 'address', 'chunk', 'flagged', 'compliant']); w.writerows([(i, *x) for i, x in enumerate(S, 1)])
want = {}
for i, (ch, ad, idx, fl, co) in enumerate(S, 1): want.setdefault((ch, idx), {})[ad] = i
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
print('bytecode found for', len(code), 'of', N)
with open(f'{HERE}/view_{N}_seed{SEED}.txt', 'w') as v:
    for i, (ch, ad, idx, fl, co) in enumerate(S, 1):
        c = code[i]; b = c[2:] if c.startswith('0x') else c; d = dispatcher_selectors(c)
        v.write(f'#{i} {ch} {ad} size={len(b)//2}B delegatecall={"f4" in [b[j:j+2] for j in range(0, len(b), 2)]} flags={fl} compliant={co}\n')
        for e in sorted(set(fl.split('|')) - SKIP - {''}):
            if True:
                sl = SPEC[e]['selectors']; miss = [s for s in sl if s not in d]
                v.write(f'   {e} {len(sl)-len(miss)}/{len(sl)} missing: ' + ', '.join(f'{NAME.get(s, s)}{" [in code text]" if s in b else ""}' for s in miss) + '\n')
        v.write('   functions: ' + ', '.join(sorted(FB.get(s, s).split('(')[0] for s in d)) + '\n')
print('wrote view')
