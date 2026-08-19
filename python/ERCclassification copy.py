import os

import requests
import json
import time
import pandas as pd
import sys
import os
from dotenv import load_dotenv
from collections import defaultdict




current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.abspath(os.path.join(current_dir, ".."))

if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

import rattle

sys.setrecursionlimit(20000)

# Load .env explicitly from the main project directory

load_env = load_dotenv("/home/ashok/ERC-analysis/.env")
# load_env = load_dotenv()

# Verify if .env is loaded
print(f"✅ .env Loaded: {load_env}")

# Get API key from environment variable
API_KEY = os.getenv("ETHERSCAN_API_KEY")

if not API_KEY:
    raise ValueError("⚠️ API Key not found! Make sure to set ETHERSCAN_API_KEY in your .env file.")

print(f"🔑 Using Etherscan API Key: {API_KEY[:5]}****** (Hidden for security)")



# List of token ERCs
# token_ercs = {
#     "ERC20", "ERC165", "ERC173", "ERC721", "ERC223", "ERC777", "ERC1155", "ERC884", "ERC998", 
#     "ERC875", "ERC1046", "ERC1363", "ERC2135", "ERC2309", "ERC2612", "ERC1948", "ERC1261", 
#     "ERC1271", "ERC1337", "ERC1820", "ERC2021", "ERC2018", "ERC2019", "ERC1996", "ERC2020", 
#     "ERC2981", "ERC3135", "ERC3440", "ERC3589", "ERC3754", "ERC4494", "ERC4524", "ERC4675", 
#     "ERC3525", "ERC3643", "ERC4400", "ERC4519", "ERC4626", "ERC4906", "ERC4907", "ERC4337", 
#     "ERC4910", "ERC4955", "ERC5006", "ERC5007", "ERC5023", "ERC5169", "ERC5192", "ERC5267", 
#     "ERC5375", "ERC5380", "ERC5484", "ERC5489", "ERC5507", "ERC5521", "ERC5528", "ERC5570", 
#     "ERC5585", "ERC5606", "ERC5615", "ERC5646", "ERC5679", "ERC5725", "ERC5773", "ERC6059", 
#     "ERC6066", "ERC6105", "ERC6147", "ERC6150", "ERC6220", "ERC6239", "ERC6381", "ERC6454", 
#     "ERC6492", "ERC6551", "ERC6672", "ERC6808", "ERC6809", "ERC6982", "ERC7160", "ERC7231", 
#     "ERC7401", "ERC7409"
# }

# token_ercs = {
#     "ERC1155","ERC5005","ERC5169","ERC5606","ERC5615"}

token_ercs = {
    "ERC721"
    }

# Common ERC types to skip
# common_erc_types = {"ERC20", "ERC721","ERC165", "ERC1155", "ERC173", "ERC2981", "ERC2612", "ERC3754", "ERC6492", "ERC1271"}
common_erc_types = {}
# common_erc_types = {}

# Function to process a single CSV file
def ERC_classification(file_path, erc_config, output_file):
    # Load the dataset
    df_subset = pd.read_csv(file_path)
    # df_subset = df.head(10000).copy()  # Adjust the number of rows as needed
    
    # Ensure "matched_erc" and "bytecode_short" columns exist (use existing if available)
    if "matched_erc" not in df_subset.columns:
        df_subset["matched_erc"] = ""
        
    if "partially_matched_erc" not in df_subset.columns:
        df_subset["partially_matched_erc"] = ""

    # if "bytecode_short" not in df_subset.columns:
    #     df_subset["bytecode_short"] = df_subset["bytecode"].str[:40]  # Create if missing

    # Initialize a list to store matched ERC types for each bytecode
    matched_erc_types = []
    matched_erc_types_partial = []
    # Dictionary to track the count of matches per ERC type
    erc_match_counts = defaultdict(int)
    erc_match_counts_partial = defaultdict(int)
    
    erc_NOT_match_counts = defaultdict(int)
    
    # Iterate over each row in the dataset
    for idx, row in df_subset.iterrows():
        original_bytecode_str = row["bytecode"]
        current_matches = []
        current_matches_partial = []
        
        
        # Iterate over each ERC type in the configuration
        for erc_type, config in erc_config.items():
            if erc_type in common_erc_types:
                continue
            # Skip if this ERC type has already reached the limit of 10 matches
            # if erc_match_counts[erc_type] >= 1:
            #     continue
            # Get the required selectors and event topics for the ERC type
            selectors = config.get("selectors", [])
            event_topics = config.get("topics", [])
            
            selector_matched = match_erc_type(original_bytecode_str, selectors)
            event_matched = match_erc_type(original_bytecode_str, event_topics)
            
            # if(len(selectors)!=0 and len(event_topics)!=0):
            #     selector_matched = match_erc_type(original_bytecode_str, selectors)
            #     event_matched = match_erc_type(original_bytecode_str, event_topics)
                
            # elif(len(selectors)!=0 and len(event_topics)==0) :
            #     selector_matched = match_erc_type(original_bytecode_str, selectors)
                
            # elif(len(selectors)==0 and len(event_topics)!=0):
            #     event_matched = match_erc_type(original_bytecode_str, event_topics)
            #     # print(f"ONLY-EVENT case: {erc_type}" )
                
            # else:
            #     print(f"RANDOM case: {erc_type}" )
            
            
            # # If both selectors and events match, add the ERC type to the current matches
            # if selector_matched and event_matched:
            #     current_matches.append(erc_type)
            #     erc_match_counts[erc_type] += 1
            # elif selector_matched and not event_matched:
            #     current_matches.append(erc_type)
            #     erc_match_counts[erc_type] += 1
            # elif not selector_matched and event_matched:
            #     current_matches.append(erc_type)
            #     erc_match_counts[erc_type] += 1
            # else:
            #     erc_NOT_match_counts[erc_type] += 1
            #     # print(f"Missing ERC type")
            # If both selectors and events match, add the ERC type to the current matches
            if selector_matched == 100  and event_matched == 100:
                current_matches.append(erc_type)
                erc_match_counts[erc_type] += 1
            elif selector_matched > 70  and event_matched > 70:
                current_matches_partial.append(erc_type)
                erc_match_counts_partial[erc_type] += 1
            elif selector_matched == 100 :
                current_matches.append(erc_type)
                erc_match_counts[erc_type] += 1
            elif selector_matched > 70 :
                current_matches_partial.append(erc_type)
                erc_match_counts_partial[erc_type] += 1
            else:
                erc_NOT_match_counts[erc_type] += 1
                
        
        # Add the current matches to the list of matched ERC types
        matched_erc_types.append(current_matches)
        matched_erc_types_partial.append(current_matches_partial)
    print(f"erc_match_counts : {erc_match_counts}")
    print(f"erc_match_counts_partial : {erc_match_counts_partial}")
    
    # print(f"erc_NOT_match_counts : {erc_NOT_match_counts}")
    # Ensure that matched_erc_types has the same length as df_subset
    if len(matched_erc_types) != len(df_subset):
        raise ValueError(f"Length mismatch: {len(matched_erc_types)} vs {len(df_subset)}")
    
    if len(matched_erc_types_partial) != len(df_subset):
        raise ValueError(f"Length mismatch: {len(matched_erc_types_partial)} vs {len(df_subset)}")
    
    # Convert matched_erc_types to a flat string before assigning (if column was empty)
    df_subset["matched_erc"] = [
        ";".join(map(str, lst)) if isinstance(lst, list) else str(lst)
        if val == "" else val  # Keep existing values
        for lst, val in zip(matched_erc_types, df_subset["matched_erc"])
    ]
    
    df_subset["partially_matched_erc"] = [
        ";".join(map(str, lst)) if isinstance(lst, list) else str(lst)
        if val == "" else val  # Keep existing values
        for lst, val in zip(matched_erc_types_partial, df_subset["partially_matched_erc"])
    ]
    
    # Add the "Binary Token Classification" column
    df_subset["Binary Token Classification"] = df_subset["matched_erc"].apply(
        lambda x: f"YES, {x}" if x in token_ercs else ""
    )
    
    # Filter the DataFrame to only include rows where "matched_erc" and partially_matched_erc is non-empty
    filtered_df = df_subset[df_subset["matched_erc"].apply(lambda x: len(x) > 0)] 
    filtered_df_partial = df_subset[df_subset["partially_matched_erc"].apply(lambda x: len(x) > 0)]
    
   # Now, further filter by transaction activity.
    final_rows = []
    unique_addresses = set()  # Track unique addresses

    for idx, row in filtered_df.iterrows():
        final_rows.append(row)
        # address = row["address"]  
        
        # # Check if the address is already in the set
        # if address not in unique_addresses:
        #     unique_addresses.add(address)
        #     final_rows.append(row)
    
    # Create a new DataFrame from the final rows.
    if final_rows:
        final_df = pd.DataFrame(final_rows)
        # Sort the DataFrame by matched_erc to group rows with the same ERC type together
        final_df = final_df.explode("matched_erc").sort_values(by="matched_erc")
        final_df = final_df.explode("partially_matched_erc").sort_values(by="partially_matched_erc")
        
        # print(final_df[["address", "bytecode_short", "matched_erc", "Binary Token Classification"]])
        
        # Save the results to a new CSV file
        # output_file = os.path.join(os.path.dirname(file_path), f"processed_{os.path.basename(file_path)}")
        output_file = output_file + os.path.basename(file_path)
        # output_file = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/partial_match_" + os.path.basename(file_path)

        final_df.to_csv(output_file, index=False)
        # final_df.to_csv("test1_erc_classification_results_top10_server_full_dataset.csv", index=False)
        
        print(f"Processed results saved to {output_file}")
    else:
        print(f"No contracts meet both the ERC match and transaction activity criteria in {file_path}.")






def fetch_source_code(address: str) -> dict:
    """
    Fetch the verified source code for a contract address from Etherscan.
    """
    url = (
        f"https://api.etherscan.io/api?module=contract&action=getsourcecode"
        f"&address={address}&apikey={API_KEY}"
    )
    response = requests.get(url)
    try:
        return response.json()
    except Exception as e:
        return {"error": str(e)}

def save_source_code(address: str, source_info: dict) -> None:
    """
    Save the contract source code into a file named <address>.sol in the "contracts" folder.
    """
    result = source_info.get("result")
    if not result or len(result) == 0:
        print(f"No source code data found for {address}")
        return

    source_code = result[0].get("SourceCode")
    if not source_code:
        print(f"No source code available for {address}")
        return

    os.makedirs("contracts", exist_ok=True)
    filename = f"contracts/{address}.sol"
    base_filename = filename[:-4]
    counter = 1
    while os.path.exists(filename):
        filename = f"{base_filename}_{counter}.sol"
        counter += 1

    with open(filename, "w", encoding="utf-8") as f:
        f.write(source_code)
    print(f"Saved source code for {address} to {filename}")




def match_erc_type(bytecode, functions_events):
    functions_events = [topic.lower() for topic in functions_events]
    
    actual_count = len(functions_events)
    
    if actual_count == 0:
        return False
    
    not_matched_erc = 0
    
    for topic in functions_events:
        if topic not in bytecode.lower():
            not_matched_erc += 1  
    
    # Calculate the percentage of matched functions/events
    matched_percentage = ((actual_count - not_matched_erc) / actual_count) * 100
    
    return matched_percentage
    
    # # Return True if the matched percentage is more than 70%, else False
    # if matched_percentage == 100 :
    #     return "EXACT_MATCH"
        
    # elif matched_percentage > 70:
    #     return "PARTIAL_MATCH"
    
    # else:
    #     return "NOT_MATCHED"
        

    

def should_fetch_contract_copy(tx_list) -> bool:
    """
    Return True if the total number of transactions is > 100 and
    at least one transaction happened in the last 30 days.
    """
    if not tx_list:
        return False

    

    now = int(time.time())
    thirty_days = 900 * 24 * 3600
    recent = any(int(tx["timeStamp"]) >= (now - thirty_days) for tx in tx_list)
    
    if not recent:
        return False

    # Sum transaction values (in Wei)
    total_value = sum(int(tx["value"]) for tx in tx_list)
    min_total_value = 100000000000000000  # 0.1 ETH in wei

    has_min_value = total_value >= min_total_value

    # Debug prints (optional)
    # print(f"Total transactions: {total_tx}, Recent? {recent}, Total value (wei): {total_value}, has_min_value : {has_min_value}")

    # Heuristic 2: Total transaction volume
    # total_tx = len(tx_list)
    # if total_tx <= 10:
    #     print(f"Low transaction volume: {total_tx}.")
    #     return False

    # # Heuristic 3: Total transaction value
    # total_value = sum(int(tx["value"]) for tx in tx_list)
    # min_total_value = 10000000000000000
    # if total_value < min_total_value:
    #     print(f"Low transaction value: {total_value}.")
    #     return False

    # # Heuristic 4: Unique interactors
    # unique_interactors = set(tx["from"] for tx in tx_list).union(set(tx["to"] for tx in tx_list))
    # if len(unique_interactors) < 10:
    #     print(f"Low unique interactors: {len(unique_interactors)}.")
    #     return False

    # # Heuristic 5: Gas usage
    # total_gas_used = sum(int(tx["gasUsed"]) for tx in tx_list)
    # min_gas_used = 1000000
    # if total_gas_used < min_gas_used:
    #     print(f"Low gas usage: {total_gas_used}.")
    #     return False
    # return recent and has_min_value
    return True


def fetch_tx_activity_copy(address: str) -> dict:
    """
    Fetch the transaction activity for a contract address from Etherscan.
    """
    url = (
        f"https://api.etherscan.io/api?module=account&action=txlist"
        f"&address={address}&startblock=0&endblock=99999999&sort=asc&apikey={API_KEY}"
    )
    response = requests.get(url)
    try:
        return response.json()
    except Exception as e:
        return {"error": str(e)}
   
# def verify_source():
#      # Load CSV file containing contract addresses (with a "address" column).
#     df = pd.read_csv("test1_erc_classification_results_erc_top10.csv")  # adjust path as needed
    
#     # Extract unique addresses.
#     addresses = df["address"].dropna().unique()
    
#     for address in addresses:
#         # print(f"\nProcessing contract: {address}")
#         tx_info = fetch_tx_activity(address)
#         if tx_info.get("status") != "1":
#             print(f"Error fetching transaction activity for {address}: {tx_info.get('message', tx_info)}")
#             continue
        
#         tx_list = tx_info.get("result", [])
#         if not should_fetch_contract(tx_list):
#             # print(f"Skipping {address}: does not meet criteria (tx count, recency, or total value)")
#             continue

#         source_info = fetch_source_code(address)
#         if source_info.get("status") == "1":
#             # save_source_code(address, source_info)
#             print(f"address : {address}")
#         else:
#             print(f"Error fetching source code for {address}: {source_info.get('message', source_info)}")



def compare_json_files(basic_file, full_file):
    # Load JSON files
    with open(basic_file, 'r') as f:
        basic_data = json.load(f)
    
    with open(full_file, 'r') as f:
        full_data = json.load(f)

    missing_ercs = []
    non_matched_ercs = {}

    # Check for missing ERCs
    for erc in basic_data:
        if erc not in full_data:
            missing_ercs.append(erc)

    # Compare selectors and topics for existing ERCs
    for erc, details in basic_data.items():
        if erc in full_data:
            full_details = full_data[erc]

            # Get selectors and topics
            basic_selectors = set(details.get("selectors", []))
            full_selectors = set(full_details.get("selectors", []))

            basic_topics = set(details.get("topics", []))
            full_topics = set(full_details.get("topics", []))

            # Check if all basic_selectors and basic_topics are present in full_data
            missing_selectors = basic_selectors - full_selectors
            missing_topics = basic_topics - full_topics

            if missing_selectors or missing_topics:
                non_matched_ercs[erc] = {
                    "missing_selectors": list(missing_selectors),
                    "missing_topics": list(missing_topics)
                }

    # Print results
    # if missing_ercs:
    #     print("Missing ERCs in full.json:")
    #     print(missing_ercs)
    print(f"len : {len(non_matched_ercs)}")
    if non_matched_ercs:
        print("\nERCs with missing selectors or topics:")
        
        for erc, mismatches in non_matched_ercs.items():
            print(f"\nERC: {erc}")
            # for key, value in mismatches.items():
            #     if value:
            #         print(f"  {key}: {value}")



def number_of_rows(folder_path):
    # List all files in the folder
    for file_name in os.listdir(folder_path):
        if folder_path.__contains__("output") and file_name.__contains__("safeBatchTransferFro") and file_name.endswith(".csv"):
            file_path = os.path.join(folder_path, file_name)
            try:
                df = pd.read_csv(file_path)
                print(f"Processed '{file_name}' - Number of rows: {len(df)}")
            except Exception as e:
                print(f"Error processing '{file_name}': {e}")
        if folder_path.__contains__("data") and file_name.endswith(".csv"):  # Process only CSV files
            file_path = os.path.join(folder_path, file_name)
            try:
                df = pd.read_csv(file_path)
                print(f"Processed '{file_name}' - Number of rows: {len(df)}")
            except Exception as e:
                print(f"Error processing '{file_name}': {e}")


def main():
    
    # with open("erc712_DOMAIN_SEPARATOR.json", "r") as f:
    #     erc_config = json.load(f)
    
    # # # Directory containing CSV files
    # data_dir = "/home/ashok/data"
    # output_file = "/home/ashok/output/ERC-712_DOMAIN_SEPARATOR.json_"
    
    # # Directory containing CSV files
    # # data_dir = "/Users/ashokk/Downloads/evm_data"
    # # output_file = "/Users/ashokk/Documents/ERC-analysis-master/erc-classify/ERC-223_transfer_custom"
    
    # # data_dir = "/Users/ashokk/Downloads/evm_data"
    # csv_files = [os.path.join(data_dir, f) for f in os.listdir(data_dir) if f.endswith(".csv")]
    
    # if not csv_files:
    #     print(f"No CSV files found in {data_dir}.")
    #     return
    # for csv_file in csv_files:
    #     print(f"Processing file: {csv_file}")
    #     ERC_classification(csv_file, erc_config, output_file)
        
        
    
    # verify_source()
    
    # compare_json_files("final_basic_erc_specifications.json", "final_full_erc_specifications.json")
    number_of_rows("/home/ashok/output")
    # number_of_rows("/home/ashok/data")
    
    

if __name__ == "__main__":
    main()





# Processed 'BASIC_config_binance_deduplicated_results.csv' - Number of rows: 1602251
# Processed 'BASIC_config_ethereum_deduplicated_results.csv.csv' - Number of rows: 630846
# Processed 'BASIC_config__deduplicated_polygon.csv' - Number of rows: 123017
# Processed 'BASIC_config__deduplicated_avalanche.csv' - Number of rows: 43777



# Processed 'FULL_config_binance_deduplicated_results.csv' - Number of rows: 1602719
# Processed 'FULL_config_ethereum_deduplicated_results.csv' - Number of rows: 631220
# Processed 'FULL_config_deduplicated_polygon.csv' - Number of rows: 123127
# Processed 'FULL_config_deduplicated_avalanche.csv' - Number of rows: 43805




# Processed 'binance_deduplicated_results.csv' - Number of rows: 2308899
# Processed 'ethereum_deduplicated_results.csv' - Number of rows: 1114861
# Processed 'deduplicated_polygon.csv' - Number of rows: 288611
# Processed 'deduplicated_avalanche.csv' - Number of rows: 96173




# Processed 'config_FULL_server_processed_ethereum_deduplicated_results.csv' - Number of rows: 636069
# Processed 'config_FULL_server_processed_deduplicated_polygon.csv' - Number of rows: 124388
# Processed 'config_basic_server_processed_deduplicated_avalanche.csv' - Number of rows: 44490