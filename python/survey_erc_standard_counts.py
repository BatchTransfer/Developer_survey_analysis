#!/usr/bin/env python3
"""Count ERC/EIP standards reported in a survey CSV.

The script is intentionally conservative for publication-quality analysis:

* It counts respondent-level prevalence (a standard is counted at most once
  per response), while also reporting raw mentions.
* It normalizes spelling and formatting variants such as ERC20, ERC-20,
  ERC 20, ECR-20, and bare identifiers such as 20 or 721.
* It corrects only explicitly documented aliases. Unknown or ambiguous
  identifiers are written to the audit output instead of being silently
  changed to a different standard.
* It detects common Qualtrics metadata rows and preserves the source CSV row
  number for auditability.

No third-party Python packages are required.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable, Sequence


# Canonical families for identifiers expected in this survey. This mapping
# also resolves common ERC/EIP prefix confusion (for example, ERC-712 is
# normalized to EIP-712). Add a standard here only after verifying its number
# and family, or supply a documented --alias on the command line.
KNOWN_STANDARDS: dict[int, str] = {
    20: "ERC-20",
    137: "EIP-137",
    165: "ERC-165",
    712: "EIP-712",
    721: "ERC-721",
    777: "ERC-777",
    1155: "ERC-1155",
    1271: "ERC-1271",
    1337: "ERC-1337",
    1400: "ERC-1400",
    1559: "EIP-1559",
    1822: "ERC-1822",
    1967: "ERC-1967",
    2535: "ERC-2535",
    2612: "ERC-2612",
    2981: "ERC-2981",
    3009: "EIP-3009",
    4337: "ERC-4337",
    4626: "ERC-4626",
    5792: "ERC-5792",
    5805: "ERC-5805",
    7702: "EIP-7702",
    8004: "ERC-8004",
}

# Only high-confidence typographical corrections belong here. Each correction
# is retained in the per-response audit notes.
NUMBER_ALIASES: dict[int, int] = {
    11155: 1155,
}

PREFIX_RE = re.compile(
    r"(?i)\b(?P<prefix>ERC|EIP|ECR)\s*[-\u2010-\u2015_:]?\s*(?P<number>\d{2,5})\b"
)
NUMBER_RE = re.compile(r"\b\d{2,5}\b")
EXPLICIT_NONE_RE = re.compile(
    r"(?ix)^\s*(?:n\s*/?\s*a|none|nil|not\s+applicable|no|0)\s*[.!]?\s*$"
)
CANONICAL_RE = re.compile(r"(?i)^\s*(ERC|EIP)\s*[- ]?\s*(\d{2,5})\s*$")


@dataclass
class CodedResponse:
    source_row: int
    raw_response: str
    status: str
    standards: list[str]
    excluded_identifiers: list[str]
    normalization_notes: list[str]
    raw_mentions: list[str]


def normalize_prefix(prefix: str) -> str:
    """Normalize an entered prefix without changing the identifier number."""
    upper = prefix.upper()
    return "ERC" if upper == "ECR" else upper


def canonical_sort_key(identifier: str) -> tuple[int, int, str]:
    """Sort ERC identifiers before EIP identifiers, then numerically."""
    match = CANONICAL_RE.match(identifier)
    if not match:
        return (2, 10**9, identifier)
    family, number = match.groups()
    return (0 if family.upper() == "ERC" else 1, int(number), identifier)


def parse_aliases(alias_items: Sequence[str]) -> dict[int, str]:
    """Parse repeatable aliases such as --alias 4333=ERC-4337."""
    aliases: dict[int, str] = {}
    for item in alias_items:
        if "=" not in item:
            raise ValueError(
                f"Invalid alias {item!r}; expected RAW_NUMBER=ERC-N or RAW_NUMBER=EIP-N"
            )
        raw_number_text, canonical_text = item.split("=", 1)
        raw_number_text = raw_number_text.strip()
        if not raw_number_text.isdigit():
            raise ValueError(f"Alias source must be numeric: {raw_number_text!r}")
        match = CANONICAL_RE.match(canonical_text)
        if not match:
            raise ValueError(
                f"Invalid canonical alias target {canonical_text!r}; use ERC-N or EIP-N"
            )
        family, number = match.groups()
        aliases[int(raw_number_text)] = f"{family.upper()}-{int(number)}"
    return aliases


def _overlaps(span: tuple[int, int], other_spans: Iterable[tuple[int, int]]) -> bool:
    return any(span[0] < other[1] and other[0] < span[1] for other in other_spans)


def code_response(
    raw_response: str,
    source_row: int,
    user_aliases: dict[int, str],
    include_unverified: bool,
) -> CodedResponse:
    """Normalize and code one response."""
    text = (raw_response or "").strip()
    if not text:
        return CodedResponse(source_row, raw_response, "missing", [], [], [], [])
    if EXPLICIT_NONE_RE.fullmatch(text):
        return CodedResponse(
            source_row, raw_response, "explicit_none", [], [], [], []
        )

    included_mentions: list[str] = []
    excluded: list[str] = []
    notes: list[str] = []
    explicit_spans: list[tuple[int, int]] = []
    explicit_prefixes: list[str] = []

    def resolve_number(
        number: int,
        entered_label: str,
        entered_prefix: str | None,
    ) -> None:
        original_number = number
        if number in user_aliases:
            canonical = user_aliases[number]
            included_mentions.append(canonical)
            notes.append(f"{entered_label} -> {canonical} (user-supplied alias)")
            return
        if number in NUMBER_ALIASES:
            number = NUMBER_ALIASES[number]
            notes.append(
                f"{entered_label} -> {number} (documented typographical correction)"
            )
        if number in KNOWN_STANDARDS:
            canonical = KNOWN_STANDARDS[number]
            included_mentions.append(canonical)
            if entered_prefix:
                canonical_prefix = canonical.split("-", 1)[0]
                if entered_prefix != canonical_prefix:
                    notes.append(f"{entered_label} -> {canonical} (family normalization)")
            elif original_number == number:
                notes.append(f"{entered_label} -> {canonical} (bare identifier)")
            return

        if entered_prefix:
            unverified = f"{entered_prefix}-{number}"
        elif len(set(explicit_prefixes)) == 1:
            unverified = f"{explicit_prefixes[0]}-{number}"
        else:
            unverified = f"UNVERIFIED-{number}"

        if include_unverified:
            included_mentions.append(unverified)
            notes.append(f"{entered_label} -> {unverified} (unverified identifier included)")
        else:
            excluded.append(unverified)

    # First parse identifiers carrying an explicit ERC/EIP/ECR prefix.
    for match in PREFIX_RE.finditer(text):
        entered_prefix = match.group("prefix").upper()
        normalized_prefix = normalize_prefix(entered_prefix)
        number = int(match.group("number"))
        explicit_spans.append(match.span())
        explicit_prefixes.append(normalized_prefix)
        if entered_prefix == "ECR":
            notes.append(f"{match.group(0)} -> {normalized_prefix}-{number} (prefix typo)")
        resolve_number(number, match.group(0), normalized_prefix)

    # Then parse bare numeric identifiers. This covers entries such as
    # "20, 721, 4337" and mixed lists such as "ERC-20, 721, 1155".
    for match in NUMBER_RE.finditer(text):
        if _overlaps(match.span(), explicit_spans):
            continue
        number = int(match.group(0))
        resolve_number(number, match.group(0), None)

    standards = sorted(set(included_mentions), key=canonical_sort_key)
    excluded = sorted(set(excluded))
    if standards:
        status = "coded_with_exclusions" if excluded else "coded"
    elif excluded:
        status = "unverified_only"
    else:
        status = "noncodable_text"

    return CodedResponse(
        source_row=source_row,
        raw_response=raw_response,
        status=status,
        standards=standards,
        excluded_identifiers=excluded,
        normalization_notes=notes,
        raw_mentions=included_mentions,
    )


def detect_delimiter(csv_path: Path) -> str:
    with csv_path.open("r", encoding="utf-8-sig", newline="") as handle:
        sample = handle.read(65536)
    try:
        return csv.Sniffer().sniff(sample, delimiters=",;\t|").delimiter
    except csv.Error:
        return ","


def read_csv(csv_path: Path) -> tuple[list[str], list[dict[str, str]], str]:
    delimiter = detect_delimiter(csv_path)
    with csv_path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle, delimiter=delimiter)
        if not reader.fieldnames:
            raise ValueError("The CSV has no header row.")
        fieldnames = [name if name is not None else "" for name in reader.fieldnames]
        rows = [dict(row) for row in reader]
    return fieldnames, rows, delimiter


def compact_text(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", (value or "").casefold()).strip()


def choose_column(
    fieldnames: Sequence[str], rows: Sequence[dict[str, str]], requested: str | None
) -> str:
    if requested:
        exact = [name for name in fieldnames if name.casefold() == requested.casefold()]
        if len(exact) == 1:
            return exact[0]
        partial = [name for name in fieldnames if requested.casefold() in name.casefold()]
        if len(partial) == 1:
            return partial[0]
        available = "\n  - ".join(fieldnames)
        raise ValueError(
            f"Could not uniquely match column {requested!r}. Available columns:\n  - {available}"
        )

    scored: list[tuple[int, str]] = []
    for name in fieldnames:
        evidence = compact_text(name)
        for row in rows[:5]:
            evidence += " " + compact_text(str(row.get(name, "") or ""))
        score = 0
        if "qid24 text" in evidence or "qid24_text" in name.casefold():
            score += 20
        if "standards implemented" in evidence:
            score += 12
        if "which erc standards" in evidence:
            score += 12
        if "erc standards" in evidence:
            score += 5
        scored.append((score, name))

    best_score = max((score for score, _ in scored), default=0)
    winners = [name for score, name in scored if score == best_score and score > 0]
    if len(winners) == 1:
        return winners[0]
    available = "\n  - ".join(fieldnames)
    raise ValueError(
        "Could not automatically identify the Q4 standards column. "
        "Use --column with one of:\n  - " + available
    )


def is_qualtrics_metadata_row(row: dict[str, str], selected_value: str) -> bool:
    joined = " ".join(str(value or "") for value in row.values())
    # Qualtrics metadata can arrive as valid JSON, CSV-escaped JSON, or text
    # containing doubled quote marks, depending on the export route.
    joined_compact = compact_text(joined)
    if "importid" in joined_compact and "qid" in joined_compact:
        return True
    compact = compact_text(selected_value)
    return "which erc standards" in compact or compact.startswith(
        "standards implemented"
    )


def percentage(numerator: int, denominator: int) -> float | None:
    if denominator == 0:
        return None
    return round(100.0 * numerator / denominator, 1)


def write_outputs(
    output_dir: Path,
    input_path: Path,
    selected_column: str,
    delimiter: str,
    coded: Sequence[CodedResponse],
    user_aliases: dict[int, str],
    include_unverified: bool,
    metadata_rows_skipped: int,
) -> tuple[Path, Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    counts_path = output_dir / "q4_standard_counts.csv"
    audit_path = output_dir / "q4_coded_responses.csv"
    summary_path = output_dir / "q4_summary.json"

    respondent_counts: Counter[str] = Counter()
    raw_mention_counts: Counter[str] = Counter()
    for response in coded:
        respondent_counts.update(response.standards)
        raw_mention_counts.update(response.raw_mentions)

    total_rows = len(coded)
    nonempty = sum(response.status != "missing" for response in coded)
    codable = sum(response.status in {"coded", "coded_with_exclusions"} for response in coded)
    explicit_none = sum(response.status == "explicit_none" for response in coded)
    unverified_only = sum(response.status == "unverified_only" for response in coded)
    noncodable_text = sum(response.status == "noncodable_text" for response in coded)

    ordered_standards = sorted(
        respondent_counts,
        key=lambda standard: (-respondent_counts[standard], canonical_sort_key(standard)),
    )

    with counts_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "standard",
                "respondent_count",
                "pct_of_codable_responses",
                "pct_of_nonempty_responses",
                "pct_of_all_survey_rows",
                "raw_mention_count",
            ],
        )
        writer.writeheader()
        for standard in ordered_standards:
            count = respondent_counts[standard]
            writer.writerow(
                {
                    "standard": standard,
                    "respondent_count": count,
                    "pct_of_codable_responses": percentage(count, codable),
                    "pct_of_nonempty_responses": percentage(count, nonempty),
                    "pct_of_all_survey_rows": percentage(count, total_rows),
                    "raw_mention_count": raw_mention_counts[standard],
                }
            )

    with audit_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "source_csv_row",
                "status",
                "raw_response",
                "normalized_standards",
                "excluded_or_unverified_identifiers",
                "normalization_notes",
            ],
        )
        writer.writeheader()
        for response in coded:
            writer.writerow(
                {
                    "source_csv_row": response.source_row,
                    "status": response.status,
                    "raw_response": response.raw_response,
                    "normalized_standards": "; ".join(response.standards),
                    "excluded_or_unverified_identifiers": "; ".join(
                        response.excluded_identifiers
                    ),
                    "normalization_notes": "; ".join(response.normalization_notes),
                }
            )

    status_counts = Counter(response.status for response in coded)
    summary = {
        "input_file": str(input_path.resolve()),
        "selected_column": selected_column,
        "detected_delimiter": delimiter,
        "metadata_rows_skipped": metadata_rows_skipped,
        "survey_rows": total_rows,
        "nonempty_responses": nonempty,
        "missing_responses": status_counts["missing"],
        "explicit_none_responses": explicit_none,
        "codable_responses": codable,
        "unverified_only_responses": unverified_only,
        "noncodable_text_responses": noncodable_text,
        "counting_unit": "respondents; each standard is counted at most once per response",
        "include_unverified": include_unverified,
        "user_aliases": {str(key): value for key, value in sorted(user_aliases.items())},
        "documented_number_aliases": {
            str(key): value for key, value in sorted(NUMBER_ALIASES.items())
        },
        "standard_counts": [
            {
                "standard": standard,
                "respondent_count": respondent_counts[standard],
                "raw_mention_count": raw_mention_counts[standard],
            }
            for standard in ordered_standards
        ],
    }
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return counts_path, audit_path, summary_path


def run_self_test() -> None:
    cases = [
        ("ERC20, ERC-721, 1155", {"ERC-20", "ERC-721", "ERC-1155"}),
        ("ECR -4337\nECR-721", {"ERC-4337", "ERC-721"}),
        ("erc-712, ERC-7702, EIP1155", {"EIP-712", "EIP-7702", "ERC-1155"}),
        ("ERC11155", {"ERC-1155"}),
        ("20, 721, 4337", {"ERC-20", "ERC-721", "ERC-4337"}),
        ("N/A", set()),
    ]
    for row_number, (text, expected) in enumerate(cases, start=2):
        result = code_response(text, row_number, {}, include_unverified=False)
        actual = set(result.standards)
        if actual != expected:
            raise AssertionError(f"Self-test failed for {text!r}: {actual} != {expected}")

    ambiguous = code_response("ERC-20, 4333", 99, {}, include_unverified=False)
    if set(ambiguous.standards) != {"ERC-20"} or "ERC-4333" not in ambiguous.excluded_identifiers:
        raise AssertionError("Ambiguous-identifier self-test failed")
    print("Self-test passed: normalization and ambiguity checks are working.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Count ERC/EIP standards in a survey CSV and produce both aggregate "
            "counts and a row-level coding audit."
        )
    )
    parser.add_argument("csv_file", nargs="?", type=Path, help="Qualtrics or other survey CSV")
    parser.add_argument(
        "--column",
        help=(
            "Exact column name or a unique substring. If omitted, the script "
            "searches for QID24_TEXT / 'Standards implemented'."
        ),
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("q4_erc_count_output"),
        help="Output directory (default: q4_erc_count_output)",
    )
    parser.add_argument(
        "--alias",
        action="append",
        default=[],
        metavar="RAW=CANONICAL",
        help=(
            "Document an investigator-approved correction, e.g. "
            "--alias 4333=ERC-4337. Repeat as needed."
        ),
    )
    parser.add_argument(
        "--include-unverified",
        action="store_true",
        help="Include unknown identifiers in counts; default is to flag and exclude them.",
    )
    parser.add_argument(
        "--skip-first-data-rows",
        type=int,
        default=0,
        help="Skip N data rows after the CSV header, in addition to auto-detected metadata rows.",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Run built-in normalization tests and exit.",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.self_test:
        run_self_test()
        return 0
    if args.csv_file is None:
        parser.error("csv_file is required unless --self-test is used")
    if args.skip_first_data_rows < 0:
        parser.error("--skip-first-data-rows cannot be negative")
    if not args.csv_file.is_file():
        parser.error(f"CSV file not found: {args.csv_file}")

    try:
        user_aliases = parse_aliases(args.alias)
        fieldnames, rows, delimiter = read_csv(args.csv_file)
        selected_column = choose_column(fieldnames, rows, args.column)
    except (OSError, ValueError, csv.Error) as error:
        parser.error(str(error))

    coded: list[CodedResponse] = []
    metadata_rows_skipped = 0
    for data_index, row in enumerate(rows):
        source_csv_row = data_index + 2  # Header is CSV row 1.
        if data_index < args.skip_first_data_rows:
            metadata_rows_skipped += 1
            continue
        raw_value = str(row.get(selected_column, "") or "")
        if is_qualtrics_metadata_row(row, raw_value):
            metadata_rows_skipped += 1
            continue
        coded.append(
            code_response(
                raw_value,
                source_csv_row,
                user_aliases=user_aliases,
                include_unverified=args.include_unverified,
            )
        )

    counts_path, audit_path, summary_path = write_outputs(
        output_dir=args.output_dir,
        input_path=args.csv_file,
        selected_column=selected_column,
        delimiter=delimiter,
        coded=coded,
        user_aliases=user_aliases,
        include_unverified=args.include_unverified,
        metadata_rows_skipped=metadata_rows_skipped,
    )

    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    print(f"Selected column: {selected_column}")
    print(f"Survey rows: {summary['survey_rows']}")
    print(f"Nonempty responses: {summary['nonempty_responses']}")
    print(f"Codable responses: {summary['codable_responses']}")
    print(f"Missing responses: {summary['missing_responses']}")
    print(f"Explicit none/N/A responses: {summary['explicit_none_responses']}")
    print(f"Unverified-only responses: {summary['unverified_only_responses']}")
    print("\nRespondent-level standard counts:")
    for item in summary["standard_counts"]:
        print(f"  {item['standard']:<12} {item['respondent_count']:>3}")
    print("\nOutputs:")
    print(f"  {counts_path.resolve()}")
    print(f"  {audit_path.resolve()}")
    print(f"  {summary_path.resolve()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
