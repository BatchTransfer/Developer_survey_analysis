# Labelled set for classifier precision

`labelled_set.csv` holds 200 flagged contract-standard pairs drawn at random
(seed 42, one standard per contract) from the 4,712 validation contracts.
Sample size: n = z^2 p(1-p) / e^2 with z = 1.96, p = 0.5, e = 0.07, giving 196, rounded to 200.

Each item is labelled independently of the classifier using an opcode-aligned
disassembly of the function dispatcher:

- `reported_missing`: functions the classifier reports as missing
- `confirmed_absent`: those functions also absent in the disassembly
- `label`: `TP` if at least one reported function is truly absent, else `FP`

Result: 200 TP, 0 FP, precision 100% (95% Wilson CI: 98.1-100%).

Reproduce (from the repository root):

    python validation/labelled_set/build_labelled_set.py
    python validation/labelled_set/evaluate_precision.py
