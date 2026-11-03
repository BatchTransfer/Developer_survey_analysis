"""Build one labelled set for estimating both classifier precision and recall.

Ground truth: opcode-aligned disassembly of the function dispatcher
(PUSH1-PUSH4 operand followed by EQ), independent of the classifier.

Sampling frame: every (contract, standard) pair in the 4,712 validation
contracts that the classifier flags OR the reference shows to deviate
(>70% but not all mandatory functions). Drawing from the union lets both
false positives and false negatives appear. 200 distinct contracts are drawn
at random (seed 42), one pair each (z = 1.96, p = 0.5, e = 0.07 -> 196, rounded up).

Labels (paper rule): a flag is TP if every reported missing function is also
absent from the dispatcher, else FP; a true deviation that is not flagged is FN.
`reference_agrees` additionally records whether the reference also places the
contract above the 70% threshold for that standard.

Usage (from the repository root):
    python validation/labelled_set/build_single_set.py
"""
import os
import random
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "validation_set.csv")
N, SEED = 200, 42

import sys
sys.argv = [sys.argv[0], "--corrected"]
# Reuse the classifier and reference definitions without running the recall sampling.
src = open(os.path.join(HERE, "build_recall_set.py")).read().split("\npool = []")[0]
ns = {"__file__": os.path.join(HERE, "build_recall_set.py"), "__name__": "lib"}
exec(compile(src, "build_recall_set.py", "exec"), ns)
rows, flagged_standards, true_deviations, dispatcher_selectors = (
    ns["rows"], ns["flagged_standards"], ns["true_deviations"], ns["dispatcher_selectors"])

pool = []
for r in rows.itertuples():
    code = r.bytecode.lower()
    f, t = flagged_standards(code), true_deviations(code)
    if f or t:
        pool.append((r, f, t, dispatcher_selectors(code)))
print(f"Contracts flagged or truly deviating: {len(pool)}")

rng = random.Random(SEED)
items = []
for r, f, t, ref in rng.sample(pool, N):
    erc = rng.choice(sorted(set(f) | set(t)))
    reported = f.get(erc, [])
    if erc in f:
        label = "TP" if all(s not in ref for s in reported) else "FP"
    else:
        label = "FN"
    items.append({"chain": r.chain, "address": r.address, "standard": erc,
                  "reported_missing": ";".join(reported),
                  "truly_missing": ";".join(t.get(erc, [])),
                  "classifier_flagged": erc in f, "reference_agrees": erc in t,
                  "label": label})

df = pd.DataFrame(items)
df.to_csv(OUT, index=False)
c = df.label.value_counts().to_dict()
tp, fp = c.get("TP", 0), c.get("FP", 0)
print(f"Wrote {len(df)} items to {OUT}: {c}")
flag = df[df.classifier_flagged]
dev = df[df.reference_agrees]
print(f"Precision {tp}/{tp+fp} = {tp/(tp+fp):.3f}")
print(f"Recall {dev.classifier_flagged.sum()}/{len(dev)} = {dev.classifier_flagged.mean():.3f}")
print(f"Flags where the reference also exceeds 70%: {flag.reference_agrees.sum()}/{len(flag)}")
