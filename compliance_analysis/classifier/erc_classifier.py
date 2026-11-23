"""Fixed ERC compliance classifier.

Changes from ERCclassification_V1.py:
1. Exposed functions: identifiers are read from the function dispatcher
   (PUSH1-PUSH4 operand followed by EQ), not by text search over the bytecode.
   This drops identifiers a contract only uses to call other contracts, and it
   recovers identifiers the compiler stored in shorter form (e.g. 00fdd58e).
2. Extension rule: a contract is a candidate for a standard only if it exposes
   at least one function distinctive to that standard (an identifier no other
   analyzed standard lists; if the standard has none, one outside the
   ERC-20/721/1155/165/173 base interfaces).
3. Anchor functions (v3): where a standard's distinctive identifiers are generic,
   an explicit anchor is used instead (ERC-2612: permit only, since nonces is
   used by many other signature schemes). ERC-7160 (v4): tokenURIs(uint256),
   which only that standard defines.
4. ERC-721 overlap (v3): a contract exposing the complete ERC-721 interface is
   not checked against ERC-20 or ERC-20 extensions (standards that include the
   ERC-20 interface but not ownerOf).
5. Distinctive share (v4): at least half of a standard's distinctive functions
   must be exposed, so one coincidental function name does not make a candidate.
6. Threshold unchanged: more than 70% of mandatory functions makes a candidate,
   100% is compliant, otherwise flagged.
7. Output labels: status() turns the classify() result into one label per
   contract: "Flagged violation" (at least one candidate standard is missing a
   mandatory function), "Flagged no violation" (every candidate standard is
   complete), or "Not flagged" (no candidate standard).
"""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import json, sys
from collections import Counter

def dispatcher_selectors(code):
    b = bytes.fromhex(code[2:] if code.startswith("0x") else code)
    s, i, a1, a2, a3 = set(), 0, None, None, None
    while i < len(b):
        op, arg = b[i], None
        if op == 0x14:
            s.update(a for a in (a1, a2, a3) if a)
        if 0x60 <= op <= 0x7F:
            n = op - 0x5F
            if op <= 0x63:
                x = b[i + 1:i + 1 + n]
                arg = x.rjust(4, b"\0").hex() if x else None
            i += 1 + n
        else:
            i += 1
        a3, a2, a1 = a2, a1, arg
    return s

ANCHOR = {"ERC2612": {"d505accf"}, "ERC7160": {"6c8b703f"}}

def load_spec(path):
    c = json.load(open(path))
    spec = {e: [x.lower() for x in v["selectors"]] for e, v in c.items() if v.get("selectors")}
    use = Counter(x for v in spec.values() for x in set(v))
    base = {x for e in ("ERC20", "ERC721", "ERC1155", "ERC165", "ERC173") for x in spec.get(e, [])}
    dist = {}
    for e, v in spec.items():
        u = {x for x in v if use[x] == 1}
        dist[e] = u or {x for x in v if x not in base}
    for e, a in ANCHOR.items():
        if e in dist:
            dist[e] = set(a)
    return spec, dist

def classify(code, spec, dist, threshold=70, overlap=True):
    """overlap=False turns off rule 4 (ERC-721 overlap), so complete ERC-721 contracts are also checked against ERC-20."""
    exposed = dispatcher_selectors(code.lower())
    flagged, compliant = {}, []
    full721 = "ERC721" in spec and all(x in exposed for x in spec["ERC721"])
    erc20 = set(spec.get("ERC20", []))
    for e, sels in spec.items():
        if overlap and full721 and erc20 and erc20 <= set(sels) and "6352211e" not in sels:
            continue
        if dist[e] and 2 * len(dist[e] & exposed) < len(dist[e]):
            continue
        k = sum(x in exposed for x in sels)
        p = 100 * k / len(sels)
        if p == 100:
            compliant.append(e)
        elif p > threshold:
            flagged[e] = [x for x in sels if x not in exposed]
    return flagged, compliant

FLAGGED_VIOLATION = "Flagged violation"
FLAGGED_NO_VIOLATION = "Flagged no violation"
NOT_FLAGGED = "Not flagged"

def status(flagged, compliant):
    """One label per contract from the classify() result."""
    if flagged:
        return FLAGGED_VIOLATION
    if compliant:
        return FLAGGED_NO_VIOLATION
    return NOT_FLAGGED

def label(code, spec, dist, threshold=70):
    """classify() plus its status label: (status, flagged, compliant)."""
    flagged, compliant = classify(code, spec, dist, threshold)
    return status(flagged, compliant), flagged, compliant
