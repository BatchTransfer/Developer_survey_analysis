import os
import re
import json
from typing import List, Dict, Optional, Set, Tuple
from eth_utils import keccak
import pandas as pd
import matplotlib.pyplot as plt
import pandas as pd
import requests
import time
from pathlib import Path


from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock


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

def find_functions_by_signature(functions: List[Dict], target_signature: str) -> List[Dict]:
    """Find all functions matching the normalized signature with parameter types."""
    # print(f"target_signature:{target_signature}")
    target_normalized = normalize_signature(target_signature)
    # print(f"target_normalized:{target_normalized}")
    target_normalized_hash = keccak(text=target_normalized).hex()
    # print(f"target_normalized_hash:{target_normalized_hash}")
    matching_functions = []
    
    for func in functions:
        current_sig = f"{func['name']}({func['params']})"
        current_normalized = normalize_signature(current_sig)
        # print(f"current_normalized:{current_normalized}")
        current_normalized_hash = keccak(text=current_normalized).hex()
        
        if current_normalized_hash == target_normalized_hash :
            print(f"current_normalized_hash:{current_normalized_hash}")
            # Add parameters to function info
            func['parameters'] = get_parameter_dict(func['params'])
            matching_functions.append(func)
    
    # print(f"matching_functions:{len(matching_functions)}")
    return matching_functions

def get_all_internal_calls(function_body: str, all_functions: List[Dict], visited: Set[str] = None) -> List[Dict]:
    """Recursively get all internal function calls (including nested calls)."""
    if visited is None:
        visited = set()
    
    internal_calls = []
    
    # Split code into tokens to better identify function calls
    tokens = re.split(r'(\W)', function_body)  # Split on non-word characters
    tokens = [t for t in tokens if t.strip()]  # Remove empty tokens
    
    i = 0
    while i < len(tokens):
        token = tokens[i]
        
        # Look for potential function calls (identifier followed by parenthesis)
        if (token.isidentifier() and i+1 < len(tokens) and 
            tokens[i+1] == '(' and 
            token not in visited):
            
            call_name = token
            # print(f"call_name:{call_name}")
            
            # Skip keywords and built-ins
            if (call_name.lower() in {
                'require', 'assert', 'revert', 'emit', 'new', 'return',
                'returns', 'if', 'try', 'iscontract', 'continue', 'break',
                'for', 'while', 'do', 'else', 'catch', 'delete', 'length'
            } or call_name in {
                'gasleft', 'msg', 'block', 'tx', 'abi', 'type', 'this', 'selfdestruct', 'sha3', 'keccak256', 'ripemd160',
                'ecrecover', 'addmod', 'mulmod', 'balance', 'sub', 'add'
            }):
                i += 1
                continue
            
            # Skip library calls (those with dots)
            if '.' in call_name:
                i += 1
                continue
            
            # Find matching function definition
            for func in all_functions:
                if func['name'] == call_name:
                    # # Skip self-references
                    # if func['body'] == function_body:
                    #     continue
                    
                    # Only process if we haven't visited this function before
                    # if call_name not in visited:
                    #     visited.add(call_name)
                    
                    if func['body'] != function_body:
                        
                        visited.add(call_name)
                        internal_calls.append(func)
                        # Recursively get calls from this function
                        nested_calls = get_all_internal_calls(func['body'], all_functions, visited)
                        if nested_calls:  # Only extend if we got valid results
                            internal_calls.extend(nested_calls)
            
            # Skip past the parameters
            paren_count = 1
            i += 2  # Skip past '('
            while i < len(tokens) and paren_count > 0:
                if tokens[i] == '(':
                    paren_count += 1
                elif tokens[i] == ')':
                    paren_count -= 1
                i += 1
        else:
            i += 1
    
    return internal_calls if internal_calls else None


def find_if_revert_control_flow(code: str):
    """Find all if conditions containing revert statements"""
    conditions = []
    pos = 0
    code_len = len(code)
    
    while pos < code_len:
        # Find the next 'if' keyword
        if_pos = code.find('if', pos)
        if if_pos == -1:
            break
            
        # Check if it's a real if statement (not part of another word)
        if if_pos > 0 and (code[if_pos-1].isalnum() or code[if_pos-1] == '_'):
            pos = if_pos + 2
            continue
            
        # Find the opening parenthesis after 'if'
        paren_pos = code.find('(', if_pos)
        if paren_pos == -1 or paren_pos > if_pos + 10:  # Allow some whitespace
            pos = if_pos + 2
            continue
            
        # Find matching closing parenthesis
        paren_level = 1
        end_pos = paren_pos + 1
        while end_pos < code_len and paren_level > 0:
            if code[end_pos] == '(':
                paren_level += 1
            elif code[end_pos] == ')':
                paren_level -= 1
            end_pos += 1
            
        if paren_level != 0:
            pos = if_pos + 2
            continue
            
        # Look for revert in the if block (either single line or braced)
        block_start = end_pos
        block_end = code.find('}', block_start)
        semi_pos = code.find(';', block_start)
        
        # Determine the block end position
        if block_end == -1 or (semi_pos != -1 and semi_pos < block_end):
            block_end = semi_pos
        if block_end == -1:
            pos = if_pos + 2
            continue
            
        # Check for revert in this block
        revert_pos = code.find('revert', block_start, block_end)
        if revert_pos != -1:
            # Extract the condition
            condition = code[paren_pos+1:end_pos-1].strip()
            condition = re.sub(r'\s+', ' ', condition)
            conditions.append(condition)
            
        pos = end_pos
        
    return conditions

def extract_parameters_data_flow_analysis(target_func: Dict) -> Dict:
    """Extract and return all relevant parameters from the target function."""
    params = list(target_func.get('parameters', {}).items())
    return {
        'from_param': params[0][0] if len(params) > 0 else None,
        'to_param': params[1][0] if len(params) > 1 else None,
        'ids_param': params[2][0] if len(params) > 2 else None,
        'amounts_param': params[3][0] if len(params) > 3 else None,
        'data_param': params[4][0] if len(params) > 4 else None
    }

def extract_setApprovalForAll_parameters(target_func: Dict) -> Dict:
    """Extract and return all relevant parameters from the target function."""
    params = list(target_func.get('parameters', {}).items())
    return {
        'owner_param': params[0][0] if len(params) > 0 else None,
        'operator_param': params[0][0] if len(params) > 1 else None,
        'approved_param': params[1][0] if len(params) > 2 else None
        
    }
    

def perform_data_flow_analysis(all_code: List[Tuple[str, str]], ids_param: str) -> Dict:
    """Find all length assignments in the provided code."""
    length_assignments = {}
    for code, source in all_code:
        # Look for both direct and indirect length assignments
        matches = re.finditer(
            rf'uint256\s+(\w+)\s*=\s*{re.escape(ids_param)}\s*\.\s*length\s*;',
            code,
            re.DOTALL
        )
        for match in matches:
            var_name = match.group(1)
            length_assignments[var_name] = {
                'source': source,
                'full_match': match.group(0)
            }
    return length_assignments

def contains_assembly(code):
    """Check for inline assembly in Solidity code"""
    if isinstance(code, str):
        patterns = [
            r'assembly\s*{',       # Standard assembly block
            r'assembly\s*\w*\s*{', # With EVM dialect
            r'let\s+\w+\s*:=',     # Assembly variable declaration
            r'mload\(|sload\('     # Common assembly ops
        ]
        return any(re.search(p, code, re.IGNORECASE) for p in patterns)
    elif isinstance(code, dict):
        return any(contains_assembly(part) for part in code.values())
    return False

def verify_erc1155_requirements(target_func: Dict, internal_functions: List[Dict]) -> Dict:
    
    
    """Verify if the function and its internal calls meet ERC1155 requirements."""
    requirements = {
        'sender_check': False,
        'approval_check': False,
        'zero_address_check': False,
        'length_matching_check': False,
       
        'event_emission_order': False,
        'transfer_batch_event_found': False,
        'to_isContract_check':False,
        'on_received_check': False, 
        # 'gas_family_errors': False, 
        
        
    }
    #  'balance_checks': False,
    
    params = extract_parameters_data_flow_analysis(target_func)
    from_param = params['from_param']
    to_param = params['to_param']
    ids_param = params['ids_param']
    amounts_param = params['amounts_param']
    data_param = params['data_param']
    
    # Combine all code to analyze (main function + internal calls)
    # Interprocedural Analysis
    all_code = [(target_func['body'], "main function")]
    for func in internal_functions:
        # print(f"func['body']:{func['body']}")
        
        # if target_func['body'] != func['body'] and len(internal_functions) != 1:
        all_code.append((func['body'], f"internal function {func['name']}"))
        
         
        
    # Find all length assignments first
    length_assignments = perform_data_flow_analysis(all_code, ids_param) if ids_param else {}
    all_conditions = []
    event_pos = None
    
    
    
    # Forward Flow Analysis - main analysis loop
    for code, source in all_code:
        
        condition_matches = []
        # Pattern for require statements
        require_pattern = r'require\s*\(((?:[^()]|\((?:[^()]|\([^()]*\))*\))*)\)'
        # Find all require matches
        require_matches = re.finditer(require_pattern, code, re.DOTALL)
        
        for match in require_matches:
            req_content = re.sub(r'\s+', ' ', match.group(1).strip())
            condition_matches.append((req_content, source, 'require'))
        
        # Usage in your code:
        if_revert_conditions = find_if_revert_control_flow(code)
        
        for condition in if_revert_conditions:
            condition_matches.append((condition, source, 'if-revert'))
            
        all_conditions.extend(condition_matches)
    
    
    # Possible sender representations
    sender_reprs = ['msg.sender', '_msgSender()', 'sender']
    
    
    
    # Check conditions
    for condition_content, condition_source, condition_type in all_conditions:
        # Check for sender condition
        # Check for sender condition
        if from_param and not requirements['sender_check']:
            for sender in sender_reprs:
                if condition_type == "if-revert":
                    
                    # Basic inequality checks (complete conditions)
                    pattern1 = rf'{re.escape(sender)}\s*!=\s*{from_param}'
                    pattern2 = rf'{from_param}\s*!=\s*{re.escape(sender)}'
                    
                    # Combined sender and approval check
                    pattern3 = rf'if\s*\(\s*{re.escape(sender)}\s*!=\s*{from_param}\s*&&\s*!isApprovedForAll\(\s*{from_param}\s*,\s*{re.escape(sender)}\s*\)\s*\)'
                    
                    # New patterns for partial conditions
                    pattern4 = rf'if\s*\(\s*{from_param}\s*!=\s*{re.escape(sender)}'  # matches "if (from != sender"
                    pattern5 = rf'if\s*\(\s*{re.escape(sender)}\s*!=\s*{from_param}'  # matches "if (sender != from"
                    
                    if (re.search(pattern1, condition_content) or 
                        re.search(pattern2, condition_content) or
                        re.search(pattern3, condition_content) or 
                        re.search(pattern4, condition_content) or
                        re.search(pattern5, condition_content)):
                        requirements['sender_check'] = True
                        break
                    
                if condition_type == "require":
                    pattern6 = rf'{re.escape(sender)}\s*==\s*{from_param}'
                    pattern7 = rf'{from_param}\s*==\s*{re.escape(sender)}'
                    if re.search(pattern6, condition_content) or re.search(pattern7, condition_content):
                        requirements['sender_check'] = True
                        break

        # Check for approval condition
        if from_param and not requirements['approval_check']:
            for sender in sender_reprs:
                if condition_type == "if-revert":
                    
                    pattern1 = rf'!isApprovedForAll\(\s*{from_param}\s*,\s*{re.escape(sender)}\s*\)'
                    exact_pattern1 = rf'operatorApproval\[{from_param}\]\[{re.escape(sender)}\]\s*==\s*false'
                    # New pattern for mapping-style access
                    mapping_pattern1 = rf'!isApprovedForAll\[{from_param}\]\[{re.escape(sender)}\]'
                    # New pattern for combined check with revert
                    pattern2 = rf'if\s*\(\s*{re.escape(sender)}\s*!=\s*{from_param}\s*&&\s*!isApprovedForAll\(\s*{from_param}\s*,\s*{re.escape(sender)}\s*\)\s*\)\s*{{\s*revert\s*ERC1155MissingApprovalForAll\(\s*{re.escape(sender)}\s*,\s*{from_param}\s*\)'
                    if (re.search(pattern1, condition_content) or 
                        re.search(exact_pattern1, condition_content, re.IGNORECASE) or
                        re.search(mapping_pattern1, condition_content) or
                        re.search(pattern2, condition_content)):
                        requirements['approval_check'] = True
                        break
                    if not requirements['approval_check']:
                        if (re.search(r'Approval', condition_content, re.IGNORECASE) and
                            re.search(rf'{from_param}', condition_content) and
                            re.search(rf'{re.escape(sender)}', condition_content) and
                            re.search(r'false', condition_content, re.IGNORECASE)):
                            requirements['approval_check'] = True
                            break
                if condition_type == "require":
                    pattern3 = rf'isApprovedForAll\(\s*{from_param}\s*,\s*{re.escape(sender)}\s*\)'
                    exact_pattern2 = rf'operatorApproval\[{from_param}\]\[{re.escape(sender)}\]\s*==\s*true'
                    # New pattern for mapping-style access in require
                    mapping_pattern2 = rf'isApprovedForAll\[{from_param}\]\[{re.escape(sender)}\]'
                    # New pattern for specific case you mentioned
                    specific_case_pattern = rf'require\(\s*isApprovedForAll\[{from_param}\]\[{re.escape(sender)}\]\s*,\s*[\'"]NOT_AUTHORIZED[\'"]\s*\)'
                    
                    if (re.search(pattern3, condition_content) or 
                        re.search(exact_pattern2, condition_content, re.IGNORECASE) or
                        re.search(mapping_pattern2, condition_content) or
                        re.search(specific_case_pattern, condition_content)):
                        requirements['approval_check'] = True
                        break
                    if not requirements['approval_check']:
                        if (re.search(r'Approval', condition_content, re.IGNORECASE) and
                            re.search(rf'{from_param}', condition_content) and
                            re.search(rf'{re.escape(sender)}', condition_content) and
                            re.search(r'true', condition_content, re.IGNORECASE)):
                            requirements['approval_check'] = True
                            break
        
        # Check for zero address condition
        if to_param and not requirements['zero_address_check']:
            
            if condition_type == "if-revert":
                zero_addr_pattern1 = [
                    rf'{to_param}\s*==\s*address\(0\)',
                    rf'address\(0\)\s*==\s*{to_param}',
                    rf'{to_param}\s*==\s*address\(0x0\)',
                    rf'address\(0x0\)\s*==\s*{to_param}',
                    rf'recipient\s*==\s*address\(0\)',  # Added recipient check
                    rf'recipient\s*==\s*address\(0x0\)'  # Added recipient check
                ]
                for pattern in zero_addr_pattern1:
                    if re.search(pattern, condition_content):
                        
                        requirements['zero_address_check'] = True
                        break
                    
            if condition_type == "require":
                zero_addr_pattern2 = [
                    rf'{to_param}\s*!=\s*address\(0\)',
                    rf'address\(0\)\s*!=\s*{to_param}',
                    rf'{to_param}\s*!=\s*address\(0x0\)',
                    rf'address\(0x0\)\s*!=\s*{to_param}',
                    rf'recipient\s*!=\s*address\(0\)',  # Added recipient check
                    rf'recipient\s*!=\s*address\(0x0\)',  # Added recipient check
                    rf'require\s*\(\s*recipient\s*!=\s*address\(0\)\s*,\s*[\'"]ERC1155:\s*transfer\s*to\s*the\s*zero\s*address[\'"]\s*\)'  # Specific ERC1155 case
                ]
                for pattern in zero_addr_pattern2:
                    if re.search(pattern, condition_content):
                        
                        requirements['zero_address_check'] = True
                        break
        
       
        # Check for length matching condition
        if ids_param and amounts_param and not requirements['length_matching_check']:
            assigned_var = None
            # Check direct length comparisons
            direct_patterns = [
                rf'{ids_param}\.length\s*[!=]=\s*{amounts_param}\.length',
                rf'{amounts_param}\.length\s*[!=]=\s*{ids_param}\.length',
                rf'{ids_param}\.length\s*[==]=\s*{amounts_param}\.length',
                rf'{amounts_param}\.length\s*[==]=\s*{ids_param}\.length',
               
                ]
            
            direct_patterns1 = [
                r'\.length\s*!=\s*\.length',
                r'\.length\s*==\s*\.length'
                ]
            # direct_patterns = [
            #     rf'{ids_param}\.length\s*[!=]=\s*{amounts_param}\.length',
            #     rf'{amounts_param}\.length\s*[!=]=\s*{ids_param}\.length',
            #     r'(?!(?:ids|values?|amounts?)\.length\s*!=\s*(?:ids|values?|amounts?)\.length)'
            #     r'([A-Za-z_][A-Za-z0-9_]*)\.length\s*!=\s*([A-Za-z_][A-Za-z0-9_]*)\.length'
            # ]


            assigned_patterns = []
            for var_name in length_assignments:
                assigned_patterns.extend([
                    rf'{var_name}\s*[!=]=\s*{amounts_param}\.length',
                    rf'{amounts_param}\.length\s*[!=]=\s*{var_name}'
                ])
            if any(re.search(p, condition_content) for p in direct_patterns + assigned_patterns+direct_patterns1):
                requirements['length_matching_check'] = True
  
        # # Check for balance checks
        # if from_param and ids_param and amounts_param and not requirements['balance_checks']:
        #     balance_pattern = rf'balanceOf\(\s*{from_param}\s*,\s*{ids_param}\[i\]\)\s*>=\s*{amounts_param}\[i\]'
        #     if re.search(balance_pattern, condition_content):
        #         requirements['balance_checks'] = True
    
    
    # Check for event emission and onReceived in the code
    # Backward Flow Analysis - event position tracking
    for code, source in all_code:
        # Event emission check
        if 'emit TransferBatch(' in code and not requirements['transfer_batch_event_found']:
            requirements['transfer_batch_event_found'] = True
            event_pos = (source, code.find('emit TransferBatch('))
        
        # Check if transfers happen after event emission
        if requirements['transfer_batch_event_found'] and source == event_pos[0]:
            event_pos_num = event_pos[1]
            post_event_code = code[event_pos_num:]
            if 'safeTransferFrom(' in post_event_code or 'safeBatchTransferFrom(' in post_event_code:
                requirements['event_emission_order'] = False
            else:
                requirements['event_emission_order'] = True
        # Normalize code by removing comments and extra spaces
        normalized_code = re.sub(r'//.*?\n|/\*.*?\*/', '', code, flags=re.DOTALL)
        normalized_code = re.sub(r'\s+', ' ', normalized_code)
        
    
        # 1. Check for isContract() guard
        contract_check_patterns = [
        # Standard if(isContract()) checks
        rf'if\s*\(\s*{to_param}\s*\.\s*isContract\s*\(\s*\)\s*\)',
        ]
        contract_check_patterns1 = [
        
        # Various code.length comparisons
        rf'if\s*\(\s*{to_param}\s*\.\s*code\s*\.\s*length\s*[!=]=\s*0\s*\)',
        rf'if\s*\(\s*{to_param}\s*\.\s*code\s*\.\s*length\s*>\s*0\s*\)',
        ]
        contract_check_patterns2 = [
        # Ternary require checks
        rf'require\s*\(\s*{to_param}\s*\.\s*code\s*\.\s*length\s*==\s*0\s*\?\s*{to_param}\s*!=\s*address\s*\(\s*0\s*\)',
        rf'require\s*\(\s*{to_param}\s*\.\s*code\s*\.\s*length\s*==\s*0\s*\?\s*{to_param}\s*!=\s*0x0\b',
        rf'require\s*\(\s*{to_param}\s*\.\s*code\s*\.\s*length\s*==\s*0\s*\?\s*{to_param}\s*!=\s*address\s*\(\s*0\s*\)\s*:'
        ]

        if any(re.search(pattern, normalized_code) for pattern in contract_check_patterns1):
            requirements['to_isContract_check'] = True
            print(f"contract_check_patterns1")
        if any(re.search(pattern, normalized_code) for pattern in contract_check_patterns2):
            requirements['zero_address_check'] = False
            requirements['to_isContract_check'] = True
            requirements['event_emission_order'] = False
            requirements['on_received_check'] = True
            print(f"contract_check_patterns2")
        if any(re.search(pattern, normalized_code) for pattern in contract_check_patterns):
            requirements['to_isContract_check'] = True
            print(f"contract_check_patterns")
        # Check for onReceived implementation in functions called after the event
        if event_pos and source != event_pos[0]:
            if requirements['to_isContract_check'] and check_on_received_implementation(code, params, requirements['to_isContract_check']):
                requirements['on_received_check'] = True
            elif not requirements['to_isContract_check'] and check_on_received_implementation(code, params, requirements['to_isContract_check']):
                requirements['on_received_check'] = True

    return requirements



def verify_erc3643_batchTransfer_requirements(target_func: Dict, internal_functions: List[Dict]) -> Dict:

    erc3643_requirements = {
        # 'erc3643_sender_check': False,
        'erc3643_zero_address_check_from': False,
        'erc3643_zero_address_check_to': False,
        'erc3643_frozen_wallet_check': False,
        'erc3643_balance_check': False,
        'erc3643_identity_registry_check': False,
        'erc3643_compliance_check': False,
        # 'erc3643_length_matching_check': False,
        'erc3643_event_emission_check': False
    }

    params = extract_parameters_data_flow_analysis(target_func)
    erc3643_from_param = 'msg.sender'
    erc3643_to_param = 'to'
    erc3643_amounts_param = 'amount'

    all_code = [(target_func['body'], "main function")]
    for func in internal_functions:
        all_code.append((func['body'], f"internal function {func['name']}"))

    for code, source in all_code:
        # # 1. Length matching check
        # if not erc3643_requirements['erc3643_length_matching_check']:
        #     length_pattern = rf'{erc3643_to_param}\.length\s*==\s*{erc3643_amounts_param}\.length'
        #     if re.search(length_pattern, code):
        #         erc3643_requirements['erc3643_length_matching_check'] = True

        # 2. Zero address checks (for _from, which is msg.sender, and _to inside loop)
        if not erc3643_requirements['erc3643_zero_address_check_from']:
            zero_from_patterns = [
                rf'{erc3643_from_param}\s*!=\s*address\(0\)',
                rf'{erc3643_from_param}\s*!=\s*0x0',
                rf'from\s*!=\s*address\(0\)',
                rf'from\s*!=\s*0x0'
            ]
            if any(re.search(p, code) for p in zero_from_patterns):
                erc3643_requirements['erc3643_zero_address_check_from'] = True

        if not erc3643_requirements['erc3643_zero_address_check_to']:
            zero_to_patterns = [
                rf'{erc3643_to_param}\[i\]\s*!=\s*address\(0\)',
                rf'{erc3643_to_param}\[i\]\s*!=\s*0x0',
                 rf'to\s*!=\s*address\(0\)',
                rf'to\s*!=\s*0x0'
            ]
            if any(re.search(p, code) for p in zero_to_patterns):
                erc3643_requirements['erc3643_zero_address_check_to'] = True

        # 3. Frozen wallet checks
        if not erc3643_requirements['erc3643_frozen_wallet_check']:
            frozen_pattern = r'!frozen\[\s*(msg\.sender|_from|_to)\s*\]'
            if re.search(frozen_pattern, code):
                erc3643_requirements['erc3643_frozen_wallet_check'] = True

        # 4. Balance check
        if not erc3643_requirements['erc3643_balance_check']:
            balance_pattern = rf'_balances\[\s*{erc3643_from_param}\s*\]\s*>=\s*{erc3643_amounts_param}'
            if re.search(balance_pattern, code):
                erc3643_requirements['erc3643_balance_check'] = True

        # 5. Identity registry check (isVerified)
        if not erc3643_requirements['erc3643_identity_registry_check']:
            id_registry_pattern = rf'tokenIdentityRegistry\.isVerified\(\s*{erc3643_to_param}\s*\)'
            if re.search(id_registry_pattern, code):
                erc3643_requirements['erc3643_identity_registry_check'] = True

        # 6. Compliance check (canTransfer)
        if not erc3643_requirements['erc3643_compliance_check']:
            compliance_pattern = rf'tokenCompliance\.canTransfer\(\s*{erc3643_from_param}\s*,\s*{erc3643_to_param}\s*,\s*{erc3643_amounts_param}\s*\)'
            if re.search(compliance_pattern, code):
                erc3643_requirements['erc3643_compliance_check'] = True

        # 7. Event emission check
        if not erc3643_requirements['erc3643_event_emission_check']:
            if re.search(r'emit\s+Transfer\(', code):
                erc3643_requirements['erc3643_event_emission_check'] = True

        # # 8. Sender check (normally implicit, but we still verify)
        # if not erc3643_requirements['erc3643_sender_check']:
        #     if erc3643_from_param in code:
        #         erc3643_requirements['erc3643_sender_check'] = True

    return erc3643_requirements



def verify_erc3643_batchForcedTransfer_requirements(target_func: Dict, internal_functions: List[Dict]) -> Dict:

    erc3643_forced_requirements = {
        'length_matching_check': False,
        'zero_address_check_from': False,
        'zero_address_check_to': False,
        'frozen_tokens_unfreeze_check': False,
        'frozen_tokens_balance_check': False,
        'identity_registry_check': False,
        'compliance_check': False,
        'unfreeze_event_check': False,
        'transfer_event_check': False
    }

    # Assume function parameters as per forced transfer
    from_list_param = 'from'
    to_list_param = 'to'
    amounts_param = 'amount'

    all_code = [(target_func['body'], "main function")]
    for func in internal_functions:
        all_code.append((func['body'], f"internal function {func['name']}"))

    for code, source in all_code:
        # 1. Length matching check
        if not erc3643_forced_requirements['length_matching_check']:
            length_pattern = rf'{from_list_param}\.length\s*==\s*{to_list_param}\.length\s*&&\s*{to_list_param}\.length\s*==\s*{amounts_param}\.length'
            length_pattern_simple = rf'{from_list_param}\.length\s*==\s*{to_list_param}\.length'
            if re.search(length_pattern, code) or re.search(length_pattern_simple, code):
                erc3643_forced_requirements['length_matching_check'] = True

        # 2. Zero address check for _from
        if not erc3643_forced_requirements['zero_address_check_from']:
            zero_from_patterns = [
                rf'{from_list_param}\[i\]\s*!=\s*address\(0\)',
                rf'{from_list_param}\[i\]\s*!=\s*0x0'
            ]
            if any(re.search(p, code) for p in zero_from_patterns):
                erc3643_forced_requirements['zero_address_check_from'] = True

        # 3. Zero address check for _to
        if not erc3643_forced_requirements['zero_address_check_to']:
            zero_to_patterns = [
                rf'{to_list_param}\[i\]\s*!=\s*address\(0\)',
                rf'{to_list_param}\[i\]\s*!=\s*0x0'
            ]
            if any(re.search(p, code) for p in zero_to_patterns):
                erc3643_forced_requirements['zero_address_check_to'] = True

        # 4. Frozen token unfreeze logic (freeBalance / frozenTokens[_from])
        if not erc3643_forced_requirements['frozen_tokens_unfreeze_check']:
            unfreeze_patterns = [
                r'if\s*\(\s*_amount\s*>\s*freeBalance\s*\)',
                r'frozenTokens\[\s*_from\s*\]\s*=\s*frozenTokens\[\s*_from\s*\]\s*-\s*tokensToUnfreeze'
            ]
            if all(re.search(p, code) for p in unfreeze_patterns):
                erc3643_forced_requirements['frozen_tokens_unfreeze_check'] = True

        # 5. Check that frozenTokens[_from] >= tokensToUnfreeze before subtract
        if not erc3643_forced_requirements['frozen_tokens_balance_check']:
            balance_pattern = r'frozenTokens\[\s*_from\s*\]\s*>=\s*tokensToUnfreeze'
            if re.search(balance_pattern, code):
                erc3643_forced_requirements['frozen_tokens_balance_check'] = True

        # 6. IdentityRegistry check
        if not erc3643_forced_requirements['identity_registry_check']:
            id_registry_pattern = rf'tokenIdentityRegistry\.isVerified\(\s*_to\s*\)'
            if re.search(id_registry_pattern, code):
                erc3643_forced_requirements['identity_registry_check'] = True

        # 7. Compliance hook check
        if not erc3643_forced_requirements['compliance_check']:
            compliance_pattern = rf'tokenCompliance\.transferred\(\s*_from\s*,\s*_to\s*,\s*_amount\s*\)'
            if re.search(compliance_pattern, code):
                erc3643_forced_requirements['compliance_check'] = True

        # 8. Unfreeze event emitted
        if not erc3643_forced_requirements['unfreeze_event_check']:
            if re.search(r'emit\s+TokensUnfrozen\(', code):
                erc3643_forced_requirements['unfreeze_event_check'] = True

        # 9. Transfer event emitted
        if not erc3643_forced_requirements['transfer_event_check']:
            if re.search(r'emit\s+Transfer\(', code):
                erc3643_forced_requirements['transfer_event_check'] = True

    return erc3643_forced_requirements


def verify_erc3643_batchBurn_requirements(target_func: Dict, internal_functions: List[Dict]) -> Dict:

    burn_requirements = {
        'length_matching_check': False,
        'zero_address_check': False,
        'balance_check': False,
        'frozen_unfreeze_check': False,
        'frozen_balance_check': False,
        'unfreeze_event_check': False,
        'burn_event_check': False,
        'compliance_destroyed_check': False
    }

    user_addresses_param = '_userAddresses'
    amounts_param = '_amounts'

    all_code = [(target_func['body'], "main function")]
    for func in internal_functions:
        all_code.append((func['body'], f"internal function {func['name']}"))

    for code, source in all_code:
        # 1. Length matching check
        if not burn_requirements['length_matching_check']:
            length_pattern = rf'{user_addresses_param}\.length\s*==\s*{amounts_param}\.length'
            if re.search(length_pattern, code):
                burn_requirements['length_matching_check'] = True

        # 2. Zero address check
        if not burn_requirements['zero_address_check']:
            zero_addr_pattern = r'_userAddress\s*!=\s*address\(0\)'
            if re.search(zero_addr_pattern, code):
                burn_requirements['zero_address_check'] = True

        # 3. Balance check
        if not burn_requirements['balance_check']:
            balance_pattern = r'_balances\[\s*_userAddress\s*\]\s*>=\s*_amount'
            if re.search(balance_pattern, code):
                burn_requirements['balance_check'] = True

        # 4. Unfreeze check if insufficient free balance
        if not burn_requirements['frozen_unfreeze_check']:
            unfreeze_pattern = r'if\s*\(\s*_amount\s*>\s*freeBalance\s*\)'
            if re.search(unfreeze_pattern, code):
                burn_requirements['frozen_unfreeze_check'] = True

        # 5. Frozen token sufficient before unfreeze
        if not burn_requirements['frozen_balance_check']:
            frozen_balance_pattern = r'frozenTokens\[\s*_userAddress\s*\]\s*>=\s*tokensToUnfreeze'
            if re.search(frozen_balance_pattern, code):
                burn_requirements['frozen_balance_check'] = True

        # 6. Emit TokensUnfrozen()
        if not burn_requirements['unfreeze_event_check']:
            if re.search(r'emit\s+TokensUnfrozen\(', code):
                burn_requirements['unfreeze_event_check'] = True

        # 7. Emit burn Transfer event
        if not burn_requirements['burn_event_check']:
            if re.search(r'emit\s+Transfer\(\s*_userAddress\s*,\s*address\(0\)\s*,', code):
                burn_requirements['burn_event_check'] = True

        # 8. Compliance destroyed hook
        if not burn_requirements['compliance_destroyed_check']:
            if re.search(r'tokenCompliance\.destroyed\(\s*_userAddress\s*,\s*_amount\s*\)', code):
                burn_requirements['compliance_destroyed_check'] = True

    return burn_requirements




def verify_erc3643_batchMint_requirements(target_func: Dict, internal_functions: List[Dict]) -> Dict:

    mint_requirements = {
        'length_matching_check': False,
        'zero_address_check': False,
        'identity_registry_check': False,
        'compliance_check': False,
        'mint_event_check': False,
        'compliance_created_check': False
    }

    to_list_param = '_toList'
    amounts_param = '_amounts'

    all_code = [(target_func['body'], "main function")]
    for func in internal_functions:
        all_code.append((func['body'], f"internal function {func['name']}"))

    for code, source in all_code:
        # 1. Length matching check
        if not mint_requirements['length_matching_check']:
            length_pattern = rf'{to_list_param}\.length\s*==\s*{amounts_param}\.length'
            if re.search(length_pattern, code):
                mint_requirements['length_matching_check'] = True

        # 2. Zero address check in _mint()
        if not mint_requirements['zero_address_check']:
            zero_addr_pattern = r'_userAddress\s*!=\s*address\(0\)'
            if re.search(zero_addr_pattern, code):
                mint_requirements['zero_address_check'] = True

        # 3. Identity Registry check
        if not mint_requirements['identity_registry_check']:
            id_registry_pattern = r'tokenIdentityRegistry\.isVerified\(\s*_to\s*\)'
            if re.search(id_registry_pattern, code):
                mint_requirements['identity_registry_check'] = True

        # 4. Compliance check
        if not mint_requirements['compliance_check']:
            compliance_pattern = r'tokenCompliance\.canTransfer\(\s*msg\.sender\s*,\s*_to\s*,\s*_amount\s*\)'
            if re.search(compliance_pattern, code):
                mint_requirements['compliance_check'] = True

        # 5. Mint Transfer event
        if not mint_requirements['mint_event_check']:
            if re.search(r'emit\s+Transfer\(\s*address\(0\)\s*,\s*_userAddress\s*,', code):
                mint_requirements['mint_event_check'] = True

        # 6. Compliance created hook
        if not mint_requirements['compliance_created_check']:
            if re.search(r'tokenCompliance\.created\(\s*_to\s*,\s*_amount\s*\)', code):
                mint_requirements['compliance_created_check'] = True

    return mint_requirements




def verify_setApprovalForAll_requirements(target_func: Dict, internal_functions: List[Dict]) -> Dict:
    """Verify if the function meets setApprovalForAll requirements."""
    requirements = {
        'self_approval_check': False,
        'status_change_check': False,
        'event_emission': False
    }
    
    params = extract_setApprovalForAll_parameters(target_func)
    operator_param = params.get('operator_param', 'operator')
    
    # operator_param = ''
    # owner_param = ''
    
    
    # Combine all code to analyze (main function + internal calls)
    all_code = [(target_func['body'], "main function")]
    for func in internal_functions:
        all_code.append((func['body'], f"internal function {func['name']}"))
        # if func['body'] and "setApprovalForAll" in func['name']:
        #     # Split parameters into a list and clean them
        #     param_list = [p.strip() for p in func['params'].split(',')]

        #     # Extract individual parameters (just the variable names)
        #     owner_param = param_list[0].split()[-1]  # Gets '_account' from 'address _account'
        #     operator_param = param_list[1].split()[-1]  # Gets '_operator' from 'address _operator'
        #     approved_param = param_list[2].split()[-1]  # Gets '_approved' from 'bool _approved'

        #     print(f"Owner parameter: {owner_param}")
        #     print(f"Operator parameter: {operator_param}")
        #     print(f"Approved parameter: {approved_param}")
            
    
    all_conditions = []
    event_pos = None
    
    for code, source in all_code:
        condition_matches = []
        # Pattern for require statements
        require_pattern = r'require\s*\(((?:[^()]|\((?:[^()]|\([^()]*\))*\))*)\)'
        # Find all require matches
        require_matches = re.finditer(require_pattern, code, re.DOTALL)
        
        for match in require_matches:
            req_content = re.sub(r'\s+', ' ', match.group(1).strip())
            condition_matches.append((req_content, source, 'require'))
        
        # Find if-revert conditions
        if_revert_conditions = find_if_revert_control_flow(code)
        for condition in if_revert_conditions:
            condition_matches.append((condition, source, 'if-revert'))
            
        all_conditions.extend(condition_matches)
    
    # Possible sender representations
    sender_reprs = ['msg.sender', '_msgSender()', 'sender', 'owner', "owner_", '_account', 'account']
    
    # Check conditions
    for condition_content, condition_source, condition_type in all_conditions:
        # Check for self-approval prevention
        if not requirements['self_approval_check']:
            for sender in sender_reprs:
                escaped_operator = re.escape(operator_param)
                # print(f"sender :{sender}")
                # print(f"operator_param :{operator_param}")
                
                # patterns = [
                #     rf'{owner_param}\s*==\s*{operator_param}',
                #     rf'{operator_param}\s*==\s*{owner_param}',
                #     rf'{owner_param}\s*!=\s*{operator_param}',
                #     rf'{operator_param}\s*!=\s*{owner_param}'
                # ]
                patterns1 = [
                    rf'{sender}\s*==\s*{operator_param}',
                    rf'{operator_param}\s*==\s*{sender}',
                    rf'{sender}\s*!=\s*{operator_param}',
                    rf'{operator_param}\s*!=\s*{sender}'
                ]
                
                patterns2 = [
                    rf'{re.escape(sender)}\s*\(\s*\)\s*!=\s*{escaped_operator}',  # _msgSender() != operator
                    rf'{escaped_operator}\s*!=\s*{re.escape(sender)}\s*\(\s*\)',  # operator != _msgSender()
                    rf'{re.escape(sender)}\s*!=\s*{escaped_operator}',            # msg.sender != operator (fallback)
                    rf'{escaped_operator}\s*!=\s*{re.escape(sender)}'             # operator != msg.sender (fallback)
                ]
                if any(re.search(p, condition_content) for p in patterns1) or \
                    (any(re.search(p, condition_content) for p in patterns2)):
                    requirements['self_approval_check'] = True
                    break
        
        # # Check for zero address operator
        # if not requirements['zero_address_check']:
        #     zero_addr_patterns = [
        #         rf'{operator_param}\s*==\s*address\(0\)',
        #         rf'address\(0\)\s*==\s*{operator_param}',
        #         rf'{operator_param}\s*!=\s*address\(0\)',
        #         rf'address\(0\)\s*!=\s*{operator_param}'
        #     ]
        #     if any(re.search(p, condition_content) for p in zero_addr_patterns):
        #         requirements['zero_address_check'] = True
        
        # Check for status change validation (front-running protection)
        # if not requirements['frontrunning_protection']:
        #     status_patterns = [
        #         rf'_operatorApprovals\[{sender}\]\[{operator_param}\]\s*==\s*approved',
        #         rf'operatorApprovals\[{sender}\]\[{operator_param}\]\s*==\s*approved',
        #         rf'_approvals\[{sender}\]\[{operator_param}\]\s*==\s*approved',
        #         rf'approvals\[{sender}\]\[{operator_param}\]\s*==\s*approved'
        #     ]
        #     if any(re.search(p, condition_content) for p in status_patterns):
        #         requirements['frontrunning_protection'] = True
    
    # Check for event emission in the code
    for code, source in all_code:
        # Event emission check
        if 'emit ApprovalForAll(' in code:
            requirements['event_emission'] = True
            event_pos = (source, code.find('emit ApprovalForAll('))
            
            # Verify event is emitted after all checks
            if event_pos:
                pre_event_code = code[:event_pos[1]]
                check_patterns = [
                    r'require\s*\(',
                    r'if\s*\(',
                    r'revert\s*\('
                ]
                if any(re.search(p, pre_event_code) for p in check_patterns):
                    requirements['status_change_check'] = True
    
    return requirements





def verify_erc2612_requirements(target_func: Dict, internal_functions: List[Dict]) -> Dict:
    """Verify if the function and its internal calls meet ERC2612 requirements."""
    requirements = {
        'deadline_check': False,
        'timestamp_check': False,
        'signature_validation': False,
        'nonce_usage': False,
        'domain_separator_usage': False,
        'permit_function_exists': False,
        'owner_check': False,
        'spender_approval': False
    }

    # Extract parameters
    params = extract_parameters(target_func)
    owner_param = params.get('owner_param', 'owner')
    spender_param = params.get('spender_param', 'spender')
    value_param = params.get('value_param', 'value')
    deadline_param = params.get('deadline_param', 'deadline')
    v_param = params.get('v_param', 'v')
    r_param = params.get('r_param', 'r')
    s_param = params.get('s_param', 's')

    # Combine all code to analyze (main function + internal calls)
    all_code = [(target_func['body'], "main function")]
    for func in internal_functions:
        if target_func['body'] != func['body']:
            all_code.append((func['body'], f"internal function {func['name']}"))

    all_conditions = []
    
    for code, source in all_code:
        condition_matches = []
        
        # Pattern for require statements
        require_pattern = r'require\s*\(((?:[^()]|\((?:[^()]|\([^()]*\))*\))*)\)'
        require_matches = re.finditer(require_pattern, code, re.DOTALL)
        
        for match in require_matches:
            req_content = re.sub(r'\s+', ' ', match.group(1).strip())
            condition_matches.append((req_content, source, 'require'))
        
        # Find if-revert conditions
        if_revert_conditions = find_if_revert_control_flow(code)
        for condition in if_revert_conditions:
            condition_matches.append((condition, source, 'if-revert'))
            
        all_conditions.extend(condition_matches)

    # Check conditions
    for condition_content, condition_source, condition_type in all_conditions:
        # Check for deadline validation
        if deadline_param and not requirements['deadline_check']:
            if condition_type == "if-revert":
                deadline_patterns = [
                    rf'{deadline_param}\s*<\s*block\.timestamp',
                    rf'block\.timestamp\s*>\s*{deadline_param}',
                    rf'isExpired\(\s*{deadline_param}\s*\)',
                    rf'!isValid\(\s*{deadline_param}\s*\)'
                ]
            else:  # require
                deadline_patterns = [
                    rf'{deadline_param}\s*>=\s*block\.timestamp',
                    rf'block\.timestamp\s*<=\s*{deadline_param}',
                    rf'!isExpired\(\s*{deadline_param}\s*\)',
                    rf'isValid\(\s*{deadline_param}\s*\)'
                ]
            
            if any(re.search(p, condition_content) for p in deadline_patterns):
                requirements['deadline_check'] = True

        # Check for timestamp validation (separate from deadline)
        if not requirements['timestamp_check']:
            timestamp_patterns = [
                r'block\.timestamp',
                r'now\s*[<>=]',
                r'timestamp\s*[<>=]'
            ]
            if any(re.search(p, condition_content) for p in timestamp_patterns):
                requirements['timestamp_check'] = True

        # Check for signature validation
        if (v_param and r_param and s_param) and not requirements['signature_validation']:
            sig_patterns = [
                r'ecrecover\s*\(',
                r'ECDSA\.recover\s*\(',
                r'signature\s*=\s*abi\.encodePacked\s*\(',
                r'\.verify\s*\('
            ]
            if any(re.search(p, condition_content) for p in sig_patterns):
                requirements['signature_validation'] = True

        # Check for nonce usage
        if not requirements['nonce_usage']:
            if re.search(r'nonces\[', condition_content) or re.search(r'incrementNonce\s*\(', condition_content):
                requirements['nonce_usage'] = True

    # Additional checks that don't depend on conditions
    for code, source in all_code:
        # Check for DOMAIN_SEPARATOR usage
        if not requirements['domain_separator_usage']:
            if re.search(r'DOMAIN_SEPARATOR', code) or re.search(r'domainSeparator\s*\(', code):
                requirements['domain_separator_usage'] = True

        # Check for permit function existence
        if not requirements['permit_function_exists']:
            if re.search(r'function\s+permit\s*\(', code):
                requirements['permit_function_exists'] = True

        # Check for owner validation
        if owner_param and not requirements['owner_check']:
            owner_patterns = [
                rf'{owner_param}\s*==\s*msg\.sender',
                rf'msg\.sender\s*==\s*{owner_param}',
                rf'isOwner\(\s*{owner_param}\s*\)',
                rf'ownerOf\(\s*{owner_param}\s*\)'
            ]
            if any(re.search(p, code) for p in owner_patterns):
                requirements['owner_check'] = True

        # Check for spender approval
        if spender_param and not requirements['spender_approval']:
            if re.search(rf'approve\(\s*{spender_param}\s*,', code):
                requirements['spender_approval'] = True

    return requirements


# def verify_erc5267_requirements(target_func: Dict, internal_functions: List[Dict]) -> Dict:
#     """Verify ERC-5267 compliance with enhanced security checks.
    
#     Args:
#         target_func: The eip712Domain function to analyze
#         internal_functions: List of related internal functions
        
#     Returns:
#         Dict containing verification results and warnings
#     """
#     requirements = {
#         # Core compliance checks
#         'eip712Domain_function_exists': False,
#         'returns_correct_fields': False,
#         'typehash_declared': False,
#         'domain_separator_usage': False,
        
#         # Field-specific validations
#         'fields': {
#             'valid': False,
#             'value': None,
#             'required_bits': {'name': True, 'version': True, 'chainId': True, 
#                              'verifyingContract': True, 'salt': False, 'extensions': False}
#         },
#         'name': {'valid': False, 'immutable': False, 'non_empty': False},
#         'version': {'valid': False, 'immutable': False},
#         'chainId': {'valid': False, 'uses_block_chainid': False},
#         'verifyingContract': {'valid': False, 'uses_address_this': False, 'proxy_safe': False},
#         'salt': {'valid': False, 'non_zero': False},
#         'extensions': {'valid': False, 'non_empty': False},
        
#         # Security flags
#         'warnings': [],
#         'critical_issues': []
#     }

#     # Combine all code to analyze
#     all_code = [(target_func['body'], "main function")]
#     for func in internal_functions:
#         if target_func['body'] != func['body']:
#             all_code.append((func['body'], f"internal function {func['name']}"))

#     # Enhanced patterns
#     eip712_domain_pattern = re.compile(
#         r'function\s+eip712Domain\s*\(\s*\)\s*(?:external|public)\s+view\s+returns\s*\(\s*'
#         r'bytes1\s+\w+\s*,\s*'          # fields
#         r'string\s+(?:memory\s+)?\w+\s*,\s*'  # name
#         r'string\s+(?:memory\s+)?\w+\s*,\s*'  # version
#         r'uint256\s+\w+\s*,\s*'         # chainId
#         r'address\s+\w+\s*,\s*'         # verifyingContract
#         r'bytes32\s+\w+\s*,\s*'         # salt
#         r'uint256\[\]\s+(?:memory\s+)?\w+\s*\)',  # extensions
#         re.DOTALL
#     )

#     return_pattern = re.compile(
#         r'return\s*\(\s*'
#         r'(bytes1\(.*?\)|hex"[0-9a-fA-F]+"|[\w\d]+)\s*,\s*'  # fields
#         r'("[^"]*"|_\w+\.toString\(\)|[\w\d]+)\s*,\s*'       # name
#         r'("[^"]*"|_\w+\.toString\(\)|[\w\d]+)\s*,\s*'       # version
#         r'(block\.chainid|_\w+|\d+)\s*,\s*'                  # chainId
#         r'(address\(this\)|_\w+|\w+)\s*,\s*'                 # verifyingContract
#         r'(bytes32\(.*?\)|_\w+|0x[0-9a-fA-F]+)\s*,\s*'       # salt
#         r'(new\s*uint256\[\]\(.*?\)|_\w+|\[\])\s*\)\s*;',    # extensions
#         re.DOTALL
#     )

#     # Immutability checks
#     immutable_pattern = re.compile(r'(?:immutable|constant)\s+(string|bytes32)\s+(_name|_version|_hashedName|_salt)')
    
#     for code, source in all_code:
#         # Check function existence and signature
#         if eip712_domain_pattern.search(code):
#             requirements['eip712Domain_function_exists'] = True
            
#             # Check return values
#             if return_match := return_pattern.search(code):
#                 fields, name, version, chainId, verifyingContract, salt, extensions = return_match.groups()
                
#                 # Validate fields bitmap
#                 if hex_match := re.search(r'hex"([0-9a-fA-F]{1,2})"', fields):
#                     fields_hex = int(hex_match.group(1), 16)
#                     requirements['fields']['value'] = fields_hex
#                     # Verify all required bits are set
#                     required_bits = 0x0f  # 00001111 in binary (name|version|chainId|verifyingContract)
#                     if (fields_hex & required_bits) == required_bits:
#                         requirements['fields']['valid'] = True
#                     else:
#                         requirements['critical_issues'].append(
#                             f"Fields bitmap 0x{fields_hex:x} missing required bits (needs 0x{required_bits:x})"
#                         )
                
#                 # Validate name
#                 if re.match(r'".+"', name) or ('toString()' in name and '_name' in name):
#                     requirements['name']['non_empty'] = True
#                     requirements['name']['valid'] = True
#                     if '_name' in name and 'immutable' in code:
#                         requirements['name']['immutable'] = True
                
#                 # Validate version (can be empty)
#                 if re.match(r'""|".+"', version) or ('toString()' in version and '_version' in version):
#                     requirements['version']['valid'] = True
#                     if '_version' in version and 'immutable' in code:
#                         requirements['version']['immutable'] = True
                
#                 # Validate chainId
#                 if 'block.chainid' in chainId.lower():
#                     requirements['chainId']['uses_block_chainid'] = True
#                     requirements['chainId']['valid'] = True
#                 else:
#                     requirements['warnings'].append("chainId should use block.chainid for fork safety")
                
#                 # Validate verifyingContract
#                 if 'address(this)' in verifyingContract.lower():
#                     requirements['verifyingContract']['uses_address_this'] = True
#                     requirements['verifyingContract']['valid'] = True
#                     # Check for proxy patterns
#                     if re.search(r'\.delegatecall', code) or re.search(r'proxy', code, re.I):
#                         requirements['verifyingContract']['proxy_safe'] = False
#                         requirements['critical_issues'].append(
#                             "Proxy pattern detected but no proxy address handling"
#                         )
                
#                 # Validate salt
#                 if 'bytes32(' in salt or re.match(r'0x[0-9a-fA-F]{64}', salt):
#                     requirements['salt']['valid'] = True
#                     if not ('0' in salt or '00' in salt):
#                         requirements['salt']['non_zero'] = True
#                     if '_salt' in salt and 'immutable' in code:
#                         requirements['salt']['immutable'] = True
                
#                 # Validate extensions
#                 if 'new uint256[]' in extensions or '[]' in extensions:
#                     requirements['extensions']['valid'] = True
#                     if not ('[]' in extensions or '0' in extensions):
#                         requirements['extensions']['non_empty'] = True
            
#             # Check for immutability of critical parameters
#             if immutable_pattern.search(code):
#                 for match in immutable_pattern.finditer(code):
#                     var_type, var_name = match.groups()
#                     if var_name == '_name':
#                         requirements['name']['immutable'] = True
#                     elif var_name == '_version':
#                         requirements['version']['immutable'] = True
#                     elif var_name == '_salt':
#                         requirements['salt']['immutable'] = True
    
#     # Additional security checks
#     for code, source in all_code:
#         # Domain separator usage check
#         if re.search(r'_domainSeparatorV4\(\)|DOMAIN_SEPARATOR', code):
#             requirements['domain_separator_usage'] = True
        
#         # Typehash declaration check
#         if re.search(
#             r'bytes32\s+[A-Z_]+\s*=\s*keccak256\s*\(\s*"EIP712Domain\s*\(.*?\)\s*"\)',
#             code
#         ):
#             requirements['typehash_declared'] = True
    
#     # Final validation logic
#     if requirements['eip712Domain_function_exists']:
#         requirements['returns_correct_fields'] = all([
#             requirements['fields']['valid'],
#             requirements['name']['valid'],
#             requirements['version']['valid'],
#             requirements['chainId']['valid'],
#             requirements['verifyingContract']['valid'],
#             requirements['salt']['valid'],
#             requirements['extensions']['valid']
#         ])
        
#         # Add critical issues if immutable params aren't enforced
#         if not requirements['name']['immutable']:
#             requirements['critical_issues'].append("name parameter should be immutable")
#         if not requirements['version']['immutable']:
#             requirements['warnings'].append("version parameter should be immutable for security")
    
#     return requirements



def verify_erc5267_requirements(target_func: Dict, internal_functions: List[Dict]) -> Dict:
    """
    Verify ERC-5267 eip712Domain() implementation.

    Correct interpretation:
      - ERC-5267 requires the function signature and return tuple shape.
      - The `fields` bitmap determines which EIP-712 fields are present.
      - name/version/chainId/verifyingContract/salt are not all mandatory.
      - salt = bytes32(0) is NOT a bug if the salt bit is absent.
      - version = "" is NOT a bug if the version bit is absent.
      - The real bug is mismatch between ERC-5267 metadata and the actual
        EIP-712 domain used for verification, or semantic insufficiency
        such as missing verifyingContract or chainId in risky contexts.

    Args:
        target_func: Dict for eip712Domain function.
        internal_functions: related internal functions discovered by your analysis.

    Returns:
        Dict with compliance, decoded bitmap, warnings, and critical issues.
    """

    import re

    def strip_comments(code: str) -> str:
        """Remove Solidity comments for easier regex matching."""
        code = re.sub(r"/\*.*?\*/", "", code, flags=re.DOTALL)
        code = re.sub(r"//.*", "", code)
        return code

    def decode_erc5267_fields(fields_value: int) -> Dict[str, bool]:
        """
        ERC-5267 bitmap:
          bit 0: name
          bit 1: version
          bit 2: chainId
          bit 3: verifyingContract
          bit 4: salt
        """
        return {
            "name": bool(fields_value & 0x01),
            "version": bool(fields_value & 0x02),
            "chainId": bool(fields_value & 0x04),
            "verifyingContract": bool(fields_value & 0x08),
            "salt": bool(fields_value & 0x10),
        }

    def normalize_expr(expr: str) -> str:
        return re.sub(r"\s+", "", expr or "")

    def extract_return_tuple(code: str):
        """
        Extract the top-level return tuple from:
            return (...);
        This is more robust than one giant regex because return values can contain
        nested calls such as _EIP712Name(), bytes32(0), new uint256[](0), etc.
        """
        m = re.search(r"\breturn\s*\(", code)
        if not m:
            return None

        start = m.end()  # position after "return("
        depth = 1
        i = start
        while i < len(code):
            ch = code[i]
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    tuple_text = code[start:i]
                    return split_top_level_commas(tuple_text)
            i += 1

        return None

    def split_top_level_commas(s: str):
        """
        Split 'a, f(x,y), new uint256[](0)' into top-level arguments.
        """
        parts = []
        cur = []
        paren = bracket = brace = 0
        in_str = False
        quote = ""

        i = 0
        while i < len(s):
            ch = s[i]

            if in_str:
                cur.append(ch)
                if ch == quote and (i == 0 or s[i - 1] != "\\"):
                    in_str = False
                i += 1
                continue

            if ch in ("'", '"'):
                in_str = True
                quote = ch
                cur.append(ch)
            elif ch == "(":
                paren += 1
                cur.append(ch)
            elif ch == ")":
                paren -= 1
                cur.append(ch)
            elif ch == "[":
                bracket += 1
                cur.append(ch)
            elif ch == "]":
                bracket -= 1
                cur.append(ch)
            elif ch == "{":
                brace += 1
                cur.append(ch)
            elif ch == "}":
                brace -= 1
                cur.append(ch)
            elif ch == "," and paren == 0 and bracket == 0 and brace == 0:
                parts.append("".join(cur).strip())
                cur = []
            else:
                cur.append(ch)

            i += 1

        if cur:
            parts.append("".join(cur).strip())

        return parts

    def parse_fields_value(fields_expr: str):
        """
        Parse fields expression:
          hex"0f"
          0x0f
          bytes1(0x0f)
          bytes1(uint8(0x0f))
        Returns int or None.
        """
        expr = fields_expr.strip()

        patterns = [
            r'hex"([0-9a-fA-F]{1,2})"',
            r"0x([0-9a-fA-F]{1,2})",
            r"bytes1\s*\(\s*0x([0-9a-fA-F]{1,2})\s*\)",
            r"uint8\s*\(\s*0x([0-9a-fA-F]{1,2})\s*\)",
        ]

        for pat in patterns:
            m = re.search(pat, expr)
            if m:
                return int(m.group(1), 16)

        # decimal literal, e.g., 15 or bytes1(uint8(15))
        m = re.search(r"\b([0-9]{1,3})\b", expr)
        if m:
            val = int(m.group(1))
            if 0 <= val <= 255:
                return val

        return None

    def expr_looks_dynamic_chainid(expr: str) -> bool:
        e = normalize_expr(expr).lower()
        return "block.chainid" in e or "chainid()" in e

    def expr_looks_address_this(expr: str) -> bool:
        e = normalize_expr(expr).lower()
        return "address(this)" in e

    def expr_looks_zero_salt(expr: str) -> bool:
        e = normalize_expr(expr).lower()
        return (
            e in {"0", "bytes32(0)", "bytes32(0x0)", "bytes32(uint256(0))"}
            or re.fullmatch(r"0x0+", e or "") is not None
        )

    def expr_looks_empty_extensions(expr: str) -> bool:
        e = normalize_expr(expr).lower()
        return (
            "newuint256[](0)" in e
            or e == "[]"
            or e == "extensions"
        )

    def has_domain_separator_typehash(code: str) -> bool:
        return bool(
            re.search(r"EIP712Domain\s*\(", code)
            or re.search(r"8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f", code, re.I)
        )

    def has_domain_separator_usage(code: str) -> bool:
        return bool(
            re.search(r"\bDOMAIN_SEPARATOR\b", code)
            or re.search(r"_domainSeparatorV4\s*\(", code)
            or re.search(r"_hashTypedDataV4\s*\(", code)
            or re.search(r"\x19\x01|0x1901|1901", code)
        )

    requirements = {
        "eip712Domain_function_exists": False,
        "returns_correct_tuple_shape": False,
        "returns_correct_fields": False,

        "typehash_declared_or_used": False,
        "domain_separator_usage": False,

        "fields": {
            "valid": False,
            "raw": None,
            "value": None,
            "decoded": {
                "name": False,
                "version": False,
                "chainId": False,
                "verifyingContract": False,
                "salt": False,
            },
            "unknown_bits": False,
        },

        "name": {
            "present_by_bitmap": False,
            "return_expr": None,
            "valid_if_present": False,
        },
        "version": {
            "present_by_bitmap": False,
            "return_expr": None,
            "valid_if_present": False,
        },
        "chainId": {
            "present_by_bitmap": False,
            "return_expr": None,
            "valid_if_present": False,
            "uses_block_chainid_or_chainid_opcode": False,
            "possibly_hardcoded": False,
        },
        "verifyingContract": {
            "present_by_bitmap": False,
            "return_expr": None,
            "valid_if_present": False,
            "uses_address_this": False,
            "possibly_hardcoded": False,
        },
        "salt": {
            "present_by_bitmap": False,
            "return_expr": None,
            "valid_if_present": False,
            "zero_placeholder_when_absent": False,
            "non_zero_when_present": False,
        },
        "extensions": {
            "return_expr": None,
            "valid": False,
            "empty": False,
            "non_empty": False,
        },

        "erc5267_classification": None,

        "warnings": [],
        "critical_issues": [],
        "notes": [],
    }

    # Combine visible code.
    all_code_parts = [target_func.get("body", "")]
    for func in internal_functions or []:
        body = func.get("body", "")
        if body and body not in all_code_parts:
            all_code_parts.append(body)

    combined_code = "\n\n".join(all_code_parts)
    code_no_comments = strip_comments(combined_code)

    # ERC-5267 signature check.
    # We do not require exact spacing or memory keywords.
    eip712_domain_sig = re.compile(
        r"function\s+eip712Domain\s*\(\s*\)\s*"
        r"(?:external|public)\s+view\s+"
        r"(?:virtual\s+)?(?:override\s+)?"
        r"returns\s*\(",
        re.DOTALL,
    )

    if eip712_domain_sig.search(code_no_comments):
        requirements["eip712Domain_function_exists"] = True
    else:
        # The parser may pass only the function body without the signature.
        # If target signature was already matched by caller, allow body-only analysis.
        if target_func.get("name") == "eip712Domain" or target_func.get("signature") == "eip712Domain()":
            requirements["eip712Domain_function_exists"] = True
            requirements["notes"].append("Function signature not visible in body; assuming caller matched eip712Domain().")
        else:
            requirements["critical_issues"].append("eip712Domain() function signature not detected.")

    # Extract return tuple.
    return_values = extract_return_tuple(code_no_comments)
    if not return_values:
        requirements["critical_issues"].append("No return tuple found in eip712Domain().")
    elif len(return_values) != 7:
        requirements["critical_issues"].append(
            f"eip712Domain() should return 7 values, found {len(return_values)}."
        )
    else:
        requirements["returns_correct_tuple_shape"] = True

        fields_expr, name_expr, version_expr, chain_expr, verifier_expr, salt_expr, extensions_expr = return_values

        requirements["fields"]["raw"] = fields_expr
        requirements["name"]["return_expr"] = name_expr
        requirements["version"]["return_expr"] = version_expr
        requirements["chainId"]["return_expr"] = chain_expr
        requirements["verifyingContract"]["return_expr"] = verifier_expr
        requirements["salt"]["return_expr"] = salt_expr
        requirements["extensions"]["return_expr"] = extensions_expr

        fields_value = parse_fields_value(fields_expr)
        requirements["fields"]["value"] = fields_value

        if fields_value is None:
            requirements["warnings"].append(
                f"Could not statically parse ERC-5267 fields bitmap expression: {fields_expr}"
            )
        elif fields_value == 0:
            requirements["critical_issues"].append("ERC-5267 fields bitmap is zero; no EIP-712 domain fields reported.")
        else:
            decoded = decode_erc5267_fields(fields_value)
            requirements["fields"]["decoded"] = decoded
            requirements["fields"]["valid"] = True

            if fields_value & ~0x1F:
                requirements["fields"]["unknown_bits"] = True
                requirements["warnings"].append(
                    f"ERC-5267 fields bitmap has bits outside EIP-712 base fields: 0x{fields_value:x}"
                )

            # Presence flags.
            requirements["name"]["present_by_bitmap"] = decoded["name"]
            requirements["version"]["present_by_bitmap"] = decoded["version"]
            requirements["chainId"]["present_by_bitmap"] = decoded["chainId"]
            requirements["verifyingContract"]["present_by_bitmap"] = decoded["verifyingContract"]
            requirements["salt"]["present_by_bitmap"] = decoded["salt"]

            # name validation.
            if decoded["name"]:
                if name_expr and name_expr.strip():
                    requirements["name"]["valid_if_present"] = True
                else:
                    requirements["critical_issues"].append("name bit is set but returned name expression is empty.")
            else:
                if name_expr.strip() not in {"", '""'}:
                    requirements["notes"].append("name bit is absent; returned name value is unspecified and ignored.")

            # version validation.
            if decoded["version"]:
                if version_expr and version_expr.strip() and version_expr.strip() != '""':
                    requirements["version"]["valid_if_present"] = True
                else:
                    requirements["warnings"].append("version bit is set but version appears empty.")
            else:
                if version_expr.strip() not in {"", '""'}:
                    requirements["notes"].append("version bit is absent; returned version value is unspecified and ignored.")

            # chainId validation.
            if decoded["chainId"]:
                if expr_looks_dynamic_chainid(chain_expr):
                    requirements["chainId"]["uses_block_chainid_or_chainid_opcode"] = True
                    requirements["chainId"]["valid_if_present"] = True
                else:
                    requirements["chainId"]["possibly_hardcoded"] = True
                    requirements["warnings"].append(
                        f"chainId bit is set but chainId does not obviously use block.chainid/chainid(): {chain_expr}"
                    )
            else:
                requirements["warnings"].append(
                    "Domain omits chainId; check for cross-chain replay risk if signatures can cross chains."
                )

            # verifyingContract validation.
            if decoded["verifyingContract"]:
                if expr_looks_address_this(verifier_expr):
                    requirements["verifyingContract"]["uses_address_this"] = True
                    requirements["verifyingContract"]["valid_if_present"] = True
                else:
                    requirements["verifyingContract"]["possibly_hardcoded"] = True
                    requirements["warnings"].append(
                        f"verifyingContract bit is set but verifier is not obviously address(this): {verifier_expr}"
                    )
            else:
                requirements["critical_issues"].append(
                    "Domain omits verifyingContract; possible cross-contract replay risk."
                )

            # salt validation.
            if decoded["salt"]:
                if salt_expr and salt_expr.strip():
                    requirements["salt"]["valid_if_present"] = True
                    if not expr_looks_zero_salt(salt_expr):
                        requirements["salt"]["non_zero_when_present"] = True
                    else:
                        requirements["warnings"].append(
                            "salt bit is set but salt appears to be zero; check whether this is intentional."
                        )
                else:
                    requirements["critical_issues"].append("salt bit is set but returned salt expression is empty.")
            else:
                # bytes32(0) is correct placeholder when salt is absent.
                if expr_looks_zero_salt(salt_expr):
                    requirements["salt"]["zero_placeholder_when_absent"] = True
                    requirements["notes"].append("salt bit is absent; zero salt return value is ignored by ERC-5267.")
                else:
                    requirements["notes"].append("salt bit is absent; returned salt value is unspecified and ignored.")

            # extensions validation.
            if extensions_expr and extensions_expr.strip():
                requirements["extensions"]["valid"] = True
                if expr_looks_empty_extensions(extensions_expr):
                    requirements["extensions"]["empty"] = True
                else:
                    requirements["extensions"]["non_empty"] = True
                    requirements["warnings"].append(
                        f"Non-empty or dynamic ERC-5267 extensions returned: {extensions_expr}. Verify referenced EIPs."
                    )
            else:
                requirements["critical_issues"].append("extensions return expression missing.")

            # Classification.
            if fields_value == 0x0D:
                requirements["erc5267_classification"] = "name_chainId_verifyingContract"
            elif fields_value == 0x0F:
                requirements["erc5267_classification"] = "name_version_chainId_verifyingContract"
            elif fields_value == 0x1F:
                requirements["erc5267_classification"] = "name_version_chainId_verifyingContract_salt"
            else:
                requirements["erc5267_classification"] = f"custom_bitmap_0x{fields_value:x}"

    # Supplemental checks over combined code.
    requirements["typehash_declared_or_used"] = has_domain_separator_typehash(combined_code)
    requirements["domain_separator_usage"] = has_domain_separator_usage(combined_code)

    # These are not ERC-5267 compliance failures by themselves, only useful notes.
    if not requirements["typehash_declared_or_used"]:
        requirements["notes"].append(
            "EIP712Domain typehash not visible in analyzed slice; may be inherited/library code or outside current analysis scope."
        )

    if not requirements["domain_separator_usage"]:
        requirements["notes"].append(
            "DOMAIN_SEPARATOR/_domainSeparatorV4 usage not visible in analyzed slice; compare ERC-5267 output with actual verifier domain separately."
        )

    # Final high-level correctness.
    if requirements["eip712Domain_function_exists"] and requirements["returns_correct_tuple_shape"] and requirements["fields"]["valid"]:
        # Must not have structural critical issues.
        structural_criticals = [
            issue for issue in requirements["critical_issues"]
            if (
                "7 values" in issue
                or "No return tuple" in issue
                or "fields bitmap is zero" in issue
                or "function signature not detected" in issue
            )
        ]
        requirements["returns_correct_fields"] = len(structural_criticals) == 0

    return requirements



def check_on_received_implementation(code: str, params, isContract) -> bool:
    # Get parameters by position (assuming standard ERC1155 order)
    from_param = params['from_param']
    to_param = params['to_param']
    ids_param = params['ids_param']
    amounts_param = params['amounts_param']
    data_param = params['data_param']
    
    # Operator is typically not a parameter in safeBatchTransferFrom,
    # but comes from msg.sender in the actual call
    operator_param = "operator"
    
    operator_var = None
    operator_assignment = re.search(
        r'(address\s+(\w+)\s*=\s*(?:msg\.sender|_msgSender\(\))\s*;)',
        code)
    
    if operator_assignment:
        operator_var = operator_assignment.group(2)
        
    
    # Normalize code by removing comments and extra spaces
    normalized_code = re.sub(r'//.*?\n|/\*.*?\*/', '', code, flags=re.DOTALL)
    normalized_code = re.sub(r'\s+', ' ', normalized_code)
    
    if not isContract:
        # 1. Check for isContract() guard
        if not re.search(rf'if\s*\(\s*{to_param}\s*\.\s*isContract\s*\(\s*\)\s*\)', normalized_code):
            # print(f"no is isContract() check")
            return False
    
    # 2. Check for onERC1155BatchReceived call with increasingly flexible parameter matching
    receiver_pattern = None
    param_matched = False
    
    
    # Attempt 1: Exact parameter name matching (with operator or msg.sender)
    if not param_matched:
        param_patterns = [
        operator_var or operator_param or r'(msg\.sender|_msgSender\(\))',
        from_param or r'_\w+',
        ids_param or r'_\w+',
        amounts_param or r'_\w+',
        data_param or r'_\w+'
        ]
        receiver_pattern = (
            r'\.onERC1155BatchReceived'
            r'(?:\s*\{[^}]*\})?'
            r'\s*\(\s*'
            + r'\s*,\s*'.join(param_patterns) +
            r'\s*\)'
        )
        # print(f"receiver_pattern:{receiver_pattern}")
        param_matched = re.search(receiver_pattern, normalized_code) is not None
        # print(f"param_matched:{param_matched}")
    
    # Attempt 2: Type-based parameter matching
    if not param_matched:
        type_patterns = [
            r'address',        # operator
            r'address',        # from
            r'uint256\[\]',    # ids
            r'uint256\[\]',    # amounts
            r'bytes'           # data
        ]
        receiver_pattern = (
            r'\.onERC1155BatchReceived'
            r'(?:\s*\{[^}]*\})?'
            r'\s*\(\s*'
            r'[^,)]+\s*,\s*' * 4 +  # First 4 params
            r'[^)]+'                # Last param
            r'\s*\)'
        )
        
        # print(f"receiver_pattern:{receiver_pattern}")
        call_match = re.search(receiver_pattern, normalized_code)
        # print(f"call_match:{call_match}")
        if call_match:
            # Then check if the surrounding code has matching types
            context = normalized_code[max(0, call_match.start()-100):call_match.end()+100]
            param_matched = all(
                re.search(type_pattern, context)
                for type_pattern in type_patterns
            )
    
    # Attempt 3: Simple parameter count check
    if not param_matched:
        receiver_pattern = (
            r'\.onERC1155BatchReceived'
            r'(?:\s*\{[^}]*\})?'
            r'\s*\(\s*'
            r'([^,)]+\s*,\s*){4}'  # Exactly 4 commas = 5 params
            r'[^)]+'               # Last param
            r'\s*\)'
        )
        param_matched = re.search(receiver_pattern, normalized_code) is not None
        # print(f"param_matched:{param_matched}")
    
    if param_matched:
        print("parameters matched")
    else:
        print("Failed to match receiver parameters with any method")
        # return False
    
    # 3. Check return value capture
    return_valid = False
    
    # Optimized pattern that will definitely work
    pattern = r'''
        (?:require|if)\s*\(                          # Start with require or if
        [^)]*?                                       # Any characters (non-greedy)
        (?:[a-zA-Z_][\w.]*\s*\(\s*[^)]*\s*\)\s*\.)? # Optional contract prefix with params
        onERC1155BatchReceived\s*\(                  # The target function
        [^)]*                                        # Parameters
        \s*\)                                        # Closing paren of function call
        [^)]*                                        # Any remaining condition
        \)                                           # Closing paren of require/if
    '''

    # Use re.VERBOSE to allow comments and ignore whitespace in pattern
    if re.search(pattern, normalized_code, re.VERBOSE | re.DOTALL) and param_matched:
        return_valid = True
    
    # Approach 2: Check for bytes4 return value capture and validation
    if not return_valid:
        # Pattern to capture the return value assignment
        retval_pattern = (
            r'(bytes4\s+(\w+)\s*=\s*'  # Return value declaration
            r'[^;]*?\.onERC1155BatchReceived'
            r'(?:\s*\{[^}]*\})?'
            r'\([^)]+\)'
            r'\s*;)'
        )
        
        retval_match1 = re.search(retval_pattern, normalized_code)
            
        if retval_match1:
            retval_name = retval_match1.group(2)
            # print(f"retval_name:{retval_name}")
            retval_check_pattern = (
                r'(?:require|if)\s*\(\s*' + 
                re.escape(retval_name) + 
                r'\s*(==|!=)\s*[^)]+' +
                r'\s*\)'
    )
            if re.search(retval_check_pattern, normalized_code):
                return_valid = True
    
    # Approach 3: Check returns() clause in try-catch pattern
    if not return_valid:
        returns_pattern = (
            r'try\s+[^.]*\.onERC1155BatchReceived'
            r'(?:\s*\{[^}]*\})?'
            r'\([^)]+\)'
            r'\s+returns\s*\(\s*bytes4\s+(\w+)\s*\)'
        )
        returns_match = re.search(returns_pattern, normalized_code)
        
        
        if returns_match:
            retval_name = returns_match.group(1)
            # print(f"retval_name :{retval_name}")
            
            # Check if the return value is used in the try block
            try_block_pattern = (
                r'(?:require|if)\s*\(\s*[^)]*?' + 
                re.escape(retval_name) + 
                r'[^)]*\)'
            )
            
            if re.search(try_block_pattern, normalized_code, re.DOTALL):
                return_valid = True
    
    if not return_valid:
        print("Failed to validate return value check")
        return False
    
    return True


def analyze_safeBatchTransfer_interprocedural_analysis(solidity_code: str, target_sig) -> Dict:
    """Main analysis function for safeBatchTransferFrom compliance."""
    all_functions = find_all_functions(solidity_code)
    
    target_funcs = find_functions_by_signature(all_functions, target_sig)
    
    
    
    if not target_funcs:
        return {"error": "safeBatchTransferFrom function not found"}
    
    results = []
    for target_func in target_funcs:
        if contains_assembly(target_func['body']):
            print(f"assembly in target_func:")
            break
        
        internal_calls = get_all_internal_calls(target_func['body'], all_functions)
        for f in internal_calls:
            if contains_assembly(f['body']):
                print(f"assembly in internal_calls:")
                break
        # Skip analysis if we got None (self-recursive call detected)
        if internal_calls is None:
            continue
            
        # print(f"\nAnalyzing function implementation: {target_func['name']}")
        # print("Found internal calls:", [f['name'] for f in internal_calls])
        # if "safeBatchTransferFrom" in target_sig:
        requirements = verify_erc1155_requirements(target_func, internal_calls)
        
        
        # if "batchTransfer" in target_sig:
        # requirements = verify_erc3643_batchTransfer_requirements(target_func, internal_calls)
        
        # if "setApprovalForAll" in target_sig:
        #     requirements = verify_setApprovalForAll_requirements(target_func, internal_calls)
        
        
        
        requirements = furtherERC1155Checks(internal_calls, requirements)
    
        all_reqs = [
                'sender_check',
                'approval_check',
                'zero_address_check',
                'length_matching_check',
                'event_emission_order',
                'transfer_batch_event_found',
                'to_isContract_check',
                'on_received_check', 
                # 'gas_family_errors',
        ]
        all_met = all(requirements.get(req, False) for req in all_reqs)
        some_met = any(requirements.get(req, False) for req in all_reqs)
        
        results.append({
                "function": target_func['name'],
                "implementation_location": f"Line {target_func['start']}-{target_func['end']}",
                "parameters": target_func.get('parameters', {}),
                "requirements": requirements,
                "internal_calls": [f['name'] for f in internal_calls],
                # "gas_family_errors": requirements.get('gas_family_errors', False),
                "on_received_check_found": requirements.get('on_received_check', False),
                "all_requirements_met": all_met,
                "some_requirements_met": some_met
            })
    
    # Return consolidated results
    if results:
        return {
            "all_implementations": results,
            "summary": {
                "total_implementations": len(results),
                "fully_compliant": sum(1 for r in results if r.get('all_requirements_met', False)),
                "partially_compliant": sum(1 for r in results if r.get('some_requirements_met', False))
            }
        }
    return {"error": "No valid implementations found (possibly due to recursive calls)"}

def furtherERC1155Checks(internal_calls, requirements) -> List[Dict]:
    for f in internal_calls:
            if "onERC1155BatchReceived" in f.get('name', ''):
                requirements["on_received_check"] = True
                
            if "isContract" in f.get('name', ''):
                requirements["to_isContract_check"] = True
            
            if "isApprovedForAll" in f.get('name', ''):
                requirements["approval_check"] = True
                
            if "msgSender" in f.get('name', ''):
                requirements["sender_check"] = True
            
            if "isOperatable" in f.get('name', ''):
                requirements["sender_check"] = True
                requirements["approval_check"] = True
            
            if "isApprovedOrOwner" in f.get('name', ''):
                requirements["sender_check"] = True
                requirements["approval_check"] = True
                
            if "isSameLength" in f.get('name', ''):
                requirements["length_matching_check"] = True 
                
            # if f.get('name', '') == "safeTransferFrom":
            #     requirements["gas_family_errors"] = True 
                
    return requirements
    
def analyze_directory(directory_path: str, output_file, target_sig) -> List[Dict]:
    """Analyze all Solidity files in a directory for ERC1155 compliance."""
    results = []
    
    for root, _, files in os.walk(directory_path):
        for file in files:
            # if file.startswith("ERC3643_0x6e534da0cbfeed25fad935d213615001fe7a71be.sol") and file.endswith('.sol'):
            if file.endswith('.sol'):
                # file.startswith("avalanche_ERC1155_0x3bef4ce67588beb59d37f47ee2e6de7065c7f4f8.sol") and
                
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        solidity_code = f.read()
                    
                    result = analyze_safeBatchTransfer_interprocedural_analysis(solidity_code, target_sig)
                    result['file'] = file_path
                    
                    # Check if any implementation has gas_family_errors
                    if 'all_implementations' in result:
                        for impl in result['all_implementations']:
                            if impl.get('gas_family_errors', False):
                                result["gas_error_file"] = file_path
                                print(f"Gas family error found in {file_path}")
                                break  # Only need to mark once per file
                              
                    results.append(result)
                    """Save analysis results to a JSON file."""
                    with open(output_file, 'w', encoding='utf-8') as f:
                        json.dump(results, f, indent=2)
                    print(f"Analysis complete. Results saved to {output_file}")
                    
                except Exception as e:
                    results.append({
                        'file': file_path,
                        'error': f"Error processing file: {str(e)}"
                    })
    
    return results

def save_results_to_json(results: List[Dict], output_path: str) -> None:
    """Save analysis results to a JSON file."""
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2)

def find_all_functions(solidity_code: str) -> List[Dict]:
    """Find all function declarations in Solidity code, handling both implementations and interfaces."""
    # Pattern to match both:
    # 1. Full function implementations (with body)
    # 2. Interface function declarations (ending with ;)
    func_pattern = re.compile(
        r'function\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(([^)]*)\)'  # Function name and params
        r'([^{;]*)'                                           # Modifiers
        r'(?:\{)',                                          # Body start or declaration end
        re.DOTALL
    )
    
    functions = []
    for match in func_pattern.finditer(solidity_code):
        func_name = match.group(1)
        params = match.group(2).strip()
        modifiers = match.group(3).strip()
        start_pos = match.start()
        declaration_end = match.end()
        
        # Determine if this is an implementation (has body) or interface declaration
        if solidity_code[declaration_end - 1] == '{':
            # Implementation with body
            open_brace_pos = declaration_end - 1
            brace_level = 1
            close_brace_pos = open_brace_pos + 1
            
            while brace_level > 0 and close_brace_pos < len(solidity_code):
                char = solidity_code[close_brace_pos]
                if char == '{':
                    brace_level += 1
                elif char == '}':
                    brace_level -= 1
                close_brace_pos += 1
            
            if brace_level == 0:
                functions.append({
                    'name': func_name,
                    'params': params,
                    'modifiers': modifiers,
                    'start': start_pos,
                    'end': close_brace_pos,
                    'body': solidity_code[start_pos:close_brace_pos].strip(),
                    'is_implementation': True
                })
        else:
            # Interface declaration (ends with semicolon)
            functions.append({
                'name': func_name,
                'params': params,
                'modifiers': modifiers,
                'start': start_pos,
                'end': declaration_end,
                'body': solidity_code[start_pos:declaration_end].strip(),
                'is_implementation': False
            })
    
    return functions

def normalize_signature(signature: str) -> str:
    """Normalize function signature for comparison, matching Etherscan's behavior.
    Converts 'uint' to 'uint256' but preserves explicit sizes like 'uint8'."""
    if '(' not in signature:
        return signature
    
    func_name = signature.split('(')[0].strip()
    params = signature[len(func_name):].strip('()').split(',')
    
    param_types = []
    for param in params:
        param = param.strip()
        # Remove parameter name if present (anything after last space)
        if ' ' in param:
            param = param.rsplit(' ', 1)[0].strip()
        # Remove storage location keywords
        param = re.sub(r'\s+(memory|calldata|storage)\b', '', param)
        # Convert 'uint' to 'uint256' but keep 'uint8', 'uint16', etc.
        if param == 'uint':
            param = 'uint256'
        elif re.match(r'uint(?!\d)', param):  # catches 'uint' followed by non-digit
            param = 'uint256'
        param_types.append(param)
    
    normalized = f"{func_name}({','.join(param_types)})"
    return normalized

def get_parameter_dict(params_str: str) -> Dict[str, str]:
    """Convert parameters string to dictionary of name: type"""
    params = {}
    for param in params_str.split(','):
        param = param.strip()
        if param:
            parts = [p.strip() for p in param.split()]
            if len(parts) >= 2:
                param_type = ' '.join(parts[:-1])
                param_name = parts[-1]
                params[param_name] = param_type
    return params

def get_function_parameters(function_body: str) -> Dict[str, str]:
    """Extract parameter names and types from function signature."""
    params = {}
    # Match function parameters
    param_pattern = re.compile(r'function\s+\w+\s*\((.*?)\)')
    match = param_pattern.search(function_body)
    if match:
        param_list = match.group(1).split(',')
        for param in param_list:
            param = param.strip()
            if param:
                parts = param.split()
                if len(parts) >= 2:
                    param_type = parts[-2]
                    param_name = parts[-1]
                    params[param_name] = param_type
    return params





def create_automated_ground_truth(input_file: str, output_file: str, sample_size: int = 1000) -> dict:
    """
    Create a fully automated ground truth that marks files as non-compliant if:
    1. Any implementation fails any requirement, OR
    2. The sender_check requirement is specifically false
    """
    # Load analysis results
    with open(input_file, 'r', encoding='utf-8') as f:
        analysis_results = json.load(f)
    
    # Create automated ground truth
    ground_truth = {}
    
    for result in analysis_results[:sample_size]:
        if 'error' in result:
            # Mark files with errors as non-compliant
            filename = os.path.basename(result['file'])
            ground_truth[filename] = {
                'is_compliant': False,
                'reason': 'function_not_found_or_error'
            }
            continue
            
        filename = os.path.basename(result['file'])
        file_compliant = True
        reasons = []
        
        for impl in result.get('all_implementations', []):
            # Check if sender_check is specifically false
            if not impl['requirements'].get('sender_check', True):
                file_compliant = False
                reasons.append('sender_check_failed')
                break
            
            # Check interface pattern: to_isContract true but on_received false
            if (impl['requirements'].get('to_isContract_check', False) and 
                not impl['requirements'].get('on_received_check', True)):
                file_compliant = False
                reasons.append('interface_check_failed')
                break
            
            # Check if any requirement is false
            if not all(impl['requirements'].values()):
                file_compliant = False
                failed_reqs = [k for k, v in impl['requirements'].items() if not v]
                reasons.append(f'failed_requirements: {", ".join(failed_reqs)}')
        
        ground_truth[filename] = {
            'is_compliant': file_compliant,
            'requirements': impl['requirements'] if result.get('all_implementations') else {},
            'reason': 'compliant' if file_compliant else "; ".join(reasons)
        }
    
    # Save automated ground truth
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(ground_truth, f, indent=2)
    
    # Print summary statistics
    compliant_count = sum(1 for v in ground_truth.values() if v['is_compliant'])
    print(f"Created automated ground truth with {len(ground_truth)} contracts")
    print(f"Compliant contracts: {compliant_count} ({compliant_count/len(ground_truth):.1%})")
    print(f"Non-compliant contracts: {len(ground_truth)-compliant_count}")
    print(f"Saved to {output_file}")
    
    return ground_truth

def calculate_metrics(analysis_results: list, ground_truth: dict) -> dict:
    """
    Calculate precision, recall, and F1 score for overall compliance.
    """
    tp = fp = fn = 0
    
    for filename, truth in ground_truth.items():
        # Find matching result in analysis results
        result = next((r for r in analysis_results if os.path.basename(r.get('file', '')) == filename), None)
        if not result:
            continue
        
        # Determine detected compliance
        detected_compliant = True
        if 'error' in result:
            detected_compliant = False
        else:
            for impl in result.get('all_implementations', []):
                if not all(impl['requirements'].values()):
                    detected_compliant = False
                    break
        
        # Compare with ground truth
        if detected_compliant and truth['is_compliant']:
            tp += 1
        elif detected_compliant and not truth['is_compliant']:
            fp += 1
        elif not detected_compliant and truth['is_compliant']:
            fn += 1
    
    # Calculate metrics
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 0
    f1 = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0
    
    return {
        'overall': (precision, recall, f1),
        'counts': {'tp': tp, 'fp': fp, 'fn': fn},
        'compliance_rate': tp / len(ground_truth) if ground_truth else 0
    }


def analyze_transferFrom_interprocedural_analysis(solidity_code: str, target_sig: str = "transferFrom(address,address,uint256)") -> Dict:
    """Main analysis function for transferFrom compliance with allowance check."""
    all_functions = find_all_functions(solidity_code)
    
    
    target_funcs = find_functions_by_signature(all_functions, target_sig)
    print(f"len of target_funcs count: {len(target_funcs)}")
    
    
    if not target_funcs:
        return {"error": "transferFrom function not found"}
    
    results = []
    for target_func in target_funcs:
        # if contains_assembly(target_func['body']):
        #     print(f"assembly in target_func: {target_func['name']}")
        #     break
        
        internal_calls = get_all_internal_calls(target_func['body'], all_functions)
        # for f in internal_calls:
        #     if contains_assembly(f['body']):
        #         print(f"assembly in internal_calls: {f['name']}")
        #         break
        
        if internal_calls is None:
            print(f"internal_calls is None")
            # continue
            
        # requirements = verify_transferFrom_requirements(target_func, internal_calls)
        requirements = verify_erc5267_requirements(target_func, internal_calls)
        # print(f"requirements:{requirements}")
        
        
        # all_reqs = [
        #     # 'sender_check',
        #     'allowance_check',
        #     'conditional_allowance_check'
        #     # 'balance_check',
        #     # 'zero_address_check',
        #     # 'approval_event_found'
        # ]
        
        # all_met = all(requirements.get(req, False) for req in all_reqs)
        # some_met = any(requirements.get(req, False) for req in all_reqs)
        
        results.append({
            # "function": target_func['name'],
            # "implementation_location": f"Line {target_func['start']}-{target_func['end']}",
            # "parameters": target_func.get('parameters', {}),
            "requirements": requirements,
            # "internal_calls": [f['name'] for f in internal_calls],
            # "allowance_check_found": requirements.get('allowance_check', False),
            # "all_requirements_met": all_met,
            # "some_requirements_met": some_met
        })
    
    if results:
        return {
            "all_implementations": results,
            # "summary": {
            #     "total_implementations": len(results),
            #     "fully_compliant": sum(1 for r in results if r.get('all_requirements_met', False)),
            #     "partially_compliant": sum(1 for r in results if r.get('some_requirements_met', False))
            # }
        }
    return {"error": "No valid implementations found (possibly due to recursive calls)"}


def verify_transferFrom_requirements(target_func: Dict, internal_functions: List[Dict]) -> Dict:
    """
    Verify if transferFrom function meets ERC20 requirements:
    1. allowance check (msg.sender must have allowance)
    2. sender != zero address
    3. recipient != zero address
    4. sufficient balance
    5. Approval event emitted
    """
    requirements = {
        # 'sender_check': False,
        'allowance_check': False,
        'conditional_allowance_check': False,
        # 'balance_check': False,
        # 'zero_address_check': False,
        # 'approval_event_found': False
    }
    
    # Extract parameters
    params = extract_parameters_data_flow_analysis(target_func)
    from_param = params.get('from_param', 'from')
    to_param = params.get('to_param', 'to')
    amount_param = params.get('amount_param', 'amount')
    
    # Combine all code for analysis
    all_code = [(target_func['body'], "main function")]
    print(f"Searching in all_code: {all_code}")
    if(internal_functions is not None):
        for func in internal_functions:
            all_code.append((func['body'], f"internal function {func['name']}"))

    sender_reprs = ['msg.sender', '_msgSender()']
    
    # Analyze all conditions
    for code, source in all_code:
        
        # Remove multi-line and single-line comments
        code = re.sub(r'/\*.*?\*/', '', code, flags=re.DOTALL)
        code = re.sub(r'//.*$', '', code, flags=re.MULTILINE)
        # Find require statements
        require_pattern = r'require\s*\(((?:[^()]|\((?:[^()]|\([^()]*\))*\))*)\)'
        require_matches = re.finditer(require_pattern, code, re.DOTALL)
        
        # for match in require_matches:
        # req_content = re.sub(r'\s+', ' ', match.group(1).strip())
        
        # Pattern for allowance check inside if condition
        
        sub_pattern3 = r'_?a?pprove\s*\([^,]+,\s*[^,]+,\s*_?_?allowances?\[[^\]]+\]\[[^\]]+\]\s*-?\s*[^,)]+\)'
        if re.search(sub_pattern3, code, re.DOTALL): 
            requirements['allowance_check'] = True
            break
        
        sub_pattern5 = r'_?a?pprove\s*\([^;]+_?_?allowances?\[[^\]]+\]\[[^\]]+\]\.sub\s*\('
        if re.search(sub_pattern5, code, re.DOTALL): 
            requirements['allowance_check'] = True
            break
        
        sub_pattern6 = r'if\s*\([^;]*_*_*allowances?\[[^\]]+\]\[[^\]]+\]\s*>=\s*[^;]*\)'
        if re.search(sub_pattern6, code, re.DOTALL): 
            requirements['allowance_check'] = True
            break
        
        sub_pattern7 = r'require\s*\([^;]*_*_*allowances?\[[^\]]+\]\[[^\]]+\]\s*>=\s*[^;]*\)'
        if re.search(sub_pattern7, code, re.DOTALL): 
            requirements['allowance_check'] = True
            break
        sub_pattern8 = r'require\s*\([^;]*_*_*allowances?\[[^\]]+\]\[[^\]]+\]\s*[<>=]+\s*[^,]+,\s*["\'][^"\']*["\']\s*\)'
        if re.search(sub_pattern8, code, re.DOTALL): 
            requirements['allowance_check'] = True
            break
        
        sub_pattern9 = r'require\s*\([^;]*_*_*allowances?\[[^\]]+\]\[[^\]]+\]\s*[<>=]+\s*[^,]+,\s*["\'][^"\']*["\']\s*\)'
        if re.search(sub_pattern9, code, re.DOTALL): 
            requirements['allowance_check'] = True
            break
        
        var_match = re.search(r'uint256\s+(\w+)\s*=\s*_?_?allowances?\[[^\]]+\]\[[^\]]+\]', code)
        if var_match:
            var_name = var_match.group(1)  # Captures "allowed"
            print(f"var_name:{var_name}")
            
            # Step 2: Check if that variable appears in an if condition
            if_var_pattern = rf'if\s*\(\s*{var_name}\s*!=\s*type\(uint256\)\.max\s*\)'
            if re.search(if_var_pattern, code):
                requirements['allowance_check'] = True
                # requirements['conditional_allowance_check'] = False
                # print(f"variable appears in an if condition")
                break
            if_var_pattern1 = rf'if\s*\(\s*{var_name}\s*!=\s*[^)]+\)'
            if re.search(if_var_pattern1, code):
                requirements['allowance_check'] = True
                # requirements['conditional_allowance_check'] = False
                # print(f"variable appears in an if condition")
                break
        
        sub_pattern10 = r'if\s*\([^{]*!=[^{]*\)\s*\{[^{}]*_*_*allowances?\[[^\]]+\]\[[^\]]+\]'
        if re.search(sub_pattern10, code, re.DOTALL): 
            requirements['allowance_check'] = True
            break
        
        # sub_pattern2 = r'if\s*\([^;]*\)\s*\{?[^;]*?_?_?allowances?\[[^\]]+\]\[[^\]]+\]'
        sub_pattern2 = r'if\s*\((?![^)]*_?_?allowances?\[)[^)]*\)\s*\{?[^;]*?_?_?allowances?\[[^\]]+\]\[[^\]]+\]'
        # sub_pattern2 = r'if\s*\((?![^)]*_?_?allowances?\[[^\]]+\]\[[^\]]+\)[^)]*\)\s*\{?[^;]*?_?_?allowances?\[[^\]]+\]\[[^\]]+\]'
        if re.search(sub_pattern2, code, re.DOTALL): 
            requirements['conditional_allowance_check'] = True
            print(f"✅ allowance_check inside the if condition block in {source}")
            break
        
       
            
            
        
        # # Debug: Print the code when '_allowances' is found
        # if '_allowances' in code:
            print(f"\n🔍 Found '_allowances' in {source}")
            print(f"   Looking for if pattern...")
            
            # Test the pattern
            match = re.search(sub_pattern2, code, re.DOTALL)
            if match:
                print(f"   ✅ PATTERN MATCHED")
                print(f"   Matched text: {match.group(0)[:200]}")
            else:
                print(f"   ❌ PATTERN DID NOT MATCH")
                
                # Check condition separately
                if_pattern = r'if\s*\([^;]*?\)'
                if_match = re.search(if_pattern, code, re.DOTALL)
                if if_match:
                    print(f"   Found if statement: {if_match.group(0)}")
                    
                    # Check if condition contains _allowances
                    condition = if_match.group(0)
                    if '_allowances' in condition:
                        print(f"   → Condition contains _allowances (should NOT match)")
                    else:
                        print(f"   → Condition does NOT contain _allowances")
                        
                        # Check if body contains _allowances after the if
                        after_if = code[if_match.end():]
                        if '_allowances' in after_if:
                            print(f"   → Body contains _allowances (SHOULD match!)")
                            print(f"   Body snippet: {after_if[:200]}")
        
        
        
        
        sub_pattern4 = r'require\s*\(\s*_*allowances?\[[^\]]+\]\[[^\]]+\]\s*>=\s*[^,]+,\s*["\'][^"\']*["\']\s*\)'
        if re.search(sub_pattern4, code, re.DOTALL): 
            requirements['allowance_check'] = True
            break
        # Debug for _allowances presence
        # if '_allowances' in code:
        #     print(f"   ✅ Found '_allowances' in {source}")
        #     # Print the actual line
        #     for line in code.split('\n'):
        #         if '_allowances' in line:
        #             print(f"      Line: {line.strip()[:150]}")
        #             break
        
        # 2. ALLOWANCE CHECK - MODIFIED FOR .sub() DETECTION
        if not requirements['allowance_check']:
            # First, check the entire code (not just require conditions) for .sub() pattern
            for check_sender in sender_reprs:
                # .sub() pattern - captures allowance subtraction regardless of require wrapper
                sub_pattern = rf'_?allowances?\[{from_param}\]\[{re.escape(check_sender)}\]\.sub\s*\(\s*{amount_param}\s*,'
                
                if re.search(sub_pattern, code, re.DOTALL):
                    requirements['allowance_check'] = True
                    break
                
                # Also check for allowance[from][msg.sender].sub pattern
                sub_pattern2 = rf'_?allowances?\[{from_param}\]\[{re.escape(check_sender)}\]\.sub\s*\(\s*{amount_param}\s*,'
                if re.search(sub_pattern2, code, re.DOTALL):
                    requirements['allowance_check'] = True
                    break
                # Pattern matches: _allowances[anything][anything].sub(anything, "error")
                sub_pattern = r'_?allowances?\[[^\]]+\]\[[^\]]+\]\.sub\s*\([^,]+,\s*["\'][^"\']*["\']\s*\)'

                # DEBUG: Print the code being searched
                # print(f"Searching in: {source}")
                # print(f"Code snippet: {code[:2000]}")  # First 500 chars
                # print(f"Looking for pattern: {sub_pattern}")
                
                if re.search(sub_pattern, code, re.DOTALL): 
                    requirements['allowance_check'] = True
                    break
                
                # Pattern matches: _allowances[anything][anything]
                sub_pattern1 = r'return\s+_?allowances?\[[^\]]+\]\[[^\]]+\]'
                if re.search(sub_pattern1, code, re.DOTALL): 
                    requirements['allowance_check'] = True
                    break
                

                if '.sub(' in code:
                    requirements['allowance_check'] = True
                    print(f"✅ Found .sub() in {source}")
                    break
            
                # Also check in require conditions
                allowance_patterns = [
                    rf'_?allowances?\[{from_param}\]\[{re.escape(s)}\]\s*>=\s*{amount_param}' for s in sender_reprs
                ] + [
                    rf'_?allowances?\[{from_param}\]\[{re.escape(s)}\]\s*>=\s*{amount_param}' for s in sender_reprs
                ] + [
                    rf'_?allowances?\(\s*{from_param}\s*,\s*{re.escape(s)}\s*\)\s*>=\s*{amount_param}' for s in sender_reprs
                ] + [
                    rf'require\s*\(\s*_?allowances?\[{from_param}\]\[{re.escape(s)}\]\.sub\s*\(\s*{amount_param}\s*,' for s in sender_reprs
                ]
                
                for pattern in allowance_patterns:
                    if re.search(pattern, code, re.DOTALL):
                        requirements['allowance_check'] = True
                        break
        
       
    
    return requirements


def extract_parameters_data_flow_analysis(target_func: Dict) -> Dict:
    """Extract parameter names from transferFrom function."""
    params = target_func.get('parameters', {})
    param_names = params.get('names', [])
    
    result = {
        'from_param': param_names[0] if len(param_names) > 0 else 'from',
        'to_param': param_names[1] if len(param_names) > 1 else 'to',
        'amount_param': param_names[2] if len(param_names) > 2 else 'amount'
    }
    return result




def parse_solidity_file(file_path: str) -> str:
    """Parse files with comments and double braces before JSON content."""
    with open(file_path, 'r', encoding='utf-8-sig') as f:
        data = f.read()
    
    # Remove leading comments (lines starting with //)
    lines = data.split('\n')
    json_start_index = 0
    for i, line in enumerate(lines):
        if line.strip().startswith('{'):
            json_start_index = i
            break
    
    # Extract JSON part (from first '{' onwards)
    json_part = '\n'.join(lines[json_start_index:])
    
    # Fix double braces: replace {{ with { and }} with }
    json_part = re.sub(r'{{', '{', json_part)
    json_part = re.sub(r'}}', '}', json_part)
    
    # Try to parse as JSON
    try:
        json_data = json.loads(json_part)
        print(f"   ✅ Successfully parsed JSON after cleaning")
        
        if 'sources' in json_data:
            sources = []
            for source_name, source_info in json_data['sources'].items():
                if 'content' in source_info:
                    sources.append(f"// File: {source_name}\n{source_info['content']}")
            return '\n\n'.join(sources)
        return json_part
    except json.JSONDecodeError as e:
        print(f"   ⚠️ JSON parse failed: {e}")
        return data

def analyze_directory_transferFrom(directory_path: str, output_file: str, target_sig: str, max_files: int = None) -> List[Dict]:
    """
    Analyze all Solidity files in a directory for transferFrom compliance.
    
    Args:
        directory_path: Path to directory containing .sol files
        output_file: Path to save JSON results
        target_sig: Function signature to analyze (default: transferFrom)
        max_files: Maximum number of files to process (None = unlimited)
    
    Returns:
        List of analysis results for each file
    """
    results = []
    files_processed = 0
    files_with_errors = 0
    
    print(f"📁 Scanning directory: {directory_path}")
    print(f"🎯 Target signature: {target_sig}")
    print(f"💾 Output file: {output_file}")
    if max_files:
        print(f"🔢 Max files to process: {max_files}")
    print("-" * 60)
    
    for root, _, files in os.walk(directory_path):
        for file in files:
            # Stop if max_files limit reached
            if max_files and files_processed >= max_files:
                print(f"🛑 Reached max files limit ({max_files}). Stopping.")
                break
            
            if file.endswith('.sol'):
                file_path = os.path.join(root, file)
                files_processed += 1
                
                print(f"📄 Processing ({files_processed}): {file_path}")
                
                try:
                    # solidity_code = parse_solidity_file(file_path)
                    with open(file_path, 'r', encoding='utf-8') as f:
                        solidity_code = f.read()
                    
                    # if not solidity_code.strip():
                    #     print(f"   ⚠️ Empty file, skipping")
                    #     continue
                    
                    result = analyze_transferFrom_interprocedural_analysis(solidity_code, target_sig)
                    result['file'] = file_path
                    
                    if 'error' in result:
                        files_with_errors += 1
                        print(f"   ❌ Error: {result['error']}")
                    
                    results.append(result)
                    
                    with open(output_file, 'w', encoding='utf-8') as f:
                        json.dump(results, f, indent=2)
                    
                except Exception as e:
                    files_with_errors += 1
                    error_msg = f"Error processing file: {str(e)}"
                    print(f"   ❌ {error_msg}")
                    results.append({
                        'file': file_path,
                        'error': error_msg
                    })
        
        # Break outer loop if limit reached
        if max_files and files_processed >= max_files:
            break
    
    print("-" * 60)
    print(f"📊 ANALYSIS COMPLETE")
    print(f"   Total files processed: {files_processed}")
    print(f"   Files with errors: {files_with_errors}")
    print(f"   Results saved to: {output_file}")
    
    return results

def analyze_single_file_transferFrom(file_path: str, target_sig: str = "transferFrom(address,address,uint256)") -> Dict:
    """
    Analyze a single Solidity file for transferFrom compliance.
    
    Args:
        file_path: Path to .sol file
        target_sig: Function signature to analyze
    
    Returns:
        Analysis result dictionary
    """
    print(f"📄 Analyzing single file: {file_path}")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            solidity_code = f.read()
        
        result = analyze_transferFrom_interprocedural_analysis(solidity_code, target_sig)
        result['file'] = file_path
        
        if 'summary' in result:
            summary = result['summary']
            print(f"   ✅ Total implementations: {summary['total_implementations']}")
            print(f"   ✅ Fully compliant: {summary['fully_compliant']}")
            print(f"   ⚠️ Partially compliant: {summary['partially_compliant']}")
        elif 'error' in result:
            print(f"   ❌ Error: {result['error']}")
        
        return result
        
    except Exception as e:
        error_msg = f"Error processing file: {str(e)}"
        print(f"   ❌ {error_msg}")
        return {'file': file_path, 'error': error_msg}


def print_vulnerable_contracts(results_file: str):
    """
    Print only vulnerable contracts (where allowance_check is False)
    """
    with open(results_file, 'r', encoding='utf-8') as f:
        results = json.load(f)
    
    print("\n" + "=" * 80)
    print("🔴 VULNERABLE CONTRACTS (Missing Allowance Check)")
    print("=" * 80)
    
    vulnerable_count = 0
    for result in results:
        if 'all_implementations' in result:
            for impl in result['all_implementations']:
                if not impl.get('requirements', {}).get('allowance_check', False):
                    vulnerable_count += 1
                    print(f"\n📁 File: {result.get('file', 'Unknown')}")
                    print(f"   Function: {impl.get('function', 'transferFrom')}")
                    print(f"   Lines: {impl.get('implementation_location', 'Unknown')}")
                    print(f"   Missing: allowance_check")
                    print(f"   All requirements met: {impl.get('all_requirements_met', False)}")
    
    if vulnerable_count == 0:
        print("\n✅ No vulnerable contracts found!")
    else:
        print(f"\n⚠️ Total vulnerable implementations found: {vulnerable_count}")





CATEGORY_MAPPING = {
    "Missing Access Control": "MAC",
    "Missing Address Validation": "MAV",
    "Missing Array Length Check": "MAL",
    "Missing Event Emission": "MEM",
    "Reentrancy on Receiver (Redundant/misordered receiver callbacks)": "RoR",
    "Missing interface compliance checks": "MIC",
    "Gas Griefing (Unexpected large Batch Loop Size)": "GG",
    "Inefficient transfers (Using safetransferfrom inside of batch structure)": "IET",
    "Incorrect Transfers (Mint operation inside transfer function)": "ICT",
    "Intentional Revert inside of Logic:\n(_enforceNonTransferable)": "IR",
    "Violation of Atomicity": "VA",
    "Zero Length Transfer": "ZLT"
}

def plot_vulnerability_distribution(file_path, sheet_name):
    """
    Plots the distribution of vulnerabilities across categories from an Excel file.
    Uses exact column names: 'Security & Vulnerability category' and '# of founded vulnerabilites'
    """
    try:
        # Read the first 11 rows of data
        df = pd.read_excel(file_path, sheet_name=sheet_name, nrows=11)
        
        # Verify the exact column names exist
        required_columns = {
            'category': 'Security & Vulnerability category',
            'addresses': '# of founded vulnerabilites'
        }
        
        missing_cols = [col for col in required_columns.values() if col not in df.columns]
        if missing_cols:
            print(f"Error: Required columns not found. Missing: {missing_cols}")
            print(f"Available columns: {list(df.columns)}")
            return
        
        # Select and rename columns
        df = df[list(required_columns.values())].copy()
        df.columns = ['category', 'addresses']
        
        # Clean and process the data
        df = df.dropna()
        
        # Clean category names and apply mapping
        df['category'] = df['category'].str.strip()
        df['short_category'] = df['category'].map(CATEGORY_MAPPING)
        
        # Handle any categories not in our mapping
        df['short_category'] = df['short_category'].fillna(df['category'])
        
        # Split addresses if they're in a single string separated by newlines
        df['addresses'] = df['addresses'].apply(lambda x: x.split('\n') if isinstance(x, str) else [])
        
        # Explode the list of addresses into separate rows
        exploded_df = df.explode('addresses')
        
        # Count unique addresses per category (remove empty strings)
        vuln_counts = exploded_df[exploded_df['addresses'].str.strip() != ''].groupby('short_category').size()
        vuln_counts = vuln_counts.sort_values(ascending=False)
        
        if vuln_counts.empty:
            print("Error: No valid contract addresses found after processing.")
            return
        
        # Create plot
        plt.figure(figsize=(10, 6))
        ax = vuln_counts.plot(kind='bar', color='#1f77b4')
        
        # Customize plot
        plt.title("Smart Contract Vulnerabilities Distribution", fontsize=14, pad=20)
        plt.xlabel("Vulnerability Category", fontsize=12)
        plt.ylabel("Number of Affected Contracts", fontsize=12)
        plt.xticks(rotation=45, ha='right', fontsize=10)
        plt.yticks(fontsize=10)
        
        # Remove top and right spines
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        
        # Add value labels on top of each bar
        for i, v in enumerate(vuln_counts):
            ax.text(i, v + 0.1, str(v), ha='center', va='bottom', fontsize=9)
        
        plt.tight_layout()
        plt.show()
        
        # Return the counts for reference
        return vuln_counts
        
    except FileNotFoundError:
        print(f"Error: The file {file_path} was not found.")
    except Exception as e:
        print(f"An error occurred: {str(e)}")



if __name__ == "__main__":

    
    # erc1155_directory = "/home/ashok/ERC-analysis/erc-classify/ERC1155-ethereum/ERC1155"
    # erc1155_output_file = "/home/ashok/ERC-analysis/erc-classify/erc1155_TEST_TEST_analysis_results.json"
    # erc1155_directory = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/ERC_Solidity_Source/ERC1155"
    # erc1155_directory = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/ERC1155_Solidity_SourceCode/ERC1155"
    # erc1155_directory = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/ERC1155-avalanche"
    
    # erc1155_directory = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/Recall_dataset4"
    
    # erc1155_output_file = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/erc1155_TEST_TEST_analysis_results.json"
    # erc1155_output_file = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/erc1155_ethereum1_analysis_results.json"
    # erc1155_directory = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/ERC1155-polygon/polygon_ERC1155"
    # erc3643_directory = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/ERC_Solidity_Source/ERC3643"
    # erc1155_output_file = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/erc1155_SafeBatch_avalanche_assembly_delete.json"
    # erc1155_output_file = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/erc1155_SafeBatch_bsc_assembly_delete.json"
    # erc1155_output_file = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/erc1155_SafeBatch_polygon_assembly_delete.json"
    # erc1155_output_file = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/erc1155_SafeBatch_ethereum_assembly_delete.json"
    
    erc1155_output_file = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/erc1155_Recall_Results4.json"
    
    # erc3643_output_file = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/erc3643_batchTransfer_TEST_ONE.json"
    
    erc1155_target_sig = "safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)"

    erc20_transferFrom_sig = "transferFrom(address from, address to, uint256 value)"

    # erc20_transferFrom_directory = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/erc20-transferFrom"
    erc20_transferFrom_directory = "/Users/ashokk/Downloads/evm_data/erc20-transferFrom1"
    # erc20_output = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/erc20-transferFrom/erc20-output"
    erc20_output_20k_files = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/erc20-transferFrom/erc20-output_20k_files"
    
    erc5267_code_directory = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/DATA/erc5267-source_code"
    
    erc5267_code_output = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/DATA/erc5267-source_code/erc5267_code_outputfile"
    erc5267_sig = "eip712Domain()"
    # erc5267_sig = "eip712Domain() external view returns ( bytes1 fields, string name, string version, uint256 chainId, address verifyingContract, bytes32 salt, uint256[] extensions )"
    
    
    
    
    # erc3643_target_sig = "batchTransfer(address[] calldata _toList, uint256[] calldata _amounts)"
    
    # # BatchMetadataUpdate(uint256,uint256) : 6bd5c950
    #ERC3443
    # event TokensFrozen(address indexed _userAddress, uint256 _amount);
    # event TokensUnfrozen(address indexed _userAddress, uint256 _amount);
    # "batchTransfer(address[],uint256[])": "88d695b2",
    #         "batchForcedTransfer(address[],address[],uint256[])": "42a47abc",
    #         "batchMint(address[],uint256[])": "68573107",
    #         "batchBurn(address[],uint256[])": "4a6cc677",
    #         "batchSetAddressFrozen(address[],bool[])": "1a7af379",
    #         "batchFreezePartialTokens(address[],uint256[])": "fc7e5fa8",
    #         "batchUnfreezePartialTokens(address[],uint256[])": "4710362d"
    #         "safeMintBatch(address,uint256[],uint256[],bytes)": "c39dfed8",
    #  
    #         "burnBatch(address,uint256[],uint256[],bytes)": "5473422e"
    # "balanceOfBatch(address[],uint256[])": "4e1273f4",
    # "setApprovalForAll(address,bool)": "a22cb465",
    
    # erc1155_target_sig_setApprovalForAll = "setApprovalForAll(address operator, bool approved)"
    
    # analysis_results = analyze_directory(erc1155_directory, erc1155_output_file, erc1155_target_sig)
    # analysis_results = analyze_directory(erc1155_directory,erc1155_output_file, erc20_transferFrom)
    analyze_directory_transferFrom(erc5267_code_directory,erc5267_code_output, erc5267_sig, max_files=1000)
    
    # compliant_files = [r for r in analysis_results if not r.get('error')]
    # print(f"\nFiles with safeBatchTransferFrom implementation: {len(compliant_files)}")
    
    # if compliant_files:
    #     # Collect all implementations across all files
    #     all_implementations = []
    #     for result in compliant_files:
    #         if 'all_implementations' in result:
    #             all_implementations.extend(result['all_implementations'])
        
    #     if all_implementations:
    #         print("\nRequirement compliance summary across all implementations:")
    #         for req in ['sender_check', 'approval_check', 'zero_address_check', 
    #                    'length_matching_check', 
    #                    'event_emission_order',
    #                    'transfer_batch_event_found', 'to_isContract_check', 'on_received_check','gas_family_errors']:
    #             count = sum(1 for impl in all_implementations 
    #                       if impl.get('requirements', {}).get(req, False))
    #             print(f"- {req}: {count}/{len(all_implementations)} compliant")
            
    #         # Print overall compliance
    #         fully_compliant = sum(
    #             1 for impl in all_implementations
    #             if all(impl.get('requirements', {}).get(req, False) 
    #                 for req in ['sender_check', 'approval_check', 'zero_address_check',
    #                             'length_matching_check', 'event_emission_order',
    #                             'transfer_batch_event_found', 'to_isContract_check', 
    #                             'on_received_check','gas_family_errors'])
    #         )
    #         print(f"\nFully compliant implementations: {fully_compliant}/{len(all_implementations)}")
    
    # error_files = [r for r in analysis_results if r.get('error')]
    # if error_files:
    #     print("\nFiles with processing errors:")
    #     for file in error_files:
    #         print(f"- {file['file']}: {file['error']}")
            
            
            
            
            
    
    # Example usage:
    # plot_vulnerability_distribution(
    #     file_path="/Users/ashokk/Downloads/Ethereum_ERC.xlsx",
    #     sheet_name="Multi-Token Operation")
    
    # total_files = sum(1 for file in os.listdir("/Users/ashokk/Documents/ERC-analysis-master/erc-classify/ERC1155-binance/bsc_ERC1155") if file.endswith('.sol'))
    # print(f"Total .sol files: {total_files}")
    
    
   
    
    
#    # File paths
    # input_json = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/erc1155_ethereum1_Local_analysis_results.json"
    # output_json = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/erc1155_automated_ground_truth.json"
    
    # Create automated ground truth (first 1000 files)
    # ground_truth = create_automated_ground_truth(input_json, output_json, sample_size=1000)
    
    # Load analysis results for metrics calculation
    # with open(input_json, 'r', encoding='utf-8') as f:
    #     analysis_results = json.load(f)
        
    # with open(output_json, 'r', encoding='utf-8') as f:
    #     ground_truth = json.load(f)
    
    # # Calculate metrics
    # metrics = calculate_metrics(analysis_results, ground_truth)
    
    # # Print results
    # print("\nCompliance Metrics:")
    # print(f"True Positives (Correctly identified compliant): {metrics['counts']['tp']}")
    # print(f"False Positives (Incorrectly marked as compliant): {metrics['counts']['fp']}")
    # print(f"False Negatives (Incorrectly marked as non-compliant): {metrics['counts']['fn']}")
    # print(f"\nEstimated Compliance Rate: {metrics['compliance_rate']:.1%}")
    # print("\nPerformance Metrics:")
    # print(f"Precision: {metrics['overall'][0]:.2f}")
    # print(f"Recall: {metrics['overall'][1]:.2f}")
    # print(f"F1 Score: {metrics['overall'][2]:.2f}")
    
    
    
    
            
            
# Processed 'ERC-1155_safeBatchTransferFrom_deduplicated_avalanche.csv' - Number of rows: 1023
# Processed 'ERC-1155_safeBatchTransferFrom_deduplicated_polygon.csv' - Number of rows: 17666
# Processed 'ERC-1155_safeBatchTransferFrom_ethereum_deduplicated_results.csv' - Number of rows: 9914
# Processed 'ERC-1155_safeBatchTransferFrom_binance_deduplicated_results.csv' - Number of rows: 6803