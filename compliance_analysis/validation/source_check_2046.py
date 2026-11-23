"""Check the seed-2046 labels against verified source (sources_seed2046/). For each contract with source, find the deployed contract
(meta.json name) and its inheritance closure, then, for each function the classifier reported missing, look for
  - a function definition with that name in the closure (with its parameter list, visibility and whether it has a body), and
  - a public state variable with that name in the closure (the compiler generates a getter, e.g. `mapping(...) public allowance`).
Definitions only in interfaces or in contracts outside the closure are listed separately (they do not make the function exposed).
Usage: python source_check_2046.py  -> sources_seed2046/source_check.csv and a printed per-contract report."""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import csv, json, os, re, glob
HERE = os.path.dirname(os.path.abspath(__file__)); S = HERE + '/sources_seed2046'
def strip(t):
    t = re.sub(r'/\*.*?\*/', ' ', t, flags=re.S); t = re.sub(r'//[^\n]*', ' ', t)
    return re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '""', t)
HDR = re.compile(r'\b(abstract\s+contract|contract|interface|library)\s+([A-Za-z_]\w*)\s*(?:is\s+([^{]*))?\{')
def units(t):
    u = {}
    for m in HDR.finditer(t):
        d, i = 1, m.end()
        while d and i < len(t):
            d += {'{': 1, '}': -1}.get(t[i], 0); i += 1
        parents = [re.split(r'[\s(]', p.strip())[0] for p in (m.group(3) or '').split(',') if p.strip()]
        u.setdefault(m.group(2), (m.group(1).split()[-1], parents, t[m.end():i - 1]))
    return u
def closure(u, n, seen=None):
    seen = seen if seen is not None else []
    if n in u and n not in seen:
        seen.append(n)
        for p in u[n][1]: closure(u, p, seen)
    return seen
rows = []
for r in csv.DictReader(open(S + '/index.csv')):
    if r['source_from'] == 'not verified / not found': continue
    d = glob.glob(f"{S}/{int(r['i']):03d}_*")[0]; m = json.load(open(d + '/meta.json'))
    t = '\n'.join(strip(open(f, errors='ignore').read()) for f in glob.glob(d + '/**/*', recursive=True)
                  if f.endswith(('.sol', '.vy')) and '/impl_' not in f)
    u = units(t); main = m['name'] if m['name'] in u else None; cl = closure(u, main) if main else []
    for fn in r['missing_functions_to_check'].split('; '):
        name, args = fn.split('(')[0], fn.split('(', 1)[1].rstrip(')')
        inside, outside = [], []
        for cn, (kind, _, body) in u.items():
            for fm in re.finditer(r'\bfunction\s+' + name + r'\s*\(([^)]*)\)([^{;]*)([{;])', body):
                txt = f"{kind} {cn}: function {name}({' '.join(fm.group(1).split())}) {' '.join(fm.group(2).split())} {'body' if fm.group(3) == '{' else 'no body'}"
                (inside if cn in cl and kind != 'interface' else outside).append(txt)
            for vm in re.finditer(r'[^;{}]*\bpublic\b[^;{}()]*\b' + name + r'\s*[;=]', body):
                txt = f"{kind} {cn}: public variable: {' '.join(vm.group(0).split())[:90]}"
                (inside if cn in cl and kind != 'interface' else outside).append(txt)
        rows.append([r['i'], r['chain'], r['address'], m['name'], r['flagged'], fn, main is not None, ' > '.join(cl), ' || '.join(inside), ' || '.join(outside)])
with open(S + '/source_check.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['i', 'chain', 'address', 'contract', 'flagged', 'missing_function', 'main_contract_found', 'inheritance', 'defined_in_contract', 'defined_elsewhere_only']); w.writerows(rows)
for x in rows:
    print(f"#{x[0]} {x[3]} [{x[4]}] missing {x[5]}\n   main found={x[6]}  inherits: {x[7][:150]}\n   IN CONTRACT: {x[8] or '-'}\n   elsewhere: {x[9][:300] or '-'}")
