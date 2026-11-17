"""Join the 79 specification entries (creation year) with per-ERC contract counts on 3.8M contracts.
Usage: python build.py SPEC_YEAR_CSV PER_ERC_CSV SPEC_JSON OUT_CSV
Per-ERC counts come from census_agg.py (old classifier, >70% = match, 100% = compliant, else flagged, multi-label)."""
import csv, json, sys
yr = {r['spec_entry']: r for r in csv.DictReader(open(sys.argv[1]))}
cnt = {r['erc']: r for r in csv.DictReader(open(sys.argv[2]))}
sel = {e for e, v in json.load(open(sys.argv[3])).items() if v.get('selectors')}
CH = ['bnb', 'ethereum', 'polygon', 'avalanche']
rows = []
for e, y in yr.items():
    c = cnt.get(e, {})
    g = lambda k: int(c.get(k, 0) or 0)
    rows.append({'spec_entry': e, 'erc': y['erc'], 'title': y['title'], 'status': y['status'], 'created': y['created'],
                 'in_classifier': 'yes' if e in sel else 'no (no mandatory selectors)',
                 'matched_gt70': g('contracts_total'), 'compliant_100': g('compliant'), 'flagged': g('flagged'),
                 **{f'{ch}_matched': g(f'{ch}_compliant') + g(f'{ch}_flagged') for ch in CH}})
rows.sort(key=lambda r: (-r['matched_gt70'], r['created']))
w = csv.DictWriter(open(sys.argv[4], 'w', newline=''), fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
print(len(rows), 'entries,', sum(r['in_classifier'] == 'yes' for r in rows), 'in classifier,', sum(r['matched_gt70'] > 0 for r in rows), 'with >=1 match')
