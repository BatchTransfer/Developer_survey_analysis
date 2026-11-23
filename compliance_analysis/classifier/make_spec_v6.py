"""erc_specification_v6.json = v5 with the ERC-173 entry corrected: EIP-173 requires only owner() and transferOwnership(address)
("Every ERC-173 compliant contract must implement the ERC173 interface"); ERC-165 supportsInterface is a SHOULD, so it is removed.
Prints every standard whose distinctive-function set (erc_classifier.load_spec) changes, so side effects are visible.
Usage: python make_spec_v6.py"""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import json, os, sys
H = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, H)
from erc_classifier import load_spec
s = json.load(open(H + '/erc_specification_v5.json'))
s['ERC173']['selectors'] = ['8da5cb5b', 'f2fde38b']
s['ERC173']['functions'] = {'owner()': '8da5cb5b', 'transferOwnership(address)': 'f2fde38b'}
json.dump(s, open(H + '/erc_specification_v6.json', 'w'), indent=1)
a, da = load_spec(H + '/erc_specification_v5.json'); b, db = load_spec(H + '/erc_specification_v6.json')
print('mandatory-set changes:', [e for e in a if a[e] != b[e]])
print('distinctive-set changes:', [(e, sorted(da[e]), sorted(db[e])) for e in a if da[e] != db[e]])
