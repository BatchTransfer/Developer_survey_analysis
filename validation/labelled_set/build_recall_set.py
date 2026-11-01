"""Build a labelled set for estimating classifier recall.

Ground truth comes from the independent reference only: an opcode-aligned
disassembly of the function dispatcher (PUSH1-PUSH4 operand followed by EQ).
A (contract, standard) pair is a true deviation if the dispatcher exposes
more than 70% but not all of the standard's mandatory functions. This is the
same scope the classifier covers (contracts treated as implementing the ERC).
ERC-1363 is excluded: its spec entry lists onTransferReceived, which belongs to
the receiver interface (IERC1363Receiver), not the token, so every ERC-1363
"deviation" in the reference is an artefact of the spec entry.

Sampling: from all true deviations in the 4,712 validation contracts, draw
200 distinct contracts at random (seed 42), one true deviation each. n = 200
as for the precision set (z = 1.96, p = 0.5, e = 0.07 -> 196, rounded up).

Labelling: an item is a true positive (TP) if the classifier also flags that
standard for that contract, otherwise a false negative (FN).

Usage (from the repository root):
    python validation/labelled_set/build_recall_set.py
"""
import json
import os
import random
import sys

import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "validation_bytecodes.csv.gz")
# Pass --corrected to use the curated specification (Json/erc_specification_corrected.json).
CORRECTED = "--corrected" in sys.argv
CONFIG = os.path.join(HERE, "..", "..", "Json",
                      "erc_specification_corrected.json" if CORRECTED else "erc_config_top50.json")
OUT = os.path.join(HERE, "recall_set_corrected.csv" if CORRECTED else "recall_set.csv")
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



# The corrected specification omits onTransferReceived, so no exclusion is needed.
EXCLUDE = set() if CORRECTED else {"ERC1363"}


def true_deviations(code):
    """Reference: standards with >70% but not all functions in the dispatcher."""
    ref = dispatcher_selectors(code)
    out = {}
    for erc, spec in cfg.items():
        sels = [s.lower() for s in spec.get("selectors", [])]
        if not sels or erc in EXCLUDE:
            continue
        present = [s for s in sels if s in ref]
        if THRESHOLD < 100 * len(present) / len(sels) < 100:
            out[erc] = [s for s in sels if s not in ref]
    return out


pool = []
total = detected = 0
for r in rows.itertuples():
    code = r.bytecode.lower()
    t = true_deviations(code)
    if t:
        f = flagged_standards(code)
        total += len(t)
        detected += sum(1 for e in t if e in f)
        pool.append((r, t, f))
print(f"Contracts with a true deviation: {len(pool)}")
print(f"All true deviations in pool: {detected}/{total} detected")

rng = random.Random(SEED)
items = []
for r, t, f in rng.sample(pool, N):
    erc = rng.choice(sorted(t))
    items.append({
        "chain": r.chain,
        "address": r.address,
        "standard": erc,
        "truly_missing": ";".join(t[erc]),
        "classifier_flagged": erc in f,
        "label": "TP" if erc in f else "FN",
    })

df = pd.DataFrame(items)
df.to_csv(OUT, index=False)
print(f"Wrote {len(df)} labelled items to {OUT}")
print(df.label.value_counts().to_dict())
