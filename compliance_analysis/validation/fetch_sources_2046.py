"""Download verified source for the seed-2046 sample of 100 from the 12,673 flagged contracts (labels_100_seed2046.csv), for manual review.
Reuses the fetchers of ../erc_compliance_oldflagged200/fetch_sources_2035.py: Sourcify (no key), Routescan for Avalanche (no key),
Etherscan v2 only with --env PATH (a file with ETHERSCAN_API_KEY=...). Proxies also get impl_<address>/.
Usage: python fetch_sources_2046.py [--env PATH]
Writes sources_seed2046/<i>_<chain>_<address>/ and sources_seed2046/index.csv (label, flagged standards, missing functions to look for)."""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import argparse, csv, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); R = ROOT
sys.path.insert(0, HERE); from fetch_sources_2035 import fetch, write_sources, load_key, URL
SPEC = json.load(open(CLASSIFIER + '/erc_specification_v5.json'))
NAME = {s: f for e in SPEC.values() for f, s in (e.get('functions') or {}).items()}
ap = argparse.ArgumentParser(); ap.add_argument('--env'); A = ap.parse_args(); key = load_key(A.env)
OUT = HERE + '/sources_seed2046'; os.makedirs(OUT, exist_ok=True)
rows = list(csv.DictReader(open(HERE + '/new_classifier_70_no_overlap/labels_100_seed2046.csv'))); idx = []; n = 0
for r in rows:
    i, ch, a = r['i'], r['chain'], r['address'].lower(); d = f'{OUT}/{int(i):03d}_{ch}_{a}'
    if os.path.exists(d + '/meta.json'): m = json.load(open(d + '/meta.json'))
    else:
        where, res = fetch(ch, a, key); m = {'where': where, 'name': '', 'compiler': '', 'impl': '', 'impl_where': ''}
        if res:
            os.makedirs(d, exist_ok=True); write_sources(d, res['files']); m.update(name=res['name'], compiler=res['compiler'], impl=res['impl'])
            if res['impl']:
                w2, r2 = fetch(ch, res['impl'], key)
                if r2: write_sources(f"{d}/impl_{res['impl']}", r2['files']); m['impl_where'] = w2
            json.dump(m, open(d + '/meta.json', 'w'), indent=1)
    n += bool(m['where'])
    miss = '; '.join(NAME.get(s, s) for s in r['missing_selectors'].split())
    idx.append([i, ch, a, r['label'], r['flagged'], miss, m['where'] or 'not verified / not found', m['name'], m['compiler'], m['impl'],
                m.get('impl_where', ''), URL[ch] + a + '#code'])
    print(i, ch, a, m['where'] or '-', m['name'], flush=True)
with open(OUT + '/index.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['i', 'chain', 'address', 'label', 'flagged', 'missing_functions_to_check', 'source_from', 'contract_name', 'compiler',
                                   'proxy_implementation', 'implementation_source_from', 'explorer_url']); w.writerows(idx)
print(f'source found for {n} of {len(rows)}; index: {OUT}/index.csv')
