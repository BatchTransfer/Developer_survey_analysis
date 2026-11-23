"""Build data/compliance_results/ERC_compliance_results_v1.xlsx from the new (dispatcher-based) classifier only.
Inputs (all produced by the scripts in this folder):
  ~/Downloads/evm_data/match_pct_70_no_overlap/   match_pct_census.py: per contract, STD:k/n for every standard matched (>70%,
                                                   distinctive-function rule, overlap rule off) and the best match % (0 if none)
  data/ground_truth/new_flagged_all_100/new_classifier_70_no_overlap/labels_100_seed2046.csv   validation labels (seed 2046)
  data/ground_truth/new_flagged_all_100/sources_seed2046/source_verdicts.csv                   source-code check of 53 of them
  data/specifications/yearly_distribution/erc_79_specifications_by_year.csv                     spec creation years
Conventions: blue = counts from the data, black = formulas, green = links to another tab. Match-% bins are [x, x+1) etc.; 100 = exactly 100%.
Contract-level match % = lowest dispatched share over the standards it implements (ERC-173/4906 not counted); a contract implementing
none is placed at its best match (<=70%). Usage: python build_results_workbook.py"""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import csv, glob, math, os
from collections import Counter, defaultdict
from openpyxl import Workbook
from openpyxl.styles import Font, Alignment, PatternFill
from openpyxl.utils import get_column_letter as L

R = ROOT; H = EVM_DATA
MATCH = os.environ.get('MATCH_DIR', RESULTS + '/match_pct_70_no_overlap'); OUT = ROOT + '/ERC_compliance_results_v1.xlsx'
GT = VALIDATION; SPEC_YEARS = ROOT + '/../erc_distribution/erc_79_specifications_by_year.csv'
CH = ['ethereum', 'bnb', 'polygon', 'avalanche']; CHN = {'ethereum': 'Ethereum', 'bnb': 'BNB', 'polygon': 'Polygon', 'avalanche': 'Avalanche'}
SKIP = {'ERC173', 'ERC4906'}

# ---------- one pass over the census ----------
tot, impl, flg = Counter(), Counter(), Counter()
d1 = defaultdict(Counter)              # (chain, kind) -> 1% bin counts; kind in none / flagged / complete
std_c, std_f = defaultdict(Counter), defaultdict(Counter)   # std -> chain -> compliant / flagged
flagged_rows = []
def b1(p): return 100 if p >= 100 else min(99, math.floor(round(p, 6)))
for f in sorted(glob.glob(MATCH + '/*.tsv')):
    for l in open(f):
        x = l.rstrip('\n').split('\t'); ch = x[0]; tot[ch] += 1
        m = [(e, int(k), int(n)) for e, kn in (s.split(':') for s in x[3].split('|')) if x[3] for k, n in [kn.split('/')]] if x[3] else []
        for e, k, n in m: (std_c if k == n else std_f)[e][ch] += 1
        ps = [100 * k / n for e, k, n in m if e not in SKIP]
        if not ps:
            d1[(ch, 'none')][b1(float(x[4]))] += 1; continue
        impl[ch] += 1; lo = min(ps)
        if lo < 100:
            flg[ch] += 1; d1[(ch, 'flagged')][b1(lo)] += 1
            flagged_rows.append([CHN[ch], x[1].strip('"').lower(), '|'.join(sorted(e for e, k, n in m if k < n)),
                                 '|'.join(sorted(e for e, k, n in m if k == n)), ' | '.join(f'{e} {k}/{n}' for e, k, n in sorted(m)), round(lo, 2)])
        else:
            d1[(ch, 'complete')][100] += 1
assert sum(tot.values()) == 3808540 and sum(impl.values()) == 2369723 and sum(flg.values()) == 12673, (tot, impl, flg)
flagged_rows.sort(key=lambda r: (r[0], r[1]))

# ---------- styles ----------
F = 'Arial'; BLUE = Font(name=F, color='0000FF', size=10); BLACK = Font(name=F, size=10); GREEN = Font(name=F, color='008000', size=10)
BOLD = Font(name=F, bold=True, size=10); TITLE = Font(name=F, bold=True, size=12); NOTE = Font(name=F, italic=True, size=9, color='52514E')
HDR = PatternFill('solid', fgColor='E4E3DF'); N0, P2 = '#,##0', '0.00%'
wb = Workbook(); wb.remove(wb.active)
def sheet(name, title, note, widths):
    ws = wb.create_sheet(name); ws['A1'] = title; ws['A1'].font = TITLE; ws['A2'] = note; ws['A2'].font = NOTE
    for i, w in enumerate(widths, 1): ws.column_dimensions[L(i)].width = w
    return ws
def header(ws, row, cols):
    for j, c in enumerate(cols, 1):
        cell = ws.cell(row, j, c); cell.font = BOLD; cell.fill = HDR; cell.alignment = Alignment(wrap_text=True, vertical='center')
def put(ws, r, c, v, font=BLACK, fmt=None):
    cell = ws.cell(r, c, v); cell.font = font
    if fmt: cell.number_format = fmt
    return cell

# ---------- README ----------
ws = sheet('README', 'ERC compliance results v1 (new dispatcher-based classifier only)',
           'Blue = counts from the data. Black = formulas. Green = links to another tab. No results of the earlier text-search classifier.', [26, 120])
rows = [('Tab', 'What it shows'),
        ('1 Dataset 3.8M', 'All 3,808,540 contracts per chain: implementing a standard (>70%), not implementing, flagged, complete.'),
        ('2 Dataset 2.3M', 'The 2,369,723 contracts implementing at least one standard per chain: complete vs flagged, flag rate.'),
        ('3 Flagged 12,673', 'One row per flagged contract: flagged and complete standards, dispatched/mandatory functions per standard, lowest match %.'),
        ('4 Dist 1%', 'Match-% distribution of all 3.8M contracts in 1% bins [x, x+1), split into no standard / flagged / complete and by chain.'),
        ('5 Dist 5%', '5% bins [x, x+5), SUMIFS over tab 4.'),
        ('6 Dist 10%', '10% bins [x, x+10), SUMIFS over tab 4 (the bins of the paper figure).'),
        ('7 Per-ERC 3.8M', 'Contracts implementing each standard (>70%) per chain, as a share of all 3,808,540 contracts.'),
        ('8 Per-ERC 2.3M', 'Per standard and chain: complete (100%) and flagged (<100%) contracts, flag rate.'),
        ('9 Ground truth', 'Random sample of 100 of the 12,673 flagged contracts (seed 2046): manual labels Violation / Not a Violation, precision with Wilson 95% CI.'),
        ('10 Spec years', 'Creation year of the 79 ERC/EIP specification entries (EIP header "created" field).'),
        ('', ''),
        ('Classifier', 'erc_classifier.py: exposed functions = selectors pushed (PUSH1-4, leading zeros restored) within 3 opcodes before an EQ in the dispatcher.'),
        ('Implementing', 'A contract implements a standard when more than 70% of its mandatory functions are dispatched and at least half of its distinctive functions are present (ERC-2612: permit; ERC-7160: tokenURIs). Overlap rule off.'),
        ('Complete / flagged', 'Complete = 100% of mandatory functions dispatched; flagged = implementing but below 100%. ERC-4906 (same functions as ERC-721) and ERC-173 are not counted as flags.'),
        ('Match % of a contract', 'Lowest dispatched share over the standards it implements (a contract is flagged when any of them is below 100%). A contract implementing none is placed at its best match, which is at most 70%.'),
        ('Bins', '[x, x+1): bar 83 holds 83.0-83.99% (e.g. 5/6 = 83.3%). Bar 100 is exactly 100%. Bar 0 is exactly 0% (the smallest non-zero match is above 1%).'),
        ('Scope', 'All 3,808,540 contracts, including 30,778 Vyper or SUB/XOR-dispatch contracts whose selectors the EQ reader may miss (limitation in the paper).'),
        ('Per-contract data', 'Excel holds at most 1,048,576 rows per sheet, so the 3.8M per-contract results are in results/match_pct_70_no_overlap/*.tsv.gz (one file per chain).'),
        ('Scripts', 'research_scripts/classifier_census/: match_pct_census.py, match_pct_plot.py, match_pct_plot_1pct.py, table_counts.py, build_results_workbook.py (this file).'),
        ('Labels', 'Labelled by Claude from the disassembled dispatcher; 53 checked against verified source. Not yet cross-checked by a second researcher.')]
for i, (a, b) in enumerate(rows, 4):
    put(ws, i, 1, a, BOLD if i == 4 or a else BLACK); put(ws, i, 2, b).alignment = Alignment(wrap_text=True, vertical='top')
for c in (1, 2): ws.cell(4, c).fill = HDR

# ---------- 1 Dataset 3.8M ----------
ws = sheet('1 Dataset 3.8M', 'All contracts per chain (3,808,540)', 'Blue = counts from the census; black = formulas.', [14, 16, 18, 18, 14, 14, 16, 16])
header(ws, 4, ['Chain', 'All contracts', 'Implementing a standard (>70%)', 'Implementing no standard', 'Flagged', 'Complete', 'Implementing share', 'Flagged share of all'])
for i, ch in enumerate(CH, 5):
    put(ws, i, 1, CHN[ch]); put(ws, i, 2, tot[ch], BLUE, N0); put(ws, i, 3, impl[ch], BLUE, N0); put(ws, i, 4, f'=B{i}-C{i}', fmt=N0)
    put(ws, i, 5, flg[ch], BLUE, N0); put(ws, i, 6, f'=C{i}-E{i}', fmt=N0); put(ws, i, 7, f'=C{i}/B{i}', fmt=P2); put(ws, i, 8, f'=E{i}/B{i}', fmt=P2)
put(ws, 9, 1, 'Total', BOLD)
for c in range(2, 7): put(ws, 9, c, f'=SUM({L(c)}5:{L(c)}8)', BOLD, N0)
put(ws, 9, 7, '=C9/B9', BOLD, P2); put(ws, 9, 8, '=E9/B9', BOLD, P2)

# ---------- 2 Dataset 2.3M ----------
ws = sheet('2 Dataset 2.3M', 'Contracts implementing at least one standard (2,369,723)', 'Green = linked from tab 1; black = formulas. Flag rate = flagged / implementing.', [14, 18, 14, 14, 14, 16])
header(ws, 4, ['Chain', 'Implementing', 'Complete', 'Flagged', 'Flag rate', 'Share of implementing'])
for i in range(5, 10):
    put(ws, i, 1, f"='1 Dataset 3.8M'!A{i}", GREEN if i < 9 else BOLD); put(ws, i, 2, f"='1 Dataset 3.8M'!C{i}", GREEN, N0)
    put(ws, i, 3, f"='1 Dataset 3.8M'!F{i}", GREEN, N0); put(ws, i, 4, f"='1 Dataset 3.8M'!E{i}", GREEN, N0)
    put(ws, i, 5, f'=D{i}/B{i}', BOLD if i == 9 else BLACK, P2); put(ws, i, 6, f'=B{i}/$B$9', BOLD if i == 9 else BLACK, P2)

# ---------- 3 Flagged 12,673 ----------
ws = sheet('3 Flagged 12,673', 'Flagged contracts (12,673)', 'One row per contract (blue, from the census). Dispatched/mandatory = functions found in the dispatcher / mandatory functions of the standard.', [11, 46, 30, 40, 70, 13])
header(ws, 4, ['Chain', 'Address', 'Flagged standards', 'Complete standards', 'Dispatched/mandatory per implemented standard', 'Lowest match %'])
for i, r in enumerate(flagged_rows, 5):
    for j, v in enumerate(r, 1): put(ws, i, j, v, BLUE, '0.00' if j == 6 else None)
ws.freeze_panes = 'A5'; ws.auto_filter.ref = f'A4:F{4 + len(flagged_rows)}'

# ---------- 4 Dist 1% ----------
ws = sheet('4 Dist 1%', 'Match-% distribution of all 3,808,540 contracts, 1% bins [x, x+1)',
           'Blue = counts from the census; black = formulas. Bin = lower edge x; 100 = exactly 100%. No standard: best match; implementing: lowest match.', [9] + [13] * 17)
cols = ['Bin [x, x+1)', 'No standard', 'Flagged', 'Complete', 'All contracts', 'Implementing'] + [f'{CHN[c]} {k}' for c in CH for k in ('no standard', 'flagged', 'complete')]
header(ws, 4, cols)
for i, b in enumerate(range(101), 5):
    put(ws, i, 1, b)
    for ci, ch in enumerate(CH):
        for ki, k in enumerate(('none', 'flagged', 'complete')): put(ws, i, 7 + 3 * ci + ki, d1[(ch, k)][b], BLUE, N0)
    for ki in range(3): put(ws, i, 2 + ki, '=' + '+'.join(f'{L(7 + 3 * ci + ki)}{i}' for ci in range(4)), fmt=N0)
    put(ws, i, 5, f'=B{i}+C{i}+D{i}', fmt=N0); put(ws, i, 6, f'=C{i}+D{i}', fmt=N0)
put(ws, 106, 1, 'Total', BOLD)
for c in range(2, 19): put(ws, 106, c, f'=SUM({L(c)}5:{L(c)}105)', BOLD, N0)
put(ws, 107, 1, 'Check', BOLD); put(ws, 107, 2, "=IF(AND(E106='1 Dataset 3.8M'!B9,F106='1 Dataset 3.8M'!C9,C106='1 Dataset 3.8M'!E9),\"matches tab 1\",\"DIFFERS from tab 1\")")
ws.freeze_panes = 'B5'

# ---------- 5 / 6 coarse distributions ----------
def coarse(name, w):
    ws = sheet(name, f'Match-% distribution of all 3,808,540 contracts, {w}% bins [x, x+{w})',
               f"SUMIFS over tab 4 (bins x to x+{w - 1}). 0 = exactly 0%; (0, {w}) = above 0 and below {w}%; 100 = exactly 100%.", [12] + [13] * 17)
    header(ws, 4, ['Bin'] + cols[1:]); r = 5
    bins = [('0', 0, 0), (f'(0, {w})', 1, w - 1)] + [(f'[{x}, {x + w})', x, x + w - 1) for x in range(w, 100, w)] + [('100', 100, 100)]
    for lab, lo, hi in bins:
        put(ws, r, 1, lab)
        for c in range(2, 19):
            col = L(c); put(ws, r, c, f"=SUMIFS('4 Dist 1%'!{col}$5:{col}$105,'4 Dist 1%'!$A$5:$A$105,\">=\"&{lo},'4 Dist 1%'!$A$5:$A$105,\"<=\"&{hi})", GREEN, N0)
        r += 1
    put(ws, r, 1, 'Total', BOLD)
    for c in range(2, 19): put(ws, r, c, f'=SUM({L(c)}5:{L(c)}{r - 1})', BOLD, N0)
    ws.freeze_panes = 'B5'
coarse('5 Dist 5%', 5); coarse('6 Dist 10%', 10)

# ---------- 7 Per-ERC 3.8M ----------
stds = sorted(set(std_c) | set(std_f), key=lambda e: -sum(std_c[e].values()) - sum(std_f[e].values()))
ws = sheet('7 Per-ERC 3.8M', 'Contracts implementing each standard (>70%), all 3,808,540 contracts',
           'A contract is counted once for every standard it implements, so rows overlap. Blue = census counts; black = formulas. ERC-173 and ERC-4906 are listed but never counted as flags.', [12, 13, 13, 13, 13, 14, 16])
header(ws, 4, ['ERC'] + [CHN[c] for c in CH] + ['Total', 'Share of 3.8M'])
for i, e in enumerate(stds, 5):
    put(ws, i, 1, e)
    for j, ch in enumerate(CH, 2): put(ws, i, j, std_c[e][ch] + std_f[e][ch], BLUE, N0)
    put(ws, i, 6, f'=SUM(B{i}:E{i})', fmt=N0); put(ws, i, 7, f"=F{i}/'1 Dataset 3.8M'!$B$9", fmt=P2)
last = 4 + len(stds); put(ws, last + 2, 1, 'All contracts', BOLD)
for j in range(2, 6): put(ws, last + 2, j, f"='1 Dataset 3.8M'!B{4 + j - 1}", GREEN, N0)
put(ws, last + 2, 6, "='1 Dataset 3.8M'!B9", GREEN, N0); ws.freeze_panes = 'B5'

# ---------- 8 Per-ERC 2.3M ----------
ws = sheet('8 Per-ERC 2.3M', 'Complete and flagged contracts per standard (2,369,723 implementing contracts)',
           'Blue = census counts; black = formulas. Flag rate = flagged / implementing. ERC-173 and ERC-4906 flags are not counted in the 12,673.', [12] + [12] * 8 + [13, 13, 13, 12])
hd = ['ERC'] + [f'{CHN[c]} {k}' for c in CH for k in ('complete', 'flagged')] + ['Complete', 'Flagged', 'Implementing', 'Flag rate']
header(ws, 4, hd)
for i, e in enumerate(stds, 5):
    put(ws, i, 1, e)
    for ci, ch in enumerate(CH):
        put(ws, i, 2 + 2 * ci, std_c[e][ch], BLUE, N0); put(ws, i, 3 + 2 * ci, std_f[e][ch], BLUE, N0)
    put(ws, i, 10, f'=B{i}+D{i}+F{i}+H{i}', fmt=N0); put(ws, i, 11, f'=C{i}+E{i}+G{i}+I{i}', fmt=N0)
    put(ws, i, 12, f'=J{i}+K{i}', fmt=N0); put(ws, i, 13, f'=IF(L{i}=0,0,K{i}/L{i})', fmt=P2)
ws.freeze_panes = 'B5'

# ---------- 9 Ground truth ----------
lab = list(csv.DictReader(open(GT + '/new_classifier_70_no_overlap/labels_100_seed2046.csv')))
sv = {r['i']: r for r in csv.DictReader(open(GT + '/sources_seed2046/source_verdicts.csv'))}
idx = {r['i']: r for r in csv.DictReader(open(GT + '/sources_seed2046/index.csv'))}
ws = sheet('9 Ground truth', 'Validation: random sample of 100 of the 12,673 flagged contracts (seed 2046)',
           'Manual label (blue): Violation = every mandatory function the tool reports missing has no dispatcher entry; Not a Violation = one of them is exposed. Outcome and metrics are formulas.',
           [6, 11, 46, 22, 44, 12, 16, 10, 22, 26, 70])
put(ws, 4, 1, 'Metric', BOLD); put(ws, 4, 2, 'Value', BOLD)
for c in (1, 2): ws.cell(4, c).fill = HDR
N = len(lab); first, lastr = 16, 15 + N
mets = [('Sample size', f'=COUNTA(C{first}:C{lastr})', N0), ('Population (flagged contracts)', "='1 Dataset 3.8M'!E9", N0),
        ('Labelled Violation', f'=COUNTIF(G{first}:G{lastr},"Violation")', N0), ('Labelled Not a Violation', f'=COUNTIF(G{first}:G{lastr},"Not a Violation")', N0),
        ('TP (tool flagged, Violation)', f'=COUNTIF(H{first}:H{lastr},"TP")', N0), ('FP (tool flagged, Not a Violation)', f'=COUNTIF(H{first}:H{lastr},"FP")', N0),
        ('Precision', '=B9/(B9+B10)', P2),
        ('Wilson 95% low', '=(B11+1.96^2/(2*B5)-1.96*SQRT(B11*(1-B11)/B5+1.96^2/(4*B5^2)))/(1+1.96^2/B5)', P2),
        ('Wilson 95% high', '=(B11+1.96^2/(2*B5)+1.96*SQRT(B11*(1-B11)/B5+1.96^2/(4*B5^2)))/(1+1.96^2/B5)', P2),
        ('Cochran margin of error (95%, p=0.5)', '=1.96*SQRT(0.25/B5)*SQRT((B6-B5)/(B6-1))', P2)]
for i, (a, f, fm) in enumerate(mets, 5): put(ws, i, 1, a); put(ws, i, 2, f, GREEN if 'Dataset' in f else BLACK, fm)
ws.column_dimensions['A'].width = 34
header(ws, 15, ['#', 'Chain', 'Address', 'Flagged standards', 'Functions reported missing', 'Tool output', 'Manual label', 'Outcome',
                'Verified source', 'Source check', 'Why'])
for i, r in enumerate(lab, first):
    s = sv.get(r['i']); x = idx.get(r['i'], {})
    vals = [int(r['i']), CHN[r['chain']], r['address'], r['flagged'], x.get('missing_functions_to_check', r['missing_selectors']), 'Flagged',
            'Violation' if r['label'] == 'TP' else 'Not a Violation']
    for j, v in enumerate(vals, 1): put(ws, i, j, v, BLUE)
    put(ws, i, 8, f'=IF(F{i}="Flagged",IF(G{i}="Violation","TP","FP"),"")')
    put(ws, i, 9, (s['contract'] if s else 'not verified'), BLUE)
    put(ws, i, 10, ('confirms label' if s and s['source_verdict'].startswith(r['label']) else 'contradicts label') if s else 'bytecode only', BLUE)
    put(ws, i, 11, s['why'] if s else r['why'], BLUE)
ws.freeze_panes = 'A16'

# ---------- 10 Spec years ----------
sp = list(csv.DictReader(open(SPEC_YEARS)))
ws = sheet('10 Spec years', f'Creation year of the {len(sp)} ERC/EIP specification entries',
           'Year from the official EIP header "created" field (blue). Counts per year are COUNTIF formulas over the list.', [14, 14, 14, 4, 16, 8, 46, 12, 12, 8])
header(ws, 4, ['Year', 'Specification entries', 'Cumulative'])
years = sorted({int(r['year']) for r in sp}); ls = 5 + len(years) + 3
for i, y in enumerate(years, 5):
    put(ws, i, 1, y); put(ws, i, 2, f'=COUNTIF($J${ls + 1}:$J${ls + len(sp)},A{i})', fmt=N0); put(ws, i, 3, f'=SUM($B$5:B{i})', fmt=N0)
put(ws, 5 + len(years), 1, 'Total', BOLD); put(ws, 5 + len(years), 2, f'=SUM(B5:B{4 + len(years)})', BOLD, N0)
for j, c in enumerate(['Spec entry', 'ERC', 'Title', 'Status', 'Created', 'Year'], 5): ws.cell(ls, j, c).font = BOLD; ws.cell(ls, j, c).fill = HDR
for i, r in enumerate(sp, ls + 1):
    for j, k in enumerate(['spec_entry', 'erc', 'title', 'status', 'created', 'year'], 5):
        v = r[k]; put(ws, i, j, int(v) if k in ('erc', 'year') and v.isdigit() else v, BLUE)

from openpyxl.workbook.properties import CalcProperties
wb.calculation = CalcProperties(fullCalcOnLoad=True)   # no cached values: Excel computes every formula on open
wb.save(OUT); print('wrote', OUT, '| flagged rows', len(flagged_rows), '| standards', len(stds))
