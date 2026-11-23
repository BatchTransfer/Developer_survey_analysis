"""Rebuild erc_distribution/erc_79_by_year_and_contracts_3.8M.csv from the new (dispatcher-based) classifier.
Joins the 79 specification entries (creation year) with per-standard contract counts from results/match_pct_70_no_overlap/*.tsv.gz
(column 4: STD:k/n for every standard the contract implements, i.e. >70% of mandatory functions dispatched plus the distinctive-function rule).
implementing = k/n > 70%; compliant = k == n; flagged = k < n. Multi-label: one contract can implement several standards.
ERC-173 and ERC-4906 are listed per standard but not counted in the paper's 12,673 flagged contracts.
Usage: python census/build_erc_distribution.py"""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import csv, glob, gzip, json, os
from collections import Counter, defaultdict
CH = ['bnb', 'ethereum', 'polygon', 'avalanche']
MATCH = os.environ.get('MATCH_DIR', RESULTS + '/match_pct_70_no_overlap')
comp, flag = defaultdict(Counter), defaultdict(Counter)
for p in sorted(glob.glob(MATCH + '/*.tsv.gz')):
    for l in gzip.open(p, 'rt'):
        x = l.rstrip('\n').split('\t')
        if not x[3]: continue
        for s in x[3].split('|'):
            e, kn = s.split(':'); k, n = kn.split('/'); (comp if k == n else flag)[e][x[0]] += 1
D = ROOT + '/../erc_distribution'
yr = list(csv.DictReader(open(D + '/erc_79_specifications_by_year.csv')))
sel = {e for e, v in json.load(open(CLASSIFIER + '/erc_specification_v5.json')).items() if v.get('selectors')}
rows = []
for y in yr:
    e = y['spec_entry']; c, f = comp[e], flag[e]
    rows.append({'spec_entry': e, 'erc': y['erc'], 'title': y['title'], 'status': y['status'], 'created': y['created'],
                 'in_classifier': 'yes' if e in sel else 'no (no mandatory selectors)',
                 'implementing_gt70': sum(c.values()) + sum(f.values()), 'compliant_100': sum(c.values()), 'flagged': sum(f.values()),
                 **{f'{ch}_implementing': c[ch] + f[ch] for ch in CH}})
rows.sort(key=lambda r: (-r['implementing_gt70'], r['created']))
out = D + '/erc_79_by_year_and_contracts_3.8M.csv'
w = csv.DictWriter(open(out, 'w', newline=''), fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
print(len(rows), 'entries,', sum(r['in_classifier'] == 'yes' for r in rows), 'in classifier,',
      sum(r['implementing_gt70'] > 0 for r in rows), 'implemented by >=1 contract ->', out)
