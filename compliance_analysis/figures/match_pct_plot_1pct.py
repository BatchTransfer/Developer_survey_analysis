"""1%-bin version of the 3.8M lowest-match distribution (match_pct_plot.py, third figure).
Bar k holds match values in [k, k+1) (e.g. 5/6 = 83.3% -> bar 83, 9/10 = 90% -> bar 90); bar 100 is exactly 100%.
A contract implementing at least one standard (>70%) is placed at its lowest match over those standards (ERC-173/4906 not counted);
a contract implementing none is placed at its best match. Usage: python match_pct_plot_1pct.py MATCH_DIR OUT_PREFIX"""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import sys, glob, math
from collections import Counter
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
D, P = sys.argv[1:3]; SKIP = {'ERC173', 'ERC4906'}
L = Counter(); IMPL = Counter()
def k(p): return 100 if p >= 100 else min(99, math.floor(round(p, 6)))
for f in glob.glob(D + '/*.tsv'):
    for l in open(f):
        x = l.rstrip('\n').split('\t')
        ps = [100 * int(a) / int(n) for m in (x[3].split('|') if x[3] else []) for e, kn in [m.split(':')] if e not in SKIP for a, n in [kn.split('/')]]
        b = k(min(ps)) if ps else k(float(x[4])); L[b] += 1
        if ps: IMPL[b] += 1
assert sum(L.values()) == 3808540, sum(L.values())
nz = [(b, L[b], IMPL[b]) for b in range(101) if L[b]]
open(P + '.txt', 'w').write('bar [k,k+1)%  contracts  of which implementing a standard\n' + ''.join(f'{b:>4} {n:>10,} {i:>10,}\n' for b, n, i in nz)
    + f'implementing {sum(IMPL.values()):,}; flagged {sum(IMPL[b] for b in range(100)):,}\n')
for b, n, i in nz: print(b, n, i)
print('implementing', sum(IMPL.values()), 'flagged', sum(IMPL[b] for b in range(100)))
plt.rcParams.update({'font.size': 8, 'font.family': 'serif', 'axes.spines.top': False, 'axes.spines.right': False})
fig, ax = plt.subplots(figsize=(7.0, 2.4)); xs = list(range(101)); v = [L[b] for b in xs]
col = ['#52514e' if b == 100 else '#2a78d6' if IMPL[b] else '#c3c2b7' for b in xs]
bars = ax.bar(xs, v, color=col, width=0.8, zorder=2)
ax.set_yscale('log'); ax.set_ylim(0.8, max(v) * 40); ax.set_xlim(-1, 101.5)
for b, n, i in nz: ax.text(b, n * 1.3, f'{n:,}', ha='center', va='bottom', fontsize=4.5, rotation=90, color='#0b0b0b')
ax.axvline(69.5, color='#8a8984', lw=0.6, ls='--', zorder=1)
ax.text(69, max(v) * 25, 'implements no standard ', fontsize=6.5, color='#52514e', ha='right', va='top')
ax.text(70, max(v) * 25, ' implements a standard (>70%)', fontsize=6.5, color='#52514e', ha='left', va='top')
ax.set_xticks(range(0, 101, 10)); ax.set_xticks(range(0, 101, 1), minor=True)
ax.set_xlabel('Mandatory functions dispatched (%), 1% bins'); ax.set_ylabel('Contracts (log scale)')
ax.grid(axis='y', color='#e4e3df', lw=0.5, zorder=0); ax.tick_params(length=2); ax.tick_params(which='minor', length=1)
for s_ in ('left', 'bottom'): ax.spines[s_].set_color('#8a8984'); ax.spines[s_].set_linewidth(0.6)
fig.tight_layout(pad=0.3); fig.savefig(P + '.pdf'); fig.savefig(P + '.png', dpi=250)
