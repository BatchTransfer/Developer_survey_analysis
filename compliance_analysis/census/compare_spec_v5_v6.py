"""Compare two match_pct_census.py outputs (v5 spec vs v6 spec with ERC-173 = owner + transferOwnership).
Per run: contracts, implementing any standard, implementing a standard other than ERC-173/ERC-4906, contracts whose only standards are
ERC-173/ERC-4906, flagged (ERC-173/4906 flags not counted), ERC-173 complete/flagged, per chain; plus contracts whose flag set changed.
Usage: python compare_spec_v5_v6.py V5_DIR V6_DIR"""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import sys, glob, os
from collections import Counter
SKIP = {'ERC173', 'ERC4906'}
def load(d):
    r = {}
    for f in glob.glob(d + '/*.tsv'):
        for l in open(f):
            x = l.rstrip('\n').split('\t')
            m = [(e, int(k), int(n)) for e, kn in (s.split(':') for s in x[3].split('|')) for k, n in [kn.split('/')]] if x[3] else []
            r[(x[0], x[1])] = (m, x[4])
    return r
def stats(r):
    c = Counter()
    for (ch, a), (m, best) in r.items():
        es = {e for e, k, n in m}; core = es - SKIP; fl = {e for e, k, n in m if k < n} - SKIP
        for key, cond in (('contracts', True), ('implementing any standard', bool(es)), ('implementing excl. ERC-173/4906', bool(core)),
                          ('only ERC-173/4906', bool(es) and not core), ('flagged', bool(fl)),
                          ('ERC-173 complete', any(e == 'ERC173' and k == n for e, k, n in m)), ('ERC-173 flagged', any(e == 'ERC173' and k < n for e, k, n in m))):
            if cond: c[key] += 1; c[(key, ch)] += 1
    return c
a, b = load(sys.argv[1]), load(sys.argv[2]); sa, sb = stats(a), stats(b)
keys = ['contracts', 'implementing any standard', 'implementing excl. ERC-173/4906', 'only ERC-173/4906', 'flagged', 'ERC-173 complete', 'ERC-173 flagged']
print(f"{'':34}{'v5':>12}{'v6':>12}{'change':>12}")
for k in keys: print(f'{k:34}{sa[k]:>12,}{sb[k]:>12,}{sb[k] - sa[k]:>+12,}')
for ch in ['bnb', 'ethereum', 'polygon', 'avalanche']:
    print(ch, ' | '.join(f'{k}: {sa[(k, ch)]:,} -> {sb[(k, ch)]:,}' for k in ('implementing any standard', 'implementing excl. ERC-173/4906', 'flagged')))
fa = {k for k, (m, _) in a.items() if {e for e, x, n in m if x < n} - SKIP}; fb = {k for k, (m, _) in b.items() if {e for e, x, n in m if x < n} - SKIP}
print('flagged contracts identical:', fa == fb, '| only v5:', len(fa - fb), '| only v6:', len(fb - fa))
ch = sum(1 for k in a if sorted(e for e, x, n in a[k][0] if e != 'ERC173') != sorted(e for e, x, n in b.get(k, ([], ''))[0] if e != 'ERC173'))
print('contracts whose non-ERC-173 matches changed:', ch)
