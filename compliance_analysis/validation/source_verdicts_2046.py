"""Source-code verdicts for the 53 seed-2046 contracts with verified source, from source_check_2046.py plus manual reading of the cases
it could not settle (#77 header not parsed, #91 function in a comment, #29 parameter type). A verdict agrees with the TP label when no
reported-missing function is exposed by the deployed contract or its parents (definitions only in interfaces, internal functions,
different signatures, renamed functions, or commented-out code do not expose it). Reviewed by Claude, not yet by a second researcher.
Usage: python source_verdicts_2046.py -> sources_seed2046/source_verdicts.csv and a summary."""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import csv, os
from collections import Counter
S = os.path.dirname(os.path.abspath(__file__)) + '/sources_seed2046'
WHY = {11: 'renamed: Approve(address,uint256) instead of approve', 21: 'only in interface IERC20 (used for outgoing calls)',
       23: 'ERC-1820 registry, no supportsInterface (literal rule)', 24: 'different signatures: safeTransfer/safeTransferFrom without bytes; no supportsInterface',
       29: 'different signature: safeTransferFrom(address,address,uint16); no supportsInterface', 31: 'different signatures: deposit/redeem with extra minOut parameter; no mint/withdraw',
       33: 'only in interface IERC20', 46: 'transferFrom declared internal', 51: 'DOMAIN_SEPARATOR only in interface IUniswapV2Pair',
       57: 'different signature: permit(address,uint256,uint256,uint8,bytes32,bytes32) (v,r,s instead of bytes)',
       64: 'nonce getter has another name (Aave AToken)', 72: 'nonce getter has another name (Aave AToken)',
       77: 'ERC-721 contract (cryptogifts is ERC721Full, ERC721Mintable, Ownable), no allowance anywhere', 91: 'balanceOf is commented out ("Disabled due to tokenEnumeration not enabled")'}
lab = {r['i']: r['label'] for r in csv.DictReader(open(S + '/../new_classifier_70_no_overlap/labels_100_seed2046.csv'))}
chk = {}
for r in csv.DictReader(open(S + '/source_check.csv')):
    chk.setdefault(r['i'], []).append(r)
rows = []
for i, rs in chk.items():
    exposed = [r['missing_function'] for r in rs if r['defined_in_contract'] and int(i) not in WHY]
    v = 'FP (function exposed in source)' if exposed else 'TP (confirmed by source)'
    rows.append([i, rs[0]['chain'], rs[0]['address'], rs[0]['contract'], rs[0]['flagged'], '; '.join(r['missing_function'] for r in rs), lab[i], v,
                 WHY.get(int(i), 'reported-missing function not defined in the contract or its parents')])
with open(S + '/source_verdicts.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['i', 'chain', 'address', 'contract', 'flagged', 'missing', 'bytecode_label', 'source_verdict', 'why']); w.writerows(rows)
print(len(rows), 'contracts with source;', Counter(r[7] for r in rows), '; agree with bytecode label:', sum(r[6] == r[7][:2] for r in rows))
