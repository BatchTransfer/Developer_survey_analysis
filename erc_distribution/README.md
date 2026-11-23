# ERC specifications by year and deployed contracts per ERC (3.8M)

**Contracts:** 3,808,540 deployed contracts on BNB Chain (2,308,898), Ethereum (1,114,860), Polygon (288,610) and Avalanche (96,172), from January 2018 to December 2024.

**Specifications:** 79 specification entries (75 distinct ERCs, because ERC-5507 and ERC-5679 each have three variants), including ERC-223. 72 entries define mandatory function selectors and are checked by the dispatcher-based classifier (`../compliance_analysis/classifier/erc_classifier.py`). The other 7 (ERC-2135, ERC-5507 ×3, ERC-5679 ×3) define none.

| File | Content |
|---|---|
| `erc_79_specifications_by_year.csv` | The 79 entries with status and creation date (eips.ethereum.org, December 2025 snapshot) |
| `erc_79_yearly_distribution.csv` | Entries created per year, with a cumulative count |
| `erc_79_by_year_and_contracts_3.8M.csv` | Per entry: creation date; contracts implementing it (>70% of mandatory functions dispatched); compliant (100%); flagged (below 100%); implementing per chain. Built by `../compliance_analysis/census/build_erc_distribution.py` |

Entries were created between November 2015 (ERC-20) and July 2023: 3 before 2018, 10 in 2018, 8 in 2019, 4 in 2020, 9 in 2021, 33 in 2022 and 12 in 2023.

## Notes

- **Multi-label counts.** One contract can implement several standards, so the rows overlap. For example, a complete ERC-721 contract also counts for ERC-165.
- **ERC-173 and ERC-4906.** Both are listed here but not counted in the paper's 12,673 flagged contracts.
- **Deployment dates.** Every contract is checked against every standard, regardless of when it was deployed.
