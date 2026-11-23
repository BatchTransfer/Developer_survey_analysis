// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract TopDawgCoin {
    string private constant _name = "Top Dawg Coin";
    string private constant _symbol = "DAWGC";
    uint8 public immutable decimals = 18;
    uint256 public immutable totalSupply;
    address public owner;

    struct Account {
        uint256 balance;
        mapping(address => uint256) allowance;
    }

    mapping(address => Account) public accounts;
    mapping(address => bool) public isFeeExempt;

    address public immutable marketingAddress;
    address public immutable developerAddress;
    address public constant burnAddress = 0x000000000000000000000000000000000000dEaD;

    address public constant pancakeRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    bool private locked;

    uint256 private constant marketingFee = 35; // 3.5%
    uint256 private constant developerFee = 10; // 1%
    uint256 private constant burnFee = 5; // 0.5%
    uint256 private constant feeDenominator = 1000; // Denominator for percentage calculations

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard");
        locked = true;
        _;
        locked = false;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(
        address _marketingAddress,
        address _developerAddress
    ) {
        owner = msg.sender;
        totalSupply = 100e9 * (10 ** decimals); // 100 miliardów tokenów z 18 miejscami dziesiętnymi
        accounts[owner].balance = totalSupply;
        marketingAddress = _marketingAddress;
        developerAddress = _developerAddress;
        isFeeExempt[owner] = true;
        emit Transfer(address(0), owner, totalSupply);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function balanceOf(address account) public view returns (uint256) {
        return accounts[account].balance;
    }

    function transfer(address _to, uint256 _value) public nonReentrant returns (bool success) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        accounts[msg.sender].allowance[_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public nonReentrant returns (bool success) {
        Account storage fromAccount = accounts[_from];
        require(_value <= fromAccount.allowance[msg.sender], "Allowance exceeded");
        fromAccount.allowance[msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    function _transfer(address _from, address _to, uint256 _value) internal {
        require(_to != address(0), "Invalid address");

        Account storage fromAccount = accounts[_from];
        Account storage toAccount = accounts[_to];

        uint256 fromBalance = fromAccount.balance;
        require(_value <= fromBalance, "Insufficient balance");

        if (isFeeExempt[_from] || isFeeExempt[_to]) {
            fromAccount.balance = fromBalance - _value;
            toAccount.balance += _value;
            emit Transfer(_from, _to, _value);
        } else {
            uint256 marketingAmount = _calculateFee(_value, marketingFee);
            uint256 developerAmount = _calculateFee(_value, developerFee);
            uint256 burnAmount = _calculateFee(_value, burnFee);
            uint256 transferAmount = _value - marketingAmount - developerAmount - burnAmount;

            fromAccount.balance = fromBalance - _value;
            toAccount.balance += transferAmount;
            accounts[marketingAddress].balance += marketingAmount;
            accounts[developerAddress].balance += developerAmount;
            accounts[burnAddress].balance += burnAmount;

            emit Transfer(_from, _to, transferAmount);
            emit Transfer(_from, marketingAddress, marketingAmount);
            emit Transfer(_from, developerAddress, developerAmount);
            emit Transfer(_from, burnAddress, burnAmount);
        }
    }

    function _calculateFee(uint256 _value, uint256 _fee) internal pure returns (uint256 feeAmount) {
        feeAmount = (_value * _fee) / feeDenominator;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        isFeeExempt[owner] = false;
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        isFeeExempt[newOwner] = true;
    }

    function setFeeExempt(address account, bool exempt) public onlyOwner {
        isFeeExempt[account] = exempt;
    }
}