from web3 import Web3
from eth_account import Account
from eth_account.messages import encode_typed_data
from dotenv import load_dotenv
import os
import json

# Load .env
load_dotenv()
private_key = os.getenv("METAMASK_PRIVATE_KEY")
alchemy_key = os.getenv("ALCHEMY_KEY")
account = Account.from_key(private_key)

# Connect to Sepolia via Alchemy
w3 = Web3(Web3.HTTPProvider("https://eth-sepolia.g.alchemy.com/v2/" + alchemy_key))
print(f"✅ Connected to chain ID: {w3.eth.chain_id}")

# Convert addresses to checksum format
VULNERABLE_CONTRACT = Web3.to_checksum_address("0xc2d738b010489e9948f15c1097b42ac6661595bb")
SECURE_CONTRACT = Web3.to_checksum_address("0xf927311aa7332c3de9755289f980b9045ea39602")

# ABI for verifyMessage function
CONTRACT_ABI = json.loads('''
[
    {
        "inputs": [
            {"name": "content", "type": "string"},
            {"name": "signature", "type": "bytes"}
        ],
        "name": "verifyMessage",
        "outputs": [{"name": "", "type": "address"}],
        "stateMutability": "view",
        "type": "function"
    }
]
''')

message = {"content": "Transfer 100 ETH"}

# Type definitions
types_without_salt = {
    "EIP712Domain": [
        {"name": "name", "type": "string"},
        {"name": "version", "type": "string"},
        {"name": "chainId", "type": "uint256"},
        {"name": "verifyingContract", "type": "address"}
    ],
    "Message": [{"name": "content", "type": "string"}]
}

types_with_salt = {
    "EIP712Domain": [
        {"name": "name", "type": "string"},
        {"name": "version", "type": "string"},
        {"name": "chainId", "type": "uint256"},
        {"name": "verifyingContract", "type": "address"},
        {"name": "salt", "type": "bytes32"}
    ],
    "Message": [{"name": "content", "type": "string"}]
}

# Domains
domain_vulnerable = {
    "name": "App",
    "version": "1",
    "chainId": 11155111,
    "verifyingContract": VULNERABLE_CONTRACT
}

domain_secure = {
    "name": "App",
    "version": "1",
    "chainId": 11155111,
    "verifyingContract": SECURE_CONTRACT,
    "salt": "0x6f4b2b6e2295a6bdfa0f03e57f4e016e6a89b5c0e7b5e5e5e5e5e5e5e5e5e5e5"
}

# Generate signatures
typed_data_vulnerable = {
    "types": types_without_salt,
    "primaryType": "Message",
    "domain": domain_vulnerable,
    "message": message
}

typed_data_secure = {
    "types": types_with_salt,
    "primaryType": "Message",
    "domain": domain_secure,
    "message": message
}

encoded_msg_vulnerable = encode_typed_data(full_message=typed_data_vulnerable)
signed_vulnerable = Account.sign_message(encoded_msg_vulnerable, private_key)

encoded_msg_secure = encode_typed_data(full_message=typed_data_secure)
signed_secure = Account.sign_message(encoded_msg_secure, private_key)

print(f"🔐 Vulnerable Signature: {signed_vulnerable.signature.hex()}")
print(f"🔐 Secure Signature: {signed_secure.signature.hex()}")
print(f"👤 Signer address: {account.address}")

# Test function updated to accept signature parameter
def test_contract(contract_address, signature):
    contract = w3.eth.contract(address=contract_address, abi=CONTRACT_ABI)
    try:
        recovered = contract.functions.verifyMessage(
            message["content"],
            signature
        ).call()
        print(f"✅ Verified on {contract_address}. Recovered: {recovered} (Matches signer: {recovered == account.address})")
        return recovered
    except Exception as e:
        print(f"❌ Failed on {contract_address}. Error: {str(e)}")
        return None

print("\n=== Testing VulnerableContract ===")
test_contract(VULNERABLE_CONTRACT, signed_vulnerable.signature)

print("\n=== Testing SecureContract with its own signature ===")
test_contract(SECURE_CONTRACT, signed_secure.signature)

print("\n=== Attempting Replay Attack (Vulnerable signature on SecureContract) ===")
test_contract(SECURE_CONTRACT, signed_vulnerable.signature)  # Should fail