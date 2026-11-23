// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

//////////////////////////// UTILITIES ////////////////////////////
import "./utilities/Context.sol";
//////////////////////////// UTILITIES ////////////////////////////

//////////////////////////// LIBRARIES ////////////////////////////
import "./libraries/Counters.sol";
import "./libraries/Address.sol";
import "./libraries/Strings.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/SafeMath.sol";
//////////////////////////// LIBRARIES ////////////////////////////

//////////////////////////// INTERFACES ////////////////////////////
import "./interfaces/IERC721.sol";
import "./interfaces/IERC721Receiver.sol";
import "./interfaces/IERC721Metadata.sol";
import "./interfaces/IERC721Enumerable.sol";
import "./interfaces/IERC165.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ICatNIP.sol";
//////////////////////////// INTERFACES ////////////////////////////



contract CatNIPNFT is Context, IERC165, IERC721, IERC721Metadata, IERC721Receiver {

    

    //////////////////////////// USING STATEMENTS ////////////////////////////
    using Strings for uint256;
    using Address for address;
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    //////////////////////////// USING STATEMENTS ////////////////////////////




    //////////////////////////// ACCESS CONTROL ////////////////////////////  
    address public directorAccount = _msgSender();  // TODO - director is the multisig
    address public minterAccount = 0xE5d30eeF39D0C428924de4d6cd4Dc96f84Ab1027;  // TODO - minter is account used by the game
    mapping(address => bool) public isAuthorizedToView;
    //////////////////////////// ACCESS CONTROL ////////////////////////////  


    

    //////////////////////////// ACCESS CONTROL FUNCTIONS ////////////////////////////
    modifier OnlyDirector() {   // The director is the multisig
        require(_msgSender() == directorAccount, "Caller is not the Director");  
        _;      
    }

    function TransferDirectorAccount(address newDirector) external OnlyDirector()  {   
        directorAccount = newDirector;
    }

    modifier OnlyMinter() {   // The minter is the account the game uses to mint the NFTs
        require(_msgSender() == minterAccount, "Caller is not the Minter");  
        _;      
    }

    function TransferMinterAccount(address newMinter) external OnlyDirector()  {   
        minterAccount = newMinter;
    }
    //////////////////////////// ACCESS CONTROL FUNCTIONS ////////////////////////////







    //////////////////////////// INFO VARS ////////////////////////////
    Counters.Counter private _tokenIds;     // token IDs, gives a numerical part to the token structure
    mapping(uint256 => string) private _tokenURIs;  // contains the URI

    string private _name = "CatNIP NFT";
    string private _symbol = "NIPNFT";

    mapping(uint256 => address) private _owners;        // Mapping from token ID to owner address
    mapping(address => uint256) private _balances;      // Mapping owner address to token count
    mapping(uint256 => address) private _tokenApprovals;        // Mapping from token ID to approved address
    mapping(address => mapping(address => bool)) private _operatorApprovals;        // Mapping from owner to operator approvals - this is allows others to operate someone else's NFTs, it's standard
    //////////////////////////// INFO VARS ////////////////////////////



    //////////////////////////// NIP VARS ////////////////////////////  
    address public nipContractAddress = 0xF6805C059470592B03d17d3e706B20501E7159Eb;       // CHANGEIT - set the right contract address
    IERC20 private nipContractAddressIERC20 = IERC20(nipContractAddress);
    ICatNIP private nipContractAddressICatNIP = ICatNIP(nipContractAddress);
    //////////////////////////// NIP VARS ////////////////////////////  


    //////////////////////////// MINTING VARS ////////////////////////////
    mapping(address => bool) public isMinting;
    
    bool public isMintingEnabled = true;
    // address private codeContractAddress;  // don't need
    uint256 private randomNumber = 1;
    uint256 public minimumNipAmountInDepositToMint = 100000000000;   // set the minimum to 100 NIP
    uint256 public minimumGasAmountInDepositToMint = 5000000000000000;   // set the minimum to 100 NIP

    uint256 public minimumNipAmountInDepositToChangeMetaData = 100000000000;   // set the minimum to 100 NIP
    uint256 public minimumGasAmountInDepositToChangeMetaData = 5000000000000000;   // set the minimum to 100 NIP
    //////////////////////////// MINTING VARS ////////////////////////////





    event Debug1(uint256 param1);


    constructor() {
        randomNumber = randomNumber.add(1);
        isAuthorizedToView[directorAccount] = true;
    }










    
    //////////////////////////// INFO FUNCTIONS ////////////////////////////
    function name() public view virtual override returns (string memory) {
        return _name;
    }
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
    function balanceOf(address owner) public view virtual override returns (uint256) {
        return _balances[owner];
    }
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }
    function _exists(uint256 tokenId) internal view virtual returns (bool) {        // checks if a token exists or not
        return _owners[tokenId] != address(0);
    }
    //////////////////////////// INFO FUNCTIONS ////////////////////////////



    





    

    






    //////////////////////////// APPROVAL FUNCTIONS ////////////////////////////
    function _approve(address to, uint256 tokenId) internal virtual {       // internal approve
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(_msgSender() == owner || isApprovedForAll(owner, _msgSender()),"ERC721: approve caller is not owner nor approved for all");
        _approve(to, tokenId);
    }
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");
        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }
    //////////////////////////// APPROVAL FUNCTIONS ////////////////////////////












    //////////////////////////// TRANSFER FUNCTIONS ////////////////////////////
    function transfer(address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(_msgSender(), to, tokenId);
    }
    function transferGroup(address to, uint256[] memory tokenIdArray) public {
        for(uint i = 0; i < tokenIdArray.length; i++){
            require(_isApprovedOrOwner(_msgSender(), tokenIdArray[i]), "ERC721: transfer caller is not owner nor approved");
            _transfer(_msgSender(), to, tokenIdArray[i]);
        }
    }
    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        _approve(address(0), tokenId);      // Clear approvals from the previous owner

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }
    function transferFrom(address from,address to,uint256 tokenId) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }
    function safeTransferFrom(address from,address to,uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }
    function safeTransferFrom(address from,address to,uint256 tokenId,bytes memory _data) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }
    function _safeTransfer(address from,address to,uint256 tokenId,bytes memory _data) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
         // Enumerable Functionality
        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } 
        else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        // Enumerable Functionality
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } 
        else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }
    //////////////////////////// TRANSFER FUNCTIONS ////////////////////////////




    




    //////////////////////////// ENUMERABLE FUNCTIONS ////////////////////////////
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;       // Mapping from owner to list of owned token IDs
    mapping(uint256 => uint256) private _ownedTokensIndex;      // Mapping from token ID to index of the owner tokens list
    uint256[] private _allTokens;       // Array with all token ids, used for enumeration
    mapping(uint256 => uint256) private _allTokensIndex;        // Mapping from token id to position in the allTokens array

    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual returns (uint256) {
        require(index < balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    function totalSupply() public view virtual returns (uint256) {
        return _allTokens.length;
    }

    function tokenByIndex(uint256 index) public view virtual returns (uint256) {
        require(index < totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
    //////////////////////////// ENUMERABLE FUNCTIONS ////////////////////////////
















    //////////////////////////// MINT FUNCTIONS ////////////////////////////
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }
    function _safeMint(address to,uint256 tokenId,bytes memory _data) internal virtual {
        _mint(to, tokenId);
        require(_checkOnERC721Received(address(0), to, tokenId, _data),"ERC721: transfer to non ERC721Receiver implementer");
    }
    function _mint(address to, uint256 tokenId) internal virtual {      // Internal Mint, use Safe Mint when possible to require the receiver part
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }
    //////////////////////////// MINT FUNCTIONS ////////////////////////////






    //////////////////////////// BURN FUNCTIONS ////////////////////////////
    function burn(uint256 tokenId) public virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        _burn(tokenId);
    }

    function burnGroupAsUser(uint256[] memory tokenIdArray) public virtual OnlyDirector() {
        for(uint i = 0; i < tokenIdArray.length; i++){
            require(_isApprovedOrOwner(_msgSender(), tokenIdArray[i]), "ERC721Burnable: caller is not owner nor approved");
            _burn(tokenIdArray[i]);
        }
    }

    // function burnAsDirector(uint256 tokenId) public virtual OnlyDirector() {
    //     _burn(tokenId);
    // }

    // function burnGroupAsDirector(uint256[] memory tokenIdArray) public virtual OnlyDirector() {
    //     for(uint i = 0; i < tokenIdArray.length; i++){
    //         _burn(tokenIdArray[i]);
    //     }
    // }


    function _burn(uint256 tokenId) internal virtual {
        address owner = ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }
    //////////////////////////// BURN FUNCTIONS ////////////////////////////








    //////////////////////////// INTERFACE FUNCTIONS ////////////////////////////
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {       // merged supportsInterface from ERC165
        return interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC721Metadata).interfaceId || interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC721Enumerable).interfaceId;
    }
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) private returns (bool) {     // activates upon receiving ERC721, but only if it's a contract, if it's a user does not activate
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {       // activates if the contract receives NFTs
        return this.onERC721Received.selector;
    }
    //////////////////////////// INTERFACE FUNCTIONS ////////////////////////////










    //////////////////////////// URI FUNCTIONS ////////////////////////////
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {       // Merged into 1 tokenURI function
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
    //////////////////////////// URI FUNCTIONS ////////////////////////////









    //////////////////////////// UTILITY FUNCTIONS ////////////////////////////
    function PayableMsgSenderAddress() private view returns (address payable) {   // gets the sender of the payable address, makes sure it is an address format too
        address payable payableMsgSender = payable(address(_msgSender()));      
        return payableMsgSender;
    }

    function GetCurrentBlockTime() public view returns (uint256) {
        return block.timestamp;     // gets the current time and date in Unix timestamp
    }

    function GetCurrentBlockDifficulty() public view returns (uint256) {
        return block.difficulty;  
    }

    function GetCurrentBlockNumber() public view returns (uint256) {
        return block.number;      
    }

    function GetCurrentBlockStats() public view returns (uint256,uint256,uint256) {
        return (block.number, block.difficulty, block.timestamp);      
    }

    //////////////////////////// UTILITY FUNCTIONS ////////////////////////////


    //////////////////////////// RESCUE FUNCTIONS ////////////////////////////
    function RescueAllBNBSentToContractAddress() external OnlyDirector()  {   
        PayableMsgSenderAddress().transfer(address(this).balance);
    }

    function RescueAmountBNBSentToContractAddress(uint256 amount) external OnlyDirector()  {   
        PayableMsgSenderAddress().transfer(amount);
    }

    function RescueAllTokenSentToContractAddress(IERC20 tokenToWithdraw) external OnlyDirector() {
        tokenToWithdraw.safeTransfer(PayableMsgSenderAddress(), tokenToWithdraw.balanceOf(address(this)));
    }

    function RescueAmountTokenSentToContractAddress(IERC20 tokenToWithdraw, uint256 amount) external OnlyDirector() {
        tokenToWithdraw.safeTransfer(PayableMsgSenderAddress(), amount);
    }

    function RescueAllContractToken() external OnlyDirector() {
        _transfer(address(this), PayableMsgSenderAddress(), balanceOf(address(this)));
    }

    function RescueAmountContractToken(uint256 amount) external OnlyDirector() {
        _transfer(address(this), PayableMsgSenderAddress(), amount);
    }
    //////////////////////////// RESCUE FUNCTIONS ////////////////////////////













    function RandomNumberForGamesViewable() external view returns (uint256) {
        require(isAuthorizedToView[_msgSender()], "Caller is not a Game Contract");  
        return randomNumber;
    }

    function SetRandomNumber(uint256 newNumber) external OnlyDirector() {
        randomNumber = newNumber;
    }



    function SetIsMintingEnabled(bool isEnabled) external OnlyDirector() {
        isMintingEnabled = isEnabled;
    }

    function SetIsAuthorizedToView(address newAddress, bool isAuth) external OnlyDirector() {
        isAuthorizedToView[newAddress] = isAuth;
    }

    function SetMinimumNipDepositAmountRequiredToMint(uint256 newMinAmount) external OnlyDirector() {
        minimumNipAmountInDepositToMint = newMinAmount;
    }

    function SetMinimumGasDepositAmountRequiredToMint(uint256 newMinAmount) external OnlyDirector() {
        minimumGasAmountInDepositToMint = newMinAmount;
    }

    function SetMinimumNipDepositAmountRequiredToChangeMetaData(uint256 newMinAmount) external OnlyDirector() {
        minimumNipAmountInDepositToChangeMetaData = newMinAmount;
    }

    function SetMinimumGasDepositAmountRequiredToChangeMetaData(uint256 newMinAmount) external OnlyDirector() {
        minimumGasAmountInDepositToChangeMetaData = newMinAmount;
    }






    function MintCatNIPNFT(string memory tokenURIstring, uint256 costOfNFT, address addressToMintTo) OnlyMinter() public returns (uint256) {

        require(!isMinting[addressToMintTo], "Minter must not already have a mint in progress.");
        isMinting[addressToMintTo] = true;

        require(nipContractAddressICatNIP.isGameSystemEnabled(), "Game System must be enabled to Mint NFTs");
        require(isMintingEnabled, "Minting must be enabled.");

        // if(randomNumber >= 1000000000000000000000000000000000){
        //     randomNumber = randomNumber.div(2);
        // }
        // randomNumber = randomNumber.add(79);

        require(!nipContractAddressICatNIP.isBannedFromAllGamesForManipulation(addressToMintTo), "You need to appeal your ban from all games. You may have been caught manipulating the system in some way. Please appeal in Telegram or Discord.");



        (uint256 nipDeposit, uint256 gasDeposit) = nipContractAddressICatNIP.GetDepositsAmountTotal(addressToMintTo);
        // require(nipContractAddressICatNIP.GetDepositAmountTotal(addressToMintTo) > 0, "You have no deposit, please deposit more NIP");
        require(nipDeposit >= minimumNipAmountInDepositToMint, "You do not have enough CatNIP in the Deposit, At least have the minimum amount.");
        require(gasDeposit >= minimumGasAmountInDepositToMint, "You do not have enough Gas in the Deposit, At least have the minimum amount.");
        require(nipDeposit >= costOfNFT, "You do not have enough NIP in the Deposit, please deposit more NIP");
        nipContractAddressICatNIP.DecreaseDepositAmountTotal(costOfNFT, addressToMintTo);


        
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(addressToMintTo, newItemId);
        _setTokenURI(newItemId, tokenURIstring);

        isMinting[addressToMintTo] = false;

        return newItemId;

    }

    function SetCatNIPNFTMetaData(uint256 itemId, string memory newTokenURIstring, uint256 costOfChange, address addressOfNFTtoChange) OnlyMinter() external {

        require(!isMinting[addressOfNFTtoChange], "Minter must not already have a Change in progress.");
        isMinting[addressOfNFTtoChange] = true;

        require(nipContractAddressICatNIP.isGameSystemEnabled(), "Game System must be enabled to Change NFTs");
        require(isMintingEnabled, "Minting must be enabled.");

        require(_isApprovedOrOwner(addressOfNFTtoChange, itemId), "ERC721: caller is not owner nor approved");

        require(!isNFTlockedFromModification[itemId], "Must be UnLocked in order to modify.");

        // if(randomNumber >= 1000000000000000000000000000000000){
        //     randomNumber = randomNumber.div(2);
        // }
        // randomNumber = randomNumber.add(71);

        

        require(!nipContractAddressICatNIP.isBannedFromAllGamesForManipulation(addressOfNFTtoChange), "You need to appeal your ban from all games. You may have been caught manipulating the system in some way. Please appeal in Telegram or Discord.");


        (uint256 nipDeposit, uint256 gasDeposit) = nipContractAddressICatNIP.GetDepositsAmountTotal(addressOfNFTtoChange);
        // require(nipContractAddressICatNIP.GetDepositAmountTotal(addressToMintTo) > 0, "You have no deposit, please deposit more NIP");
        require(nipDeposit >= minimumNipAmountInDepositToChangeMetaData, "You do not have enough CatNIP in the Deposit, At least have the minimum amount.");
        require(gasDeposit >= minimumGasAmountInDepositToChangeMetaData, "You do not have enough Gas in the Deposit, At least have the minimum amount.");
        require(nipDeposit >= costOfChange, "You do not have enough NIP in the Deposit, please deposit more NIP");
        nipContractAddressICatNIP.DecreaseDepositAmountTotal(costOfChange, addressOfNFTtoChange);


        _setTokenURI(itemId, newTokenURIstring);

        isMinting[addressOfNFTtoChange] = false;
    }


    function MintSpecialCatNIPNFT(address addressToMintTo, string memory tokenURIstring) external OnlyDirector()  returns (uint256) {

        // if(randomNumber >= 1000000000000000000000000000000000){
        //     randomNumber = randomNumber.div(2);
        // }
        // randomNumber = randomNumber.add(73);

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(addressToMintTo, newItemId);
        _setTokenURI(newItemId, tokenURIstring);

        return newItemId;
    }

    function SetCatNIPNFTMetaDataAsDirector(uint256 itemId, string memory newTokenURIstring) external OnlyDirector() {

        require(!isNFTlockedFromModification[itemId], "Must be UnLocked in order to modify.");

        // if(randomNumber >= 1000000000000000000000000000000000){
        //     randomNumber = randomNumber.div(2);
        // }
        // randomNumber = randomNumber.add(72);

        _setTokenURI(itemId, newTokenURIstring);

    }


    mapping(uint256 => bool) public isNFTlockedFromModification;
    function LockNFTFromModification(uint256 itemId) external {
        require(_isApprovedOrOwner(_msgSender(), itemId), "ERC721: caller is not owner nor approved");
        isNFTlockedFromModification[itemId] = true;
    }

    function UnLockNFTFromModification(uint256 itemId) external {
        require(_isApprovedOrOwner(_msgSender(), itemId), "ERC721: caller is not owner nor approved");
        isNFTlockedFromModification[itemId] = false;
    }
    




    receive() external payable {}       // Oh it's payable alright.
}