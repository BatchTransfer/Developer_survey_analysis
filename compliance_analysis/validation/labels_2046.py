"""Labels for the seed-2046 random sample of 100 from all 12,673 flagged contracts (3,808,540 contracts, threshold 70%, no overlap rule,
ERC-173 and ERC-4906 not counted). Literal rule (as decided by the author): TP when every function reported missing has no dispatcher entry
(EQ, SUB or XOR compare, checked by check_nonEQ_2046.py); renamed functions and selectors that only build outgoing calls count as missing.
Labelled by Claude from view_100_seed2046.txt and check_nonEQ_seed2046.csv, not yet cross-verified by a second researcher.
Usage: python labels_2046.py"""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import csv, math, os
D = os.path.dirname(os.path.abspath(__file__)) + '/new_classifier_70_no_overlap'
NOTE = {21: 'transfer selector occurs only as PUSH32 calldata for an outgoing call, not dispatched',
        23: 'ERC-1820 registry; supportsInterface occurs only in outgoing ERC-165 calls (literal rule, EIP-1820 does not require it of the registry)'}
FP = set()   # no reported-missing selector is dispatched in any form (check_nonEQ_seed2046.csv)
chk = {int(r['i']): r for r in csv.DictReader(open(D + '/check_nonEQ_seed2046.csv'))}
rows = []
for r in csv.DictReader(open(D + '/sample_100_seed2046.csv')):
    i = int(r['i']); c = chk[i]
    lab = 'FP' if i in FP or c['missing_dispatched_SUB_XOR'] else 'TP'
    rows.append([i, r['chain'], r['address'], r['flagged'], c['missing'], lab, NOTE.get(i, 'reported-missing function has no dispatcher entry')])
with open(D + '/labels_100_seed2046.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['i', 'chain', 'address', 'flagged', 'missing_selectors', 'label', 'why']); w.writerows(rows)
n = len(rows); tp = sum(r[5] == 'TP' for r in rows); p = tp / n; z = 1.96
c = (p + z*z/(2*n)) / (1 + z*z/n); h = z*math.sqrt(p*(1-p)/n + z*z/(4*n*n)) / (1 + z*z/n)
print(f'n={n} TP={tp} FP={n-tp} precision={100*p:.1f}% Wilson95=[{100*(c-h):.1f}, {100*(c+h):.1f}]')
from collections import Counter
print(Counter(e for r in rows for e in set(r[3].split('|')) - {'ERC4906', 'ERC173', ''}).most_common())
print(Counter(r[1] for r in rows))
