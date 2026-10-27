# Compliance-classifier validation (Section VII-A)

- `validation_bytecodes.csv.gz`: 4,712 unique runtime bytecodes (Ethereum 3,570; BNB Chain 635; Polygon 398; Avalanche 109) from the deployment-analysis pipeline output.
- `validate_compliance_classifier.py`: re-applies the classifier in `python/ERCclassification copy.py` (selector matching, 70% candidate threshold) and checks every flag against an independent opcode-aligned disassembly of the function dispatcher.

Run from the repository root:

```bash
python validation/validate_compliance_classifier.py
```

`Json/erc_status_snapshot_2025-12.csv` lists the status and creation date of each analyzed standard at ethereum/ERCs commit `d80b518` (31 December 2025).
