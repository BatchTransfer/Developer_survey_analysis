# ERC Standards Security Analysis

This repository contains the research artifacts for our multi-method security study of the Ethereum ERC ecosystem. The study connects ERC specification requirements, security-risk dimensions, practitioner evidence, deployed-contract deviations, controlled Sepolia exploits, and actionable recommendations.

## Study Overview

The study comprises six interconnected stages:

1. Analysis of ERC/EIP specifications and their mandatory requirements.
2. Derivation of four security-risk dimensions:

   * Authority Boundary Risks
   * Transfer Operation Risks
   * Signature Construction Risks
   * System Integration Risks
3. Survey of 72 smart-contract practitioners.
4. Compliance analysis of 1.68 million bytecode-deduplicated contracts across Ethereum, BNB Chain, Polygon, and Avalanche.
5. Controlled exploit demonstrations on the Sepolia testnet.
6. Evidence-based recommendations for developers, auditors, specification authors, and security-tool builders.

## Repository Structure

```text
.
├── Data/
│   └── Processed and anonymized study data
├── Json/
│   └── Structured ERC specification requirements and dependency data
├── Labels_ERC-analysis_Developer-interviews_August-11-2026_analysis/
│   └── Aggregated survey-analysis results, labels, and statistical outputs
├── drawio/
│   └── Editable source files for figures and research diagrams
├── exploit_demonstration/
│   └── Vulnerable contracts, deployment configurations, and Sepolia exploit evidence
├── python/
│   └── Scripts for specification, survey, contract, and compliance analysis
├── q4_erc_count_output/
│   └── Per-chain and per-standard deployment-analysis results
├── Algorithm.png
│   └── Overview of the analysis algorithm
├── Labels_ERC-analysis_Developer-interviews_August-11-2026_23.41.csv
│   └── De-identified survey-analysis dataset
├── .gitignore
└── README.md
```

## Specification Dataset

The `Json/` directory contains structured records extracted from the analyzed ERC/EIP specifications, including:

* Mandatory functions and function selectors
* Mandatory events and event topics
* Required interfaces
* Declared `requires` dependencies
* Specification metadata and functional classifications

Declared normative dependencies are maintained separately from researcher-identified conceptual interoperability relationships.

## Practitioner Survey

The survey examined developers’:

* ERC specification comprehension
* Security-risk awareness
* Implementation challenges
* Dependency verification practices
* Authorization and transfer handling
* Signature construction
* Receiver-hook and interoperability practices

The complete sample contains 72 practitioners. Results from optional technical subgroups are reported separately and are not generalized to the full sample.

Agreement proportions classify “Agree” and “Strongly agree” as agreement. Two-sided 95% Wilson confidence intervals are reported as descriptive uncertainty intervals because participant recruitment was non-probabilistic.

## Deployment Analysis

The deployment analysis covers 1,682,782 bytecode-deduplicated contracts deployed from 2018 through December 2024 across:

* Ethereum
* BNB Chain
* Polygon
* Avalanche

A contract is flagged when it is identified as implementing an ERC standard but lacks at least one mandatory element detectable by the analysis, such as a required function selector, event signature, or interface dependency.

A flagged deviation is not automatically classified as an exploitable vulnerability. Exploitability depends on the affected requirement, execution context, and attacker-controlled preconditions.

## Exploit Demonstrations

The `exploit_demonstration/` directory contains controlled Sepolia experiments covering:

* Allowance-enforcement bypass
* ERC-1155 zero-address transfer
* Mismatched batch-array processing
* Cross-contract EIP-712 signature replay
* Receiver-validation failure
* Receiver-hook reentrancy

The artifact includes vulnerable source contracts, participant roles, deployment parameters, contract addresses, transaction hashes, block numbers, and pre-/post-state assertions where available.

These contracts are intentionally vulnerable and must not be deployed on production networks.

## Reproducing the Analysis

Use Python 3.10 or later. We recommend creating an isolated environment:

Run analysis scripts from the repository root so that relative paths to `Data/`, `Json/`, and output directories resolve correctly.

```bash
python python/<survey_likert_analysis>.py
```

The generated results are written to the corresponding analysis and output directories. Exact commands, input files, and configuration parameters should be documented in each script.

## Research Ethics and Data Handling

Only public blockchain data and de-identified research data are included. No private keys, personally identifiable information, or address-clustering information are provided.

Before making the repository public, verify that the survey CSV contains no participant identifiers, platform identifiers, IP addresses, timestamps capable of re-identification, or free-text responses containing personal information.

## Artifact Scope

The repository supports verification of:

* ERC requirement extraction and dependency mapping
* Survey aggregation and descriptive statistical analysis
* Multi-chain contract-compliance measurements
* Controlled exploit execution and state assertions
* Figures and tables reported in the paper

Results may differ if specifications, blockchain datasets, RPC providers, compiler versions, or analysis dependencies are updated.

## Citation

If you use this repository, please cite:

```bibtex
@inproceedings{erc_security_study,
  title     = {From ERC Specifications to Smart-Contract Exploits: A Multi-Method Security Study},
  year      = {2026}
}
```

The citation will be updated after the peer-review process.

## Responsible Use

This repository is intended exclusively for academic research, defensive security analysis, and reproducibility. The vulnerable contracts and exploit demonstrations must not be used against third-party systems or deployed assets.

## License

Add the applicable software and dataset licenses before public release. If different components require different licenses, document them separately in their corresponding directories.
