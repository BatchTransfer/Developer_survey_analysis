"""Count dispatcher forms the new classifier's reader (erc_classifier.dispatcher_selectors: PUSH1-4 value within the 3 opcodes
before an EQ) can miss, over all 3.8M contracts.
Per contract:
  E   = selectors found by the classifier's reader (PUSH1-4 then EQ)
  S   = PUSH1-4 values followed within 2 opcodes by SUB, then within 2 opcodes by JUMPI   (SUB form)
  X   = PUSH1-4 values followed within 2 opcodes by XOR, then within 2 opcodes by JUMPI   (XOR form)
  vyper = CBOR metadata with the "vyper" key (a1 65 'vyper'), the marker Vyper >= 0.3.4 appends
Only 4-byte values (PUSH4) count for S and X, so small constants are not mistaken for selectors.
Output: OUT_DIR/<chain>_<chunk>.tsv with one row per contract that has a SUB/XOR selector missed by E, or Vyper metadata:
chain, address, n_E, missed_SUB, missed_XOR, vyper, missed selectors that are in the spec (erc_specification_v5.json).
Usage: python dispatch_forms_census.py OUT_DIR        then: python dispatch_forms_census.py --summary OUT_DIR"""
import os as _o, sys as _s; _s.path.insert(0, _o.path.dirname(_o.path.dirname(_o.path.abspath(__file__)))); from paths import *  # repo paths
import sys, os, time, glob, json
from multiprocessing import Pool
R = CLASSIFIER
SPEC = {s for v in json.load(open(R + '/erc_specification_v5.json')).values() for s in v.get('selectors', [])}
H = EVM_DATA
SRC = {'ethereum': H + 'ethereum_deduplicated_results.csv', 'bnb': H + 'evm_data_source/deduplicated_results.csv',
       'avalanche': H + 'evm_data_source/avalanche/deduplicated_avalanche.csv', 'polygon': H + 'polygon/deduplicated_polygon.csv'}
SZ = 128 * 2**20
VY = bytes.fromhex('a165767970657283')

ONE = rb'(?:[\x00-\x5f\x64-\xff]|\x60.|\x61..|\x62...)'  # one opcode: any non-push byte, or PUSH1-3 with its data
CAND = __import__('re').compile(rb'\x63....' + ONE + rb'?[\x03\x18]' + ONE + rb'?\x57', __import__('re').S)

def forms(b):
    """Exact opcode-aligned check. Speed: a byte regex (CAND) finds contracts that can contain a SUB/XOR compare; only those, and
    Vyper contracts, are parsed. Opcodes between PUSH4, SUB/XOR and JUMPI are limited to one 1-byte op or PUSH1-3, as in CAND."""
    ops = []; i = 0
    while i < len(b):
        op = b[i]; arg = None
        if 0x60 <= op <= 0x7F:
            n = op - 0x5F
            if op <= 0x63:
                x = b[i + 1:i + 1 + n]; arg = (x.rjust(4, b'\0').hex() if x else None, n)
            i += 1 + n
        else:
            i += 1
        ops.append((op, arg))
    E, S, X = set(), set(), set()
    for k, (op, arg) in enumerate(ops):
        if op == 0x14:
            for j in range(max(0, k - 3), k):
                if ops[j][1] and ops[j][1][0]: E.add(ops[j][1][0])
        if arg and arg[1] == 4:
            ok = lambda o: not (0x63 <= o <= 0x7F)   # 1-byte op or PUSH1-3, as in CAND
            for j in range(k + 1, min(k + 3, len(ops))):
                if ops[j][0] in (0x03, 0x18):
                    if all(ok(ops[m][0]) for m in range(k + 1, j)) and any(
                            ops[m][0] == 0x57 and all(ok(ops[q][0]) for q in range(j + 1, m)) for m in range(j + 1, min(j + 3, len(ops)))):
                        (S if ops[j][0] == 0x03 else X).add(arg[0])
                    break
    return E, S, X

def job(a):
    out, ch, p, st, en, idx = a; o = f'{out}/{ch}_{idx}.tsv'
    if os.path.exists(o): return
    tot = 0
    with open(p, 'rb') as f, open(o + '.tmp', 'w') as w:
        f.seek(st)
        if st: f.readline()
        while f.tell() <= en:
            l = f.readline()
            if not l: break
            if l.startswith(b'address,'): continue
            x = l.split(b',', 2)
            if len(x) < 3: continue
            c = x[1].decode('ascii', 'ignore').strip('"').lower()
            if len(c) <= 2: continue
            try: b = bytes.fromhex(c[2:] if c.startswith('0x') else c)
            except ValueError: continue
            tot += 1
            vy = VY in b
            if not vy and not CAND.search(b): continue
            E, S, X = forms(b); ms, mx = S - E, X - E
            if ms or mx or vy:
                sp = sorted((ms | mx) & SPEC)
                w.write(f"{ch}\t{x[0].decode().strip(chr(34)).lower()}\t{len(E)}\t{len(ms)}\t{len(mx)}\t{int(vy)}\t{'|'.join(sp)}\n")
        w.write(f"#TOTAL\t{tot}\n")
    os.rename(o + '.tmp', o)

def summary(out):
    t = n = sub = xor = vy = spec = vy_noE = 0
    for p in glob.glob(out + '/*.tsv'):
        for l in open(p):
            x = l.rstrip('\n').split('\t')
            if x[0] == '#TOTAL': t += int(x[1]); continue
            n += 1; sub += x[3] != '0'; xor += x[4] != '0'; vy += x[5] == '1'; spec += bool(x[6]); vy_noE += x[5] == '1' and int(x[2]) < 3
    print(f'contracts {t:,}\nSUB-form selectors missed by reader: {sub:,}\nXOR-form selectors missed by reader: {xor:,}\n'
          f'Vyper metadata: {vy:,} (of which reader finds <3 selectors: {vy_noE:,})\nmissed selector is in an ERC spec: {spec:,}')

if __name__ == '__main__':
    if sys.argv[1] == '--summary': summary(sys.argv[2]); sys.exit()
    out = sys.argv[1]; os.makedirs(out, exist_ok=True); J = []
    for ch, p in SRC.items():
        s = os.path.getsize(p)
        for i, st in enumerate(range(0, s, SZ)): J.append((out, ch, p, st, min(st + SZ - 1, s), i))
    T = time.time()
    with Pool(10) as P:
        for k, _ in enumerate(P.imap_unordered(job, J), 1):
            if k % 50 == 0: print(k, len(J), int(time.time() - T), flush=True)
    print('DONE', int(time.time() - T), flush=True)
