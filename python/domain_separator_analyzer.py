#!/usr/bin/env python3
"""
Domain Separator Construction Analyzer

Analyze Solidity .sol files for EIP-712 DOMAIN_SEPARATOR construction risks.

Requirement-level checks:
  R1  Missing chainId in EIP712Domain typehash
  R2  Missing verifyingContract in EIP712Domain typehash
  R3  Hardcoded / constant chainId
  R4  Missing or incorrect verifyingContract binding
  R5  Stale cached DOMAIN_SEPARATOR in constructor / initializer
  R6  Proxy / upgradeable stale-domain risk
  R7  Missing salt or equivalent uniqueness field in multi-domain contexts
  R8  Hardcoded / zero / duplicated salt patterns
  R9  Direct use of cached DOMAIN_SEPARATOR inside permit()

Taxonomy:
  T1  Unseparated Signing Domain
  T2  Cross-Chain Replay Risk
  T3  Cross-Contract Replay Risk
  T4  Cross-Project / Logical-Domain Replay Risk
  T5  Proxy / Upgradeable Domain Drift

Example:
  python3 domain_separator_analyzer.py \
    --input-dir /path/to/sol/files \
    --output-json results/domain_separator_results.json \
    --output-summary results/domain_separator_summary.json \
    --max-files 200
"""

import argparse
import json
import re
from pathlib import Path
from typing import Any, Dict, List, Optional


DOMAIN_SEPARATOR_REQUIREMENTS = {
    "R1_CHAIN_ID_PRESENT": {
        "description": "EIP712Domain typehash should include uint256 chainId when signatures must be chain-bound.",
        "risk_if_missing": "Cross-chain replay risk.",
        "severity": "High/Medium",
    },
    "R2_VERIFYING_CONTRACT_PRESENT": {
        "description": "EIP712Domain typehash should include address verifyingContract.",
        "risk_if_missing": "Cross-contract replay risk.",
        "severity": "High",
    },
    "R3_DYNAMIC_CHAIN_ID": {
        "description": "DOMAIN_SEPARATOR should use block.chainid or chainid(), not a stale/hardcoded chain ID.",
        "risk_if_missing": "Fork/cross-chain replay or stale-domain risk.",
        "severity": "Medium",
    },
    "R4_CORRECT_VERIFYING_CONTRACT": {
        "description": "DOMAIN_SEPARATOR should bind to address(this) unless a deliberate external verifier is used.",
        "risk_if_missing": "Wrong verifier binding or cross-contract replay risk.",
        "severity": "High",
    },
    "R5_NO_STALE_CACHED_DOMAIN": {
        "description": "If DOMAIN_SEPARATOR is cached in constructor/initializer, it should be recomputed or invalidated when block.chainid changes.",
        "risk_if_missing": "Stale domain separator after chain split/fork.",
        "severity": "Medium",
    },
    "R6_PROXY_SAFE_DOMAIN": {
        "description": "Upgradeable/proxy contracts should avoid stale cached domains and bind signatures to the proxy/verifier actually used.",
        "risk_if_missing": "Cross-version/proxy-context replay risk.",
        "severity": "Medium/High",
    },
    "R7_LOGICAL_DOMAIN_DISAMBIGUATION": {
        "description": "If one verifier handles multiple logical domains, domain or signed struct should include salt/poolId/marketId/vaultId/accountId or equivalent.",
        "risk_if_missing": "Cross-pool/cross-subdomain replay risk.",
        "severity": "High/Medium",
    },
    "R8_SALT_CORRECTNESS": {
        "description": "If salt is used, it should be meaningful and unique per logical signing domain; zero/constant salt should be justified.",
        "risk_if_missing": "False sense of domain uniqueness or duplicated logical domains.",
        "severity": "Medium",
    },
    "R9_PERMIT_USES_SAFE_DOMAIN": {
        "description": "permit() should use a current/recomputed domain separator or a safe cached separator with chainId invalidation.",
        "risk_if_missing": "Replay-enabled permit authorization risk.",
        "severity": "High/Medium",
    },
}


DOMAIN_SEPARATOR_TAXONOMY = {
    "T1_UNSEPARATED_SIGNING_DOMAIN": {
        "name": "Unseparated Signing Domain",
        "description": "The signing domain is under-specified because one or more domain separators are missing.",
        "subcategories": [
            "missing_domain_separator",
        ],
        "attack_boundary": "generic domain confusion",
    },
    "T2_CROSS_CHAIN_REPLAY": {
        "name": "Cross-Chain Replay Risk",
        "description": "A signature may be replayable across chains or forks.",
        "subcategories": [
            "missing_chainId",
            "hardcoded_chainId"
        ],
        "attack_boundary": "chain/fork boundary",
    },
    "T3_CROSS_CONTRACT_REPLAY": {
        "name": "Cross-Contract Replay Risk",
        "description": "A signature may be replayable across different verifier contracts.",
        "subcategories": [
            "missing_verifyingContract",
            "incorrect_verifyingContract",
            "hardcoded_verifier",
        ],
        "attack_boundary": "contract/verifier boundary",
    },
    "T4_LOGICAL_DOMAIN_REPLAY": {
        "name": "Cross-Project / Logical-Domain Replay Risk",
        "description": "A signature may be replayable across pools, vaults, markets, routers, modules, or other logical domains.",
        "subcategories": [
            "missing_logical_domain_disambiguator",
            "hardcoded_salt",
            "zero_salt_used",
        ],
        "attack_boundary": "application/logical-domain boundary",
    },
    "T5_DOMAIN_FRESHNESS_FAILURE": {
        "name": "Proxy / Upgradeable Domain Drift",
        "description": "The domain separator may become stale or bind to the wrong proxy/implementation context.",
        "subcategories": [
            "proxy_stale_domain",
            "stale_cached_DOMAIN_SEPARATOR"
        ],
        "attack_boundary": "proxy/upgrade/version boundary",
    },
}


def strip_comments(code: str) -> str:
    code = re.sub(r"/\*.*?\*/", "", code, flags=re.DOTALL)
    code = re.sub(r"//.*", "", code)
    return code


def extract_balanced_block(code: str, start_index: int) -> str:
    brace_start = code.find("{", start_index)
    if brace_start == -1:
        return ""

    depth = 0
    for i in range(brace_start, len(code)):
        if code[i] == "{":
            depth += 1
        elif code[i] == "}":
            depth -= 1
            if depth == 0:
                return code[start_index:i + 1]

    return code[start_index:]


def extract_function_bodies(code: str) -> Dict[str, List[str]]:
    functions: Dict[str, List[str]] = {}
    pattern = re.compile(
        r"\bfunction\s+([A-Za-z_][A-Za-z0-9_]*)\s*\([^)]*\)[^{;]*\{",
        re.DOTALL,
    )

    for m in pattern.finditer(code):
        name = m.group(1)
        body = extract_balanced_block(code, m.start())
        if body:
            functions.setdefault(name, []).append(body)

    return functions


def extract_constructor_and_initializer_bodies(code: str) -> List[str]:
    bodies: List[str] = []
    patterns = [
        r"\bconstructor\s*\([^)]*\)[^{;]*\{",
        r"\bfunction\s+initialize\s*\([^)]*\)[^{;]*\{",
        r"\bfunction\s+init\s*\([^)]*\)[^{;]*\{",
        r"\bfunction\s+__[^\(\s]*init[^\(\s]*\s*\([^)]*\)[^{;]*\{",
    ]

    for pat in patterns:
        for m in re.finditer(pat, code, flags=re.DOTALL | re.IGNORECASE):
            body = extract_balanced_block(code, m.start())
            if body:
                bodies.append(body)

    return bodies


def find_domain_typehashes(code: str) -> List[str]:
    return re.findall(
        r"EIP712Domain\s*\(([^)]*)\)",
        code,
        flags=re.IGNORECASE | re.DOTALL,
    )


def has_dynamic_chainid(expr: str) -> bool:
    return bool(
        re.search(r"\bblock\.chainid\b", expr)
        or re.search(r"\bchainid\s*(?:\(\s*\))?\b", expr)
    )


def has_address_this(expr: str) -> bool:
    return bool(
        re.search(r"\baddress\s*\(\s*this\s*\)", expr, re.IGNORECASE)
        or re.search(r"\baddress\s*\(\s*\)", expr)
    )


def has_hardcoded_chainid(expr: str) -> bool:
    common_chain_ids = [
        1, 3, 4, 5, 10, 56, 97, 100, 137, 250, 324, 1101,
        8453, 42161, 42170, 43114, 11155111,
    ]

    for cid in common_chain_ids:
        if re.search(rf"(?<![A-Za-z0-9_]){cid}(?![A-Za-z0-9_])", expr):
            return True

    if re.search(r"\b(CHAIN_ID|chainID|chainId|_CHAIN_ID|INITIAL_CHAIN_ID|CACHED_CHAIN_ID)\b", expr):
        if not has_dynamic_chainid(expr):
            return True

    return False


def detect_domain_separator_function(code: str) -> bool:
    funcs = extract_function_bodies(code)

    for name, bodies in funcs.items():
        relevant = (
            name == "DOMAIN_SEPARATOR"
            or "domainSeparator" in name
            or "_domainSeparator" in name
            or name == "_domainSeparatorV4"
            or name == "_buildDomainSeparator"
            or name == "computeDomainSeparator"
        )

        if not relevant:
            continue

        for body in bodies:
            if has_dynamic_chainid(body) and (
                "computeDomainSeparator" in body
                or "_buildDomainSeparator" in body
                or "keccak256" in body
                or "_domainSeparatorV4" in body
                or "INITIAL_DOMAIN_SEPARATOR" in body
                or "_CACHED_DOMAIN_SEPARATOR" in body
                or "_cachedDomainSeparator" in body
            ):
                return True

            if re.search(r"block\.chainid\s*==|==\s*block\.chainid", body):
                return True

            if re.search(r"chainid\s*\(\s*\)", body) and "keccak256" in body:
                return True

    return False


def detect_permit_uses_domain_separator_directly(code: str) -> bool:
    funcs = extract_function_bodies(code)

    for body in funcs.get("permit", []):
        direct_var = re.search(r"\bDOMAIN_SEPARATOR\b(?!\s*\()", body)
        safe_call = re.search(
            r"\bDOMAIN_SEPARATOR\s*\(\s*\)|_domainSeparatorV4\s*\(\s*\)|_domainSeparator\s*\(\s*\)|domainSeparator\s*\(\s*\)",
            body,
        )

        if direct_var and not safe_call:
            return True

    return False


def detect_proxy_or_upgradeable(code: str) -> bool:
    return bool(
        re.search(
            r"\binitializer\b|Initializable|Upgradeable|UUPS|TransparentUpgradeableProxy|ERC1967|delegatecall|proxy",
            code,
            re.IGNORECASE,
        )
    )


def detect_multi_domain_context(code: str) -> bool:
    return bool(
        re.search(
            r"\bpoolId\b|\bpool\b|\bmarketId\b|\bmarket\b|\bvaultId\b|\bvault\b|"
            r"\bsubdomain\b|\baccountId\b|\bwallet\b|\brouter\b|\bfactory\b|\bclone\b|"
            r"\bcollectionId\b|\btokenId\b|\bstrategy\b|\bmodule\b",
            code,
            re.IGNORECASE,
        )
    )


def detect_salt_usage(code: str) -> Dict[str, Any]:
    salt_mentions = re.findall(
        r"\bsalt\b|_salt|DOMAIN_SALT|domainSalt",
        code,
        flags=re.IGNORECASE,
    )

    salt_in_typehash = bool(
        re.search(
            r"EIP712Domain\s*\([^)]*bytes32\s+salt[^)]*\)",
            code,
            flags=re.IGNORECASE | re.DOTALL,
        )
    )

    zero_salt = bool(
        re.search(
            r"bytes32\s*\(\s*0\s*\)|bytes32\s*\(\s*uint256\s*\(\s*0\s*\)\s*\)|0x0{8,}|DOMAIN_SALT\s*=\s*bytes32\s*\(\s*0\s*\)",
            code,
            flags=re.IGNORECASE,
        )
    )

    hardcoded_salt = bool(
        re.search(
            r"DOMAIN_SALT\s*=\s*0x[0-9a-fA-F]{64}|_salt\s*=\s*0x[0-9a-fA-F]{64}|salt\s*=\s*0x[0-9a-fA-F]{64}",
            code,
            flags=re.IGNORECASE,
        )
    )

    salt_from_hash = bool(
        re.search(
            r"salt\s*=\s*keccak256|DOMAIN_SALT\s*=\s*keccak256|_salt\s*=\s*keccak256",
            code,
            flags=re.IGNORECASE,
        )
    )

    return {
        "mentions_salt": len(salt_mentions) > 0,
        "salt_in_typehash": salt_in_typehash,
        "zero_salt": zero_salt,
        "hardcoded_salt": hardcoded_salt,
        "salt_from_hash": salt_from_hash,
    }


def extract_domain_construction_contexts(code: str) -> str:
    chunks = []

    for body in extract_constructor_and_initializer_bodies(code):
        if "DOMAIN_SEPARATOR" in body and "keccak256" in body:
            chunks.append(body)

    funcs = extract_function_bodies(code)
    for name, bodies in funcs.items():
        if (
            name == "DOMAIN_SEPARATOR"
            or "domainSeparator" in name
            or "_domainSeparator" in name
            or name == "_domainSeparatorV4"
            or name == "_buildDomainSeparator"
            or name == "computeDomainSeparator"
        ):
            chunks.extend(bodies)

    return "\n".join(chunks)


def classify_taxonomy(result: Dict[str, Any]) -> Dict[str, Any]:
    categories = set(result.get("risk_category", []))
    has_permit = result.get("has_permit", False)
    has_domain = result.get("has_domain_separator", False) or result.get("has_eip712_domain_typehash", False)
    proxy_context = result.get("proxy_or_upgradeable_context", False)
    multi_domain = result.get("multi_domain_context", False)

    taxonomy_findings = []

    def add_taxonomy(
        tid: str,
        matched_categories: List[str],
        severity: str,
        confidence: str,
        reason: str,
    ) -> None:
        spec = DOMAIN_SEPARATOR_TAXONOMY[tid]
        taxonomy_findings.append({
            "taxonomy_id": tid,
            "taxonomy_name": spec["name"],
            "attack_boundary": spec["attack_boundary"],
            "matched_categories": sorted(matched_categories),
            "severity": severity,
            "confidence": confidence,
            "reason": reason,
        })

    t1_cats = categories.intersection({
        "missing_domain_separator",
        "missing_eip191_prefix",
    })

    if t1_cats:
        add_taxonomy(
            "T1_UNSEPARATED_SIGNING_DOMAIN",
            list(t1_cats),
            "High" if has_permit else "Medium",
            "High" if has_domain else "Medium",
            "The EIP-712 signing domain is missing one or more core domain-separation fields.",
        )

    t2_cats = categories.intersection({
        "missing_chainId",
        "hardcoded_chainId",
    })

    if t2_cats:
        add_taxonomy(
            "T2_CROSS_CHAIN_REPLAY",
            list(t2_cats),
            "High" if has_permit and (
                "missing_chainId" in t2_cats
                or "stale_cached_DOMAIN_SEPARATOR" in t2_cats
            ) else "Medium",
            "High",
            "The domain separator may not bind signatures to the current chain or fork.",
        )

    t3_cats = categories.intersection({
        "missing_verifyingContract",
        "incorrect_verifyingContract",
        "hardcoded_verifier",
    })

    if t3_cats:
        add_taxonomy(
            "T3_CROSS_CONTRACT_REPLAY",
            list(t3_cats),
            "High",
            "High" if (
                "missing_verifyingContract" in t3_cats
                or "incorrect_verifyingContract" in t3_cats
            ) else "Medium",
            "The domain separator may not bind signatures to the verifying contract address.",
        )

    t4_cats = categories.intersection({
        "missing_logical_domain_disambiguator",
        "hardcoded_salt",
        "zero_salt_used",
    })

    if t4_cats:
        add_taxonomy(
            "T4_LOGICAL_DOMAIN_REPLAY",
            list(t4_cats),
            "High" if multi_domain and "missing_logical_domain_disambiguator" in t4_cats else "Medium",
            "Medium",
            "The same verifier appears to serve multiple logical domains without a strong domain discriminator.",
        )

    t5_cats = categories.intersection({
        "proxy_stale_domain",
        "stale_cached_DOMAIN_SEPARATOR",
    })

    if t5_cats and proxy_context:
        add_taxonomy(
            "T5_DOMAIN_FRESHNESS_FAILURE",
            list(t5_cats),
            "High" if "proxy_stale_domain" in t5_cats else "Medium",
            "Medium",
            "The contract appears upgradeable/proxy-based and may cache or bind the domain separator in a stale context.",
        )

    if taxonomy_findings:
        max_sev = "High" if any(t["severity"] == "High" for t in taxonomy_findings) else "Medium"
    else:
        max_sev = result.get("risk_level", "Info")

    return {
        "taxonomy": taxonomy_findings,
        "taxonomy_risk_level": max_sev,
        "taxonomy_ids": [t["taxonomy_id"] for t in taxonomy_findings],
        "taxonomy_names": [t["taxonomy_name"] for t in taxonomy_findings],
    }


def analyze_domain_separator_construction(solidity_code: str) -> Dict[str, Any]:
    code = strip_comments(solidity_code)

    result: Dict[str, Any] = {
        "requirements": DOMAIN_SEPARATOR_REQUIREMENTS,
        "has_domain_separator": False,
        "has_permit": False,
        "has_eip712_domain_typehash": False,
        "domain_typehashes": [],
        "uses_chainId_in_typehash": False,
        "uses_verifyingContract_in_typehash": False,
        "uses_salt_in_typehash": False,
        "uses_dynamic_chainid": False,
        "uses_address_this": False,
        "hardcoded_chainid": False,
        "hardcoded_verifier": False,
        "domain_separator_assigned_in_constructor_or_initializer": False,
        "domain_separator_recomputed_or_chainid_checked": False,
        "permit_uses_domain_separator_directly": False,
        "proxy_or_upgradeable_context": False,
        "multi_domain_context": False,
        "salt": {},
        "risk_level": "Info",
        "risk_category": [],
        "findings": [],
        "warnings": [],
        "critical_issues": [],
    }

    result["has_domain_separator"] = bool(
        re.search(r"\bDOMAIN_SEPARATOR\b|domainSeparator|_domainSeparatorV4|_domainSeparator", code)
    )

    result["has_permit"] = bool(
        re.search(r"\bfunction\s+permit\s*\(", code)
    )
    
    OZ_EIP712_TYPEHASH = "0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f"

    result["has_oz_eip712_typehash"] = OZ_EIP712_TYPEHASH in code.lower()
    result["has_eip191_prefix"] = bool(
        re.search(r'\\x19\\x01|"\x19\x01"|toTypedDataHash\s*\(', code)
    )

    domain_typehashes = find_domain_typehashes(code)
    result["domain_typehashes"] = domain_typehashes
    result["has_eip712_domain_typehash"] = bool(domain_typehashes)

    joined_typehash = " ".join(domain_typehashes)

    result["uses_chainId_in_typehash"] = bool(
        re.search(r"uint256\s+chainId", joined_typehash, re.IGNORECASE)
    )

    result["uses_verifyingContract_in_typehash"] = bool(
        re.search(r"address\s+verifyingContract", joined_typehash, re.IGNORECASE)
    )

    result["uses_salt_in_typehash"] = bool(
        re.search(r"bytes32\s+salt", joined_typehash, re.IGNORECASE)
    )

    domain_ctx = extract_domain_construction_contexts(code)
    
    has_safe_domain_construction = (
    "block.chainid" in domain_ctx
    and re.search(r"address\s*\(\s*this\s*\)", domain_ctx)
    )

    if has_safe_domain_construction:
        result["uses_chainId_in_typehash"] = True
        result["uses_verifyingContract_in_typehash"] = True
        result["uses_dynamic_chainid"] = True
        result["uses_address_this"] = True

    result["uses_dynamic_chainid"] = has_dynamic_chainid(domain_ctx)
    result["uses_address_this"] = has_address_this(domain_ctx)

    result["hardcoded_chainid"] = (
        bool(domain_ctx)
        and has_hardcoded_chainid(domain_ctx)
        and not result["uses_dynamic_chainid"]
    )

    result["hardcoded_verifier"] = (
        bool(domain_ctx)
        and bool(re.search(r"0x[a-fA-F0-9]{40}", domain_ctx))
        and not result["uses_address_this"]
    )

    result["domain_separator_recomputed_or_chainid_checked"] = detect_domain_separator_function(code)
    result["permit_uses_domain_separator_directly"] = detect_permit_uses_domain_separator_directly(code)

    for body in extract_constructor_and_initializer_bodies(code):
        if "DOMAIN_SEPARATOR" in body and "keccak256" in body:
            result["domain_separator_assigned_in_constructor_or_initializer"] = True

    result["proxy_or_upgradeable_context"] = detect_proxy_or_upgradeable(code)
    result["multi_domain_context"] = detect_multi_domain_context(code)
    result["salt"] = detect_salt_usage(code)
    
    if result["has_oz_eip712_typehash"]:
            result["has_eip712_domain_typehash"] = True
            result["uses_chainId_in_typehash"] = True
            result["uses_verifyingContract_in_typehash"] = True

    if result["has_permit"] and not result["has_eip191_prefix"]:
            result["critical_issues"].append("T1: Missing EIP-191 typed-data prefix.")
            result["risk_category"].append("missing_eip191_prefix")
            
    if not result["has_domain_separator"] and not result["has_eip712_domain_typehash"]:
        if result["has_permit"]:
            result["critical_issues"].append(
                "T1: Missing DOMAIN_SEPARATOR/EIP712Domain in permit-enabled contract."
            )
            result["risk_category"].append("missing_domain_separator")
            result["risk_level"] = "High"
        else:
            result["warnings"].append("No obvious DOMAIN_SEPARATOR or EIP712Domain typehash found.")
            result["risk_level"] = "Info"
            return result

    if result["has_domain_separator"] and not domain_ctx:
        result["warnings"].append(
            "DOMAIN_SEPARATOR declaration found, but no implementation/construction body found; likely interface-only or abstract declaration."
        )
        result["risk_level"] = "Info"
        return result

    if result["has_eip712_domain_typehash"] and not result["uses_chainId_in_typehash"]:
        result["critical_issues"].append(
            "R1: Missing chainId in EIP712Domain typehash; possible cross-chain replay risk."
        )
        result["risk_category"].append("missing_chainId")

    if result["has_eip712_domain_typehash"] and not result["uses_verifyingContract_in_typehash"]:
        result["critical_issues"].append(
            "R2: Missing verifyingContract in EIP712Domain typehash; possible cross-contract replay risk."
        )
        result["risk_category"].append("missing_verifyingContract")

    if result["hardcoded_chainid"] and not result["uses_dynamic_chainid"]:
        result["critical_issues"].append(
            "R3: Hardcoded or constant chainId detected instead of block.chainid/chainid()."
        )
        result["risk_category"].append("hardcoded_chainId")

    elif result["hardcoded_chainid"] and result["uses_dynamic_chainid"]:
        result["warnings"].append(
            "R3: ChainId-related constant detected; verify it is not used in DOMAIN_SEPARATOR."
        )

    if result["uses_verifyingContract_in_typehash"] and not result["uses_address_this"]:
        result["critical_issues"].append(
            "R4: verifyingContract is in typehash but address(this) is not visible; possible incorrect verifier binding."
        )
        result["risk_category"].append("incorrect_verifyingContract")

    if result["hardcoded_verifier"]:
        result["critical_issues"].append(
            "R4: Hardcoded address detected with no address(this); possible hardcoded verifier."
        )
        result["risk_category"].append("hardcoded_verifier")

    if (
        result["domain_separator_assigned_in_constructor_or_initializer"]
        and result["permit_uses_domain_separator_directly"]
        and not result["domain_separator_recomputed_or_chainid_checked"]
    ):
        result["critical_issues"].append(
            "R5/R9: Stale cached DOMAIN_SEPARATOR: assigned in constructor/initializer and used directly in permit() without chainId recomputation."
        )
        result["risk_category"].append("stale_cached_DOMAIN_SEPARATOR")

    if (
        result["proxy_or_upgradeable_context"]
        and result["domain_separator_assigned_in_constructor_or_initializer"]
        and not result["domain_separator_recomputed_or_chainid_checked"]
    ):
        result["critical_issues"].append(
            "R6: Upgradeable/proxy context with cached DOMAIN_SEPARATOR and no visible recomputation."
        )
        result["risk_category"].append("proxy_stale_domain")

    if result["multi_domain_context"]:
        has_equivalent_id = bool(
            re.search(
                r"\bpoolId\b|\bmarketId\b|\bvaultId\b|\baccountId\b|\bchainId\b|\btokenId\b|\bcollectionId\b|\bmodule\b",
                code,
                re.IGNORECASE,
            )
        )

        if not result["uses_salt_in_typehash"] and not has_equivalent_id:
            result["warnings"].append(
                "R7: Multi-domain context detected but no salt or obvious domain-specific identifier found."
            )
            result["risk_category"].append("missing_logical_domain_disambiguator")

    if result["salt"].get("hardcoded_salt"):
        result["warnings"].append(
            "R8: Hardcoded salt detected; verify uniqueness per logical signing domain."
        )
        result["risk_category"].append("hardcoded_salt")

    if result["salt"].get("zero_salt") and result["uses_salt_in_typehash"]:
        result["warnings"].append(
            "R8: Salt appears present in EIP712Domain but may be zero."
        )
        result["risk_category"].append("zero_salt_used")

    if result["critical_issues"]:
        result["risk_level"] = "High"
    elif result["warnings"]:
        result["risk_level"] = "Medium"
    elif result["has_domain_separator"] or result["has_eip712_domain_typehash"]:
        result["risk_level"] = "Low"
    else:
        result["risk_level"] = "Info"

    result["risk_category"] = sorted(set(result["risk_category"]))

    taxonomy_result = classify_taxonomy(result)
    result.update(taxonomy_result)

    if result.get("taxonomy_risk_level") == "High":
        result["risk_level"] = "High"
    elif result.get("taxonomy_risk_level") == "Medium" and result["risk_level"] != "High":
        result["risk_level"] = "Medium"

    return result


def analyze_file(file_path: Path) -> Dict[str, Any]:
    try:
        solidity_code = file_path.read_text(encoding="utf-8", errors="ignore")
        result = analyze_domain_separator_construction(solidity_code)
        result["file"] = str(file_path)
        result["status"] = "ok"
        return result

    except Exception as e:
        return {
            "file": str(file_path),
            "status": "error",
            "error": str(e),
            "risk_level": "Error",
            "risk_category": ["analysis_error"],
        }


def summarize_results(results: List[Dict[str, Any]]) -> Dict[str, Any]:
    summary: Dict[str, Any] = {
        "total_files": len(results),
        "risk_level_counts": {},
        "risk_category_counts": {},
        "requirement_issue_counts": {},
        "taxonomy_counts": {},
        "taxonomy_severity_counts": {},
        "high_risk_files": [],
        "medium_risk_files": [],
    }

    for r in results:
        risk = r.get("risk_level", "Unknown")
        summary["risk_level_counts"][risk] = summary["risk_level_counts"].get(risk, 0) + 1

        for cat in r.get("risk_category", []):
            summary["risk_category_counts"][cat] = summary["risk_category_counts"].get(cat, 0) + 1

        for issue in r.get("critical_issues", []):
            key = issue.split(":")[0] if ":" in issue else issue[:40]
            summary["requirement_issue_counts"][key] = summary["requirement_issue_counts"].get(key, 0) + 1

        for warn in r.get("warnings", []):
            key = warn.split(":")[0] if ":" in warn else warn[:40]
            summary["requirement_issue_counts"][key] = summary["requirement_issue_counts"].get(key, 0) + 1

        for t in r.get("taxonomy", []):
            tid = t.get("taxonomy_id", "UNKNOWN")
            sev = t.get("severity", "Unknown")
            summary["taxonomy_counts"][tid] = summary["taxonomy_counts"].get(tid, 0) + 1
            summary["taxonomy_severity_counts"][sev] = summary["taxonomy_severity_counts"].get(sev, 0) + 1

        if risk == "High":
            summary["high_risk_files"].append(r.get("file"))
        elif risk == "Medium":
            summary["medium_risk_files"].append(r.get("file"))

    return summary


def collect_solidity_files(input_dir: Path, max_files: Optional[int] = None) -> List[Path]:
    files = sorted(input_dir.rglob("*.sol"))
    return files[:max_files] if max_files is not None else files


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Analyze Solidity files for EIP-712 DOMAIN_SEPARATOR construction risks."
    )

    parser.add_argument(
        "--input-dir",
        required=True,
        help="Directory containing .sol files.",
    )

    parser.add_argument(
        "--output-json",
        required=True,
        help="Output JSON path for per-file results.",
    )

    parser.add_argument(
        "--output-summary",
        required=True,
        help="Output JSON path for summary results.",
    )

    parser.add_argument(
        "--max-files",
        type=int,
        default=None,
        help="Maximum number of .sol files to analyze.",
    )

    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    output_json = Path(args.output_json)
    output_summary = Path(args.output_summary)

    if not input_dir.exists():
        raise FileNotFoundError(f"Input directory does not exist: {input_dir}")

    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_summary.parent.mkdir(parents=True, exist_ok=True)

    files = collect_solidity_files(input_dir, args.max_files)

    print(f"Input directory: {input_dir}")
    print(f"Solidity files found: {len(files)}")
    print(f"Output JSON: {output_json}")
    print(f"Output summary: {output_summary}")

    results: List[Dict[str, Any]] = []

    for i, file_path in enumerate(files, 1):
        print(f"[{i}/{len(files)}] Analyzing {file_path}")
        result = analyze_file(file_path)
        results.append(result)

        if i % 25 == 0 or i == len(files):
            output_json.write_text(json.dumps(results, indent=2), encoding="utf-8")

    summary = summarize_results(results)
    output_summary.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print("\nAnalysis complete.")
    print("Risk levels:")
    print(json.dumps(summary.get("risk_level_counts", {}), indent=2))
    print("Taxonomy counts:")
    print(json.dumps(summary.get("taxonomy_counts", {}), indent=2))
    print(f"Saved per-file results: {output_json}")
    print(f"Saved summary: {output_summary}")


if __name__ == "__main__":
    main()