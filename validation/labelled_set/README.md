# Labelled sets for classifier precision and recall

## Single validation set (`validation_set.csv`), used in the paper

One set measures both precision and recall. From the 4,712 validation
contracts, 3,216 are flagged by the classifier or shown to deviate by the
dispatcher disassembly. 200 of them are drawn at random (seed 42), one
(contract, standard) pair each. Drawing from both sources lets the same set
reveal false flags and missed deviations.

- `reported_missing`: functions the classifier reports as missing
- `truly_missing`: functions absent in the disassembly
- `classifier_flagged`: whether the classifier flags that standard
- `reference_agrees`: whether the disassembly also shows more than 70% but not all functions
- `label`: `TP` if every reported missing function is absent in the disassembly, `FP` if not, `FN` if a true deviation is not flagged

Results:

- Precision: 200/200 flags correct, 100% (95% Wilson CI: 98.1-100%)
- Recall: 194/194 true deviations flagged, 100% (95% Wilson CI: 98.1-100%)
- In 6 flagged contracts (`reference_agrees` = False), the disassembly exposes 70% or fewer of the standard's functions, but the reported missing functions are still absent.

Reproduce: `python validation/labelled_set/build_single_set.py`

The two separate sets below were used in earlier drafts and are kept for reference.


Both sets are drawn from the 4,712 validation contracts and labelled
independently of the classifier, using an opcode-aligned disassembly of the
function dispatcher (PUSH1-PUSH4 operand followed by EQ).
Sample size: n = z^2 p(1-p) / e^2 with z = 1.96, p = 0.5, e = 0.07, giving 196, rounded to 200.
Sampling: seed 42, one standard per contract.

## Specification

`Json/erc_specification_corrected.json` is the curated specification used in
the paper (`Json/final_full_erc_specifications.json`, 72 standards with
mandatory functions; every selector checked against keccak256 of its
signature). The earlier `Json/erc_config_top50.json` differed from it in 37 of
45 standards (for example, it listed the receiver callback
`onTransferReceived` under ERC-1363), so the corrected results below supersede
`labelled_set.csv`.

## Precision (`labelled_set_corrected.csv`)

200 contracts drawn from those the classifier flags.

- `reported_missing`: functions the classifier reports as missing
- `confirmed_absent`: those functions also absent in the disassembly
- `label`: `TP` if at least one reported function is truly absent, else `FP`

Result: 200 TP, 0 FP, precision 100% (95% Wilson CI: 98.1-100%).

## Recall (`recall_set_corrected.csv`)

200 contracts drawn from those the disassembly shows to implement more than
70% but not all of a standard's mandatory functions (the classifier's scope).

- `truly_missing`: functions absent in the disassembly
- `classifier_flagged`: whether the classifier flags that standard
- `label`: `TP` if flagged, else `FN`

Result: 200 TP, 0 FN, recall 100% (95% Wilson CI: 98.1-100%).
Across the whole pool, 14,108 of 14,111 true deviations are flagged (99.98%).
Contracts behind proxies or below the 70% threshold are outside this scope.

## Reproduce (from the repository root)

    python validation/labelled_set/build_labelled_set.py --corrected
    python validation/labelled_set/build_recall_set.py --corrected

Without `--corrected`, the scripts use `erc_config_top50.json` and write
`labelled_set.csv` / `recall_set.csv`.
