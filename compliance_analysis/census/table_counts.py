"""Per-chain and per-ERC flagged counts for tab:non-compliance from a classifier census dir.
Row: chain, address, n, flagged (|-sep), compliant (|-sep). ERC4906 and ERC173 are not counted.
Usage: python table_counts.py CENSUS_DIR"""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import sys, glob
from collections import Counter, defaultdict
SKIP = {'ERC4906', 'ERC173', ''}
tot, eli, fl = Counter(), Counter(), Counter(); per = defaultdict(Counter); allerc = Counter(); imp = defaultdict(Counter)
for p in glob.glob(sys.argv[1] + '/*.tsv'):
    for l in open(p):
        x = l.rstrip('\n').split('\t'); x += [''] * (5 - len(x)); ch = x[0]
        tot[ch] += 1
        if x[3] or x[4]: eli[ch] += 1
        f = set(x[3].split('|')) - SKIP
        for e in (set(x[3].split('|')) | set(x[4].split('|'))) - SKIP: imp[ch][e] += 1; imp['TOTAL'][e] += 1
        if f: fl[ch] += 1
        for e in f: per[ch][e] += 1; allerc[e] += 1
for ch in ['bnb', 'ethereum', 'polygon', 'avalanche']:
    print(ch, tot[ch], eli[ch], fl[ch], f'{100*fl[ch]/tot[ch]:.2f}%', *(per[ch][e] for e in ['ERC20', 'ERC721', 'ERC2612', 'ERC1155']))
T = sum(tot.values()); F = sum(fl.values())
print('TOTAL', T, sum(eli.values()), F, f'{100*F/T:.2f}%', *(allerc[e] for e in ['ERC20', 'ERC721', 'ERC2612', 'ERC1155']))
print('others', [(e, c) for e, c in allerc.most_common() if e not in {'ERC20', 'ERC721', 'ERC2612', 'ERC1155'}])
print('implementing (compliant or flagged) per standard:')
for ch in ['bnb', 'ethereum', 'polygon', 'avalanche', 'TOTAL']:
    print(ch, *(imp[ch][e] for e in ['ERC20', 'ERC721', 'ERC2612', 'ERC1155']))
print('implementing, other standards:', imp['TOTAL'].most_common()[4:14])
