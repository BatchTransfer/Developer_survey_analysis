"""Evaluate every formula in ERC_compliance_results_v1.xlsx without Excel/LibreOffice (supports the functions the builder uses:
SUM, SUMIFS, COUNTIF, COUNTA, IF, AND, SQRT, cell and cross-sheet references, + - * / ^ &, comparisons) and check key results.
Usage: python verify_results_workbook.py [XLSX]"""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import re, sys, math
from openpyxl import load_workbook
from openpyxl.utils import column_index_from_string as CI, get_column_letter as L
P = sys.argv[1] if len(sys.argv) > 1 else ROOT + '/ERC_compliance_results_v1.xlsx'
wb = load_workbook(P); cache = {}; err = []
REF = r"(?:'([^']+)'|([A-Za-z0-9_]+))!"
def cell(sh, a):
    k = (sh, a.replace('$', ''))
    if k in cache: return cache[k]
    v = wb[sh][k[1]].value
    if isinstance(v, str) and v.startswith('='):
        try: v = ev(sh, v[1:])
        except Exception as e: err.append((sh, k[1], v, repr(e))); v = '#ERR'
    cache[k] = v; return v
def rng(sh, a, b):
    a, b = a.replace('$', ''), b.replace('$', '')
    ca, ra = re.match(r'([A-Z]+)(\d+)', a).groups(); cb, rb = re.match(r'([A-Z]+)(\d+)', b).groups()
    return [cell(sh, f'{L(c)}{r}') for r in range(int(ra), int(rb) + 1) for c in range(CI(ca), CI(cb) + 1)]
def crit(v, c):
    if isinstance(c, str):
        m = re.match(r'(>=|<=|<>|>|<|=)?(.*)', c); op, t = m.group(1) or '=', m.group(2)
        try: t = float(t)
        except ValueError: pass
    else: op, t = '=', c
    if isinstance(t, float) and not isinstance(v, (int, float)): return False
    return {'=': v == t, '>=': v is not None and v >= t, '<=': v is not None and v <= t, '>': v is not None and v > t, '<': v is not None and v < t, '<>': v != t}[op]
def SUM(*a): return sum(x for g in a for x in (g if isinstance(g, list) else [g]) if isinstance(x, (int, float)))
def SUMIFS(s, *cr): return sum(v for i, v in enumerate(s) if isinstance(v, (int, float)) and all(crit(cr[j][i], cr[j + 1]) for j in range(0, len(cr), 2)))
def COUNTIF(r, c): return sum(crit(v, c) for v in r)
def COUNTA(r): return sum(v not in (None, '') for v in r)
def IF(c, a, b=False): return a if c else b
def AND(*a): return all(a)
def SQRT(x): return math.sqrt(x)
def ev(sh, f):
    toks = []
    def keep(t): toks.append(t); return f'@@{len(toks) - 1}@@'
    f = re.sub(r'"[^"]*"', lambda m: keep(m.group(0)), f)                                  # protect string literals
    f = re.sub(r"(?:" + REF + r")?(\$?[A-Z]{1,3}\$?\d+):(\$?[A-Z]{1,3}\$?\d+)",
               lambda m: keep(f"rng({(m.group(1) or m.group(2) or sh)!r},{m.group(3)!r},{m.group(4)!r})"), f)
    f = re.sub(r"(?:" + REF + r")?(?<![A-Za-z_@])(\$?[A-Z]{1,3}\$?\d+)(?![\w(@])",
               lambda m: keep(f"cell({(m.group(1) or m.group(2) or sh)!r},{m.group(3)!r})"), f)
    f = f.replace('^', '**').replace('<>', '!=')
    f = re.sub(r'(?<![<>!=])=(?!=)', '==', f)
    f = re.sub(r'(@@\d+@@)\s*&\s*([^,)]+)', r'(\1+str(\2))', f)                            # "">=""&0 -> concatenation
    while '@@' in f: f = re.sub(r'@@(\d+)@@', lambda m: toks[int(m.group(1))], f)
    return eval(f)
n = 0
for ws in wb.worksheets:
    for row in ws.iter_rows():
        for c in row:
            if isinstance(c.value, str) and c.value.startswith('='): cell(ws.title, c.coordinate); n += 1
print('formulas evaluated', n, 'errors', len(err))
for e in err[:10]: print('  ', e)
chk = {('1 Dataset 3.8M', 'B9'): 3808540, ('1 Dataset 3.8M', 'C9'): 2369723, ('1 Dataset 3.8M', 'E9'): 12673, ('1 Dataset 3.8M', 'F9'): 2357050,
       ('2 Dataset 2.3M', 'B9'): 2369723, ('4 Dist 1%', 'E106'): 3808540, ('4 Dist 1%', 'C106'): 12673, ('4 Dist 1%', 'B107'): 'matches tab 1',
       ('9 Ground truth', 'B5'): 100, ('9 Ground truth', 'B9'): 100, ('9 Ground truth', 'B10'): 0, ('9 Ground truth', 'B11'): 1.0}
for (s, a), want in chk.items(): print(f'{s}!{a} = {cache.get((s, a))}  expected {want}  {"OK" if cache.get((s, a)) == want else "MISMATCH"}')
print('Wilson low', round(cache[('9 Ground truth', 'B12')], 4), 'Cochran', round(cache[('9 Ground truth', 'B14')], 4), '2.3M flag rate', round(cache[('2 Dataset 2.3M', 'E9')], 5))
for s in ('5 Dist 5%', '6 Dist 10%'):
    ws = wb[s]; last = max(r for r in range(5, ws.max_row + 1) if ws.cell(r, 1).value == 'Total')
    print(s, 'all', cache[(s, f'E{last}')], 'flagged', cache[(s, f'C{last}')], '| rows', [(ws.cell(r, 1).value, cache[(s, f'C{r}')]) for r in range(5, last) if cache[(s, f'C{r}')]])
ws = wb['8 Per-ERC 2.3M']; print('per-ERC rows', [(ws.cell(r, 1).value, cache[('8 Per-ERC 2.3M', f'L{r}')], cache[('8 Per-ERC 2.3M', f'K{r}')]) for r in range(5, 11)])
ws = wb['10 Spec years']; print('spec years total', [cache.get(('10 Spec years', f'B{r}')) for r in range(5, 30) if ws.cell(r, 1).value == 'Total'])
