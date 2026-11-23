"""Download verified Solidity/Vyper source for the 200 contracts of the seed-2035 sample (old_rule_labels_2035.csv), so each label
can be checked by hand against the source.
Sources tried in order, per contract:
  1. Sourcify v2 (no key)                          https://sourcify.dev/server/v2/contract/{chainId}/{address}?fields=all
  2. Routescan, Avalanche only (no key)            Etherscan-compatible API used by Snowtrace
  3. Etherscan v2 multichain (needs a key)         only when --env points to a file with ETHERSCAN_API_KEY=...
If Etherscan reports a proxy, the implementation's source is fetched too (into impl_<address>/).
Usage: python fetch_sources_2035.py [--env PATH_TO_.env] [--out DIR]
Writes DIR/<i>_<chain>_<address>/ (source files + meta.json) and DIR/index.csv (i, chain, address, old_rule_label, flagged standards,
source found where, contract name, compiler, proxy implementation, explorer url). Re-running skips contracts already found."""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import argparse, csv, json, os, time, urllib.request, urllib.parse
HERE = os.path.dirname(os.path.abspath(__file__))
CID = {'ethereum': 1, 'bnb': 56, 'polygon': 137, 'avalanche': 43114}
URL = {'ethereum': 'https://etherscan.io/address/', 'bnb': 'https://bscscan.com/address/', 'polygon': 'https://polygonscan.com/address/',
       'avalanche': 'https://snowtrace.io/address/'}
RS = 'https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan/api'
ES = 'https://api.etherscan.io/v2/api'

def get(u, tries=4):
    for t in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(u, headers={'User-Agent': 'research-client'}), timeout=60) as r:
                return r.status, json.loads(r.read())
        except urllib.error.HTTPError as e:
            if e.code == 404: return 404, None
            time.sleep(2 * (t + 1))
        except Exception:
            time.sleep(2 * (t + 1))
    return 0, None

def safe(p):
    p = p.replace('\\', '/').lstrip('/')
    return '/'.join(x for x in p.split('/') if x not in ('', '.', '..'))

def write_sources(d, files):
    for p, c in files.items():
        f = os.path.join(d, safe(p) or 'Contract.sol'); os.makedirs(os.path.dirname(f), exist_ok=True); open(f, 'w').write(c)

def sourcify(cid, a):
    s, j = get(f'https://sourcify.dev/server/v2/contract/{cid}/{a}?fields=sources,compilation')
    if s != 200 or not j or not j.get('sources'): return None
    c = j.get('compilation') or {}
    return {'files': {p: v.get('content', '') for p, v in j['sources'].items()}, 'name': c.get('name', ''),
            'compiler': c.get('compilerVersion', ''), 'impl': '', 'match': j.get('match', '')}

def explorer(base, params):
    s, j = get(base + '?' + urllib.parse.urlencode(params))
    if not j or str(j.get('status')) != '1' or not j.get('result'): return None
    r = j['result'][0]; src = r.get('SourceCode') or ''
    if not src: return None
    if src.startswith('{{'): src = src[1:-1]
    try:
        m = json.loads(src); files = {p: v.get('content', '') for p, v in (m.get('sources') or m).items()}
    except (ValueError, AttributeError):
        files = {(r.get('ContractName') or 'Contract') + ('.vy' if 'vyper' in (r.get('CompilerVersion') or '').lower() else '.sol'): src}
    return {'files': files, 'name': r.get('ContractName', ''), 'compiler': r.get('CompilerVersion', ''),
            'impl': (r.get('Implementation') or '').lower() if r.get('Proxy') == '1' else '', 'match': 'verified'}

def fetch(ch, a, key):
    r = sourcify(CID[ch], a)
    if r: return 'sourcify', r
    if ch == 'avalanche':
        r = explorer(RS, {'module': 'contract', 'action': 'getsourcecode', 'address': a})
        if r: return 'routescan', r
    if key:
        r = explorer(ES, {'chainid': CID[ch], 'module': 'contract', 'action': 'getsourcecode', 'address': a, 'apikey': key}); time.sleep(0.25)
        if r: return 'etherscan', r
    return '', None

def load_key(p):
    if not p: return ''
    for l in open(os.path.expanduser(p)):
        k, _, v = l.strip().partition('=')
        if k.strip() in ('ETHERSCAN_API_KEY', 'ETHERSCAN_API_KEY1'): return v.strip().strip('"').strip("'")
    return ''

if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--env'); ap.add_argument('--out', default=HERE + '/sources_2035')
    A = ap.parse_args(); key = load_key(A.env); os.makedirs(A.out, exist_ok=True)
    rows = list(csv.DictReader(open(HERE + '/old_rule_labels_2035.csv'))); idx = []; n = 0
    for r in rows:
        i, ch, a = r['i'], r['chain'], r['address'].lower(); d = f'{A.out}/{int(i):03d}_{ch}_{a}'
        if os.path.exists(d + '/meta.json'):
            m = json.load(open(d + '/meta.json'))
        else:
            where, res = fetch(ch, a, key); m = {'where': where, 'name': '', 'compiler': '', 'impl': '', 'impl_where': ''}
            if res:
                os.makedirs(d, exist_ok=True); write_sources(d, res['files']); m.update(name=res['name'], compiler=res['compiler'], impl=res['impl'])
                if res['impl']:
                    w2, r2 = fetch(ch, res['impl'], key)
                    if r2: write_sources(f"{d}/impl_{res['impl']}", r2['files']); m['impl_where'] = w2
                json.dump(m, open(d + '/meta.json', 'w'), indent=1)
        n += bool(m['where'])
        idx.append([i, ch, a, r['old_rule_label'], r['old_flagged_standards'], m['where'] or 'not verified / not found', m['name'], m['compiler'],
                    m['impl'], m.get('impl_where', ''), URL[ch] + a + '#code'])
        print(i, ch, a, m['where'] or '-', m['name'], flush=True)
    with open(A.out + '/index.csv', 'w', newline='') as f:
        w = csv.writer(f); w.writerow(['i', 'chain', 'address', 'old_rule_label', 'old_flagged_standards', 'source_from', 'contract_name',
                                       'compiler', 'proxy_implementation', 'implementation_source_from', 'explorer_url']); w.writerows(idx)
    print(f'source found for {n} of {len(rows)}; index: {A.out}/index.csv')
