"""Build a labelled set for estimating classifier precision.

Sampling: from the 4,712 validation contracts, draw 200 distinct flagged
contracts at random (fixed seed); for each, draw one flagged standard.
n = 200 follows the usual sample-size formula n = z^2 p(1-p) / e^2 with
z = 1.96, p = 0.5 (most conservative), e = 0.07  ->  196, rounded to 200.

Labelling: each item is labelled independently of the classifier, using an
opcode-aligned disassembly of the function dispatcher (PUSH1-PUSH4 operand
followed by EQ). A flag is a true positive (TP) if at least one reported
missing function is truly absent from the dispatcher, otherwise a false
positive (FP).

Usage (from the repository root):
    python validation/labelled_set/build_labelled_set.py
"""
import json
import os
import random

import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "validation_bytecodes.csv.gz")
CONFIG = os.path.join(HERE, "..", "..", "Json", "erc_config_top50.json")
OUT = os.path.join(HERE, "labelled_set.csv")
N, SEED, THRESHOLD = 200, 42, 70

cfg = json.load(open(CONFIG))
rows = pd.read_csv(DATA)


def flagged_standards(code):
    """Classifier: hex substring search, candidate above 70%, not 100%."""
    out = {}
    for erc, spec in cfg.items():
        sels = [s.lower() for s in spec.get("selectors", [])]
        if not sels:
            continue
        present = [s for s in sels if s in code]
        if THRESHOLD < 100 * len(present) / len(sels) < 100:
            out[erc] = [s for s in sels if s not in code]
    return out


def dispatcher_selectors(code):
    """Independent reference: selectors compared with EQ in the dispatcher."""
    b = bytes.fromhex(code[2:] if code.startswith("0x") else code)
    ops, i = [], 0
    while i < len(b):
        op = b[i]
        if 0x60 <= op <= 0x7F:
            n = op - 0x5F
            ops.append((op, b[i + 1:i + 1 + n]))
            i += 1 + n
        else:
            ops.append((op, None))
            i += 1
    sels = set()
    for k, (op, arg) in enumerate(ops):
        if 0x60 <= op <= 0x63 and arg and 0x14 in [o for o, _ in ops[k + 1:k + 4]]:
            sels.add(arg.rjust(4, b"\0").hex())
    return sels


rng = random.Random(SEED)
candidates = []
for r in rows.itertuples():
    f = flagged_standards(r.bytecode.lower())
    if f:
        candidates.append((r, f))
print(f"Flagged contracts in pool: {len(candidates)}")

items = []
for r, f in rng.sample(candidates, N):
    erc = rng.choice(sorted(f))
    missing = f[erc]
    ref = dispatcher_selectors(r.bytecode.lower())
    absent = [m for m in missing if m not in ref]
    items.append({
        "chain": r.chain,
        "address": r.address,
        "standard": erc,
        "reported_missing": ";".join(missing),
        "confirmed_absent": ";".join(absent),
        "label": "TP" if absent else "FP",
    })

df = pd.DataFrame(items)
df.to_csv(OUT, index=False)
print(f"Wrote {len(df)} labelled items to {OUT}")
print(df.label.value_counts().to_dict())
