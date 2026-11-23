"""Remove contracts whose dispatcher the classifier's reader cannot fully read from a census output, before sampling.
Excluded: every contract dispatch_forms_census.py lists with a SUB-form or XOR-form selector the reader misses, or with Vyper metadata
(whether or not the missed selector is in an ERC spec). The exclusion is applied to the whole population, not to sampled contracts.
Usage: python exclude_nonstandard_dispatch.py CENSUS_DIR DISPATCH_FORMS_DIR OUT_DIR"""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import sys, os, glob
C, D, O = sys.argv[1:4]; os.makedirs(O, exist_ok=True)
ex = set()
for p in glob.glob(D + '/*.tsv'):
    for l in open(p):
        x = l.rstrip('\n').split('\t')
        if x[0] != '#TOTAL' and (x[3] != '0' or x[4] != '0' or x[5] == '1'): ex.add((x[0], x[1]))
tot = kept = fl = flk = 0
for p in glob.glob(C + '/*.tsv'):
    with open(O + '/' + os.path.basename(p), 'w') as w:
        for l in open(p):
            x = l.rstrip('\n').split('\t'); tot += 1; f = bool(x[3]); fl += f
            if (x[0], x[1].strip('"').lower()) in ex: continue
            kept += 1; flk += f; w.write(l)
print(f'excluded contracts (SUB/XOR/Vyper): {len(ex):,}\nall contracts {tot:,} -> {kept:,}\nflagged {fl:,} -> {flk:,}')
