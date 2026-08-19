#!/usr/bin/env python3
# erc1155_batch_transfer_analysis.py

"""
End‑to‑end pipeline to extract ERC‑1155 batch transfer calls, save them, and
analyse them for common vulnerabilities.

Usage example:
    python erc1155_batch_transfer_analysis.py \
        --json /path/to/erc1155_SafeBatch.json \
        --num-addresses 50 \
        --raw-csv raw_transactions.csv \
        --annotated-csv analysed_transactions.csv
"""

import os
import re
import json
import argparse
import requests
import pandas as pd
import time
from dotenv import load_dotenv
from typing import List, Tuple, Dict, Any, Optional
import traceback
# Add at top of file after imports
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from concurrent.futures import ThreadPoolExecutor, as_completed



# ---------------------------------------------------------------------
# Helper functions for configuration, extraction and decoding
# ---------------------------------------------------------------------

def load_api_key() -> str:
    """
    Load ETHERSCAN_API_KEY from .env or environment.
    Raises ValueError if the key isn't found.
    """
    load_dotenv()
    # load_env = load_dotenv("/home/ashok/ERC-analysis/.env")
    api_key = os.getenv("ETHERSCAN_API_KEY")
    if not api_key:
        raise ValueError("❌ API key not found. Please set ETHERSCAN_API_KEY in .env or environment.")
    return api_key




def extract_addresses_from_json(json_path: str, max_addresses: int) -> List[str]:
    """
    Read a JSON file and return up to max_addresses Ethereum addresses
    where the contract’s all_requirements_met flag is false.

    The JSON is expected to have objects with a 'file' field (containing
    the Solidity filename) and an 'all_implementations' array.  Each
    implementation has an 'all_requirements_met' boolean.  Only contracts
    with any implementation flagged as not meeting all requirements are
    included.

    Args:
        json_path: Path to the JSON file
        max_addresses: Maximum number of addresses to return

    Returns:
        A list of Ethereum addresses (0x-prefixed strings).
    """
    with open(json_path, "r") as f:
        data = json.load(f)

    addresses: List[str] = []
    for item in data:
        implementations = item.get("all_implementations", [])
        # Is there at least one implementation where all_requirements_met is false?
        vulnerable = any(not impl.get("all_requirements_met", True) for impl in implementations)
        if not vulnerable:
            continue  # skip fully compliant contracts

        file_path = item.get("file", "")
        match = re.search(r"(0x[a-fA-F0-9]{40})", file_path)
        if match:
            addresses.append(match.group(1))
            if len(addresses) >= max_addresses:
                break

    return addresses

def extract_addresses_from_csv(csv_path: str, max_addresses: int) -> List[str]:
    """
    Read a CSV file using pandas and return up to max_addresses Ethereum addresses
    where the contract bytecode contains the signature "2eb2c2d6".

    Args:
        csv_path: Path to the CSV file
        max_addresses: Maximum number of addresses to return

    Returns:
        A list of Ethereum addresses (0x-prefixed strings).
    """
    df = pd.read_csv(csv_path)
    addresses = []
    
    for idx, row in df.iterrows():
        original_bytecode_str = str(row.get("bytecode", ""))
        erc_type = str(row.get("ERC", ""))
        # if "2eb2c2d6" in original_bytecode_str:
        
        # dd62ed3e-allowance
        # 095ea7b3-approve
        # 081812fc-getApproved
        # a22cb465-setApprovalForAll
        # e985e9c5-isApprovedForAll
        # 2eb2c2d6-SafeBAtchTransferFrom
        
        
        # if erc_type == "ERC-721" and "b88d4fde" in original_bytecode_str:
        if  "dd62ed3e" and "095ea7b3" in  original_bytecode_str:
            address = row.get("address")
            if address:
                addresses.append(address)
                if len(addresses) >= max_addresses:
                    break
    
    return addresses

def decode_transferFrom_input(input_hex: str) -> Tuple[str, str, int]:
    """
    Decode the calldata for transferFrom: (from, to, value).
    Raises ValueError if the payload is malformed.
    """
    data = input_hex[2:] if input_hex.startswith("0x") else input_hex
    if len(data) < 8 + 64 * 3:  # 4 bytes selector + 3 parameters * 32 bytes
        raise ValueError("Input too short")
    
    params_hex = data[8:]  # Skip the 4-byte function selector
    
    # Extract the three 32-byte (64 hex chars) parameters
    from_word = params_hex[0:64]
    to_word   = params_hex[64:128]
    value_word = params_hex[128:192]
    
    # Convert to addresses (last 40 hex chars of each 32-byte word)
    from_addr = "0x" + from_word[-40:]
    to_addr   = "0x" + to_word[-40:]
    
    # Convert value from hex to integer
    value = int(value_word, 16)
    
    return from_addr, to_addr, value

def decode_safeBatchTransferFrom_input(input_hex: str) -> Tuple[str, str, List[int], List[int]]:
    """
    Decode the calldata for safeBatchTransferFrom: (from, to, ids[], amounts[]).
    Raises ValueError if the payload is malformed.
    """
    data = input_hex[2:] if input_hex.startswith("0x") else input_hex
    if len(data) < 8 + 64 * 5:
        raise ValueError("Input too short")
    params_hex = data[8:]
    from_word = params_hex[0:64]
    to_word   = params_hex[64:128]
    ids_off   = int(params_hex[128:192], 16)
    amts_off  = int(params_hex[192:256], 16)
    from_addr = "0x" + from_word[-40:]
    to_addr   = "0x" + to_word[-40:]

    def decode_array(offset: int, params: str) -> List[int]:
        start = offset * 2
        length = int(params[start:start + 64], 16)
        ptr = start + 64
        items = []
        for _ in range(length):
            items.append(int(params[ptr:ptr + 64], 16))
            ptr += 64
        return items

    ids  = decode_array(ids_off, params_hex)
    amts = decode_array(amts_off, params_hex)
    return from_addr, to_addr, ids, amts

def decode_setApprovalForAll_input(input_hex: str) -> Tuple[str, bool]:
    """
    Decode the calldata for setApprovalForAll: (operator, approved).
    Raises ValueError if the payload is malformed.
    """
    # Remove '0x' prefix if present
    data = input_hex[2:] if input_hex.startswith("0x") else input_hex
    
    # Check minimum length (function selector + 2 parameters of 32 bytes each)
    if len(data) < 8 + 64 * 2:
        raise ValueError("Input too short")
    
    # Skip function selector (first 4 bytes/8 hex characters)
    params_hex = data[8:]
    
    # Extract operator (address)
    operator_word = params_hex[0:64]
    operator_addr = "0x" + operator_word[-40:]
    
    # Extract approved (bool)
    approved_word = params_hex[64:128]
    approved_value = int(approved_word, 16) != 0  # Convert to boolean
    
    return operator_addr, approved_value


def decode_approve_input(input_hex: str) -> Tuple[str, bool]:
    """
    Decode the calldata for approve: (spender, money).
    Raises ValueError if the payload is malformed.
    """
    # Remove '0x' prefix if present
    data = input_hex[2:] if input_hex.startswith("0x") else input_hex
    
    # Check minimum length (function selector + 2 parameters of 32 bytes each)
    if len(data) < 8 + 64 * 2:
        raise ValueError("Input too short")
    
    # Skip function selector (first 4 bytes/8 hex characters)
    params_hex = data[8:]
    
    # Extract spender (address)
    spender_word = params_hex[0:64]
    spender_addr = "0x" + spender_word[-40:]
    
    # Extract approved (value)
    money_value_word = params_hex[64:128]
    approved_value = int(money_value_word, 16) != 0  # Convert to boolean
    
    return spender_addr, approved_value


  

def analyse_transactions(txs: List[Dict[str, Any]]) -> pd.DataFrame:
    """
    Decode and flag each transaction:
    - For safeBatchTransferFrom: check unauthorized, zero_address, length_mismatch
    - For setApprovalForAll: decode operator and permission
    - Check if newly approved operators are providing further approvals
    Returns a dataframe with extra columns.
    """
    df = pd.DataFrame(txs)
    df["decoded_from"] = None
    df["decoded_to"] = None
    df["decoded_ids"] = None
    df["decoded_amounts"] = None
    
    df["unauthorized"] = False
    df["unauthorized_addr"] = None
    df["zero_address"] = False
    df["length_mismatch"] = False
    
    df["decoded_operator"] = None
    df["operator_permission"] = False
    df["operator_provides_further_approvals"] = False  # New column
    df["secondary_approvals_count"] = 0  # New column: count of secondary approvals

    # Track all approval transactions with timestamps
    approvals = []  # List of (owner, operator, approved, timestamp, blockNumber)
    callerCount = 0
    operatorCount = 0
    # First pass: Process all setApprovalForAll transactions to build approval history
    for idx, row in df.iterrows():
        func_name = row.get("functionName", "").split("(")[0].strip()
        
        if func_name == "setApprovalForAll":
            try:
                operator_addr, perm_bool = decode_setApprovalForAll_input(row.get("input", ""))
                owner_addr = row.get("from", "").lower()
                operator_addr_lower = operator_addr.lower()
                timestamp = int(row.get("timeStamp", 0))
                block_number = int(row.get("blockNumber", 0))
                
                df.at[idx, "decoded_operator"] = operator_addr
                df.at[idx, "operator_permission"] = perm_bool
                
                # Store approval for later reference
                approvals.append((owner_addr, operator_addr_lower, perm_bool, timestamp, block_number, idx))
                
                
            except Exception as e:
                print(f"Error decoding setApprovalForAll for tx {row.get('hash', 'unknown')}: {e}")
                continue

    print(f"approvals total length : {len(approvals)}")
    
    # def check_operator_further_approvals(operator_addr, current_timestamp, current_block):
    #     """
    #     Check if an operator provides further approvals to other addresses
    #     after being approved themselves.
    #     """
    #     secondary_approvals = []
        
    #     # Sort approvals chronologically (by timestamp, then block number)
    #     sorted_approvals = sorted(approvals, key=lambda x: (x[3], x[4]))
        
    #     # Find all approvals where the operator becomes an owner (provides approval to others)
    #     for approval in sorted_approvals:
    #         owner, operator, approved, timestamp, block_num, tx_idx = approval
            
    #         # Check if this approval happens after the operator was approved
    #         # and the owner is the operator we're checking
    #         if (owner.lower() == operator_addr.lower() and 
    #             (timestamp > current_timestamp or 
    #              (timestamp == current_timestamp and block_num > current_block))):
    #             secondary_approvals.append((operator, approved, timestamp, block_num, tx_idx))
        
    #     return secondary_approvals

    def check_operator_approval_chain(operator_addr, current_timestamp, current_block, max_depth=2, current_depth=1):
        """
        Recursively check approval chains to multiple levels
        """
        if current_depth > max_depth:
            return []
        
        chain_approvals = []
        
        # Sort approvals chronologically
        sorted_approvals = sorted(approvals, key=lambda x: (x[3], x[4]))
        
        for approval in sorted_approvals:
            owner, operator, approved, timestamp, block_num, tx_idx = approval
            
            # Check if this approval happens after the current operator was approved
            # and the owner is the operator we're checking
            if (owner.lower() == operator_addr.lower() and 
                (timestamp > current_timestamp or 
                 (timestamp == current_timestamp and block_num > current_block)) and
                approved):  # Only consider True approvals
                
                # Add this approval to the chain
                chain_approvals.append((current_depth, operator, approved, timestamp, block_num, tx_idx))
                
                # Recursively check for further approvals from this new operator
                deeper_approvals = check_operator_approval_chain(
                    operator, timestamp, block_num, max_depth, current_depth + 1
                )
                chain_approvals.extend(deeper_approvals)
        
        return chain_approvals

    
    # Apply the check to each setApprovalForAll transaction
    for approval in approvals:
        owner_addr, operator_addr, perm_bool, timestamp, block_number, tx_idx = approval
        
        # if perm_bool:  # Only check for True approvals
        #     secondary_approvals = check_operator_further_approvals(
        #         operator_addr, timestamp, block_number
        #     )
            
        #     if secondary_approvals:
        #         df.at[tx_idx, "operator_provides_further_approvals"] = True
        #         df.at[tx_idx, "secondary_approvals_count"] = len(secondary_approvals)
                
        #         # Optional: Store details of secondary approvals
        #         # You can add more columns if needed
        #         secondary_info = []
        #         for sec_operator, sec_approved, sec_ts, sec_block, sec_tx_idx in secondary_approvals:
        #             secondary_info.append(f"{sec_operator}:{sec_approved}@{sec_ts}")
                
        #         df.at[tx_idx, "secondary_approvals_details"] = ";".join(secondary_info)
        
        if perm_bool:  # Only check for True approvals
            # Check for approval chains up to 5 levels deep
            approval_chain = check_operator_approval_chain(
                operator_addr, timestamp, block_number, max_depth=5
            )
            
            if approval_chain:
                df.at[tx_idx, "operator_provides_further_approvals"] = True
                
                # Count approvals at each level
                level_counts = {}
                for depth, operator, approved, ts, block_num, chain_tx_idx in approval_chain:
                    level_counts[depth] = level_counts.get(depth, 0) + 1
                
                # Store level information
                max_depth = max(level_counts.keys()) if level_counts else 0
                df.at[tx_idx, "approval_chain_depth"] = max_depth
                df.at[tx_idx, "total_chain_approvals"] = len(approval_chain)
                df.at[tx_idx, "secondary_approvals_count"] = len(approval_chain)  # Backward compatibility
                
                # Store level-wise counts
                for depth in range(1, 6):  # Levels 1-5
                    df.at[tx_idx, f"level_{depth}_approvals"] = level_counts.get(depth, 0)
                
                # Store chain details
                chain_details = []
                for depth, operator, approved, ts, block_num, chain_tx_idx in approval_chain:
                    chain_details.append(f"L{depth}:{operator}@{ts}")
                
                df.at[tx_idx, "approval_chain_details"] = ";".join(chain_details)

    # Second pass: Process safeBatchTransferFrom transactions and check authorization
    for idx, row in df.iterrows():
        func_name = row.get("functionName", "").split("(")[0].strip()
        
        if func_name == "safeBatchTransferFrom":
            try:
                from_addr, to_addr, ids_list, amts_list = decode_safeBatchTransferFrom_input(row.get("input", ""))
                df.at[idx, "decoded_from"] = from_addr
                df.at[idx, "decoded_to"] = to_addr
                df.at[idx, "decoded_ids"] = ids_list
                df.at[idx, "decoded_amounts"] = amts_list
                
                # Check if caller is authorized
                caller = row.get("from", "").lower()
                from_addr = from_addr.lower()
                current_timestamp = int(row.get("timeStamp", 0))
                current_block = int(row.get("blockNumber", 0))
                
                if caller != from_addr:
                    # Check if caller was approved as operator by from_addr before this transaction
                    is_approved = False
                    
                    
                    
                    
                    # Look for approval transactions where:
                    # 1. Owner is the caller
                    # 2. Operator is the caller
                    # 3. Approved is True
                    # 4. Timestamp/block is before current transaction
                    
                    
                    for owner, operator, approved, timestamp, block_num, tx_idx in approvals:
                        if (
                            (operator == from_addr or caller == operator) and 
                            approved) :
                            # and 
                            # (timestamp < current_timestamp or 
                            #  (timestamp == current_timestamp and block_num < current_block)))
                            # :
                            if(caller == operator):
                                callerCount = callerCount + 1
                            if(operator == from_addr):
                                operatorCount = operatorCount + 1
                            is_approved = True
                            break
                     
                   
                    
                    # If not approved, flag as unauthorized
                    if not is_approved:
                        df.at[idx, "unauthorized"] = True
                        df.at[idx, "unauthorized_addr"] = from_addr
                
                # zero address check
                if to_addr == "0x0000000000000000000000000000000000000000" or to_addr == "0x000000":
                    df.at[idx, "zero_address"] = True
                
                # length mismatch check
                if len(ids_list) != len(amts_list):
                    df.at[idx, "length_mismatch"] = True
                    
            except Exception as e:
                print(f"Error decoding safeBatchTransferFrom for tx {row.get('hash', 'unknown')}: {e}")
                continue
    
    
    print(f"callerCount is {callerCount}")
    print(f"operatorCount is {operatorCount}")
    return df


def analyse_approve_txs(txs: List[Dict[str, Any]]) -> pd.DataFrame:
    df = pd.DataFrame(txs)
    
    df["decoded_spender"] = None
    df["money_to_spend"] = None
    df["spender_permission"] = False
    df["spender_provides_further_approvals"] = False
    df["secondary_approvals_count"] = 0
    
    approvals = [] # (owner, spender, money_to_spend, timestamp, block, idx)
    
    for idx, row in df.iterrows():
        func_name = row.get("functionName", "").split("(")[0].strip()
        
        if func_name == "approve":
            try:
                spender_addr, money_to_spend = decode_approve_input(row.get("input", ""))
                owner_addr = row.get("from", "").lower()
                spender_addr_lower = spender_addr.lower()
                timestamp = int(row.get("timeStamp", 0))
                block_number = int(row.get("blockNumber", 0))
                tx_hash = row.get("hash", "").lower()
                
                df.at[idx, "decoded_spender"] = spender_addr
                df.at[idx, "money_to_spend"] = money_to_spend
                df.at[idx, "tx_hash"] = tx_hash
                
                if owner_addr != spender_addr_lower :
                    approvals.append((owner_addr, spender_addr_lower, money_to_spend, timestamp, block_number, idx))
                
            except Exception as e:
                print(f"Error decoding approve for tx {row.get('hash', 'unknown')}: {e}")
                continue

    print(f"approvals total length : {len(approvals)}")
    
    def check_spender_approval_chain(spender_addr, current_timestamp, current_block, max_depth=2, current_depth=1):
        if current_depth > max_depth:
            return []
        
        chain_approvals = []
        sorted_approvals = sorted(approvals, key=lambda x: (x[3], x[4]))
        
        # for owner, spender, approved, timestamp, block_num, tx_idx in sorted_approvals:
        for owner, spender, money_to_spend, timestamp, block_num, tx_idx in sorted_approvals:
            if (owner.lower() == spender_addr.lower() and 
                (timestamp > current_timestamp or 
                (timestamp == current_timestamp and block_num > current_block)) and
                money_to_spend):
                
                chain_approvals.append((current_depth, spender, money_to_spend, timestamp, block_num, tx_idx))
                
                deeper_approvals = check_spender_approval_chain(
                    spender, timestamp, block_num, max_depth, current_depth + 1
                )
                chain_approvals.extend(deeper_approvals)
        
        return chain_approvals

    for owner_addr, spender_addr, money_to_spend, timestamp, block_number, tx_idx in approvals:
        if money_to_spend:
            approval_chain = check_spender_approval_chain(
                spender_addr, timestamp, block_number, max_depth=5
            )
            
            if approval_chain:
                df.at[tx_idx, "spender_provides_further_approvals"] = True
                df.at[tx_idx, "current_owner_was_spender"] = owner_addr
                # df.at[tx_idx, "current_owner_was_spender"] = owner_addr
                
                level_counts = {}
                for depth, spender, approved, ts, block_num, chain_tx_idx in approval_chain:
                    level_counts[depth] = level_counts.get(depth, 0) + 1
                
                df.at[tx_idx, "secondary_approvals_count"] = len(approval_chain)
                df.at[tx_idx, "total_chain_approvals"] = len(approval_chain)
                df.at[tx_idx, "approval_chain_depth"] = max(level_counts.keys()) if level_counts else 0
                
                for depth in range(1, 6):
                    df.at[tx_idx, f"level_{depth}_approvals"] = level_counts.get(depth, 0)
                
                chain_details = [f"L{depth}:{spender}@{ts}" for depth, spender, _, ts, _, _ in approval_chain]
                df.at[tx_idx, "approval_chain_details"] = ";".join(chain_details)
    
    
     # Second pass: Process safeBatchTransferFrom transactions and check authorization
    
    return df
  
def analyse_ownTransfer_by_caller(txs: List[Dict[str, Any]]) -> pd.DataFrame:
    df = pd.DataFrame(txs)
    df["own_transfer"] = None
    
    for idx, row in df.iterrows():
        func_name = row.get("functionName", "").split("(")[0].strip()
        
        if func_name == "transferFrom":
            try:
                from_addr, to_addr, amts_list = decode_transferFrom_input(row.get("input", ""))
                df.at[idx, "decoded_from"] = from_addr
                df.at[idx, "decoded_to"] = to_addr
                df.at[idx, "decoded_amounts"] = amts_list
                
                # Check if caller is authorized
                caller = row.get("from", "").lower()
                from_addr = from_addr.lower()
                to_addr = to_addr.lower()
                current_timestamp = int(row.get("timeStamp", 0))
                current_block = int(row.get("blockNumber", 0))
                
                if caller == to_addr:
                    df.at[idx, "own_transfer_caller_address"] = caller
                    df.at[idx, "own_transfer_to_address"] = to_addr
  
            except Exception as e:
                print(f"Error decoding transferFrom for tx {row.get('hash', 'unknown')}: {e}")
                continue
    return df



def get_transferFrom_txs(address: str, api_key: str,
                                # start_block: int = 0,
                                start_block: int = 19000000,
                                end_block: int = 99999999,
                                sort: str = "asc",
                                chainid: int = 1) -> tuple:
    """
    Fetch transactions AND events for a contract.
    Returns (transactions, events)
    """
    # Get transactions
    all_transactions = []
    page = 1
    offset = 10000
    target_functions = {"approve"}
    function_method_id="0x95EA7B3"
    
    # Create session BEFORE while loops (in get_transactions_and_events function)
    session = requests.Session()
    retries = Retry(total=3, backoff_factor=1, status_forcelist=[500, 502, 503, 504])
    session.mount('https://', HTTPAdapter(max_retries=retries))
    
    while True:
        url = (
            "https://api.etherscan.io/v2/api"
            f"?chainid={chainid}"
            f"&module=account&action=txlist"
            f"&address={address}"
            f"&startblock={start_block}"
            f"&endblock={end_block}"
            
            # f"&startblock={14716956}"
            # f"&endblock={24718534}"
            f"&page={page}"
            f"&offset={offset}"
            f"&sort={sort}"
            f"&apikey={api_key}"
        )
        
        try:
            # resp = session.get(url, timeout=30)
            resp = requests.get(url, timeout=30)
            data = resp.json()
            # print(f"DEBUG: data keys: {data.keys()}")
            # print(f"DEBUG: data status: {data.get('status')}")
            # print(f"DEBUG: data result type: {type(data.get('result'))}")
            # print(f"DEBUG: data result value: {data.get('result')}")
            
            if data.get("status") == "0":
                error_msg = data.get("result", "Unknown error")
                if error_msg and "No transactions found" in error_msg:
                    break
                print(f"⚠️ Tx API Error: {error_msg}")
                break
            
            result = data.get("result")
            if result is None:
                print("DEBUG: result is None, breaking")
                break
                
            if not isinstance(result, list):
                print(f"DEBUG: result is not a list, it's {type(result)}")
                break
                
            
            filtered = []
            for idx, tx in enumerate(result):
                # print(f"DEBUG: tx {idx} type: {type(tx)}")
                if tx is None:
                    print(f"DEBUG: tx {idx} is None, skipping")
                    continue
                method_id = tx.get("methodId", "")
                # print(f"DEBUG: tx {idx} methodId='{method_id}'")
                # if method_id.lower() == "0x095ea7b3":
                if method_id.lower() == "0x23b872dd":
                    filtered.append(tx)
            
            all_transactions.extend(filtered)
                
            if len(data["result"]) < offset:
                break
            page += 1
            time.sleep(0.2)
            # else:
            #     break
        except requests.exceptions.Timeout:
            print(f"⚠️ Timeout, retrying...")
            time.sleep(2)
            continue
        except Exception as e:
            print(f"❌ Error fetching txs: {e}")
            traceback.print_exc()
            break
    return all_transactions

def get_transactions_and_events(address: str, api_key: str,
                                # start_block: int = 0,
                                start_block: int = 19000000,
                                end_block: int = 99999999,
                                sort: str = "asc",
                                chainid: int = 1) -> tuple:
    """
    Fetch transactions AND events for a contract.
    Returns (transactions, events)
    """
    # Get transactions
    all_transactions = []
    page = 1
    offset = 10000
    target_functions = {"approve"}
    function_method_id="0x95EA7B3"
    
    # Create session BEFORE while loops (in get_transactions_and_events function)
    session = requests.Session()
    retries = Retry(total=3, backoff_factor=1, status_forcelist=[500, 502, 503, 504])
    session.mount('https://', HTTPAdapter(max_retries=retries))
    
    while True:
        url = (
            "https://api.etherscan.io/v2/api"
            f"?chainid={chainid}"
            f"&module=account&action=txlist"
            f"&address={address}"
            f"&startblock={start_block}"
            f"&endblock={end_block}"
            
            # f"&startblock={14716956}"
            # f"&endblock={24718534}"
            f"&page={page}"
            f"&offset={offset}"
            f"&sort={sort}"
            f"&apikey={api_key}"
        )
        
        try:
            # resp = session.get(url, timeout=30)
            resp = requests.get(url, timeout=30)
            data = resp.json()
            # print(f"DEBUG: data keys: {data.keys()}")
            # print(f"DEBUG: data status: {data.get('status')}")
            # print(f"DEBUG: data result type: {type(data.get('result'))}")
            # print(f"DEBUG: data result value: {data.get('result')}")
            
            if data.get("status") == "0":
                error_msg = data.get("result", "Unknown error")
                if error_msg and "No transactions found" in error_msg:
                    break
                print(f"⚠️ Tx API Error: {error_msg}")
                break
            
            result = data.get("result")
            if result is None:
                print("DEBUG: result is None, breaking")
                break
                
            if not isinstance(result, list):
                print(f"DEBUG: result is not a list, it's {type(result)}")
                break
                
            # print(f"DEBUG: result length: {len(result)}")
            
            
                
            # if data.get("result") is not None and isinstance(data["result"], list):
            
            # filtered = [
            #     tx for tx in data["result"]
            #     if (tx.get("functionName", "").split("(")[0].strip() in target_functions)  # ✅ Fixed
            # ]
            # all_transactions.extend(filtered)
            
            filtered = []
            for idx, tx in enumerate(result):
                # print(f"DEBUG: tx {idx} type: {type(tx)}")
                if tx is None:
                    print(f"DEBUG: tx {idx} is None, skipping")
                    continue
                method_id = tx.get("methodId", "")
                # print(f"DEBUG: tx {idx} methodId='{method_id}'")
                if method_id.lower() == "0x095ea7b3":
                    filtered.append(tx)
            
            all_transactions.extend(filtered)
                
            if len(data["result"]) < offset:
                break
            page += 1
            time.sleep(0.2)
            # else:
            #     break
        except requests.exceptions.Timeout:
            print(f"⚠️ Timeout, retrying...")
            time.sleep(2)
            continue
        except Exception as e:
            print(f"❌ Error fetching txs: {e}")
            traceback.print_exc()
            break
    
    # Get events (separate call, not in same loop)
    all_events = []
    page = 1
    offset = 1000
    
    # Topic hash for Approval event: keccak256("Approval(address,address,uint256)")
    approval_topic = "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
    
    while True:
        events_url = (
            "https://api.etherscan.io/v2/api"
            f"?chainid={chainid}"
            f"&module=logs&action=getLogs"
            f"&address={address}"
            f"&fromBlock={start_block}"
            f"&toBlock={end_block}"
            # f"&startblock={14716956}"
            # f"&endblock={24718534}"
            f"&topic0={approval_topic}"  # Filter by Approval event signature
            f"&page={page}"
            f"&offset={offset}"
            f"&apikey={api_key}"
        )
        
        try:
            # resp = session.get(url, timeout=30)
            resp = requests.get(events_url, timeout=30)
            data = resp.json()
            
            if data.get("status") == "0":
                error_msg = data.get("result", "Unknown error")
                if error_msg and "No transactions found" in error_msg:
                    break
                print(f"⚠️ Events API Error: {error_msg}")
                break
            
            result = data.get("result")
            if result is None:
                print("DEBUG: result is None, breaking")
                break
                
            if not isinstance(result, list):
                print(f"DEBUG: result is not a list, it's {type(result)}")
                break
            
            # if data.get("result") is not None and isinstance(data["result"], list):
                # All events returned are already Approval events due to topic0 filter
            all_events.extend(result)
            
            if len(result) < offset:
                break
            page += 1
            time.sleep(0.2)
            # else:
            #     break
        except requests.exceptions.Timeout:
            print(f"⚠️ Timeout, retrying...")
            time.sleep(2)
            continue
        except Exception as e:
            print(f"❌ Error fetching events: {e}")
            break
    
    # print(f"Found {len(all_transactions)} matching transactions")
    # print(f"Found {len(all_events)} matching Approval events")
    if len(all_transactions) != len(all_events):
        print(f"Found {len(all_transactions)} txs and {len(all_events)} events - Risky contracts here :{address}")
    
    return all_transactions, all_events


def fetch_txs_temp(path: str, max_addresses: int, raw_csv: Optional[str] = None) -> None:
    api_key = load_api_key()
    addresses = extract_addresses_from_csv(path, max_addresses)
    print(f"📄 Extracted {len(addresses)} addresses with approve/allowance patterns from {path}")
    
    all_txs = []
    all_events = []
    risky_txs = []
    
    # Add ThreadPoolExecutor
    from concurrent.futures import ThreadPoolExecutor, as_completed
    
    def fetch_one_address(addr):
        txs, events = get_transactions_and_events(addr, api_key)
        return addr, txs, events
    
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {executor.submit(fetch_one_address, addr): addr for addr in addresses}
        
        for future in as_completed(futures):
            addr, txs, events = future.result()
            
            if txs and events:
                event_tx_hashes = {event.get("transactionHash") for event in events if event.get("transactionHash")}
            else:
                event_tx_hashes = set()
            
            for tx in txs:
                tx["contract_address"] = addr
                tx["record_type"] = "transaction"
                tx["total_approval_calls"] = len(txs)
                tx["total_event_calls"] = len(events)
                
                tx_hash = tx.get("hash")
                if tx_hash not in event_tx_hashes:
                    tx["risky_contract_address"] = addr
                    tx["is_risky"] = True
                    risky_txs.append(tx)
                else:
                    tx["is_risky"] = False
            
            all_txs.extend(txs)
            all_events.extend(events)
            
            print(f"  {addr}: {len(txs)} approve txs, {len(events)} Approval events, "
                  f"{len([tx for tx in txs if tx.get('hash') not in event_tx_hashes])} risky")
    
    # Save to CSV
    if raw_csv and all_txs:
        pd.DataFrame(all_txs).to_csv(raw_csv, index=False)
        print(f"💾 Saved {len(all_txs)} transactions to {raw_csv}")
        print(f"⚠️ Found {len(risky_txs)} risky transactions")

def fetch_transferFrom_txs(path: str,
              max_addresses: int,
              raw_csv: Optional[str] = None,
              ) -> None:
    """
    Extract addresses, fetch their transactions and Approval events,
    save raw and annotated results, and print a summary.
    """
    
    api_key = load_api_key()
    df = pd.read_csv(path)
    addresses = []
    
    for idx, row in df.iterrows():
        
        address = row.get("contract_address")
        
        if address:
            addresses.append(address)
            if len(addresses) >= max_addresses:
                break
    
    
    # addresses = extract_addresses_from_csv(path, max_addresses)
    print(f"📄 Extracted {len(addresses)} addresses with transferFrom patterns from {path}")

    all_txs = []
    risky_txs = []  # Transactions without matching events
    
    
    # for addr in addresses:
    for addr in addresses:
        txs = get_transferFrom_txs(addr, api_key)
        
        all_txs.extend(txs)
        
        print(f"  {addr}: {len(txs)} transferFrom txs")

    # Combine all data into one DataFrame
    combined_data = []
    combined_data.extend(all_txs)
    # combined_data.extend(all_events)
    
    
    # Save to single CSV
    if raw_csv and combined_data:
        pd.DataFrame(combined_data).to_csv(raw_csv, index=False)
        print(f"💾 Saved {len(all_txs)} transactions and events to {raw_csv}")
        


def fetch_txs(path: str,
              max_addresses: int,
              raw_csv: Optional[str] = None,
              ) -> None:
    """
    Extract addresses, fetch their transactions and Approval events,
    save raw and annotated results, and print a summary.
    """
    
    api_key = load_api_key()
    addresses = extract_addresses_from_csv(path, max_addresses)
    print(f"📄 Extracted {len(addresses)} addresses with approve/allowance patterns from {path}")
    
    high_risk_spenders = [
    "0x7a250d5630b4cf539739df2c5dacb4c659f2488d",  # Uniswap V2
    "0xdef1c0ded9bec7f1a1670819833240f027b25eff",  # 0x Exchange
    "0x000000000022d473030f116ddee9f6b43ac78ba3"   # Multisig
    ]

    all_txs = []
    all_events = []
    risky_txs = []  # Transactions without matching events
    
    
    # for addr in addresses:
    for addr in addresses:
        txs, events = get_transactions_and_events(addr, api_key)
        txs, events = get_transactions_and_events(addr, api_key)
        
        # Create a set of transaction hashes that have Approval events
        # event_tx_hashes = {event.get("transactionHash") for event in events if event.get("transactionHash")}
        if txs and events:  # Add this check before creating event_tx_hashes
            event_tx_hashes = {event.get("transactionHash") for event in events if event.get("transactionHash")}
        else:
            event_tx_hashes = set()
        
        # Add contract address and check if transaction has matching event
        for tx in txs:
            tx["contract_address"] = addr
            tx["record_type"] = "transaction"  # Mark as transaction
            tx["total_approval_calls"] = len(txs)
            tx["total_event_calls"] = len(events)
            
            # Check if this transaction has an Approval event
            tx_hash = tx.get("hash")
            if tx_hash not in event_tx_hashes:
                tx["risky_contract_address"] = addr  # Mark as risky
                tx["is_risky"] = True
                risky_txs.append(tx)
            else:
                tx["is_risky"] = False
        
        all_txs.extend(txs)
        
        # Add contract address to events
        # for event in events:
            # event["events_contract_address"] = addr
            # event["record_type"] = "event"  # Mark as event
        
        
        all_events.extend(events)
        
        print(f"  {addr}: {len(txs)} approve txs, {len(events)} Approval events, "
              f"{len([tx for tx in txs if tx.get('hash') not in event_tx_hashes])} risky")

    # Combine all data into one DataFrame
    combined_data = []
    combined_data.extend(all_txs)
    # combined_data.extend(all_events)
    
    
    # Save to single CSV
    if raw_csv and combined_data:
        pd.DataFrame(combined_data).to_csv(raw_csv, index=False)
        print(f"💾 Saved {len(all_txs)} transactions and {len(all_events)} events to {raw_csv}")
        print(f"⚠️ Found {len(risky_txs)} risky transactions (included in file)")
    
def check_csv_columns(csv_path: str):
    """Add ERC type columns based on bytecode signatures"""
    df = pd.read_csv(csv_path)
    
    # dd62ed3e-allowance
        # 095ea7b3-approve
        # 081812fc-getApproved
        # a22cb465-setApprovalForAll
        # e985e9c5-isApprovedForAll
        # 2eb2c2d6-SafeBAtchTransferFrom
        # b88d4fde-SafeTransferFrom with data
        # 42842e0e-SafeTransferFrom
    
    # Initialize new columns
    df['ERC-20'] = False
    df['ERC-721'] = False
    df['ERC-1155'] = False
    
    for idx, row in df.iterrows():
        bytecode = str(row.get("bytecode", ""))
        
        # ERC-20: has approve and allowance
        if "095ea7b3" in bytecode and "dd62ed3e" in bytecode:
            df.at[idx, 'ERC-20'] = True
        
        # ERC-721: has setApprovalForAll and safeTransferFrom variants
        if "a22cb465" in bytecode and "b88d4fde" in bytecode and "42842e0e" in bytecode:
            df.at[idx, 'ERC-721'] = True
        
        # ERC-1155: has setApprovalForAll and safeBatchTransferFrom
        if "a22cb465" in bytecode and "2eb2c2d6" in bytecode:
            df.at[idx, 'ERC-1155'] = True
    
    # Print counts
    print(f"📊 Total rows: {len(df)}")
    print(f"  ERC-20: {df['ERC-20'].sum()}")
    print(f"  ERC-721: {df['ERC-721'].sum()}")
    print(f"  ERC-1155: {df['ERC-1155'].sum()}")
    
    return df

def analyse_OnReceived(path: str, annotated_csv: Optional[str]) -> None:
    """
    Analyze transactions for ERC1155 onERC1155BatchReceived implementation checks
    
    Args:
        path: Path to CSV file containing transaction data with 'decoded_to' column
        annotated_csv: Optional path to save annotated results
    """
    api_key = load_api_key()
    
    # Read CSV directly into DataFrame (more efficient than dict conversion)
    df = pd.read_csv(path)
    
    # Check if required column exists
    if 'decoded_to' not in df.columns:
        print("❌ Error: 'decoded_to' column not found in the CSV file")
        return
    
    print(f"📊 Loaded {len(df)} transactions from {path}")
    
    # Pass DataFrame directly to the analysis function
    analysed_with_contracts = augment_with_contract_checks(df, api_key)
    
    if analysed_with_contracts['to_is_contract'].dtype == 'object':
        analysed_with_contracts['to_is_contract'] = analysed_with_contracts['to_is_contract'].astype(bool)
    if analysed_with_contracts['on_batch_received_impl'].dtype == 'object':
        analysed_with_contracts['on_batch_received_impl'] = analysed_with_contracts['on_batch_received_impl'].astype(bool)
    
    # Debug: Check what's in your columns
    # print("Column dtypes:")
    # print(analysed_with_contracts.dtypes)

    print("Sample values:")
    print(analysed_with_contracts[['to_is_contract', 'on_batch_received_impl']].head())

    print("Unique values in to_is_contract:")
    print(analysed_with_contracts['to_is_contract'].unique())
    
    # Filter rows where either check is False
    false_rows = analysed_with_contracts[
        (~analysed_with_contracts['to_is_contract']) | 
        (~analysed_with_contracts['on_batch_received_impl'])
    ]
    
    print(f"🔍 Number of problematic transactions: {len(false_rows)}")
    
    if len(false_rows) > 0:
        # Display summary of problematic transactions
        print("\n📋 Problematic Transactions Summary:")
        print(false_rows[['decoded_to', 'to_is_contract', 'on_batch_received_impl']].head(10))
        
        if len(false_rows) > 10:
            print(f"... and {len(false_rows) - 10} more")
    
    # Save results based on annotated_csv parameter
    if annotated_csv:
        # Save only the problematic rows to the specified annotated CSV
        false_rows.to_csv(annotated_csv, index=False)
        print(f"✅ Annotated results saved to {annotated_csv}")
    else:
        # Save to default location if no annotated_csv provided
        false_rows.to_csv("false_contract_checks.csv", index=False)
        print("✅ Results saved to false_contract_checks.csv")
    
    # Print final statistics
    total_contracts = analysed_with_contracts['to_is_contract'].sum()
    total_with_receiver = analysed_with_contracts['on_batch_received_impl'].sum()
    
    print(f"\n📈 Final Statistics:")
    print(f"   Total transactions: {len(analysed_with_contracts)}")
    print(f"   To contract addresses: {total_contracts}")
    print(f"   Contracts with onERC1155BatchReceived: {total_with_receiver}")
    print(f"   At-risk transactions: {len(false_rows)}")

def augment_with_contract_checks(df: pd.DataFrame, api_key: str) -> pd.DataFrame:
    """
    For each row in a DataFrame of decoded safeBatchTransferFrom transactions,
    determine whether the 'to' address is a contract and whether it implements
    the ERC-1155 onERC1155BatchReceived interface. Two new boolean columns
    are added: 'to_is_contract' and 'on_batch_received_impl'.

    This function uses the Etherscan API:
      * proxy.eth_getCode to check if there is bytecode at the address
      * contract.getabi to retrieve the contract's ABI and look for
        onERC1155BatchReceived.

    Args:
        df: A pandas DataFrame with at least a 'decoded_to' column (if present)
            and a 'to' column (the destination address). It may also have other
            columns from analyse_transactions.
        api_key: Your Etherscan API key.

    Returns:
        The input DataFrame with two new columns populated.
    """
    # Prepare new columns
    df['to_is_contract'] = False
    df['on_batch_received_impl'] = False
    df['to_address_zero'] = False

    # Cache results per contract address to minimise API calls
    contract_cache: Dict[str, Tuple[bool, bool]] = {}
    
    print("🔍 Checking contract addresses via Etherscan API...")

    for idx, row in df.iterrows():
        # Prefer the decoded 'to' address if present; fall back to raw 'to'
        to_addr = row.get('decoded_to') or row.get('to')
        if not isinstance(to_addr, str) or not to_addr.startswith('0x'):
            continue
        to_addr = to_addr.lower()

        # Skip the zero address
        if to_addr.startswith('0x00000000000000'):
            df['to_address_zero'] = True
            continue

        # Use cached results if we've already inspected this address
        if to_addr in contract_cache:
            is_contract, has_receiver = contract_cache[to_addr]
        else:
            # 1. Check if there is bytecode at the address using eth_getCode
            code_url = (
                "https://api.etherscan.io/api"
                f"?module=proxy&action=eth_getCode"
                f"&address={to_addr}"
                f"&apikey={api_key}"
            )
            try:
                code_resp = requests.get(code_url, timeout=10).json()
                code_result = code_resp.get("result", "")
            except Exception as e:
                print(f"⚠️  Error checking code for {to_addr}: {e}")
                code_result = ""
            is_contract = (code_result and code_result != "0x")

            has_receiver = False
            if is_contract:
                # 2. Fetch the ABI and check for onERC1155BatchReceived
                abi_url = (
                    "https://api.etherscan.io/api"
                    f"?module=contract&action=getabi"
                    f"&address={to_addr}"
                    f"&apikey={api_key}"
                )
                try:
                    abi_resp = requests.get(abi_url, timeout=10).json()
                    if abi_resp.get("status") == "1":
                        abi_str = abi_resp.get("result")
                        abi = json.loads(abi_str)
                        for entry in abi:
                            if (
                                entry.get("type") == "function"
                                and entry.get("name") == "onERC1155BatchReceived"
                            ):
                                has_receiver = True
                                break
                except Exception as e:
                    print(f"⚠️  Error fetching ABI for {to_addr}: {e}")
                    has_receiver = False

            # Cache the result
            contract_cache[to_addr] = (is_contract, has_receiver)
            
            # Progress indicator for large datasets
            # if len(contract_cache) % 10 == 0:
            #     print(f"   Checked {len(contract_cache)} unique addresses...")

        df.at[idx, 'to_is_contract'] = is_contract
        df.at[idx, 'on_batch_received_impl'] = has_receiver

    print(f"✅ Completed checking {len(contract_cache)} unique contract addresses")
    return df


def main():
    parser = argparse.ArgumentParser(
        description="Extract and analyse ERC‑1155 safeBatchTransferFrom transactions for possible exploits."
    )
    # parser.add_argument('--json', required=True,
    #                     help='Path to the JSON file containing contract metadata')
    # parser.add_argument('--csv', required=True,
    #                     help='Path to the CSV file containing contract metadata')
    # parser.add_argument('--num-addresses', type=int, default=10,
    #                     help='Number of addresses to process (default 10)')
    # parser.add_argument('--raw-csv', default=None,
    #                     help='Optional file path to save raw transaction data')

    args = parser.parse_args()
    eth_bytecode_contracts = '/Users/ashokk/Downloads/evm_data/ethereum_deduplicated_results.csv'
    eth_erc20_txs = '/Users/ashokk/Downloads/evm_data/output_ethereum_txs_60k.csv' 
    eth_erc20_txs_secondary_approvals = '/Users/ashokk/Downloads/evm_data/output_ethereum_txs_secondary_approvals_60k.csv' 
    
    eth_erc20_txs_ownTranfer_check = '/Users/ashokk/Downloads/evm_data/output_ethereum_txs_ownTranfer_check.csv' 
    
    # eth_erc20_txs_test = '/Users/ashokk/Downloads/evm_data/output_ethereum_txs_test.csv' 
    
    # columns = check_csv_columns(eth_bytecode_contracts)
    # print(f"\nTotal columns: {len(columns)}")
    
    # fetch_txs(eth_bytecode_contracts, 6000 , eth_erc20_txs)
    fetch_transferFrom_txs(eth_erc20_txs_secondary_approvals, 56 , eth_erc20_txs_ownTranfer_check)
    
    df = pd.read_csv(eth_erc20_txs_ownTranfer_check, low_memory=False)
    df['functionName'] = df['functionName'].fillna('')  # Replace NaN with empty string
    txs_list = df.to_dict('records')
    # df_analyzed = analyse_approve_txs(txs_list)
    
    
    df_analyzed = analyse_ownTransfer_by_caller(txs_list)
    for col in ['own_transfer_caller_address', 'own_transfer_to_address']:
        if col in df_analyzed.columns:
            df[col] = df_analyzed[col]

    # Save with new columns
    df.to_csv(eth_erc20_txs_ownTranfer_check, index=False)
    
    
    
    
    # # Merge analyzed columns back to original DataFrame
    # for col in ['decoded_spender', 'money_to_spend', 'spender_provides_further_approvals', 
    #             'secondary_approvals_count', 'approval_chain_depth', 'approval_chain_details']:
    #     if col in df_analyzed.columns:
    #         df[col] = df_analyzed[col]

    # # Save with new columns
    # df.to_csv(eth_erc20_txs_ownTranfer_check, index=False)
    
    # # ========== FILTER: Keep only secondary approvals ==========
    # secondary_approvals = df[df["spender_provides_further_approvals"] == True]
    
    # # Save filtered results
    # secondary_approvals.to_csv(eth_erc20_txs_secondary_approvals, index=False)
    
    # print(f"🔗 Found {len(secondary_approvals)} secondary approval transactions")
    # print(f"💾 Saved to {eth_erc20_txs}")
    
    
    #     # Print summary of secondary approvals
    # secondary_approvals = df_analyzed[df_analyzed["spender_provides_further_approvals"] == True]
    # print(f"🔗 Found {len(secondary_approvals)} transactions where spender provides further approvals")
    
    

    
    
    
    

if __name__ == "__main__":
    main()
