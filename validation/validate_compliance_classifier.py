"""Validate the bytecode compliance classifier used in Section VII.

The classifier (python/ERCclassification copy.py) searches each contract's
bytecode for the mandatory four-byte function selectors of an ERC:
  - full match: 100% of selectors present  -> compliant
  - candidate:  > threshold (70%) present    -> flagged if not compliant
This script checks every flag against an independent, opcode-aligned
disassembly of the function dispatcher (PUSH1-PUSH4 operand followed by EQ).

Usage (from the repository root):
    python validation/validate_compliance_classifier.py
"""
import json
import os
from collections import Counter
from math import sqrt

import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "validation_bytecodes.csv.gz")
CONFIG = os.path.join(HERE, "..", "Json", "erc_config_top50.json")
CORE = ("ERC20", "ERC721", "ERC1155")

cfg = json.load(open(CONFIG))
rows = pd.read_csv(DATA)


def pct(code, sels):
    """Original classifier: share of selectors found by hex substring search."""
    return 100 * sum(s.lower() in code for s in sels) / len(sels) if sels else 0


def dispatcher_selectors(code):
    """Reference: selectors compared with EQ in the opcode-aligned dispatcher."""
    b = bytes.fromhex(code[2:] if code.startswith("0x") else code)
    ops, i = [], 0
    while i < len(b):
        op = b[i]
        if 0x60 <= op <= 0x7F:  # PUSHn
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


def wilson(x, n, z=1.959964):
    p = x / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return round(100 * (c - h), 1), round(100 * (c + h), 1)


def flags(code, standards, thr=70):
    out = {}
    for e in standards:
        s = cfg[e].get("selectors", [])
        p = pct(code, s)
        if thr < p < 100:
            out[e] = [x for x in s if x.lower() not in code]
    return out


print(f"Validation set: {len(rows)} unique bytecodes {rows.chain.value_counts().to_dict()}")

for label, standards in (("All standards", list(cfg)), ("Core standards (ERC-20/721/1155)", CORE)):
    ok = bad = 0
    false_sel = Counter()
    for code in rows.bytecode:
        f = flags(code, standards)
        if not f:
            continue
        ref = dispatcher_selectors(code)
        for e, missing in f.items():
            if any(m.lower() not in ref for m in missing):
                ok += 1
            else:
                bad += 1
                false_sel.update(f"{e}:{m}" for m in missing)
    n = ok + bad
    print(f"\n{label}: {n} flagged contract-standard pairs, {ok} confirmed, {bad} false")
    print(f"  precision {100 * ok / n:.2f}%  95% Wilson CI {wilson(ok, n)}")
    if false_sel:
        print("  false-flag selectors:", dict(false_sel))

print("\nThreshold sensitivity (core standards, flagged contracts):")
for thr in (60, 70, 80, 90):
    print(f"  {thr}%: {sum(1 for c in rows.bytecode if flags(c, CORE, thr))}")
