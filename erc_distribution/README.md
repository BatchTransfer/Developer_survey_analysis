# ERC specifications by year and deployed contracts per ERC (3.8M)

Contracts: 3,808,540 deployed contracts on BNB Chain (2,308,898), Ethereum (1,114,860), Polygon (288,610) and Avalanche (96,172), January 2018 to December 2024.
Specifications: 79 specification entries (75 distinct ERCs, because ERC-5507 and ERC-5679 each have three variants), including ERC-223.
72 entries define mandatory function selectors and are checked by the classifier (`python/ERCclassification_V1.py`); the other 7 (ERC-2135, ERC-5507 x3, ERC-5679 x3) define none.

| File | Content |
|---|---|
| `erc_79_specifications_by_year.csv` | 79 entries with status and creation date (eips.ethereum.org, December 2025 snapshot) |
| `erc_79_yearly_distribution.csv` | Entries created per year, cumulative |
| `erc_79_by_year_and_contracts_3.8M.csv` | Per entry: creation date, contracts matching it (>70% of mandatory functions), compliant (100%), flagged (>70% and <100%), per chain. Multi-label: one contract can match several ERCs |
| `erc_per_erc_3.8M_one_per_contract_70pct.csv` | One label per contract (best-matching base family), sums to 3,808,540 |
| `build.py` | Joins the year and count files |

Notes
- Every contract is checked against every standard, regardless of when the contract was deployed. Many ERC-721 extensions (created 2021 to 2023) share most functions with ERC-721, so complete ERC-721 contracts match them above 70% and are flagged for the missing extension function.
- ERC-223 matches are not counted as flags, because three of its four mandatory functions are ERC-20 functions.
