#!/usr/bin/env python3
"""
Reproducible, publication-oriented analysis of a five-point Likert survey.

The preferred single-source workflow uses the Qualtrics label export:

    python3 survey_likert_analysis.py withLabels.csv

Agreement scores are derived directly from their displayed meanings, so raw
Qualtrics code direction is irrelevant. This normalizes every agreement item to
the semantic scale

    1 = Strongly disagree ... 5 = Strongly agree.

An optional paired-export validation mode remains available when an unchanged
numeric export exists:

    python3 survey_likert_analysis.py withNumbers.csv \
        --labels-csv withLabels.csv

In paired mode, the program reconciles the exports cell-by-cell before scoring.
Do not use paired mode after editing only one of the two exports; use the edited
label export as the single source instead.

Optional reproducible configuration:

    python3 survey_likert_analysis.py withLabels.csv \
        --config survey_config.json

Example survey_config.json:

{
  "likert_columns": [],
  "non_likert_columns": ["Q1", "Q2", "Q3", "Q4"],
  "reverse_worded_columns": [],
  "constructs": {
    "Example construct": ["Q5_1", "Q5_2", "Q5_3"]
  },
  "minimum_scale_answered_fraction": 0.8,
  "enable_sign_tests": false,
  "familywise_alpha": 0.05,
  "bootstrap_repetitions": 2000,
  "random_seed": 20260812
}

Leave likert_columns empty to infer agreement items from the labels export.
Inference is based on response semantics, not on whether the numeric values
happen to fall in 1--5. For a final paper, retain the generated configuration,
codebook, integrity report, and input hashes with the analysis archive.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import math
import platform
import re
import sys
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

import numpy as np
import pandas as pd
from scipy.stats import binomtest, norm, t as student_t


SCRIPT_VERSION = "2.1.0"

DEFAULT_CONFIG: dict[str, Any] = {
    "likert_columns": [],
    "non_likert_columns": ["Q1", "Q2", "Q3", "Q4"],
    "reverse_worded_columns": [],
    "constructs": {},
    "minimum_scale_answered_fraction": 0.80,
    "enable_sign_tests": False,
    "familywise_alpha": 0.05,
    "bootstrap_repetitions": 2000,
    "random_seed": 20260812,
}

# Semantic scoring. Capitalization and common punctuation variants are
# normalized before lookup.
AGREEMENT_LABEL_TO_SCORE = {
    "strongly disagree": 1,
    "somewhat disagree": 2,
    "disagree": 2,
    "neither agree nor disagree": 3,
    "neither disagree nor agree": 3,
    "neutral": 3,
    "somewhat agree": 4,
    "agree": 4,
    "strongly agree": 5,
}

SCORE_TO_LABEL = {
    1: "Strongly disagree",
    2: "Somewhat disagree",
    3: "Neither agree nor disagree",
    4: "Somewhat agree",
    5: "Strongly agree",
}

SYSTEM_COLUMNS = {
    "startdate", "enddate", "status", "ipaddress", "progress",
    "duration (in seconds)", "finished", "recordeddate", "responseid",
    "recipientlastname", "recipientfirstname", "recipientemail",
    "externalreference", "locationlatitude", "locationlongitude",
    "distributionchannel", "userlanguage",
}


@dataclass
class SurveyExport:
    path: Path
    raw: pd.DataFrame
    physical_data: pd.DataFrame
    data: pd.DataFrame
    source_rows: pd.Series
    blank_row_mask: pd.Series
    question_text: dict[str, str]
    import_ids: dict[str, str]
    data_start_index: int


def clean_text(value: Any) -> str:
    """Normalize whitespace while preserving substantive text and case."""
    if value is None or pd.isna(value):
        return ""
    text = str(value).replace("\u00a0", " ")
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    return text.strip()


def canonical_label(value: Any) -> str:
    """Canonical form used only to recognize response-category semantics."""
    text = clean_text(value).casefold()
    text = text.replace("–", "-").replace("—", "-")
    text = re.sub(r"^[1-5]\s*[-.:)]\s*", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip(" .")


def normalize_code(value: Any) -> str:
    """Canonicalize numeric choice codes without changing nonnumeric text."""
    text = clean_text(value)
    try:
        number = float(text.replace(",", ""))
    except ValueError:
        return text
    if math.isfinite(number) and number.is_integer():
        return str(int(number))
    return text


def is_numeric_code(value: Any) -> bool:
    text = clean_text(value)
    if text == "":
        return False
    try:
        number = float(text.replace(",", ""))
    except ValueError:
        return False
    return math.isfinite(number)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def package_version(name: str) -> str:
    try:
        return importlib.metadata.version(name)
    except importlib.metadata.PackageNotFoundError:
        return "not installed"


def load_config(path: Path | None) -> dict[str, Any]:
    config = json.loads(json.dumps(DEFAULT_CONFIG))
    if path:
        with path.open("r", encoding="utf-8") as handle:
            supplied = json.load(handle)
        unknown = set(supplied) - set(config)
        if unknown:
            raise ValueError(f"Unknown configuration key(s): {sorted(unknown)}")
        config.update(supplied)

    for key in ("likert_columns", "non_likert_columns", "reverse_worded_columns"):
        if not isinstance(config[key], list):
            raise ValueError(f"{key} must be a JSON list.")
    if not isinstance(config["constructs"], dict):
        raise ValueError("constructs must be a JSON object of name: [columns].")
    for name, items in config["constructs"].items():
        if not isinstance(name, str) or not isinstance(items, list):
            raise ValueError("Each construct must have a string name and a list of columns.")

    fraction = float(config["minimum_scale_answered_fraction"])
    if not 0 < fraction <= 1:
        raise ValueError("minimum_scale_answered_fraction must be in (0, 1].")
    alpha = float(config["familywise_alpha"])
    if not 0 < alpha < 1:
        raise ValueError("familywise_alpha must be in (0, 1).")
    repetitions = int(config["bootstrap_repetitions"])
    if repetitions < 0:
        raise ValueError("bootstrap_repetitions cannot be negative.")

    config["minimum_scale_answered_fraction"] = fraction
    config["familywise_alpha"] = alpha
    config["bootstrap_repetitions"] = repetitions
    config["random_seed"] = int(config["random_seed"])
    config["enable_sign_tests"] = bool(config["enable_sign_tests"])
    return config


def read_qualtrics_csv(path: Path) -> SurveyExport:
    """Read a standard or Qualtrics three-row-header CSV losslessly."""
    last_error: Exception | None = None
    frame: pd.DataFrame | None = None
    for encoding in ("utf-8-sig", "utf-8", "cp1252"):
        try:
            frame = pd.read_csv(
                path,
                dtype=str,
                keep_default_na=False,
                na_filter=False,
                encoding=encoding,
                low_memory=False,
            )
            break
        except UnicodeDecodeError as error:
            last_error = error
    if frame is None:
        raise RuntimeError(f"Could not decode {path}: {last_error}")

    normalized_headers = [clean_text(column) or f"Unnamed_{i + 1}"
                          for i, column in enumerate(frame.columns)]
    if len(normalized_headers) != len(set(normalized_headers)):
        duplicates = sorted(name for name, count in Counter(normalized_headers).items() if count > 1)
        raise ValueError(f"Duplicate column names after normalization: {duplicates}")
    frame.columns = normalized_headers

    question_text = {column: column for column in frame.columns}
    import_ids = {column: "" for column in frame.columns}
    import_row: int | None = None

    # Qualtrics normally places question text in the first body row and
    # {"ImportId":"QID..."} in the second. Search only the first six rows.
    for row_index in range(min(6, len(frame))):
        cells = [clean_text(value) for value in frame.iloc[row_index].tolist()]
        threshold = max(1, min(3, len(frame.columns) // 20))
        if sum("ImportId" in cell for cell in cells) >= threshold:
            import_row = row_index
            break

    data_start = 0
    if import_row is not None:
        text_row = max(0, import_row - 1)
        for column in frame.columns:
            text = clean_text(frame.at[text_row, column])
            if text and "ImportId" not in text:
                question_text[column] = text
            import_cell = clean_text(frame.at[import_row, column])
            match = re.search(
                r'["\']?ImportId["\']?\s*:\s*["\']?([^"\'}\s,]+)',
                import_cell,
            )
            if match:
                import_ids[column] = match.group(1)
        data_start = import_row + 1

    physical = frame.iloc[data_start:].copy().reset_index(drop=True)
    physical = physical.apply(lambda series: series.map(clean_text))
    physical = physical.replace("", np.nan)
    blank_mask = physical.isna().all(axis=1)
    retained_positions = np.flatnonzero(~blank_mask.to_numpy())
    data = physical.loc[~blank_mask].reset_index(drop=True)

    # Spreadsheet row numbers are 1-indexed and include the header row.
    source_rows = pd.Series(retained_positions + data_start + 2, name="source_csv_row")
    return SurveyExport(
        path=path,
        raw=frame,
        physical_data=physical,
        data=data,
        source_rows=source_rows,
        blank_row_mask=blank_mask,
        question_text=question_text,
        import_ids=import_ids,
        data_start_index=data_start,
    )


def reference_aliases(column: str, import_id: str) -> set[str]:
    return {clean_text(column).casefold(), clean_text(import_id).casefold()} - {""}


def resolve_requested_columns(
    requested: Iterable[str],
    columns: Iterable[str],
    import_ids: dict[str, str],
    label: str,
) -> set[str]:
    alias_to_column: dict[str, str] = {}
    for column in columns:
        for alias in reference_aliases(column, import_ids.get(column, "")):
            if alias in alias_to_column and alias_to_column[alias] != column:
                raise ValueError(f"Ambiguous column alias: {alias}")
            alias_to_column[alias] = column

    resolved: set[str] = set()
    unresolved: list[str] = []
    for name in requested:
        column = alias_to_column.get(clean_text(name).casefold())
        if column:
            resolved.add(column)
        else:
            unresolved.append(str(name))
    if unresolved:
        raise ValueError(f"Unknown {label} column(s): {unresolved}")
    return resolved


def is_system_column(column: str) -> bool:
    normalized = clean_text(column).casefold()
    return normalized in SYSTEM_COLUMNS or normalized.startswith("recipient")


def reconcile_exports(
    numeric: SurveyExport,
    labels: SurveyExport,
) -> tuple[pd.DataFrame, pd.DataFrame, dict[str, Any]]:
    """Verify row-wise equivalence and derive observed code-to-label pairs."""
    columns_equal = list(numeric.raw.columns) == list(labels.raw.columns)
    if not columns_equal:
        raise ValueError("Numeric and label exports do not have identical columns in identical order.")
    columns = list(numeric.raw.columns)

    physical_rows_equal = len(numeric.physical_data) == len(labels.physical_data)
    if not physical_rows_equal:
        raise ValueError(
            "Numeric and label exports contain different numbers of physical participant rows."
        )

    metadata_equal = all(
        clean_text(numeric.question_text.get(column, ""))
        == clean_text(labels.question_text.get(column, ""))
        and clean_text(numeric.import_ids.get(column, ""))
        == clean_text(labels.import_ids.get(column, ""))
        for column in columns
    )

    # Exact blank-row positions matter for a row-wise comparison.
    blank_positions_equal = numeric.blank_row_mask.equals(labels.blank_row_mask)
    if not blank_positions_equal:
        raise ValueError("The exports do not have blank participant rows in the same positions.")

    audit_rows: list[dict[str, Any]] = []
    codebook_rows: list[dict[str, Any]] = []
    total_missingness_mismatches = 0
    total_identity_mismatches = 0
    total_mapping_conflicts = 0

    for column in columns:
        raw_codes = numeric.physical_data[column].map(clean_text)
        raw_labels = labels.physical_data[column].map(clean_text)
        missing_codes = raw_codes.eq("")
        missing_labels = raw_labels.eq("")
        missingness_mismatches = int((missing_codes != missing_labels).sum())

        paired = pd.DataFrame({"raw_code": raw_codes, "response_label": raw_labels})
        paired = paired[(paired.raw_code != "") & (paired.response_label != "")].copy()
        normalized_codes = paired.raw_code.map(normalize_code)
        code_mode = bool(len(paired)) and bool(paired.raw_code.map(is_numeric_code).all())

        code_to_labels: dict[str, set[str]] = {}
        label_to_codes: dict[str, set[str]] = {}
        for code, response_label in zip(normalized_codes, paired.response_label):
            code_to_labels.setdefault(code, set()).add(response_label)
            label_to_codes.setdefault(response_label, set()).add(code)

        code_conflicts = sum(len(values) - 1 for values in code_to_labels.values() if len(values) > 1)
        label_conflicts = sum(len(values) - 1 for values in label_to_codes.values() if len(values) > 1)
        mapping_conflicts = code_conflicts + label_conflicts

        # Open-text and identifier fields must be literally identical. Coded
        # categorical fields are equivalent through their one-to-one mapping.
        identity_mismatches = 0
        if not code_mode:
            identity_mismatches = int((paired.raw_code != paired.response_label).sum())

        total_missingness_mismatches += missingness_mismatches
        total_identity_mismatches += identity_mismatches
        total_mapping_conflicts += mapping_conflicts

        audit_rows.append({
            "source_column": column,
            "import_id": numeric.import_ids.get(column, ""),
            "question": numeric.question_text.get(column, column),
            "physical_rows": len(raw_codes),
            "numeric_nonmissing_n": int((~missing_codes).sum()),
            "label_nonmissing_n": int((~missing_labels).sum()),
            "numeric_code_mode": code_mode,
            "missingness_mismatches": missingness_mismatches,
            "identity_mismatches": identity_mismatches,
            "mapping_conflicts": mapping_conflicts,
            "equivalent": (
                missingness_mismatches == 0
                and identity_mismatches == 0
                and mapping_conflicts == 0
            ),
        })

        pair_counts = (
            pd.DataFrame({"raw_code": normalized_codes, "response_label": paired.response_label})
            .value_counts(sort=False)
            .rename("observed_n")
            .reset_index()
        )
        for record in pair_counts.to_dict(orient="records"):
            semantic_score = AGREEMENT_LABEL_TO_SCORE.get(
                canonical_label(record["response_label"]), np.nan
            )
            codebook_rows.append({
                "source_column": column,
                "import_id": numeric.import_ids.get(column, ""),
                "raw_numeric_code": record["raw_code"],
                "response_label": record["response_label"],
                "semantic_score": semantic_score,
                "observed_n": int(record["observed_n"]),
            })

    audit = pd.DataFrame(audit_rows)
    codebook = pd.DataFrame(codebook_rows)

    response_id_columns = [
        column for column in columns
        if clean_text(column).casefold() in {"responseid", "response id"}
    ]
    alignment_method = (
        f"Response identifier: {response_id_columns[0]}"
        if response_id_columns
        else "Physical row position; no response identifier was present"
    )

    equivalent = bool(
        columns_equal
        and physical_rows_equal
        and metadata_equal
        and blank_positions_equal
        and total_missingness_mismatches == 0
        and total_identity_mismatches == 0
        and total_mapping_conflicts == 0
        and bool(audit["equivalent"].all())
    )
    integrity = {
        "exports_equivalent": equivalent,
        "columns_equal_and_ordered": columns_equal,
        "metadata_equal": metadata_equal,
        "physical_participant_rows": len(numeric.physical_data),
        "all_blank_rows_removed": int(numeric.blank_row_mask.sum()),
        "analyzed_participant_rows": len(numeric.data),
        "column_count": len(columns),
        "missingness_mismatches": total_missingness_mismatches,
        "open_text_or_identifier_mismatches": total_identity_mismatches,
        "code_label_mapping_conflicts": total_mapping_conflicts,
        "alignment_method": alignment_method,
    }
    if not equivalent:
        raise ValueError(
            "The numeric and label exports are not equivalent: "
            f"missingness mismatches={total_missingness_mismatches}, "
            f"open-text/identifier mismatches={total_identity_mismatches}, "
            f"code-label mapping conflicts={total_mapping_conflicts}."
        )
    return audit, codebook, integrity


def audit_label_only_export(
    labels: SurveyExport,
) -> tuple[pd.DataFrame, pd.DataFrame, dict[str, Any]]:
    """Build an auditable codebook when displayed labels are the sole source.

    This mode intentionally does not claim cross-export equivalence. Agreement
    responses are scored directly from label semantics; categorical and text
    responses remain unchanged.
    """
    audit_rows: list[dict[str, Any]] = []
    codebook_rows: list[dict[str, Any]] = []

    for column in labels.data.columns:
        values = labels.physical_data[column].map(clean_text)
        nonmissing = values[values != ""]
        counts = nonmissing.value_counts(sort=False)
        recognized_n = int(nonmissing.map(
            lambda value: canonical_label(value) in AGREEMENT_LABEL_TO_SCORE
        ).sum())

        audit_rows.append({
            "source_column": column,
            "import_id": labels.import_ids.get(column, ""),
            "question": labels.question_text.get(column, column),
            "physical_rows": len(values),
            "label_nonmissing_n": int(len(nonmissing)),
            "recognized_agreement_label_n": recognized_n,
            "recognized_agreement_label_pct": (
                recognized_n / len(nonmissing) if len(nonmissing) else np.nan
            ),
            "numeric_code_mode": False,
            "equivalent": np.nan,
            "validation_note": "Single label source; paired-export check not performed",
        })

        for response_label, observed_n in counts.items():
            codebook_rows.append({
                "source_column": column,
                "import_id": labels.import_ids.get(column, ""),
                "raw_numeric_code": "",
                "response_label": response_label,
                "semantic_score": AGREEMENT_LABEL_TO_SCORE.get(
                    canonical_label(response_label), np.nan
                ),
                "observed_n": int(observed_n),
            })

    integrity = {
        "analysis_input_mode": "label_only",
        "cross_export_reconciliation_performed": False,
        "semantic_scoring_source": "Displayed response labels",
        "physical_participant_rows": len(labels.physical_data),
        "all_blank_rows_removed": int(labels.blank_row_mask.sum()),
        "analyzed_participant_rows": len(labels.data),
        "column_count": len(labels.data.columns),
    }
    return pd.DataFrame(audit_rows), pd.DataFrame(codebook_rows), integrity


def classify_and_build_score_maps(
    numeric: SurveyExport,
    labels: SurveyExport,
    reconciliation: pd.DataFrame,
    codebook: pd.DataFrame,
    explicit_likert: set[str],
    explicit_non_likert: set[str],
    score_source: str = "numeric_codes",
) -> tuple[list[str], dict[str, dict[str, int]], pd.DataFrame, pd.DataFrame]:
    """Classify columns from labels and construct semantic code maps."""
    likert_columns: list[str] = []
    score_maps: dict[str, dict[str, int]] = {}
    audit_rows: list[dict[str, Any]] = []
    explicit_mode = bool(explicit_likert)

    for column in numeric.data.columns:
        label_values = labels.data[column].dropna().map(clean_text)
        recognized = label_values.map(
            lambda value: canonical_label(value) in AGREEMENT_LABEL_TO_SCORE
        )
        valid_n = int(len(label_values))
        recognized_n = int(recognized.sum())
        recognized_fraction = recognized_n / valid_n if valid_n else 0.0
        distinct_n = int(label_values.nunique())

        if is_system_column(column):
            classification = "metadata"
            reason = "Known Qualtrics/system field"
        elif column in explicit_non_likert:
            if distinct_n > 25:
                classification = "text_or_identifier"
                reason = "Explicitly excluded from Likert analysis; high-cardinality text"
            else:
                classification = "non_likert"
                reason = "Explicitly excluded; categorical/ordinal item"
        elif column in explicit_likert:
            classification = "likert"
            reason = "Explicitly included and validated against response labels"
        elif explicit_mode:
            classification = "non_likert" if distinct_n <= 25 else "text_or_identifier"
            reason = "Not included in the explicit Likert list"
        elif valid_n > 0 and recognized_fraction == 1.0:
            classification = "likert"
            reason = "All observed response labels are five-point agreement categories"
        elif distinct_n <= 25:
            classification = "non_likert"
            reason = "Categorical/ordinal but not a five-point agreement item"
        else:
            classification = "text_or_identifier"
            reason = "High-cardinality text or identifier"

        if classification == "likert":
            unknown_labels = sorted({
                value for value in label_values
                if canonical_label(value) not in AGREEMENT_LABEL_TO_SCORE
            })
            if unknown_labels:
                raise ValueError(
                    f"Likert column {column} contains unrecognized labels: {unknown_labels}"
                )

            mapping: dict[str, int] = {}
            item_codebook = codebook[codebook.source_column == column]
            for record in item_codebook.to_dict(orient="records"):
                score = record["semantic_score"]
                if pd.isna(score):
                    raise ValueError(
                        f"Could not derive a semantic score for {column}: "
                        f"{record['response_label']!r}"
                    )
                if score_source == "labels":
                    raw_value = clean_text(record["response_label"])
                elif score_source == "numeric_codes":
                    raw_value = normalize_code(record["raw_numeric_code"])
                else:
                    raise ValueError(f"Unknown scoring source: {score_source}")
                score_int = int(score)
                if raw_value in mapping and mapping[raw_value] != score_int:
                    raise ValueError(
                        f"Conflicting semantic scores for {column}, value {raw_value!r}."
                    )
                mapping[raw_value] = score_int
            if not mapping:
                raise ValueError(f"Likert column {column} has no observed score mapping.")
            score_maps[column] = mapping
            likert_columns.append(column)

        raw_direction = "not_applicable"
        if classification == "likert":
            if score_source == "labels":
                raw_direction = "not_applicable: scored directly from labels"
            else:
                pairs = []
                for raw_code, score in score_maps[column].items():
                    try:
                        raw_number = int(raw_code)
                    except ValueError:
                        continue
                    pairs.append((raw_number, score))
                if pairs and all(raw == score for raw, score in pairs):
                    raw_direction = "ascending: raw 1=disagree, raw 5=agree"
                elif pairs and all(raw == 6 - score for raw, score in pairs):
                    raw_direction = "descending: raw 1=agree, raw 5=disagree"
                else:
                    raw_direction = "custom/partially observed"

        reconciliation_row = reconciliation.loc[
            reconciliation.source_column == column
        ].iloc[0]
        paired_value = reconciliation_row["equivalent"]
        paired_equivalent = (
            bool(paired_value) if pd.notna(paired_value) else np.nan
        )
        audit_rows.append({
            "source_column": column,
            "import_id": numeric.import_ids.get(column, ""),
            "question": numeric.question_text.get(column, column),
            "classification": classification,
            "decision_reason": reason,
            "valid_n": valid_n,
            "missing_n": len(labels.data) - valid_n,
            "distinct_nonmissing_n": distinct_n,
            "agreement_label_recognized_n": recognized_n,
            "agreement_label_recognized_pct": recognized_fraction,
            "raw_code_direction": raw_direction,
            "numeric_code_mode": bool(reconciliation_row["numeric_code_mode"]),
            "paired_export_equivalent": paired_equivalent,
        })

    audit = pd.DataFrame(audit_rows)
    codebook = codebook.merge(
        audit[["source_column", "classification", "raw_code_direction"]],
        on="source_column",
        how="left",
        validate="many_to_one",
    )
    return likert_columns, score_maps, audit, codebook


def score_numeric_data(
    numeric_data: pd.DataFrame,
    likert_columns: list[str],
    score_maps: dict[str, dict[str, int]],
    source_rows: pd.Series,
) -> pd.DataFrame:
    scored = pd.DataFrame({
        "participant_row": np.arange(1, len(numeric_data) + 1),
        "source_csv_row": source_rows.to_numpy(),
    })
    for column in likert_columns:
        mapping = score_maps[column]

        def convert(value: Any) -> float:
            if pd.isna(value) or clean_text(value) == "":
                return np.nan
            code = normalize_code(value)
            if code not in mapping:
                raise ValueError(f"Unmapped numeric code in {column}: {value!r}")
            return float(mapping[code])

        scored[column] = numeric_data[column].map(convert).astype(float)
    return scored


def mean_confidence_interval(values: pd.Series, confidence: float = 0.95) -> tuple[float, float]:
    clean = values.dropna().astype(float)
    n = len(clean)
    if n < 2:
        return np.nan, np.nan
    mean = float(clean.mean())
    sem = float(clean.std(ddof=1) / math.sqrt(n))
    critical = float(student_t.ppf((1 + confidence) / 2, df=n - 1))
    return mean - critical * sem, mean + critical * sem


def wilson_interval(successes: int, total: int, confidence: float = 0.95) -> tuple[float, float]:
    if total <= 0:
        return np.nan, np.nan
    z = float(norm.ppf((1 + confidence) / 2))
    p_hat = successes / total
    denominator = 1 + z * z / total
    center = (p_hat + z * z / (2 * total)) / denominator
    margin = z * math.sqrt(
        p_hat * (1 - p_hat) / total + z * z / (4 * total * total)
    ) / denominator
    return max(0.0, center - margin), min(1.0, center + margin)


def mode_string(values: pd.Series) -> str:
    modes = sorted(float(value) for value in values.dropna().mode().tolist())
    return ", ".join(str(int(value)) if value.is_integer() else str(value) for value in modes)


def summarize_likert(
    semantic_scores: pd.DataFrame,
    likert_columns: list[str],
    numeric: SurveyExport,
    reverse_worded: set[str],
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    item_rows: list[dict[str, Any]] = []
    distribution_rows: list[dict[str, Any]] = []
    total_rows = len(semantic_scores)
    construct_scores = semantic_scores.copy()

    for column in likert_columns:
        values = semantic_scores[column]
        if column in reverse_worded:
            construct_scores[column] = 6 - values
        valid = values.dropna().astype(float)
        n = int(len(valid))
        missing = total_rows - n
        counts = {score: int((valid == score).sum()) for score in range(1, 6)}
        percentages = {score: counts[score] / n if n else np.nan for score in range(1, 6)}

        q1 = float(valid.quantile(0.25, interpolation="linear")) if n else np.nan
        q3 = float(valid.quantile(0.75, interpolation="linear")) if n else np.nan
        mean_ci_low, mean_ci_high = mean_confidence_interval(valid)
        disagree_n = counts[1] + counts[2]
        agree_n = counts[4] + counts[5]
        agree_ci_low, agree_ci_high = wilson_interval(agree_n, n)
        disagree_ci_low, disagree_ci_high = wilson_interval(disagree_n, n)

        row: dict[str, Any] = {
            "source_column": column,
            "import_id": numeric.import_ids.get(column, ""),
            "question": numeric.question_text.get(column, column),
            "reverse_worded_for_construct_scoring": column in reverse_worded,
            "valid_n": n,
            "missing_n": missing,
            "missing_pct": missing / total_rows if total_rows else np.nan,
        }
        for score in range(1, 6):
            row[f"n_{score}"] = counts[score]
            row[f"pct_{score}"] = percentages[score]
        row.update({
            "disagree_n": disagree_n,
            "disagree_pct": disagree_n / n if n else np.nan,
            "disagree_wilson95_lower": disagree_ci_low,
            "disagree_wilson95_upper": disagree_ci_high,
            "neutral_n": counts[3],
            "neutral_pct": counts[3] / n if n else np.nan,
            "agree_n": agree_n,
            "agree_pct": agree_n / n if n else np.nan,
            "agree_wilson95_lower": agree_ci_low,
            "agree_wilson95_upper": agree_ci_high,
            "agreement_balance_pp": ((agree_n - disagree_n) / n * 100) if n else np.nan,
            "mean": float(valid.mean()) if n else np.nan,
            "sample_sd": float(valid.std(ddof=1)) if n >= 2 else np.nan,
            "mean_ci95_lower": mean_ci_low,
            "mean_ci95_upper": mean_ci_high,
            "median": float(valid.median()) if n else np.nan,
            "q1": q1,
            "q3": q3,
            "iqr": q3 - q1 if n else np.nan,
            "mode": mode_string(valid) if n else "",
            "min": float(valid.min()) if n else np.nan,
            "max": float(valid.max()) if n else np.nan,
        })
        item_rows.append(row)

        for score in range(1, 6):
            category_ci_low, category_ci_high = wilson_interval(counts[score], n)
            distribution_rows.append({
                "source_column": column,
                "import_id": numeric.import_ids.get(column, ""),
                "question": numeric.question_text.get(column, column),
                "semantic_score": score,
                "response_label": SCORE_TO_LABEL[score],
                "n": counts[score],
                "pct_of_valid": percentages[score],
                "wilson95_lower": category_ci_low,
                "wilson95_upper": category_ci_high,
                "valid_n": n,
            })

    return pd.DataFrame(item_rows), pd.DataFrame(distribution_rows), construct_scores


def holm_adjust(p_values: pd.Series) -> pd.Series:
    """Holm family-wise-error adjustment with monotonicity enforcement."""
    result = pd.Series(np.nan, index=p_values.index, dtype=float)
    valid = p_values.dropna().sort_values()
    m = len(valid)
    running_max = 0.0
    for rank, (index, p_value) in enumerate(valid.items()):
        adjusted = min(1.0, (m - rank) * float(p_value))
        running_max = max(running_max, adjusted)
        result.at[index] = running_max
    return result


def directional_sign_tests(
    semantic_scores: pd.DataFrame,
    likert_columns: list[str],
    numeric: SurveyExport,
    enabled: bool,
    alpha: float,
) -> pd.DataFrame:
    rows: list[dict[str, Any]] = []
    for column in likert_columns:
        values = semantic_scores[column].dropna()
        agree_n = int(values.isin([4, 5]).sum())
        disagree_n = int(values.isin([1, 2]).sum())
        directional_n = agree_n + disagree_n
        p_value = np.nan
        ci_low = np.nan
        ci_high = np.nan
        if enabled and directional_n > 0:
            test = binomtest(agree_n, directional_n, p=0.5, alternative="two-sided")
            p_value = float(test.pvalue)
            interval = test.proportion_ci(confidence_level=0.95, method="exact")
            ci_low, ci_high = float(interval.low), float(interval.high)
        rows.append({
            "source_column": column,
            "import_id": numeric.import_ids.get(column, ""),
            "question": numeric.question_text.get(column, column),
            "agree_n": agree_n,
            "disagree_n": disagree_n,
            "neutral_excluded_n": int((values == 3).sum()),
            "directional_n": directional_n,
            "agree_share_of_directional": agree_n / directional_n if directional_n else np.nan,
            "exact95_lower": ci_low,
            "exact95_upper": ci_high,
            "two_sided_exact_binomial_p": p_value,
        })
    frame = pd.DataFrame(rows)
    frame["holm_adjusted_p"] = holm_adjust(frame["two_sided_exact_binomial_p"])
    frame["reject_after_holm"] = (
        frame["holm_adjusted_p"] < alpha if enabled else False
    )
    frame["test_enabled"] = enabled
    return frame


def summarize_non_likert(
    labels: SurveyExport,
    audit: pd.DataFrame,
    codebook: pd.DataFrame,
) -> pd.DataFrame:
    rows: list[dict[str, Any]] = []
    selected = audit.loc[audit.classification == "non_likert", "source_column"]
    for column in selected:
        values = labels.data[column].dropna().map(clean_text)
        valid_n = len(values)
        counts = Counter(values)
        audit_row = audit.loc[audit.source_column == column].iloc[0]
        if bool(audit_row["numeric_code_mode"]):
            item_codebook = codebook.loc[
                codebook.source_column == column,
                ["raw_numeric_code", "response_label"],
            ].drop_duplicates()
            categories = [
                (record.response_label, counts.get(record.response_label, 0), record.raw_numeric_code)
                for record in item_codebook.sort_values(
                    "raw_numeric_code",
                    key=lambda values_: pd.to_numeric(values_, errors="coerce"),
                ).itertuples(index=False)
            ]
        else:
            categories = [
                (category, count, "") for category, count in counts.most_common()
            ]
        for category, count, raw_code in categories:
            ci_low, ci_high = wilson_interval(int(count), valid_n)
            rows.append({
                "source_column": column,
                "import_id": labels.import_ids.get(column, ""),
                "question": labels.question_text.get(column, column),
                "raw_numeric_code": raw_code,
                "category_label": category,
                "n": int(count),
                "pct_of_valid": count / valid_n if valid_n else np.nan,
                "wilson95_lower": ci_low,
                "wilson95_upper": ci_high,
                "valid_n": valid_n,
                "missing_n": len(labels.data) - valid_n,
            })
    return pd.DataFrame(rows)


def longest_identical_run(values: list[float]) -> int:
    longest = 0
    current = 0
    previous: float | None = None
    for value in values:
        if pd.isna(value):
            previous = None
            current = 0
        elif previous is not None and value == previous:
            current += 1
        else:
            previous = value
            current = 1
        longest = max(longest, current)
    return longest


def respondent_qc(
    semantic_scores: pd.DataFrame,
    likert_columns: list[str],
) -> pd.DataFrame:
    """Return screening metrics only; never exclude respondents automatically."""
    rows: list[dict[str, Any]] = []
    for _, row in semantic_scores.iterrows():
        values = row[likert_columns].astype(float)
        valid = values.dropna()
        counts = valid.value_counts()
        rows.append({
            "participant_row": int(row["participant_row"]),
            "source_csv_row": int(row["source_csv_row"]),
            "likert_answered_n": int(len(valid)),
            "likert_total_items": len(likert_columns),
            "likert_completion_pct": len(valid) / len(likert_columns) if likert_columns else np.nan,
            "within_person_sample_sd": float(valid.std(ddof=1)) if len(valid) >= 2 else np.nan,
            "modal_response_share": float(counts.iloc[0] / len(valid)) if len(valid) else np.nan,
            "longest_identical_run_in_question_order": longest_identical_run(values.tolist()),
            "automatic_exclusion": False,
            "note": "Review with preregistered criteria; skip logic can create legitimate missingness.",
        })
    return pd.DataFrame(rows)


def cronbach_alpha(frame: pd.DataFrame) -> float:
    if frame.shape[1] < 2 or frame.shape[0] < 2:
        return np.nan
    item_variance_sum = float(frame.var(axis=0, ddof=1).sum())
    total_variance = float(frame.sum(axis=1).var(ddof=1))
    if total_variance <= 0:
        return np.nan
    k = frame.shape[1]
    return float(k / (k - 1) * (1 - item_variance_sum / total_variance))


def standardized_alpha(frame: pd.DataFrame) -> float:
    if frame.shape[1] < 2 or frame.shape[0] < 2:
        return np.nan
    correlation = frame.corr()
    k = correlation.shape[0]
    upper = correlation.to_numpy()[np.triu_indices(k, 1)]
    mean_r = float(np.nanmean(upper)) if len(upper) else np.nan
    denominator = 1 + (k - 1) * mean_r
    if not np.isfinite(mean_r) or denominator == 0:
        return np.nan
    return float(k * mean_r / denominator)


def bootstrap_alpha_interval(
    complete: pd.DataFrame,
    repetitions: int,
    rng: np.random.Generator,
) -> tuple[float, float]:
    if repetitions <= 0 or complete.shape[0] < 3 or complete.shape[1] < 2:
        return np.nan, np.nan
    estimates: list[float] = []
    n = len(complete)
    for _ in range(repetitions):
        sample_positions = rng.integers(0, n, size=n)
        estimate = cronbach_alpha(complete.iloc[sample_positions])
        if np.isfinite(estimate):
            estimates.append(float(estimate))
    if len(estimates) < max(100, repetitions // 2):
        return np.nan, np.nan
    return (
        float(np.quantile(estimates, 0.025, method="linear")),
        float(np.quantile(estimates, 0.975, method="linear")),
    )


def analyze_constructs(
    construct_scores: pd.DataFrame,
    constructs: dict[str, list[str]],
    import_ids: dict[str, str],
    minimum_fraction: float,
    bootstrap_repetitions: int,
    random_seed: int,
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    if not constructs:
        return pd.DataFrame(), pd.DataFrame(), pd.DataFrame()

    metadata_columns = ["participant_row", "source_csv_row"]
    item_scores = construct_scores.drop(columns=metadata_columns)
    summary_rows: list[dict[str, Any]] = []
    item_rows: list[dict[str, Any]] = []
    participant_scores = construct_scores[metadata_columns].copy()
    rng = np.random.default_rng(random_seed)

    for construct_name, requested_columns in constructs.items():
        resolved = resolve_requested_columns(
            requested_columns, item_scores.columns, import_ids, f"construct '{construct_name}'"
        )
        columns = [column for column in item_scores.columns if column in resolved]
        if len(columns) < 2:
            raise ValueError(f"Construct '{construct_name}' requires at least two Likert items.")

        construct_data = item_scores[columns]
        complete = construct_data.dropna(axis=0, how="any")
        alpha = cronbach_alpha(complete)
        standardized = standardized_alpha(complete)
        alpha_low, alpha_high = bootstrap_alpha_interval(
            complete, bootstrap_repetitions, rng
        )
        required_n = max(1, math.ceil(len(columns) * minimum_fraction))
        respondent_mean = construct_data.mean(axis=1, skipna=True)
        respondent_mean[construct_data.notna().sum(axis=1) < required_n] = np.nan
        participant_scores[construct_name] = respondent_mean
        valid_scores = respondent_mean.dropna()

        summary_rows.append({
            "construct": construct_name,
            "items_k": len(columns),
            "items": ", ".join(columns),
            "complete_case_n_for_reliability": len(complete),
            "cronbach_alpha": alpha,
            "alpha_bootstrap95_lower": alpha_low,
            "alpha_bootstrap95_upper": alpha_high,
            "standardized_alpha": standardized,
            "bootstrap_repetitions": bootstrap_repetitions,
            "minimum_items_required_for_score": required_n,
            "valid_scale_score_n": len(valid_scores),
            "scale_mean": float(valid_scores.mean()) if len(valid_scores) else np.nan,
            "scale_sample_sd": float(valid_scores.std(ddof=1)) if len(valid_scores) >= 2 else np.nan,
            "scale_median": float(valid_scores.median()) if len(valid_scores) else np.nan,
            "scale_iqr": (
                float(valid_scores.quantile(0.75) - valid_scores.quantile(0.25))
                if len(valid_scores) else np.nan
            ),
            "interpretation_note": (
                "Reliability is not evidence of unidimensionality; validate the construct first."
            ),
        })

        for column in columns:
            item = complete[column]
            total_without_item = complete.drop(columns=[column]).sum(axis=1)
            corrected_correlation = (
                item.corr(total_without_item) if len(complete) >= 3 else np.nan
            )
            alpha_deleted = (
                cronbach_alpha(complete.drop(columns=[column]))
                if len(columns) > 2 else np.nan
            )
            item_rows.append({
                "construct": construct_name,
                "source_column": column,
                "import_id": import_ids.get(column, ""),
                "complete_case_n": len(complete),
                "corrected_item_total_correlation": corrected_correlation,
                "alpha_if_item_deleted": alpha_deleted,
            })

    return pd.DataFrame(summary_rows), pd.DataFrame(item_rows), participant_scores


def integrity_table(integrity: dict[str, Any]) -> pd.DataFrame:
    return pd.DataFrame(
        [{"check": key, "value": value} for key, value in integrity.items()]
    )


def make_readme(
    input_path: Path,
    label_path: Path | None,
    input_mode: str,
    participant_n: int,
    likert_n: int,
    descending_columns: list[str],
    config: dict[str, Any],
) -> pd.DataFrame:
    notes = [
        ("Purpose", "Reproducible analysis of five-point Likert survey items."),
        ("Input mode", input_mode),
        (
            "Primary input",
            input_path.name if input_mode == "label_only" else label_path.name,
        ),
        (
            "Numeric validation input",
            input_path.name if input_mode == "paired_exports" else "Not used",
        ),
        (
            "Cross-export reconciliation",
            "Performed cell-by-cell" if input_mode == "paired_exports" else "Not performed",
        ),
        ("Participant rows analyzed", participant_n),
        ("Likert items analyzed", likert_n),
        ("Semantic coding", "1=Strongly disagree; 2=Somewhat disagree; 3=Neither; 4=Somewhat agree; 5=Strongly agree"),
        ("Critical normalization", "Scores are derived from displayed labels, not assumed from raw Qualtrics codes."),
        ("Descending raw-code columns", ", ".join(descending_columns) if descending_columns else "None"),
        ("Primary ordinal summaries", "Category n/%, median, Q1, Q3, and IQR"),
        ("Supplementary summaries", "Mean, sample SD, Student-t 95% CI, mode, and range"),
        ("Proportion uncertainty", "Wilson 95% confidence intervals"),
        ("Percentage denominator", "Valid responses per item; missingness uses retained participant rows"),
        ("Top/bottom two boxes", "Agree=scores 4+5; disagree=scores 1+2"),
        ("Quartiles", "pandas linear-interpolation quantiles"),
        ("All-blank rows", "Removed; partially completed rows retained; no imputation"),
        ("QC policy", "Metrics are reported but no participant is excluded automatically"),
        ("Reverse-worded items", "Affect construct scores only; item-level distributions remain in original wording"),
        ("Reliability", "Only for explicitly configured constructs; complete-case alpha with bootstrap CI"),
        ("Sign tests", "Enabled" if config["enable_sign_tests"] else "Disabled by default; enable only for pre-specified hypotheses"),
        ("Sign-test estimand", "Among non-neutral responses, exact two-sided test of P(agree)=0.5; Holm correction across tested items"),
        ("Important", "Do not compute reliability across unrelated questions or interpret p-values without a pre-specified hypothesis family"),
    ]
    return pd.DataFrame(notes, columns=["field", "value"])


def safe_sheet_name(name: str) -> str:
    return re.sub(r"[\\/*?:\[\]]", "_", name)[:31]


def style_workbook(path: Path, percentage_columns: dict[str, set[str]]) -> None:
    from openpyxl import load_workbook
    from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
    from openpyxl.utils import get_column_letter

    workbook = load_workbook(path)
    header_fill = PatternFill("solid", fgColor="17365D")
    header_font = Font(color="FFFFFF", bold=True)
    alternate_fill = PatternFill("solid", fgColor="EAF2F8")
    thin_blue = Side(style="thin", color="B4C7E7")

    for sheet in workbook.worksheets:
        sheet.freeze_panes = "A2"
        sheet.auto_filter.ref = sheet.dimensions
        sheet.sheet_view.showGridLines = False
        sheet.sheet_properties.pageSetUpPr.fitToPage = True
        sheet.page_setup.fitToWidth = 1
        sheet.page_setup.fitToHeight = 0
        sheet.sheet_view.zoomScale = 85

        for cell in sheet[1]:
            cell.fill = header_fill
            cell.font = header_font
            cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
            cell.border = Border(bottom=thin_blue)
        sheet.row_dimensions[1].height = 42

        headers = {cell.value: cell.column for cell in sheet[1] if cell.value is not None}
        for header in percentage_columns.get(sheet.title, set()):
            column_number = headers.get(header)
            if column_number:
                for row in range(2, sheet.max_row + 1):
                    sheet.cell(row, column_number).number_format = "0.0%"

        two_decimal_headers = {
            "mean", "sample_sd", "median", "q1", "q3", "iqr",
            "mean_ci95_lower", "mean_ci95_upper", "agreement_balance_pp",
            "cronbach_alpha", "standardized_alpha", "alpha_bootstrap95_lower",
            "alpha_bootstrap95_upper", "scale_mean", "scale_sample_sd",
            "scale_median", "scale_iqr", "corrected_item_total_correlation",
            "alpha_if_item_deleted", "two_sided_exact_binomial_p", "holm_adjusted_p",
        }
        for header in two_decimal_headers:
            column_number = headers.get(header)
            if column_number:
                for row in range(2, sheet.max_row + 1):
                    sheet.cell(row, column_number).number_format = "0.000"

        long_text_headers = {
            "question", "value", "decision_reason", "items", "note",
            "interpretation_note", "response_label", "category_label",
        }
        for header in long_text_headers:
            column_number = headers.get(header)
            if column_number:
                for row in range(2, sheet.max_row + 1):
                    sheet.cell(row, column_number).alignment = Alignment(
                        vertical="top", wrap_text=True
                    )

        for column_index, cells in enumerate(sheet.iter_cols(), start=1):
            header = clean_text(cells[0].value)
            sample = [clean_text(cell.value) for cell in cells[:min(len(cells), 200)]]
            max_length = max([len(header)] + [len(value) for value in sample])
            if header in long_text_headers:
                width = 52
            elif header in {"source_column", "import_id", "construct", "raw_code_direction"}:
                width = min(max(max_length + 2, 14), 36)
            else:
                width = min(max(max_length + 2, 10), 22)
            sheet.column_dimensions[get_column_letter(column_index)].width = width

        if sheet.title in {"README", "Data_Integrity"}:
            for row in range(2, sheet.max_row + 1):
                sheet.cell(row, 1).font = Font(bold=True, color="17365D")
                if row % 2 == 0:
                    for column in range(1, sheet.max_column + 1):
                        sheet.cell(row, column).fill = alternate_fill
            sheet.column_dimensions["A"].width = 36
            sheet.column_dimensions["B"].width = 105

    workbook.save(path)


def export_results(
    output_dir: Path,
    numeric: SurveyExport,
    labels: SurveyExport,
    readme: pd.DataFrame,
    integrity: pd.DataFrame,
    reconciliation: pd.DataFrame,
    codebook: pd.DataFrame,
    audit: pd.DataFrame,
    item_summary: pd.DataFrame,
    distribution: pd.DataFrame,
    directional_tests: pd.DataFrame,
    semantic_scores: pd.DataFrame,
    construct_scores: pd.DataFrame,
    non_likert: pd.DataFrame,
    qc: pd.DataFrame,
    construct_summary: pd.DataFrame,
    reliability_items: pd.DataFrame,
    scale_scores: pd.DataFrame,
    config: dict[str, Any],
    manifest: dict[str, Any],
    input_mode: str,
) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    workbook_path = output_dir / "survey_analysis.xlsx"

    csv_outputs = {
        "item_summary.csv": item_summary,
        "response_distribution.csv": distribution,
        "column_audit.csv": audit,
        "reconciliation_report.csv": reconciliation,
        "derived_codebook.csv": codebook,
        "respondent_qc.csv": qc,
    }
    for filename, frame in csv_outputs.items():
        frame.to_csv(output_dir / filename, index=False, encoding="utf-8-sig")

    with (output_dir / "analysis_config_used.json").open("w", encoding="utf-8") as handle:
        json.dump(config, handle, indent=2, ensure_ascii=False)
    with (output_dir / "analysis_manifest.json").open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False)

    analysis_labels = labels.data.copy()
    analysis_labels.insert(0, "source_csv_row", labels.source_rows.to_numpy())

    sheets: list[tuple[str, pd.DataFrame]] = [
        ("README", readme),
        ("Data_Integrity", integrity),
        ("Item_Summary", item_summary),
        ("Distribution", distribution),
        ("Directional_Tests", directional_tests),
        ("Column_Audit", audit),
        ("Derived_Codebook", codebook),
        ("Reconciliation", reconciliation),
        ("Semantic_Scores", semantic_scores),
        ("Construct_Scores", construct_scores),
        ("Non_Likert_Summary", non_likert),
        ("Respondent_QC", qc),
        ("Analysis_Labels", analysis_labels),
        ("Raw_Labels", labels.raw),
    ]
    if input_mode == "paired_exports":
        analysis_numbers = numeric.data.copy()
        analysis_numbers.insert(0, "source_csv_row", numeric.source_rows.to_numpy())
        sheets.extend([
            ("Analysis_Numbers", analysis_numbers),
            ("Raw_Numbers", numeric.raw),
        ])
    if not construct_summary.empty:
        sheets.extend([
            ("Construct_Summary", construct_summary),
            ("Reliability_Items", reliability_items),
            ("Scale_Scores", scale_scores),
        ])

    with pd.ExcelWriter(workbook_path, engine="openpyxl") as writer:
        for name, frame in sheets:
            frame.to_excel(writer, sheet_name=safe_sheet_name(name), index=False)

    percentage_columns = {
        "Item_Summary": {
            "missing_pct", "pct_1", "pct_2", "pct_3", "pct_4", "pct_5",
            "disagree_pct", "disagree_wilson95_lower", "disagree_wilson95_upper",
            "neutral_pct", "agree_pct", "agree_wilson95_lower", "agree_wilson95_upper",
        },
        "Distribution": {"pct_of_valid", "wilson95_lower", "wilson95_upper"},
        "Directional_Tests": {
            "agree_share_of_directional", "exact95_lower", "exact95_upper",
        },
        "Column_Audit": {"agreement_label_recognized_pct"},
        "Non_Likert_Summary": {"pct_of_valid", "wilson95_lower", "wilson95_upper"},
        "Respondent_QC": {"likert_completion_pct", "modal_response_share"},
    }
    style_workbook(workbook_path, percentage_columns)
    return workbook_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Analyze a Qualtrics label export, optionally reconciling a paired numeric export."
        )
    )
    parser.add_argument(
        "input_csv", type=Path,
        help=(
            "Qualtrics label export; when --labels-csv is supplied, this is the "
            "paired numeric export"
        ),
    )
    parser.add_argument(
        "--labels-csv", type=Path,
        help="Optional identical Qualtrics export using choice labels",
    )
    parser.add_argument("--config", type=Path, help="Optional JSON analysis configuration")
    parser.add_argument("--output-dir", type=Path, help="Output directory")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    input_path = args.input_csv.expanduser().resolve()
    label_path = args.labels_csv.expanduser().resolve() if args.labels_csv else None
    if not input_path.is_file():
        print(f"ERROR: Input not found: {input_path}", file=sys.stderr)
        return 2
    if label_path is not None and not label_path.is_file():
        print(f"ERROR: Label input not found: {label_path}", file=sys.stderr)
        return 2
    if label_path is not None and input_path == label_path:
        print("ERROR: Numeric and label inputs must be different files.", file=sys.stderr)
        return 2

    try:
        config_path = args.config.expanduser().resolve() if args.config else None
        config = load_config(config_path)
        input_mode = "paired_exports" if label_path is not None else "label_only"
        if input_mode == "paired_exports":
            numeric = read_qualtrics_csv(input_path)
            labels = read_qualtrics_csv(label_path)
            reconciliation, codebook, integrity_values = reconcile_exports(numeric, labels)
            integrity_values["analysis_input_mode"] = input_mode
            integrity_values["cross_export_reconciliation_performed"] = True
            score_source = "numeric_codes"
        else:
            labels = read_qualtrics_csv(input_path)
            numeric = labels
            reconciliation, codebook, integrity_values = audit_label_only_export(labels)
            score_source = "labels"

        explicit_likert = resolve_requested_columns(
            config["likert_columns"], numeric.data.columns, numeric.import_ids, "Likert"
        )
        explicit_non_likert = resolve_requested_columns(
            config["non_likert_columns"], numeric.data.columns, numeric.import_ids,
            "non-Likert",
        )
        conflict = explicit_likert & explicit_non_likert
        if conflict:
            raise ValueError(
                f"Columns cannot be both Likert and non-Likert: {sorted(conflict)}"
            )

        likert_columns, score_maps, audit, codebook = classify_and_build_score_maps(
            numeric, labels, reconciliation, codebook,
            explicit_likert, explicit_non_likert,
            score_source,
        )
        if not likert_columns:
            raise ValueError(
                "No five-point agreement items were identified. Check the label export or config."
            )

        reverse_worded = resolve_requested_columns(
            config["reverse_worded_columns"], numeric.data.columns,
            numeric.import_ids, "reverse-worded",
        )
        if not reverse_worded.issubset(set(likert_columns)):
            bad = sorted(reverse_worded - set(likert_columns))
            raise ValueError(f"Reverse-worded columns are not Likert items: {bad}")

        semantic_scores = score_numeric_data(
            numeric.data, likert_columns, score_maps, numeric.source_rows
        )
        item_summary, distribution, construct_scores = summarize_likert(
            semantic_scores, likert_columns, numeric, reverse_worded
        )
        directional_tests = directional_sign_tests(
            semantic_scores, likert_columns, numeric,
            config["enable_sign_tests"], config["familywise_alpha"],
        )
        non_likert = summarize_non_likert(labels, audit, codebook)
        qc = respondent_qc(semantic_scores, likert_columns)
        construct_summary, reliability_items, scale_scores = analyze_constructs(
            construct_scores,
            config["constructs"],
            numeric.import_ids,
            config["minimum_scale_answered_fraction"],
            config["bootstrap_repetitions"],
            config["random_seed"],
        )

        descending_columns = audit.loc[
            audit.raw_code_direction.str.startswith("descending", na=False),
            "source_column",
        ].tolist()
        integrity_values.update({
            "likert_items_identified": len(likert_columns),
            "non_likert_columns": int((audit.classification == "non_likert").sum()),
            "text_or_identifier_columns": int((audit.classification == "text_or_identifier").sum()),
            "descending_raw_code_items_normalized": len(descending_columns),
            "descending_raw_code_columns": ", ".join(descending_columns),
            "automatic_respondent_exclusions": 0,
        })
        integrity = integrity_table(integrity_values)
        readme = make_readme(
            input_path, label_path, input_mode,
            len(numeric.data), len(likert_columns),
            descending_columns, config,
        )
        manifest = {
            "script_version": SCRIPT_VERSION,
            "analysis_timestamp_utc": datetime.now(timezone.utc).isoformat(),
            "python_version": platform.python_version(),
            "platform": platform.platform(),
            "packages": {
                "pandas": package_version("pandas"),
                "numpy": package_version("numpy"),
                "scipy": package_version("scipy"),
                "openpyxl": package_version("openpyxl"),
            },
            "inputs": {
                "input_mode": input_mode,
                "primary_file": input_path.name,
                "primary_sha256": sha256_file(input_path),
                "label_file": label_path.name if label_path is not None else input_path.name,
                "label_sha256": sha256_file(label_path if label_path is not None else input_path),
            },
            "configuration": config,
        }
        output_dir = (
            args.output_dir.expanduser().resolve()
            if args.output_dir
            else input_path.parent / f"{input_path.stem}_analysis"
        )
        workbook_path = export_results(
            output_dir, numeric, labels, readme, integrity, reconciliation,
            codebook, audit, item_summary, distribution, directional_tests,
            semantic_scores, construct_scores, non_likert, qc,
            construct_summary, reliability_items, scale_scores,
            config, manifest, input_mode,
        )
    except (ValueError, RuntimeError, OSError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    if input_mode == "paired_exports":
        print("Export reconciliation: EXACT LOGICAL MATCH")
    else:
        print("Input mode: LABEL ONLY (semantic scoring from displayed responses)")
    print(
        f"Analyzed {len(numeric.data)} non-empty participant rows, "
        f"{len(likert_columns)} Likert items, and {len(audit) - len(likert_columns)} other columns."
    )
    print(
        (
            f"Normalized {len(descending_columns)} item(s) with descending Qualtrics codes: "
            f"{', '.join(descending_columns) if descending_columns else 'none'}"
            if input_mode == "paired_exports"
            else "Raw Qualtrics code direction: not applicable in label-only mode"
        )
    )
    print(f"Workbook: {workbook_path}")
    print(f"Audit report: {output_dir / 'reconciliation_report.csv'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
