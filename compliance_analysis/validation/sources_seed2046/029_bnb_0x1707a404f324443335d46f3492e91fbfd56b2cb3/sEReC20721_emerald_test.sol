pragma solidity ^0.8.0;

contract sEReC20721_emerald_test {

    string internal _name = "Pancake Emeralds";
    string internal _symbol = "PEMERALD";
    uint internal _totalSupply = 7777 * 10**6;
    uint internal _decimals = 6;
    uint one = 10**6; uint cent = 10**4;
    uint public id;
    uint excess;
    string public baseURI = "https://raw.githubusercontent.com/SerecThunderson/assets/main/emeralds/metadata/";
    address public dev;
    address[3] public pairs;
    uint minted;

    bool fromPair; bool toPair;
    bool wholeInitFrom; bool wholeInitTo;
    bool wholePostFrom; bool wholePostTo;

    mapping(address => uint) internal _balanceOf;
    mapping(address => mapping(address => uint)) internal _allowance;
    mapping(uint256 tokenId => address) public ownerOf;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(address => uint16[]) public ownedNFTs;

    event Transfer(address indexed from, address indexed to, uint indexed tokenId);
    event ERC20Transfer(address indexed from, address indexed to, uint amount);
    event Approval(address indexed owner, address indexed spender, uint256 indexed amount, uint256 id);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    modifier onlyDev() {require(msg.sender == dev, "Not the developer");_;}

    constructor() {_balanceOf[msg.sender] = _totalSupply; dev = msg.sender;}

    function name() public view virtual returns (string memory) { return _name; }
    function symbol() public view virtual returns (string memory) { return _symbol; }
    function decimals() public view virtual returns (uint) { return _decimals; }
    function totalSupply() public view virtual returns (uint) { return _totalSupply; }
    function balanceOf(address account) public view virtual returns (uint) { return _balanceOf[account]; }
    function allowance(address owner, address spender) public view virtual returns (uint) { return _allowance[owner][spender]; }
    function setPairs(address pair1, address pair2, address pair3) public onlyDev {pairs[0] = pair1;pairs[1] = pair2;pairs[2] = pair3;}
    function setBaseURI(string memory newBaseURI) public onlyDev {baseURI = newBaseURI;}
    function measure() public view returns (uint) {return ownedNFTs[msg.sender].length;}

    function approve(address spender, uint amount) public virtual returns (bool) {
        if (amount > 10**6) {
            _allowance[msg.sender][spender] = amount;
            setApprovalForAll(spender, true);
            emit Approval(msg.sender, spender, amount, 0);
        }
        else {
            address owner = ownerOf[amount];
            if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) revert("sEReC20721: You are not approved");
            _tokenApprovals[amount] = spender;
            emit Approval(owner, spender, one, uint16(amount));
        }
        return true;
    }

    function _transfer20(address from, address to, uint amount) internal virtual {
        
        excess = amount % cent; amount -= excess;
        fromPair = from == pairs[0] || from == pairs[1] || from == pairs[2];
        toPair = to == pairs[0] || to == pairs[1] || to == pairs[2];
        wholeInitFrom = _balanceOf[from] % one == 0; wholeInitTo = _balanceOf[to] % one == 0;
        wholePostFrom = (_balanceOf[from] - amount) % one == 0; wholePostTo = (_balanceOf[to] + amount) % one == 0;

        require(_balanceOf[from] >= amount, "sEReC20721: transfer amount exceeds balance");

        if ((toPair && wholeInitFrom && !wholePostFrom) ||
            (fromPair && !wholeInitTo && wholePostTo) ||
            (fromPair && !wholeInitTo && (_balanceOf[to] % one) + amount % one >= one) ||
            (toPair && !wholeInitFrom && (_balanceOf[from] % one) < amount % one)){
                uint16 tokenId = ownedNFTs[from][0]; require(from == ownerOf[tokenId],"NFT not found");
                delete _tokenApprovals[tokenId]; ownerOf[tokenId] = to;
                ownedNFTs[from][0] = ownedNFTs[from][ownedNFTs[from].length - 1];
                ownedNFTs[from].pop(); ownedNFTs[to].push(tokenId);
                emit Transfer(from, to, tokenId);
        }

        else if ((wholeInitFrom != wholePostFrom) ||
                (((_balanceOf[to] % one) + amount % one >= one))) {
                require(toPair || fromPair, "sEReC20721: break/make tokens with nonpair address");
        
        }

        uint amountInTokens = amount / one;
        if (fromPair && ownedNFTs[from].length < amountInTokens) {
            for (uint i = 0; i < amountInTokens; i++) {
                minted++;
                ownerOf[minted] = to;
                ownedNFTs[to].push(uint16(minted));
                emit Transfer(address(0), to, minted);
            }
        } 

        else {
            for (uint i = 0; i < amountInTokens && ownedNFTs[from].length > 0; i++) {
                uint16 tokenId = ownedNFTs[from][0];
                _transfer721(from, to, tokenId); emit Transfer(from, to, tokenId);
                ownedNFTs[from][0] = ownedNFTs[from][ownedNFTs[from].length - 1];
                ownedNFTs[from].pop();
                ownedNFTs[to].push(tokenId);
            }
        }

        _balanceOf[from] -= amount; _balanceOf[to] += amount;
        emit ERC20Transfer(from, to, amount);
    }

    function _transfer721(address from, address to, uint tokenId) internal virtual {
        fromPair = from == pairs[0] || from == pairs[1] || from == pairs[2];
        require(from == ownerOf[tokenId],"sEReC20721: Incorrect owner");
        require(
            msg.sender == from || msg.sender == getApproved(tokenId) ||isApprovedForAll(from, msg.sender) || fromPair,
            "sEReC20721: You don't have the right"
            );
        delete _tokenApprovals[tokenId];
        ownerOf[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function transfer(address to, uint amount) public virtual returns (bool) {
        if (amount >= cent){_transfer20(msg.sender, to, amount);}
        else {_transfer721(msg.sender, to, amount);_balanceOf[msg.sender]-= one; _balanceOf[to]+= one;}
        return true;
    }

    function transferFrom(address from, address to, uint amount) public virtual returns (bool) {
        if (amount >= cent) {_spendAllowance(from, msg.sender, amount); _transfer20(from, to, amount);}
        else {_transfer721(from, to, amount);_balanceOf[from]-= one; _balanceOf[to]+= one;}
        return true;
    }

    function safeTransferFrom(address from, address to, uint16 tokenId) public virtual returns (bool) {
        _transfer721(from, to, tokenId); _balanceOf[from]-= one; _balanceOf[to]+= one;
        return true;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        _transfer721(from, to, tokenId); _balanceOf[from]-= one; _balanceOf[to]+= one;
    }

    function _spendAllowance(address owner, address spender, uint amount) internal virtual {
        require(_allowance[owner][spender] >= amount, "sEReC20721: insufficient allowance");
        _allowance[owner][spender] -= amount;
    }

    function getApproved(uint256 tokenId) public view virtual returns (address) {
        if (ownerOf[tokenId] == address(0)) revert();
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        if (bytes(baseURI).length == 0) {return "";}
        return string(abi.encodePacked(baseURI, toString(tokenId), ".json"));
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {return "0";} uint256 temp = value; uint256 digits;
        while (temp != 0) {digits++; temp /= 10;} bytes memory buffer = new bytes(digits);
        while (value != 0) {digits -= 1; buffer[digits] = bytes1(uint8(value % 10) + 48); value /= 10;}
        return string(buffer);
    }

    function withdraw() external onlyDev {
        payable(dev).transfer(address(this).balance);
        uint256 tokenAmount = _balanceOf[address(this)];
        if (tokenAmount > 0) {_transfer20(address(this), dev, tokenAmount);}
    }
}