import pandas as pd
import numpy as np
from concurrent.futures import ProcessPoolExecutor, as_completed
import multiprocessing as mp
import os
import re



ERC_CONFIG = {
    'ERC1155_safeTransferFrom': {
        'selector': '0xf242432a',
        'function': 'safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data)',
        'erc': 'ERC-1155',
        'receiverSpecs': {
            'interface': 'IERC1155Receiver',
            'method': 'onERC1155Received',
            'magicValue': '0xf23a6e61',
            'risk': 'SAFE',  # Reverts if not implemented
            'tokenLossRisk': 'NO_RISK'
        }
    },
    'ERC1155_safeBatchTransferFrom': {
        'selector': '0x2eb2c2d6',
        'function': 'safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data)',
        'erc': 'ERC-1155',
        'receiverSpecs': {
            'interface': 'IERC1155Receiver',
            'method': 'onERC1155BatchReceived',
            'magicValue': '0xbc197c81',
            'risk': 'SAFE',  # Reverts if not implemented
            'tokenLossRisk': 'NO_RISK'
        }
    },
    'ERC721_safeTransferFrom': {
        'selector': '0xb88d4fde',
        'function': 'safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes data)',
        'erc': 'ERC-721',
        'receiverSpecs': {
            'interface': 'IERC721Receiver',
            'method': 'onERC721Received',
            'magicValue': '0x150b7a02',
            'risk': 'SAFE',  # Reverts if not implemented
            'tokenLossRisk': 'NO_RISK'
        }
    },
    'ERC223_transfer': {
        'selector': '0xbe45fd62',
        'function': 'transfer(address _to, uint _value, bytes calldata _data) returns (bool)',
        'erc': 'ERC-223',
        'receiverSpecs': {
            'interface': 'TokenReceiver',
            'method': 'tokenFallback',
            'magicValue': None,
            'risk': 'HIGH_RISK',  # Continues even if not implemented
            'tokenLossRisk': 'TOKENS_LOST'
        }
    },
    'ERC777_send': {
        'selector': '0x9bd9bbc6',
        'function': 'send(address to, uint256 amount, bytes calldata data)',
        'erc': 'ERC-777',
        'receiverSpecs': {
            'interface': 'IERC777Recipient',
            'method': 'tokensReceived',
            'magicValue': None,
            'risk': 'MEDIUM_RISK',  # Continues but may have other checks
            'tokenLossRisk': 'TOKENS_LOST'
        }
    },
    'ERC777_operatorSend': {
        'selector': '0x62ad1b83',
        'function': 'operatorSend(address from, address to, uint256 amount, bytes calldata data, bytes calldata operatorData)',
        'erc': 'ERC-777',
        'receiverSpecs': {
            'interface': 'IERC777Recipient',
            'method': 'tokensReceived',
            'magicValue': None,
            'risk': 'MEDIUM_RISK',
            'tokenLossRisk': 'TOKENS_LOST'
        }
    },
    'ERC1363_transferAndCall1': {
        'selector': '0x1296ee62',
        'function': 'transferAndCall(address to, uint256 value)',
        'erc': 'ERC-1363',
        'receiverSpecs': {
            'interface': 'ERC1363Receiver',
            'method': 'onTransferReceived',
            'magicValue': None,
            'risk': 'HIGH_RISK',  # Tokens transfer then call fails
            'tokenLossRisk': 'TOKENS_STUCK'
        }
    },
    # ... similar for other ERC-1363 functions
}

# Define ERC function selectors and their metadata
ERC_CONFIG = {
    'ERC1155_safeTransferFrom': {
        'selector': '0xf242432a',
        'function': 'safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data)',
        'erc': 'ERC-1155'
    },
    'ERC1155_safeBatchTransferFrom': {
        'selector': '0x2eb2c2d6',
        'function': 'safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data)',
        'erc': 'ERC-1155'
    },
    'ERC223_transfer': {
        'selector': '0xbe45fd62',
        'function': 'transfer(address _to, uint _value, bytes calldata _data) returns (bool)',
        'erc': 'ERC-223'
    },
    'ERC777_send': {
        'selector': '0x9bd9bbc6',
        'function': 'send(address to, uint256 amount, bytes calldata data)',
        'erc': 'ERC-777'
    },
    'ERC777_operatorSend': {
        'selector': '0x62ad1b83',
        'function': 'operatorSend(address from, address to, uint256 amount, bytes calldata data, bytes calldata operatorData)',
        'erc': 'ERC-777'
    },
    'ERC721_safeTransferFrom': {
        'selector': '0xb88d4fde',
        'function': 'safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes data)',
        'erc': 'ERC-721'
    },
    'ERC1363_transferAndCall1': {
        'selector': '0x1296ee62',
        'function': 'transferAndCall(address to, uint256 value)',
        'erc': 'ERC-1363'
    },
    'ERC1363_transferAndCall2': {
        'selector': '0x4000aea0',
        'function': 'transferAndCall(address to, uint256 value, bytes memory data)',
        'erc': 'ERC-1363'
    },
    'ERC1363_transferFromAndCall1': {
        'selector': '0xd8fbe994',
        'function': 'transferFromAndCall(address from, address to, uint256 value)',
        'erc': 'ERC-1363'
    },
    'ERC1363_transferFromAndCall2': {
        'selector': '0xc1d34b89',
        'function': 'transferFromAndCall(address from, address to, uint256 value, bytes memory data)',
        'erc': 'ERC-1363'
    },
    'ERC1363_approveAndCall1': {
        'selector': '0x3177029f',
        'function': 'approveAndCall(address spender, uint256 value)',
        'erc': 'ERC-1363'
    },
    'ERC1363_approveAndCall2': {
        'selector': '0xcae9ca51',
        'function': 'approveAndCall(address spender, uint256 value, bytes memory data)',
        'erc': 'ERC-1363'
    }
}

def check_selector_in_bytecode(bytecode, selector):
    """Optimized function to check if selector exists in bytecode"""
    if pd.isna(bytecode) or not bytecode:
        return False
    
    # Remove '0x' prefix if present and convert to lowercase for case-insensitive matching
    bytecode_clean = str(bytecode).lower().replace('0x', '')
    selector_clean = selector.lower().replace('0x', '')
    
    # Simple substring search - this is much faster than regex for large datasets
    return selector_clean in bytecode_clean

def process_batch(batch_data):
    """Process a batch of bytecode entries"""
    bytecodes, selectors = batch_data
    results = []
    
    for bytecode in bytecodes:
        matched_ercs = []
        matched_functions = []
        
        for erc_name, config in ERC_CONFIG.items():
            if check_selector_in_bytecode(bytecode, config['selector']):
                matched_ercs.append(config['erc'])
                matched_functions.append(config['function'])
        
        # Join multiple matches with semicolon
        erc_result = ';'.join(matched_ercs) if matched_ercs else ''
        function_result = ';'.join(matched_functions) if matched_functions else ''
        
        results.append((erc_result, function_result))
    
    return results

def process_file_optimized(file_path, output_file=None, batch_size=10000, n_workers=None):
    """
    Optimized function to process large CSV files with smart contract bytecode
    
    Args:
        file_path (str): Path to input CSV file
        output_file (str): Path to output CSV file (optional)
        batch_size (int): Number of rows to process in each batch
        n_workers (int): Number of parallel workers (default: CPU count - 1)
    """
    
    if n_workers is None:
        n_workers = max(1, mp.cpu_count() - 1)
    
    print(f"Processing {file_path} with {n_workers} workers...")
    
    # Use chunks to handle large files without loading everything into memory
    chunks = pd.read_csv(file_path, chunksize=batch_size, usecols=['bytecode'])
    
    all_results = []
    processed_rows = 0
    
    for chunk_idx, chunk in enumerate(chunks):
        print(f"Processing chunk {chunk_idx + 1}...")
        
        # Prepare batch data for parallel processing
        bytecodes = chunk['bytecode'].fillna('').tolist()
        
        # Split data into batches for parallel processing
        batch_size_parallel = len(bytecodes) // n_workers + 1
        batches = []
        
        for i in range(0, len(bytecodes), batch_size_parallel):
            batch_bytecodes = bytecodes[i:i + batch_size_parallel]
            batches.append((batch_bytecodes, ERC_CONFIG))
        
        # Process batches in parallel
        with ProcessPoolExecutor(max_workers=n_workers) as executor:
            future_to_batch = {
                executor.submit(process_batch, batch): idx 
                for idx, batch in enumerate(batches)
            }
            
            chunk_results = []
            for future in as_completed(future_to_batch):
                try:
                    batch_results = future.result()
                    chunk_results.extend(batch_results)
                except Exception as e:
                    print(f"Error processing batch: {e}")
                    # Add empty results for failed batch
                    failed_batch_size = len(batches[future_to_batch[future]][0])
                    chunk_results.extend([('', '')] * failed_batch_size)
        
        # Add results to chunk
        chunk_results_clean = chunk_results[:len(chunk)]
        erc_col, func_col = zip(*chunk_results_clean)
        
        chunk['ERC'] = erc_col
        chunk['function_name'] = func_col
        
        all_results.append(chunk)
        processed_rows += len(chunk)
        print(f"Processed {processed_rows} rows so far...")
    
    # Combine all chunks
    final_df = pd.concat(all_results, ignore_index=True)
    
    # Save results if output file specified
    if output_file:
        final_df.to_csv(output_file, index=False)
        print(f"Results saved to {output_file}")
    
    # Print summary statistics
    erc_counts = final_df[final_df['ERC'] != '']['ERC'].value_counts()
    print("\nERC Standards Found:")
    for erc_standard, count in erc_counts.items():
        print(f"  {erc_standard}: {count} contracts")
    
    total_matched = len(final_df[final_df['ERC'] != ''])
    print(f"\nTotal contracts with ERC standards: {total_matched}/{len(final_df)}")
    
    return final_df

def process_multiple_files(file_paths, output_dir="output", n_workers=None):
    """
    Process multiple CSV files
    
    Args:
        file_paths (list): List of CSV file paths to process
        output_dir (str): Output directory for processed files
        n_workers (int): Number of parallel workers
    """
    
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    results = {}
    
    for file_path in file_paths:
        print(f"\n{'='*50}")
        print(f"Processing: {file_path}")
        print(f"{'='*50}")
        
        # Generate output file name
        base_name = os.path.basename(file_path)
        output_file = os.path.join(output_dir, f"new_processed_{base_name}")
        
        # Process the file
        result_df = process_file_optimized(
            file_path=file_path,
            output_file=output_file,
            n_workers=n_workers
        )
        
        results[file_path] = result_df
    
    return results

# Example usage
if __name__ == "__main__":
    # List your CSV files
    csv_files = [
       
        # ,
        "/data/ethereum_deduplicated_results.csv"
        
    ]
    
    # Process all files
    results = process_multiple_files(csv_files, n_workers=4)
    


# Avalanche: 
    
#  ERC Standards Found:
#   ERC-721: 6307 contracts
#   ERC-1155;ERC-1155: 949 contracts
#   ERC-1363: 812 contracts
#   ERC-1155: 559 contracts
#   ERC-1363;ERC-1363: 108 contracts
#   ERC-1155;ERC-721: 92 contracts
#   ERC-777: 25 contracts
#   ERC-1363;ERC-1363;ERC-1363;ERC-1363;ERC-1363;ERC-1363: 25 contracts
#   ERC-1155;ERC-1155;ERC-721: 16 contracts
#   ERC-777;ERC-777: 14 contracts
#   ERC-721;ERC-1363: 14 contracts
#   ERC-223: 6 contracts
#   ERC-1155;ERC-777: 2 contracts
#   ERC-1155;ERC-1155;ERC-1363: 1 contracts
#   ERC-1155;ERC-1363: 1 contracts


# Polygon:

# ERC Standards Found:
#   ERC-721: 60244 contracts
#   ERC-1155;ERC-1155: 17336 contracts
#   ERC-1155: 2646 contracts
#   ERC-1363: 1471 contracts
#   ERC-1155;ERC-721: 510 contracts
#   ERC-721;ERC-1363: 194 contracts
#   ERC-1363;ERC-1363: 120 contracts
#   ERC-1363;ERC-1363;ERC-1363;ERC-1363;ERC-1363;ERC-1363: 111 contracts
#   ERC-777;ERC-777: 86 contracts
#   ERC-1155;ERC-1155;ERC-721: 46 contracts
#   ERC-777: 41 contracts
#   ERC-1155;ERC-1363: 26 contracts
#   ERC-1155;ERC-1155;ERC-1363: 22 contracts
#   ERC-223: 13 contracts
#   ERC-721;ERC-1363;ERC-1363;ERC-1363;ERC-1363: 11 contracts
#   ERC-223;ERC-777: 7 contracts
#   ERC-1155;ERC-721;ERC-1363: 6 contracts
#   ERC-1155;ERC-777: 6 contracts
#   ERC-777;ERC-721: 5 contracts
#   ERC-721;ERC-1363;ERC-1363;ERC-1363;ERC-1363;ERC-1363;ERC-1363: 1 contracts
#   ERC-1155;ERC-777;ERC-777: 1 contracts
#   ERC-1363;ERC-1363;ERC-1363: 1 contracts

# Binance:

# ERC Standards Found:
#   ERC-1363: 77572 contracts
#   ERC-721: 40180 contracts
#   ERC-1155;ERC-1155: 6075 contracts
#   ERC-1155: 5463 contracts
#   ERC-1363;ERC-1363: 997 contracts
#   ERC-1155;ERC-721: 497 contracts
#   ERC-1363;ERC-1363;ERC-1363;ERC-1363;ERC-1363;ERC-1363: 422 contracts
#   ERC-777;ERC-777: 322 contracts
#   ERC-721;ERC-1363: 289 contracts
#   ERC-777: 154 contracts
#   ERC-1155;ERC-1155;ERC-721: 107 contracts
#   ERC-223: 83 contracts
#   ERC-1155;ERC-1363: 58 contracts
#   ERC-1155;ERC-1155;ERC-1363: 22 contracts
#   ERC-721;ERC-1363;ERC-1363;ERC-1363;ERC-1363;ERC-1363;ERC-1363: 9 contracts
#   ERC-777;ERC-777;ERC-1363: 5 contracts
#   ERC-223;ERC-1363: 4 contracts
#   ERC-1363;ERC-1363;ERC-1363: 4 contracts
#   ERC-1155;ERC-721;ERC-1363: 4 contracts
#   ERC-1155;ERC-777: 4 contracts
#   ERC-1155;ERC-1155;ERC-777: 2 contracts
#   ERC-1155;ERC-1363;ERC-1363: 1 contracts
#   ERC-777;ERC-721: 1 contracts
# Total contracts with ERC standards: 132275/2308899

# Ethereum:

# ERC Standards Found:
#   ERC-721: 87124 contracts
#   ERC-1363: 52781 contracts
#   ERC-1155;ERC-1155: 9081 contracts
#   ERC-1155: 4287 contracts
#   ERC-223: 2100 contracts
#   ERC-1155;ERC-721: 767 contracts
#   ERC-1363;ERC-1363: 478 contracts
#   ERC-721;ERC-1363: 398 contracts
#   ERC-777;ERC-777: 376 contracts
#   ERC-1363;ERC-1363;ERC-1363;ERC-1363;ERC-1363;ERC-1363: 330 contracts
#   ERC-777: 303 contracts
#   ERC-1155;ERC-1155;ERC-721: 205 contracts
#   ERC-223;ERC-1363: 180 contracts
#   ERC-1363;ERC-1363;ERC-1363: 74 contracts
#   ERC-1155;ERC-1363: 25 contracts
#   ERC-1155;ERC-1155;ERC-1363: 12 contracts
#   ERC-777;ERC-777;ERC-1363: 10 contracts
#   ERC-721;ERC-1363;ERC-1363;ERC-1363;ERC-1363;ERC-1363;ERC-1363: 9 contracts
#   ERC-223;ERC-1363;ERC-1363;ERC-1363: 7 contracts
#   ERC-223;ERC-721: 6 contracts
#   ERC-777;ERC-721: 4 contracts
#   ERC-1155;ERC-777: 3 contracts
#   ERC-223;ERC-1363;ERC-1363: 3 contracts
#   ERC-1155;ERC-1155;ERC-777: 2 contracts
#   ERC-777;ERC-777;ERC-721: 1 contracts
#   ERC-1155;ERC-721;ERC-1363: 1 contracts
#   ERC-721;ERC-1363;ERC-1363: 1 contracts
#   ERC-1155;ERC-777;ERC-777: 1 contracts
#   ERC-1155;ERC-223: 1 contracts

# Total contracts with ERC standards: 158570/1114861