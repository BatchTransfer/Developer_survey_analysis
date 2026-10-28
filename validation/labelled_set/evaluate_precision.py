"""Run the classifier on the labelled set and compute precision.

Usage (from the repository root):
    python validation/labelled_set/evaluate_precision.py
"""
import os
import sys
from math import sqrt

import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_labelled_set import flagged_standards  # noqa: E402

labels = pd.read_csv(os.path.join(HERE, "labelled_set.csv"))
codes = pd.read_csv(os.path.join(HERE, "..", "validation_bytecodes.csv.gz"))
codes = dict(zip(codes.chain + ":" + codes.address, codes.bytecode))

same = 0
for r in labels.itertuples():
    f = flagged_standards(codes[f"{r.chain}:{r.address}"].lower())
    same += r.standard in f and ";".join(f[r.standard]) == r.reported_missing
tp = (labels.label == "TP").sum()
n = len(labels)


def wilson(x, n, z=1.959964):
    p = x / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return round(100 * (c - h), 1), round(100 * (c + h), 1)


print(f"Classifier reproduces {same}/{n} labelled flags")
print(f"TP {tp}, FP {n - tp}, precision {100 * tp / n:.1f}%, 95% Wilson CI {wilson(tp, n)}")
