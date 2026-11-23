# Compliance analysis of deployed contracts (RQ4)

The dispatcher-based ERC classifier, its results on 3,808,540 deployed contracts, the validation sample, and the figures and workbook reported in Section VIII of the paper.

## Results at a glance

| Chain | Contracts | Implementing (>70%) | Flagged (% of implementing) | ERC-20 | ERC-721 | ERC-2612 | ERC-1155 |
|---|---:|---:|---:|---:|---:|---:|---:|
| BNB Chain | 2,308,898 | 1,574,675 | 5,094 (0.32%) | 3,329 | 935 | 574 | 59 |
| Ethereum | 1,114,860 | 621,588 | 6,114 (0.98%) | 3,124 | 1,589 | 893 | 78 |
| Polygon | 288,610 | 130,717 | 874 (0.67%) | 206 | 169 | 163 | 41 |
| Avalanche | 96,172 | 42,743 | 591 (1.38%) | 65 | 153 | 333 | 5 |
| **Total** | **3,808,540** | **2,369,723** | **12,673 (0.53%)** | **6,724** | **2,846** | **1,963** | **183** |

A contract can be flagged for more than one standard, so the standard columns do not add up to the flagged total. Other flagged standards: ERC-3754 (453), ERC-7160 (312), ERC-4626 (179), ERC-4524 (171), ERC-5615 (170), ERC-4494 (86), ERC-4907 (32), ERC-1820 (27), ERC-223 (23), ERC-777 (20), and 16 standards with fewer than 20 contracts each.

**Validation.** We drew a simple random sample of 100 of the 12,673 flagged contracts (seed 2046) and labelled each one by hand as `Violation` or `Not a Violation`. All 100 are true positives, giving a precision of 100% (Wilson 95% CI: 96.3–100%). Verified Solidity source was available for 53 of the 100, and all 53 confirm their label.

## How the classifier works

1. **Dispatcher reading.** A function counts as *exposed* only when the contract's dispatcher compares its selector with the call's selector: a PUSH1–PUSH4 value within three opcodes before an `EQ`, with any dropped leading zero bytes restored (e.g., `0x00fdd58e` is stored as `PUSH3 0xfdd58e`). Selectors used only to call other contracts do not count.
2. **Implementing.** A contract implements a standard when more than 70% of the standard's mandatory functions are exposed and at least half of the functions that set it apart from related standards are present (e.g., `permit` for ERC-2612).
3. **Compliant or flagged.** A contract is *compliant* when 100% of the mandatory functions are exposed and *flagged* when fewer are. Every standard is checked on its own; there is no overlap rule.
4. **Not reported.** ERC-173 and ERC-4906 are not counted in the totals. ERC-4906's mandatory functions are the same as ERC-721's. ERC-173's two ownership functions also appear in any contract that uses an ownership library.

The specification dataset covers 79 entries, of which 72 define mandatory selectors. The other 7 (ERC-2135, ERC-5507 ×3, ERC-5679 ×3) define none. No AI- or LLM-based techniques are used.

## Folders

```text
compliance_analysis/
├── ERC_compliance_results_v1.xlsx   all tables in one workbook (README tab, datasets, 12,673 flagged, distributions, per-ERC, ground truth, spec years)
├── paths.py                         repo-relative paths used by every script (set EVM_DATA for the raw bytecode)
├── classifier/
│   ├── erc_classifier.py            dispatcher reading + classification
│   ├── erc_specification_v5.json    specification used for all reported numbers
│   ├── erc_specification_v6.json    v5 with ERC-173 corrected to owner() + transferOwnership() (EIP-173: supportsInterface is a SHOULD)
│   └── make_spec_v6.py
├── census/                          scripts that run the classifier over all contracts and aggregate the results
│   ├── new_classifier_census.py     flagged/compliant per contract (args: classifier dir, threshold, output dir; NO_OVERLAP=1)
│   ├── match_pct_census.py          per contract: STD:k/n for every implemented standard and the best match %
│   ├── table_counts.py              per-chain / per-ERC counts for the table above
│   ├── build_results_workbook.py    builds ERC_compliance_results_v1.xlsx; verify_results_workbook.py checks it
│   ├── build_erc_distribution.py    rebuilds ../erc_distribution/erc_79_by_year_and_contracts_3.8M.csv
│   ├── compare_spec_v5_v6.py        effect of the ERC-173 correction (results/compare_spec_v5_v6.txt)
│   ├── dispatch_forms_census.py, exclude_nonstandard_dispatch.py   find the 30,778 non-EQ (e.g. Vyper) dispatchers
│   └── best67_check.py              explains the spike at 66.67% (ERC-173 owner + transferOwnership)
├── results/
│   ├── match_pct_70_no_overlap/<chain>.tsv.gz   per-contract results for all 3,808,540 contracts
│   ├── compare_spec_v5_v6.txt
│   ├── erc223_tagged_summary.json   the 2,112,762 ERC-223-tagged contracts wrongly removed in the submitted version (1.68M -> 3.8M)
│   └── bytecode_dedup_summary.json
├── figures/
│   ├── analysis_pipeline_v4.pdf/.drawio   pipeline and validation figure (built from v3 by make_pipeline_figures.py)
│   ├── match_pct*.pdf/.png/.txt     match-% distributions (2.37M implementing, 3.8M lowest match, 1% bins)
│   └── match_pct_plot.py, match_pct_plot_1pct.py
└── validation/
    ├── new_classifier_70_no_overlap/   sample_100_seed2046.csv, labels_100_seed2046.csv, view_100_seed2046.txt, check_nonEQ_seed2046.csv
    ├── sources_seed2046/            verified Solidity source of 53 sampled contracts, index.csv, source_check.csv, source_verdicts.csv
    └── draw_and_view.py, labels_2046.py, check_nonEQ_2046.py, fetch_sources_2046.py (+ fetch_sources_2035.py), source_check_2046.py, source_verdicts_2046.py
```

## Per-contract result format

`results/match_pct_70_no_overlap/<chain>.tsv.gz` is tab-separated with no header: `chain`, `address`, `chunk`, `STD:k/n|...` (every standard implemented, with k of n mandatory functions exposed), `best match %` (distinctive-function rule), and `raw best match %`. A standard with `k < n` is flagged. A contract's match % is its lowest share over the standards it implements, leaving out ERC-173 and ERC-4906. Histogram bins are `[x, x+1)` and `[x, x+10)`; bar 100 means exactly 100%.

## Reproducing

Python 3.10+ with `openpyxl` and `matplotlib`. Run from `compliance_analysis/`.

```bash
cd results/match_pct_70_no_overlap && gunzip -k *.tsv.gz && cd ../..
python census/build_results_workbook.py && python census/verify_results_workbook.py
python figures/match_pct_plot.py results/match_pct_70_no_overlap figures/match_pct
python figures/match_pct_plot_1pct.py results/match_pct_70_no_overlap figures/match_pct_all_lowest_1pct
python validation/source_check_2046.py && python validation/source_verdicts_2046.py
```

Rerunning the census itself (`census/*_census.py`, `validation/draw_and_view.py`, `validation/check_nonEQ_2046.py`) needs the deduplicated bytecode CSVs of the four chains, which are not in this repository because of their size. Put them under `$EVM_DATA` using the file names in `census/new_classifier_census.py`. `fetch_sources_2046.py` uses Sourcify and Routescan without a key. For Etherscan, pass `--env FILE`, where FILE holds your own `ETHERSCAN_API_KEY`; never commit that file.

## Limitations

- Contracts whose dispatchers compare selectors without `EQ` (30,778 contracts, e.g., Vyper or SUB/XOR dispatch) are included in the 3.8M, but their selectors may be missed (see Section XI of the paper).
- The validation sample is drawn from the flagged set, so it measures precision only.
