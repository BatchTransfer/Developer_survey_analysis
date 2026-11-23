"""Match-% distribution of the contracts that implement at least one standard (output of match_pct_census.py).
Contract-level match % = lowest dispatched share over the standards it matches, ERC-173 and ERC-4906 not counted (as in tab:non-compliance);
contracts matching only ERC-173/ERC-4906 are reported separately. Also prints the standard-level distribution for the main ERCs.
Second figure (OUT_PREFIX_all): every contract's best match % over the standards that pass the distinctive-function rule (0 if none).
Usage: python match_pct_plot.py MATCH_DIR OUT_PREFIX   -> OUT_PREFIX[_all].pdf/.png, OUT_PREFIX.txt"""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import sys, glob
from collections import Counter, defaultdict
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
D, P = sys.argv[1:3]; SKIP = {'ERC173', 'ERC4906'}
BINS = [(70, 75), (75, 80), (80, 85), (85, 90), (90, 95), (95, 100)]
def b(p): return 'full' if p >= 100 else next(f'{lo}–{hi}' for lo, hi in BINS if lo <= round(p, 6) < hi)   # bins [lo, hi), as in the 1% plot
tot = eli = only_skip = 0; C = Counter(); S = defaultdict(Counter); A = Counter()
AB = ['0'] + [f'{10*i}–{10*i+10}' for i in range(10)] + ['100']
def ab(p): return '0' if p == 0 else '100' if p >= 100 else AB[1 + min(9, int(round(p, 6) // 10))]   # [x, x+10), as in the 1% plot
for f in glob.glob(D + '/*.tsv'):
    for l in open(f):
        x = l.rstrip('\n').split('\t'); tot += 1; A[ab(float(x[4]))] += 1
        if len(x) < 4 or not x[3]: continue
        eli += 1; ps = []
        for m in x[3].split('|'):
            e, kn = m.split(':'); k, n = map(int, kn.split('/')); p = 100 * k / n
            if e in SKIP: continue
            ps.append(p); S[e][b(p)] += 1
        if not ps: only_skip += 1; continue
        C[b(min(ps))] += 1
labs = [f'{lo}–{hi}' for lo, hi in BINS] + ['full']
out = [f'contracts {tot:,}; implement >=1 standard (>70%) {eli:,}; only ERC-173/ERC-4906 {only_skip:,}',
       'contract-level lowest match % (excl. ERC-173/4906):'] + [f'  {k:>7}%  {C[k]:>10,}' for k in labs]
out.append(f'  flagged (<100%) {sum(C[k] for k in labs[:-1]):,}   all matched standards complete {C["full"]:,}')
for e in ['ERC20', 'ERC721', 'ERC2612', 'ERC1155', 'ERC3754', 'ERC7160', 'ERC4626']:
    out.append(f'{e}: ' + ', '.join(f'{k}%={S[e][k]:,}' for k in labs))
out += ['all contracts, best match % (distinctive rule applied):'] + [f'  {k:>7}%  {A[k]:>10,}' for k in AB]
open(P + '.txt', 'w').write('\n'.join(out) + '\n'); print('\n'.join(out))
plt.rcParams.update({'font.size': 8, 'font.family': 'serif', 'axes.spines.top': False, 'axes.spines.right': False})
fig, ax = plt.subplots(figsize=(3.4, 2.1)); xs = ['[70, 80)', '[80, 90)', '[90, 100)', '100']   # same bins as the 3.8M figure
v = [C[labs[0]] + C[labs[1]], C[labs[2]] + C[labs[3]], C[labs[4]] + C[labs[5]], C['full']]
bars = ax.bar(xs, v, color=['#2a78d6'] * 3 + ['#52514e'], width=0.6, zorder=2)
ax.set_yscale('log'); ax.set_ylim(1, max(v) * 10)
for r, n in zip(bars, v): ax.text(r.get_x() + r.get_width() / 2, n * 1.25, f'{n:,}', ha='center', va='bottom', fontsize=6.5, color='#0b0b0b')
ax.set_xlabel('Mandatory functions dispatched (%)'); ax.set_ylabel('Contracts (log scale)')
ax.grid(axis='y', color='#e4e3df', lw=0.5, zorder=0); ax.tick_params(axis='x', labelsize=6.5); ax.tick_params(length=2)
for s in ('left', 'bottom'): ax.spines[s].set_color('#8a8984'); ax.spines[s].set_linewidth(0.6)
fig.tight_layout(pad=0.3); fig.savefig(P + '.pdf'); fig.savefig(P + '.png', dpi=220)

fig, ax = plt.subplots(figsize=(3.4, 2.1)); v = [A[k] for k in AB]
xl = ['0', '(0, 10)'] + [f'[{10*i}, {10*i+10})' for i in range(1, 10)] + ['100']
bars = ax.bar(range(len(AB)), v, color=['#c3c2b7'] * 8 + ['#2a78d6'] * 3 + ['#52514e'], width=0.75, zorder=2)
ax.set_yscale('log'); ax.set_ylim(1, max(v) * 60); ax.set_xticks(range(len(AB))); ax.set_xticklabels(xl, rotation=45, ha='right')
for r, n in zip(bars, v): ax.text(r.get_x() + r.get_width() / 2, max(n, 1) * 1.25, f'{n:,}', ha='center', va='bottom', fontsize=5, rotation=90, color='#0b0b0b')
ax.axvline(7.5, color='#8a8984', lw=0.6, ls='--', zorder=1); ax.text(7.6, max(v) * 40, '70% threshold', fontsize=6, color='#52514e', ha='left', va='top')
ax.set_xlabel('Best match: mandatory functions dispatched (%)'); ax.set_ylabel('Contracts (log scale)')
ax.grid(axis='y', color='#e4e3df', lw=0.5, zorder=0); ax.tick_params(axis='x', labelsize=6); ax.tick_params(length=2)
for s_ in ('left', 'bottom'): ax.spines[s_].set_color('#8a8984'); ax.spines[s_].set_linewidth(0.6)
fig.tight_layout(pad=0.3); fig.savefig(P + '_all.pdf'); fig.savefig(P + '_all.png', dpi=220)

# Third figure (OUT_PREFIX_all_lowest): all contracts. A contract implementing at least one standard (>70%) is placed at its lowest match over
# those standards (ERC-173/4906 not counted), so the bars right of the threshold sum to the 12,673 flagged plus the 2,357,050 complete contracts.
# A contract implementing none has no lowest match over implemented standards and is placed at its best match (<=70%).
L = Counter()
LB = ['0', '(0, 10)'] + [f'[{10*i}, {10*i+10})' for i in range(1, 10)] + ['100']
def lb(p): return '0' if p == 0 else '100' if p >= 100 else LB[1 + min(9, int(round(p, 6) // 10))]   # [x, x+10), as in the 1% plot
for f in glob.glob(D + '/*.tsv'):
    for l in open(f):
        x = l.rstrip('\n').split('\t')
        ps = [100 * int(k) / int(n) for m in (x[3].split('|') if x[3] else []) for e, kn in [m.split(':')] if e not in SKIP for k, n in [kn.split('/')]]
        L[lb(min(ps)) if ps else lb(float(x[4]))] += 1
right = sum(L[k] for k in LB[8:])
with open(P + '.txt', 'a') as t:
    t.write('all contracts, lowest match over implemented standards (best match if none implemented):\n' + ''.join(f'  {k:>10}%  {L[k]:>10,}\n' for k in LB)
            + f'  right of threshold {right:,}; flagged (<100) {right - L["100"]:,}\n')
print('lowest-match all:', [(k, L[k]) for k in LB], 'right', right, 'flagged', right - L['100'])
fig, ax = plt.subplots(figsize=(3.4, 2.2)); v = [L[k] for k in LB]
bars = ax.bar(range(len(LB)), v, color=['#c3c2b7'] * 8 + ['#2a78d6'] * 3 + ['#52514e'], width=0.75, zorder=2)
ax.set_yscale('log'); ax.set_ylim(1, max(v) * 400); ax.set_xticks(range(len(LB))); ax.set_xticklabels(LB, rotation=45, ha='right')
for r, n in zip(bars, v): ax.text(r.get_x() + r.get_width() / 2, max(n, 1) * 1.25, f'{n:,}', ha='center', va='bottom', fontsize=5, rotation=90, color='#0b0b0b')
ax.axvline(7.5, color='#8a8984', lw=0.6, ls='--', zorder=1)
ax.text(7.4, max(v) * 250, 'no standard ', fontsize=6, color='#52514e', ha='right', va='top')
ax.text(7.6, max(v) * 250, ' implements a standard', fontsize=6, color='#52514e', ha='left', va='top')
ax.set_xlabel('Mandatory functions dispatched (%)'); ax.set_ylabel('Contracts (log scale)')
ax.grid(axis='y', color='#e4e3df', lw=0.5, zorder=0); ax.tick_params(axis='x', labelsize=5.5); ax.tick_params(length=2)
for s_ in ('left', 'bottom'): ax.spines[s_].set_color('#8a8984'); ax.spines[s_].set_linewidth(0.6)
fig.tight_layout(pad=0.3); fig.savefig(P + '_all_lowest.pdf'); fig.savefig(P + '_all_lowest.png', dpi=220)
