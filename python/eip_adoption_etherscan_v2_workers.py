#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import time
from collections import Counter, deque
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from threading import Lock
from typing import Any, Dict, List, Optional

import pandas as pd
import requests
from dotenv import load_dotenv
from tqdm import tqdm

EIP_PATTERNS = {
    "EIP2612": ["d505accf"],
    "EIP712": [
        "3644e515",
        "8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f",
    ],
    "EIP5267": ["84b0196e"],
    "EIP1271": ["1626ba7e", "20c13b0b"],
}

ETHERSCAN_V2_URL = "https://api.etherscan.io/v2/api"

LEGACY_EXPLORER_URLS = {
    56: "https://api.bscscan.com/api",
    137: "https://api.polygonscan.com/api",
}

ROUTESCAN_URLS = {
    43114: "https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan/api",
}

EXPLORER_KEY_PREFIX = {
    56: "BSCSCAN_API_KEY",
    137: "POLYGONSCAN_API_KEY",
    43114: "ROUTESCAN_API_KEY",
}


class APIKeyManager:
    def __init__(self, api_keys: List[str], calls_per_second_per_key: float = 4.5):
        if not api_keys:
            raise ValueError("No Etherscan API keys provided.")
        self.api_keys = deque(api_keys)
        self.min_interval = 1.0 / calls_per_second_per_key
        self.last_call = {k: 0.0 for k in api_keys}
        self.usage = Counter()
        self.rotate_lock = Lock()
        self.key_locks = {k: Lock() for k in api_keys}

    def get_key(self) -> str:
        with self.rotate_lock:
            self.api_keys.rotate(-1)
            return self.api_keys[0]

    def wait(self, key: str) -> None:
        with self.key_locks[key]:
            now = time.time()
            elapsed = now - self.last_call[key]
            if elapsed < self.min_interval:
                time.sleep(self.min_interval - elapsed)
            self.last_call[key] = time.time()
            self.usage[key[:10] + "..."] += 1


def load_api_keys(env_path: Optional[str] = None) -> List[str]:
    if env_path:
        load_dotenv(env_path)
    else:
        load_dotenv()

    keys = []
    i = 1
    while True:
        key = os.getenv(f"ETHERSCAN_API_KEY{i}")
        if not key:
            break
        keys.append(key.strip())
        i += 1

    single = os.getenv("ETHERSCAN_API_KEY")
    if single:
        keys.append(single.strip())

    keys = list(dict.fromkeys([k for k in keys if k]))
    if not keys:
        raise ValueError("No API keys found. Use ETHERSCAN_API_KEY1=... in .env or export ETHERSCAN_API_KEY.")
    return keys


def normalize_bytecode(bytecode: Any) -> str:
    if pd.isna(bytecode) or bytecode is None:
        return ""
    b = str(bytecode).strip().lower()
    if b.startswith("0x"):
        b = b[2:]
    return "".join(c for c in b if c in "0123456789abcdef")


def normalize_address(address: Any) -> str:
    if pd.isna(address) or address is None:
        return ""
    a = str(address).strip().lower()
    return a if a.startswith("0x") else "0x" + a


def detect_features_from_bytecode(bytecode: Any) -> Dict[str, bool]:
    b = normalize_bytecode(bytecode)
    features = {
        eip: any(p.lower().replace("0x", "") in b for p in patterns)
        for eip, patterns in EIP_PATTERNS.items()
    }
    if features["EIP2612"]:
        features["EIP712"] = True
    return features


def make_combo(features: Dict[str, bool]) -> str:
    order = ["EIP2612", "EIP712", "EIP5267", "EIP1271"]
    active = [e for e in order if features.get(e, False)]
    return "_".join(active) if active else "None"


def classify_eip_family(features: Dict[str, bool]) -> str:
    if features["EIP2612"] and features["EIP5267"]:
        return "EIP2612_EIP712_EIP5267"
    if features["EIP2612"]:
        return "EIP2612_EIP712"
    if features["EIP5267"]:
        return "EIP712_EIP5267"
    if features["EIP712"]:
        return "EIP712_only"
    if features["EIP1271"]:
        return "EIP1271_only"
    return "None"


class EtherscanV2Client:
    def __init__(
        self,
        api_keys: List[str],
        chainid: int = 1,
        calls_per_second_per_key: float = 4.5,
        timeout: int = 30,
    ):
        self.chainid = str(chainid)
        self.timeout = timeout
        self.key_manager = APIKeyManager(api_keys, calls_per_second_per_key)

    def get_json(self, params: Dict[str, Any], max_retries: int = 5) -> Dict[str, Any]:
        last_error = None
        for attempt in range(max_retries):
            key = self.key_manager.get_key()
            self.key_manager.wait(key)
            p = dict(params)
            p["chainid"] = self.chainid
            p["apikey"] = key

            try:
                r = requests.get(ETHERSCAN_V2_URL, params=p, timeout=self.timeout)
                r.raise_for_status()
                data = r.json()
                text = json.dumps(data).lower()
                if "rate limit" in text or "max rate limit" in text or "too many requests" in text:
                    time.sleep(1.5 * (attempt + 1))
                    continue
                return data
            except Exception as exc:
                last_error = exc
                time.sleep(1.0 * (attempt + 1))

        raise RuntimeError(f"Etherscan request failed after retries: {last_error}")

    def get_contract_creation(self, address: str) -> Optional[Dict[str, Any]]:
        data = self.get_json({
            "module": "contract",
            "action": "getcontractcreation",
            "contractaddresses": normalize_address(address),
        })
        if data.get("status") == "1" and isinstance(data.get("result"), list) and data["result"]:
            return data["result"][0]
        return None

    def get_transaction_by_hash(self, txhash: str) -> Optional[Dict[str, Any]]:
        data = self.get_json({
            "module": "proxy",
            "action": "eth_getTransactionByHash",
            "txhash": txhash,
        })
        result = data.get("result")
        return result if isinstance(result, dict) else None

    def get_block_by_number(self, block_hex: str) -> Optional[Dict[str, Any]]:
        data = self.get_json({
            "module": "proxy",
            "action": "eth_getBlockByNumber",
            "tag": block_hex,
            "boolean": "false",
        })
        result = data.get("result")
        return result if isinstance(result, dict) else None

    def fetch_deployment_metadata(self, address: str) -> Dict[str, Any]:
        address = normalize_address(address)
        try:
            creation = self.get_contract_creation(address)
            if not creation:
                return {"address": address, "creation_status": "creation_not_found"}

            txhash = creation.get("txHash") or creation.get("hash")
            creator = creation.get("contractCreator")

            if not txhash:
                return {"address": address, "contract_creator": creator, "creation_status": "txhash_missing"}

            tx = self.get_transaction_by_hash(txhash)
            if not tx or not tx.get("blockNumber"):
                return {
                    "address": address,
                    "contract_creator": creator,
                    "creation_txhash": txhash,
                    "creation_status": "tx_not_found",
                }

            block_hex = tx["blockNumber"]
            block_number = int(block_hex, 16)
            block = self.get_block_by_number(block_hex)

            if not block or not block.get("timestamp"):
                return {
                    "address": address,
                    "contract_creator": creator,
                    "creation_txhash": txhash,
                    "block_number": block_number,
                    "creation_status": "block_not_found",
                }

            timestamp = int(block["timestamp"], 16)
            dt = datetime.fromtimestamp(timestamp, tz=timezone.utc)

            return {
                "address": address,
                "contract_creator": creator,
                "creation_txhash": txhash,
                "block_number": block_number,
                "timestamp": timestamp,
                "datetime_utc": dt.isoformat(),
                "year": dt.year,
                "creation_status": "ok",
            }
        except Exception as exc:
            return {"address": address, "creation_status": f"error: {str(exc)[:180]}"}


def load_cache(path: Path) -> Dict[str, Dict[str, Any]]:
    if not path.exists():
        return {}
    try:
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
        return {normalize_address(k): v for k, v in data.items()}
    except Exception:
        return {}


def save_cache(path: Path, cache: Dict[str, Dict[str, Any]]) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as f:
        json.dump(cache, f, indent=2, sort_keys=True)
    tmp.replace(path)


def run_pipeline(
    input_csv: str,
    outdir: str,
    env_path: Optional[str],
    chainid: int,
    limit: Optional[int],
    workers: int,
    calls_per_second_per_key: float,
    save_every: int,
) -> None:
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    output_local_all = outdir / "all_contracts_local_detection.csv"
    output_matched = outdir / "matched_contracts_with_deployment.csv"
    output_yearly = outdir / "yearly_matched_eip_trend.csv"
    output_combos = outdir / "yearly_combo_summary.csv"
    cache_path = outdir / "deployment_cache.json"

    print(f"Loading CSV: {input_csv}")
    df = pd.read_csv(input_csv, low_memory=False)
    print(f"Rows loaded: {len(df)}")
    print(f"Columns: {df.columns.tolist()}")

    for col in ["address", "bytecode"]:
        if col not in df.columns:
            raise ValueError(f"Missing required column: {col}")

    records = []
    for _, row in tqdm(df.iterrows(), total=len(df), desc="Local bytecode detection"):
        addr = normalize_address(row["address"])
        features = detect_features_from_bytecode(row["bytecode"])

        rec = {
            "address": addr,
            "EIP2612": features["EIP2612"],
            "EIP712": features["EIP712"],
            "EIP5267": features["EIP5267"],
            "EIP1271": features["EIP1271"],
            "eip_combo": make_combo(features),
            "eip_family": classify_eip_family(features),
        }
        for c in ["is_erc20", "is_erc721", "function_sighashes"]:
            if c in df.columns:
                rec[c] = row[c]
        records.append(rec)

    local_df = pd.DataFrame(records)
    local_df.to_csv(output_local_all, index=False)
    print(f"Saved local detection for all contracts: {output_local_all}")

    matched_df = local_df[
        local_df[["EIP2612", "EIP712", "EIP5267", "EIP1271"]].any(axis=1)
    ].copy()
    matched_df = matched_df[matched_df["address"].str.match(r"^0x[a-f0-9]{40}$", na=False)]

    if limit:
        matched_df = matched_df.head(limit).copy()

    print(f"Matched contracts needing Etherscan timestamp: {len(matched_df)}")
    if matched_df.empty:
        print("No matched contracts found. Exiting.")
        return

    api_keys = load_api_keys(env_path)
    print(f"Loaded {len(api_keys)} Etherscan API key(s).")

    client = EtherscanV2Client(
        api_keys=api_keys,
        chainid=chainid,
        calls_per_second_per_key=calls_per_second_per_key,
    )

    cache = load_cache(cache_path)
    print(f"Loaded cached deployments: {len(cache)}")

    addresses = matched_df["address"].dropna().drop_duplicates().tolist()
    remaining = [a for a in addresses if a not in cache]
    print(f"Remaining addresses to enrich: {len(remaining)}")
    print(f"Workers: {workers}")
    print(f"Calls/sec/key cap: {calls_per_second_per_key}")

    completed = 0
    if remaining:
        with ThreadPoolExecutor(max_workers=workers) as executor:
            future_to_addr = {
                executor.submit(client.fetch_deployment_metadata, addr): addr
                for addr in remaining
            }
            for future in tqdm(as_completed(future_to_addr), total=len(future_to_addr), desc="Fetching deployment metadata"):
                addr = future_to_addr[future]
                try:
                    result = future.result()
                except Exception as exc:
                    result = {"address": addr, "creation_status": f"worker_error: {str(exc)[:180]}"}

                cache[addr] = result
                completed += 1
                if completed % save_every == 0:
                    save_cache(cache_path, cache)

    save_cache(cache_path, cache)
    print(f"Saved deployment cache: {cache_path}")

    deploy_df = pd.DataFrame(cache.values())
    final_df = matched_df.merge(deploy_df, on="address", how="left")
    final_df.to_csv(output_matched, index=False)
    print(f"Saved matched contracts with deployment metadata: {output_matched}")

    ok_df = final_df[final_df["creation_status"] == "ok"].copy()
    if ok_df.empty:
        print("No contracts had successful deployment metadata. Check API keys/rate limits.")
        print(final_df["creation_status"].value_counts(dropna=False).head(30))
        return

    yearly_rows = []
    total_by_year = ok_df.groupby("year").size().to_dict()

    for year in sorted(total_by_year):
        subset = ok_df[ok_df["year"] == year]
        total = int(len(subset))
        row = {"year": int(year), "matched_contracts_with_timestamp": total}

        for eip in ["EIP2612", "EIP712", "EIP5267", "EIP1271"]:
            count = int(subset[eip].sum())
            row[f"{eip}_count"] = count
            row[f"{eip}_pct_among_matched"] = round((count / total) * 100, 6) if total else 0.0

        row["EIP2612_EIP712_count"] = int((subset["eip_family"] == "EIP2612_EIP712").sum())
        row["EIP2612_EIP712_EIP5267_count"] = int((subset["eip_family"] == "EIP2612_EIP712_EIP5267").sum())
        row["EIP712_EIP5267_count"] = int((subset["eip_family"] == "EIP712_EIP5267").sum())
        yearly_rows.append(row)

    yearly_df = pd.DataFrame(yearly_rows)
    yearly_df.to_csv(output_yearly, index=False)
    print(f"Saved yearly matched EIP trend: {output_yearly}")

    combo_df = (
        ok_df.groupby(["year", "eip_combo"])
        .size()
        .reset_index(name="count")
        .sort_values(["year", "count"], ascending=[True, False])
    )
    combo_df["year_total_matched"] = combo_df["year"].map(total_by_year)
    combo_df["combo_pct_among_matched"] = round((combo_df["count"] / combo_df["year_total_matched"]) * 100, 6)
    combo_df.to_csv(output_combos, index=False)
    print(f"Saved yearly combo summary: {output_combos}")

    print("\n=== Overall matched counts with timestamps ===")
    print(ok_df[["EIP2612", "EIP712", "EIP5267", "EIP1271"]].sum())

    print("\n=== Creation status counts ===")
    print(final_df["creation_status"].value_counts(dropna=False).head(30))

    print("\n=== Top combos ===")
    print(ok_df["eip_combo"].value_counts().head(20))

    print("\n=== Yearly preview ===")
    print(yearly_df.tail(15).to_string(index=False))

    print("\nAPI key usage:")
    for key_prefix, count in client.key_manager.usage.items():
        print(f"  {key_prefix}: {count} calls")


def main() -> None:
    parser = argparse.ArgumentParser(description="EIP adoption enrichment with Etherscan V2 + threaded workers.")
    parser.add_argument("--input", required=True, help="Input CSV path with address and bytecode.")
    parser.add_argument("--outdir", required=True, help="Output directory.")
    parser.add_argument("--env", default=None, help="Path to .env containing ETHERSCAN_API_KEY1, etc.")
    parser.add_argument("--chainid", type=int, default=1, help="Etherscan V2 chainid; Ethereum mainnet is 1.")
    parser.add_argument("--limit", type=int, default=None, help="Limit matched contracts for testing.")
    parser.add_argument("--workers", type=int, default=12, help="Thread workers for Etherscan enrichment.")
    parser.add_argument("--calls-per-second-per-key", type=float, default=4.5)
    parser.add_argument("--save-every", type=int, default=100)
    args = parser.parse_args()

    run_pipeline(
        input_csv=args.input,
        outdir=args.outdir,
        env_path=args.env,
        chainid=args.chainid,
        limit=args.limit,
        workers=args.workers,
        calls_per_second_per_key=args.calls_per_second_per_key,
        save_every=args.save_every,
    )


if __name__ == "__main__":
    main()

