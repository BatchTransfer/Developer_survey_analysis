// SPDX-License-Identifier: UNLICENSED
// Source: 0x72481fb01eede2093af919f2fe29334527b97f4a
// Contract Name: LiquidityPool
// This is a flattened version of all source files
// Generated on: 2026-05-06 13:21:33


================================================================================
// FILE: src/LiquidityPool.sol
================================================================================

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

import "./interfaces/IRegulationsManager.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IEtherFiNodesManager.sol";
import "./interfaces/IeETH.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IMembershipManager.sol";
import "./interfaces/ITNFT.sol";
import "./interfaces/IWithdrawRequestNFT.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IEtherFiAdmin.sol";

contract LiquidityPool is Initializable, OwnableUpgradeable, UUPSUpgradeable, ILiquidityPool {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    IStakingManager public stakingManager;
    IEtherFiNodesManager public nodesManager;
    IRegulationsManager public DEPRECATED_regulationsManager;
    IMembershipManager public membershipManager;
    ITNFT public tNft;
    IeETH public eETH; 

    bool public DEPRECATED_eEthliquidStakingOpened;

    uint128 public totalValueOutOfLp;
    uint128 public totalValueInLp;

    address public DEPRECATED_admin;

    uint32 public numPendingDeposits; // number of deposits to the staking manager, which needs 'registerValidator'

    address public DEPRECATED_bNftTreasury;
    IWithdrawRequestNFT public withdrawRequestNFT;

    BnftHolder[] public bnftHolders;
    uint128 public maxValidatorsPerOwner;
    uint128 public DEPRECATED_schedulingPeriodInSeconds;

    HoldersUpdate public DEPRECATED_holdersUpdate;

    mapping(address => bool) public admins;
    mapping(SourceOfFunds => FundStatistics) public fundStatistics;
    mapping(uint256 => bytes32) public depositDataRootForApprovalDeposits;
    address public etherFiAdminContract;
    bool public whitelistEnabled;
    mapping(address => bool) public whitelisted;
    mapping(address => BnftHoldersIndex) public bnftHoldersIndexes;

    bool public restakeBnftDeposits;
    uint128 public ethAmountLockedForWithdrawal;
    bool public paused;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event Paused(address account);
    event Unpaused(address account);

    event Deposit(address indexed sender, uint256 amount, SourceOfFunds source, address referral);
    event Withdraw(address indexed sender, address recipient, uint256 amount, SourceOfFunds source);
    event UpdatedWhitelist(address userAddress, bool value);
    event BnftHolderDeregistered(address user, uint256 index);
    event BnftHolderRegistered(address user, uint256 index);
    event UpdatedSchedulingPeriod(uint128 newPeriodInSeconds);
    event ValidatorRegistered(uint256 indexed validatorId, bytes signature, bytes pubKey, bytes32 depositRoot);
    event ValidatorApproved(uint256 indexed validatorId);
    event ValidatorRegistrationCanceled(uint256 indexed validatorId);
    event Rebase(uint256 totalEthLocked, uint256 totalEEthShares);
    event WhitelistStatusUpdated(bool value);

    error IncorrectCaller();
    error InvalidAmount();
    error InvalidParams();
    error DataNotSet();
    error InsufficientLiquidity();
    error SendFail();

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {
        if (msg.value > type(uint128).max) revert InvalidAmount();
        totalValueOutOfLp -= uint128(msg.value);
        totalValueInLp += uint128(msg.value);
    }

    function initialize(address _eEthAddress, address _stakingManagerAddress, address _nodesManagerAddress, address _membershipManagerAddress, address _tNftAddress) external initializer {
        if (_eEthAddress == address(0) || _stakingManagerAddress == address(0) || _nodesManagerAddress == address(0) || _membershipManagerAddress == address(0) || _tNftAddress == address(0)) revert DataNotSet();
        
        __Ownable_init();
        __UUPSUpgradeable_init();

        eETH = IeETH(_eEthAddress);
        stakingManager = IStakingManager(_stakingManagerAddress);
        nodesManager = IEtherFiNodesManager(_nodesManagerAddress);
        membershipManager = IMembershipManager(_membershipManagerAddress);
        tNft = ITNFT(_tNftAddress);
    }

    /// @notice Allows us to set needed variable state in phase 2
    /// @dev This data and functions are used to help with our staking router process. This helps us balance the use of funds
    ///         being allocated to deposits. It also means we are able to give permissions to certain operators to run deposits only
    ///         only from specific deposits
    /// @param _schedulingPeriod the time we want between scheduling periods
    /// @param _eEthNumVal the number of validators to set for eEth
    /// @param _etherFanNumVal the number of validators to set for ether fan
    function initializeOnUpgrade(uint128 _schedulingPeriod, uint32 _eEthNumVal, uint32 _etherFanNumVal, address _etherFiAdminContract, address _withdrawRequestNFT) external onlyOwner { 
        require(_etherFiAdminContract != address(0) && _withdrawRequestNFT != address(0), "No zero addresses");

        paused = true;
        whitelistEnabled = true;
        restakeBnftDeposits = false;
        ethAmountLockedForWithdrawal = 0;
        maxValidatorsPerOwner = 30;
        
        //Allows us to begin with a predefined number of validators
        fundStatistics[SourceOfFunds.EETH].numberOfValidators = _eEthNumVal;
        fundStatistics[SourceOfFunds.ETHER_FAN].numberOfValidators = _etherFanNumVal;

        etherFiAdminContract = _etherFiAdminContract;
        withdrawRequestNFT = IWithdrawRequestNFT(_withdrawRequestNFT);

        admins[_etherFiAdminContract] = true;
    }

    // Used by eETH staking flow
    function deposit() external payable returns (uint256) {
        return deposit(address(0));
    }

    function deposit(address _referral) public payable whenNotPaused returns (uint256) {
        require(_isWhitelisted(msg.sender), "Invalid User");

        emit Deposit(msg.sender, msg.value, SourceOfFunds.EETH, _referral);

        return _deposit();
    }

    // Used by ether.fan staking flow
    function deposit(address _user, address _referral) external payable whenNotPaused returns (uint256) {
        if (msg.sender != address(membershipManager)) {
            revert IncorrectCaller();
        }
        require(_user == address(membershipManager) || _isWhitelisted(_user), "Invalid User");

        emit Deposit(msg.sender, msg.value, SourceOfFunds.ETHER_FAN, _referral);

        return _deposit();
    }

    /// @notice withdraw from pool
    /// @dev Burns user balance from msg.senders account & Sends equal amount of ETH back to the recipient
    /// @param _recipient the recipient who will receives the ETH
    /// @param _amount the amount to withdraw from contract
    /// it returns the amount of shares burned
    function withdraw(address _recipient, uint256 _amount) external whenNotPaused returns (uint256) {
        uint256 share = sharesForWithdrawalAmount(_amount);
        require(msg.sender == address(withdrawRequestNFT) || msg.sender == address(membershipManager), "Incorrect Caller");
        if (totalValueInLp < _amount || (msg.sender == address(withdrawRequestNFT) && ethAmountLockedForWithdrawal < _amount) || eETH.balanceOf(msg.sender) < _amount) revert InsufficientLiquidity();
        if (_amount > type(uint128).max || _amount == 0 || share == 0) revert InvalidAmount();

        totalValueInLp -= uint128(_amount);
        if (msg.sender == address(withdrawRequestNFT)) {
            ethAmountLockedForWithdrawal -= uint128(_amount);
        }

        eETH.burnShares(msg.sender, share);

        (bool sent, ) = _recipient.call{value: _amount}("");
        if (!sent) revert SendFail();

        return share;
    }

    /// @notice request withdraw from pool and receive a WithdrawRequestNFT
    /// @dev Transfers the amount of eETH from msg.senders account to the WithdrawRequestNFT contract & mints an NFT to the msg.sender
    /// @param recipient address that will be issued the NFT
    /// @param amount requested amount to withdraw from contract
    /// @return uint256 requestId of the WithdrawRequestNFT
    function requestWithdraw(address recipient, uint256 amount) public whenNotPaused returns (uint256) {
        uint256 share = sharesForAmount(amount);
        if (amount > type(uint96).max || amount == 0 || share == 0) revert InvalidAmount();

        // transfer shares to WithdrawRequestNFT contract from this contract
        eETH.transferFrom(msg.sender, address(withdrawRequestNFT), amount);

        uint256 requestId = withdrawRequestNFT.requestWithdraw(uint96(amount), uint96(share), recipient, 0);
       
        emit Withdraw(msg.sender, recipient, amount, SourceOfFunds.EETH);

        return requestId;
    }

    /// @notice request withdraw from pool with signed permit data and receive a WithdrawRequestNFT
    /// @dev accepts PermitInput signed data to approve transfer of eETH (EIP-2612) so withdraw request can happen in 1 tx
    /// @param _owner address that will be issued the NFT
    /// @param _amount requested amount to withdraw from contract
    /// @param _permit signed permit data to approve transfer of eETH
    /// @return uint256 requestId of the WithdrawRequestNFT
    function requestWithdrawWithPermit(address _owner, uint256 _amount, PermitInput calldata _permit)
        external
        whenNotPaused
        returns (uint256)
    {
        eETH.permit(msg.sender, address(this), _permit.value, _permit.deadline, _permit.v, _permit.r, _permit.s);
        return requestWithdraw(_owner, _amount);
    }

    /// @notice request withdraw of some or all of the eETH backing a MembershipNFT and receive a WithdrawRequestNFT
    /// @dev Transfers the amount of eETH from MembershipManager to the WithdrawRequestNFT contract & mints an NFT to the recipient
    /// @param recipient address that will be issued the NFT
    /// @param amount requested amount to withdraw from contract
    /// @param fee the burn fee to be paid by the recipient when the withdrawal is claimed (WithdrawRequestNFT.claimWithdraw)
    /// @return uint256 requestId of the WithdrawRequestNFT
    function requestMembershipNFTWithdraw(address recipient, uint256 amount, uint256 fee) public whenNotPaused returns (uint256) {
        if (msg.sender != address(membershipManager)) revert IncorrectCaller();
        uint256 share = sharesForAmount(amount);
        if (amount > type(uint96).max || amount == 0 || share == 0) revert InvalidAmount();

        // transfer shares to WithdrawRequestNFT contract
        eETH.transferFrom(msg.sender, address(withdrawRequestNFT), amount);

        uint256 requestId = withdrawRequestNFT.requestWithdraw(uint96(amount), uint96(share), recipient, fee);

        emit Withdraw(msg.sender, recipient, amount, SourceOfFunds.ETHER_FAN);

        return requestId;
    } 

    /// @notice Allows a BNFT player to deposit their 2 ETH and pair with 30 ETH from the LP
    /// @dev This function has multiple dependencies that need to be followed before this function will succeed. 
    /// @param _candidateBidIds validator IDs that have been matched with the BNFT holder on the FE
    /// @param _numberOfValidators how many validators the user wants to spin up. This can be less than the candidateBidIds length. 
    ///         we may have more Ids sent in than needed to spin up incase some ids fail.
    /// @return Array of bids that were successfully processed.
    function batchDepositAsBnftHolder(uint256[] calldata _candidateBidIds, uint256 _numberOfValidators) external payable whenNotPaused returns (uint256[] memory) {
        uint32 index = bnftHoldersIndexes[msg.sender].index;
        require(bnftHoldersIndexes[msg.sender].registered && bnftHolders[index].holder == msg.sender, "Incorrect Caller");        
        require(msg.value == _numberOfValidators * 2 ether, "Deposit 2 ETH per validator");
        require(totalValueInLp + msg.value >= 32 ether * _numberOfValidators, "Not enough balance");
        require(_numberOfValidators <= maxValidatorsPerOwner, "Exceeded max validators per owner");
    
        //Funds in the LP can come from our membership strategy or the eEth staking strategy. We select which source of funds will
        //be used for spinning up these deposited ids. See the function for more detail on how we do this.
        SourceOfFunds _source = allocateSourceOfFunds();
        fundStatistics[_source].numberOfValidators += uint32(_numberOfValidators);

        uint256 amountFromLp = 30 ether * _numberOfValidators;
        if (amountFromLp > type(uint128).max) revert InvalidAmount();

        totalValueOutOfLp += uint128(amountFromLp);
        totalValueInLp -= uint128(amountFromLp);
        numPendingDeposits += uint32(_numberOfValidators);

        //We then call the Staking Manager contract which handles the rest of the logic
        uint256[] memory newValidators = stakingManager.batchDepositWithBidIds{value: 32 ether * _numberOfValidators}(_candidateBidIds, msg.sender, _source, restakeBnftDeposits);
        
        //Sometimes not all the validators get deposited successfully. We need to check if there were remaining IDs that were not successful
        //and refund the BNFT player their 2 ETH for each ID
        if (_numberOfValidators > newValidators.length) {
            uint256 returnAmount = 2 ether * (_numberOfValidators - newValidators.length);
            totalValueOutOfLp += uint128(returnAmount);
            totalValueInLp -= uint128(returnAmount);
            numPendingDeposits -= uint32(_numberOfValidators - newValidators.length);

            (bool sent, ) = msg.sender.call{value: returnAmount}("");
            if (!sent) revert SendFail();
        }
        
        return newValidators;
    }

    /// @notice BNFT players register validators they have deposited. This triggers a 1 ETH transaction to the beacon chain.
    /// @dev This function can only be called by a BNFT player on IDs that have been deposited.  
    /// @param _depositRoot This is the deposit root of the beacon chain. Can send in 0x00 to bypass this check in future
    /// @param _validatorIds The ids of the validators to register
    /// @param _registerValidatorDepositData As in the solo staking flow, the BNFT player must send in a deposit data object (see ILiquidityPool for struct data)
    ///         to register the validators. However, the signature and deposit data root must be for a 1 ETH deposit
    /// @param _depositDataRootApproval The deposit data roots for each validator for the 31 ETH transaction which will happen in the approval
    ///         step. See the Staking Manager for details.
    /// @param _signaturesForApprovalDeposit Much like the deposit data root. This is the signature for each validator for the 31 ETH 
    ///         transaction which will happen in the approval step.
    function batchRegisterAsBnftHolder(
        bytes32 _depositRoot,
        uint256[] calldata _validatorIds,
        IStakingManager.DepositData[] calldata _registerValidatorDepositData,
        bytes32[] calldata _depositDataRootApproval,
        bytes[] calldata _signaturesForApprovalDeposit
    ) external whenNotPaused {
        require(_validatorIds.length == _registerValidatorDepositData.length && _validatorIds.length == _depositDataRootApproval.length && _validatorIds.length == _signaturesForApprovalDeposit.length, "lengths differ");

        stakingManager.batchRegisterValidators(_depositRoot, _validatorIds, msg.sender, address(this), _registerValidatorDepositData, msg.sender);
        
        //For each validator, we need to store the deposit data root of the 31 ETH transaction so it is accessible in the approve function
        for(uint256 i; i < _validatorIds.length; i++) {
            depositDataRootForApprovalDeposits[_validatorIds[i]] = _depositDataRootApproval[i];
            emit ValidatorRegistered(_validatorIds[i], _signaturesForApprovalDeposit[i], _registerValidatorDepositData[i].publicKey, _depositDataRootApproval[i]);
        }
    }

    /// @notice Approves validators and triggers the 31 ETH transaction to the beacon chain (rest of the stake).
    /// @dev This gets called by the Oracle and only when it has confirmed the withdraw credentials of the 1 ETH deposit in the registration
    ///         phase match the withdraw credentials stored on the beacon chain. This prevents a front-running attack.
    /// @param _validatorIds The IDs of the validators to be approved
    /// @param _pubKey The pubKey for each validator being spun up.
    /// @param _signature The signatures for each validator for the 31 ETH transaction that were emitted in the register phase
    function batchApproveRegistration(
        uint256[] memory _validatorIds, 
        bytes[] calldata _pubKey,
        bytes[] calldata _signature
    ) external onlyAdmin whenNotPaused {
        require(_validatorIds.length == _pubKey.length && _validatorIds.length == _signature.length, "lengths differ");

        //Fetches the deposit data root of each validator and uses it in the approval call to the Staking Manager
        bytes32[] memory depositDataRootApproval = new bytes32[](_validatorIds.length);
        for(uint256 i; i < _validatorIds.length; i++) {
            depositDataRootApproval[i] = depositDataRootForApprovalDeposits[_validatorIds[i]];
            delete depositDataRootForApprovalDeposits[_validatorIds[i]];        

            emit ValidatorApproved(_validatorIds[i]);
        }

        numPendingDeposits -= uint32(_validatorIds.length);
        stakingManager.batchApproveRegistration(_validatorIds, _pubKey, _signature, depositDataRootApproval);
    }

    /// @notice Cancels a BNFT players deposits (whether validator is registered or deposited. Just not live on beacon chain)
    /// @dev This is called only in the BNFT player flow
    /// @param _validatorIds The IDs to be cancelled
    function batchCancelDeposit(uint256[] calldata _validatorIds) external whenNotPaused {
        _batchCancelDeposit(_validatorIds, msg.sender);
    }

    function batchCancelDepositByAdmin(uint256[] calldata _validatorIds, address _bnftStaker) external whenNotPaused onlyAdmin {
        _batchCancelDeposit(_validatorIds, _bnftStaker);
    }

    function _batchCancelDeposit(uint256[] calldata _validatorIds, address _bnftStaker) internal {
        uint256 returnAmount;

        //Due to the way we handle our totalValueOutOfLP calculations, we need to update the data before we call the Staking Manager
        //For this reason, we first need to check which phase each validator is in. Because if a bNFT cancels a validator that has 
        //already been registered, they only receive 1 ETH back because the other 1 ETH is in the beacon chain. Those funds will be lost
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            if(nodesManager.phase(_validatorIds[i]) == IEtherFiNode.VALIDATOR_PHASE.WAITING_FOR_APPROVAL) {
                returnAmount += 1 ether;

                emit ValidatorRegistrationCanceled(_validatorIds[i]);
            } else {
                returnAmount += 2 ether;
            }
        }

        totalValueOutOfLp += uint128(returnAmount);
        numPendingDeposits -= uint32(_validatorIds.length);
        stakingManager.batchCancelDepositAsBnftHolder(_validatorIds, _bnftStaker);

        totalValueInLp -= uint128(returnAmount);
        (bool sent, ) = address(_bnftStaker).call{value: returnAmount}("");
        if (!sent) revert SendFail();
    }

    /// @notice The admin can register an address to become a BNFT holder. This adds them to the bnftHolders array
    /// @dev BNFT players reach out to Etherfi externally and then Etherfi will register them
    /// @param _user The address of the BNFT player to register
    function registerAsBnftHolder(address _user) public onlyAdmin {      
        require(!bnftHoldersIndexes[_user].registered, "Already registered");  

        //We hold the users address and latest deposit timestamp in an object to make sure a user doesnt deposit twice in one scheduling period
        BnftHolder memory bnftHolder = BnftHolder({
            holder: _user,
            timestamp: 0
        });

        uint256 index = bnftHolders.length;

        bnftHolders.push(bnftHolder);
        bnftHoldersIndexes[_user] = BnftHoldersIndex({
            registered: true,
            index: uint32(index)
        });

        emit BnftHolderRegistered(_user, index);
    }

    /// @notice Removes a BNFT player from the bnftHolders array and means they are no longer eligible to be selected
    /// @dev We allow either the user themselves or admins to remove BNFT players
    /// @param _bNftHolder Address of the BNFT player to remove
    function deRegisterBnftHolder(address _bNftHolder) external {
        require(bnftHoldersIndexes[_bNftHolder].registered, "Not registered");
        uint256 index = bnftHoldersIndexes[_bNftHolder].index;
        require(admins[msg.sender] || msg.sender == bnftHolders[index].holder, "Incorrect Caller");
        
        uint256 endIndex = bnftHolders.length - 1;
        address endUser = bnftHolders[endIndex].holder;

        //Swap the end BNFT player with the BNFT player being removed
        bnftHolders[index] = bnftHolders[endIndex];
        bnftHoldersIndexes[endUser].index = uint32(index);
        
        //Pop the last user as we have swapped them around
        bnftHolders.pop();
        delete bnftHoldersIndexes[_bNftHolder];

        emit BnftHolderDeregistered(_bNftHolder, index);
    }

    /// @notice Send the exit requests as the T-NFT holder
    function sendExitRequests(uint256[] calldata _validatorIds) external onlyAdmin {
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            uint256 validatorId = _validatorIds[i];
            nodesManager.sendExitRequest(validatorId);
        }
    }

    /// @notice Rebase by ether.fi
    function rebase(int128 _accruedRewards) public {
        if (msg.sender != address(membershipManager)) revert IncorrectCaller();
        totalValueOutOfLp = uint128(int128(totalValueOutOfLp) + _accruedRewards);

        emit Rebase(getTotalPooledEther(), eETH.totalShares());
    }

    /// @notice Whether or not nodes created via bNFT deposits should be restaked
    function setRestakeBnftDeposits(bool _restake) external onlyAdmin {
        restakeBnftDeposits = _restake;
    }

    /// @notice Updates the address of the admin
    /// @param _address the new address to set as admin
    function updateAdmin(address _address, bool _isAdmin) external onlyOwner {
        admins[_address] = _isAdmin;
    }

    function pauseContract() external onlyAdmin {
        paused = true;
        emit Paused(_msgSender());
    }

    function unPauseContract() external onlyAdmin {
        paused = false;
        emit Unpaused(_msgSender());
    }

    /// @notice Sets the max number of validators a BNFT can spin up in a batch
    /// @param _newSize the number to set it to
    function setNumValidatorsToSpinUpInBatch(uint128 _newSize) external onlyAdmin {
        maxValidatorsPerOwner = _newSize;
    }

    /// @notice Sets our targeted ratio of validators for each of the fund sources
    /// @dev Fund sources are different ways where the LP receives funds. Currently, there is just through EETH staking and ETHER_FAN (membership manager)
    /// @param _eEthWeight The target weight for eEth
    /// @param _etherFanWeight The target weight for EtherFan
    function setStakingTargetWeights(uint32 _eEthWeight, uint32 _etherFanWeight) external onlyAdmin {
        if (_eEthWeight + _etherFanWeight != 100) revert InvalidParams();

        fundStatistics[SourceOfFunds.EETH].targetWeight = _eEthWeight;
        fundStatistics[SourceOfFunds.ETHER_FAN].targetWeight = _etherFanWeight;
    }

    function updateWhitelistedAddresses(address[] calldata _users, bool _value) external onlyAdmin {
        for (uint256 i = 0; i < _users.length; i++) {
            whitelisted[_users[i]] = _value;

            emit UpdatedWhitelist(_users[i], _value);
        }
    }

    function updateWhitelistStatus(bool _value) external onlyAdmin {
        whitelistEnabled = _value;

        emit WhitelistStatusUpdated(_value);
    }

    /// @notice Decreases the number of validators for a certain source of fund
    /// @dev When a user deposits, we increment the number of validators in the allocated source object. However, when a BNFT player cancels 
    ///         their deposits, we need to decrease this again.
    /// @param numberOfEethValidators How many eEth validators to decrease
    /// @param numberOfEtherFanValidators How many etherFan validators to decrease
    function decreaseSourceOfFundsValidators(uint32 numberOfEethValidators, uint32 numberOfEtherFanValidators) external {
        if (msg.sender != address(stakingManager)) revert IncorrectCaller();

        fundStatistics[SourceOfFunds.EETH].numberOfValidators -= numberOfEethValidators;
        fundStatistics[SourceOfFunds.ETHER_FAN].numberOfValidators -= numberOfEtherFanValidators;
    }

    function addEthAmountLockedForWithdrawal(uint128 _amount) external {
        if (msg.sender != address(etherFiAdminContract)) revert IncorrectCaller();

        ethAmountLockedForWithdrawal += _amount;
    }

    //--------------------------------------------------------------------------------------
    //------------------------------  INTERNAL FUNCTIONS  ----------------------------------
    //--------------------------------------------------------------------------------------

    function _deposit() internal returns (uint256) {
        totalValueInLp += uint128(msg.value);
        uint256 share = _sharesForDepositAmount(msg.value);
        if (msg.value > type(uint128).max || msg.value == 0 || share == 0) revert InvalidAmount();

        eETH.mintShares(msg.sender, share);

        return share;
    }

    function _isWhitelisted(address _user) internal view returns (bool) {
        return (!whitelistEnabled || whitelisted[_user]);
    }

    function _sharesForDepositAmount(uint256 _depositAmount) internal view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther() - _depositAmount;
        if (totalPooledEther == 0) {
            return _depositAmount;
        }
        return (_depositAmount * eETH.totalShares()) / totalPooledEther;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //--------------------------------------------------------------------------------------
    //------------------------------------  GETTERS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Selects a source of funds to be used for the deposits
    /// @dev The LP has two ways of accumulating funds, through eEth staking and through the ether fan page (membership manager).
    ///         We want to manipulate which funds we use per deposit. Example, if someone is making 2 deposits, we want to select where the 60 ETH
    ///         should come from. The funds will all be held in the LP but we are storing how many validators are spun up per source on the contract.
    ///         We simply check which of the sources is below their target allocation and allocate the deposits to it.
    /// @return The chosen source of funds (EETH or ETHER_FAN)
    function allocateSourceOfFunds() public view returns (SourceOfFunds) {
        uint256 validatorRatio = (fundStatistics[SourceOfFunds.EETH].numberOfValidators * 10_000) / fundStatistics[SourceOfFunds.ETHER_FAN].numberOfValidators;
        uint256 weightRatio = (fundStatistics[SourceOfFunds.EETH].targetWeight * 10_000) / fundStatistics[SourceOfFunds.ETHER_FAN].targetWeight;

        return validatorRatio > weightRatio ? SourceOfFunds.ETHER_FAN : SourceOfFunds.EETH;
    }

    function getTotalEtherClaimOf(address _user) external view returns (uint256) {
        uint256 staked;
        uint256 totalShares = eETH.totalShares();
        if (totalShares > 0) {
            staked = (getTotalPooledEther() * eETH.shares(_user)) / totalShares;
        }
        return staked;
    }

    function getTotalPooledEther() public view returns (uint256) {
        return totalValueOutOfLp + totalValueInLp;
    }

    function sharesForAmount(uint256 _amount) public view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther();
        if (totalPooledEther == 0) {
            return 0;
        }
        return (_amount * eETH.totalShares()) / totalPooledEther;
    }

    /// @dev withdrawal rounding errors favor the protocol by rounding up
    function sharesForWithdrawalAmount(uint256 _amount) public view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther();
        if (totalPooledEther == 0) {
            return 0;
        }

        // ceiling division so rounding errors favor the protocol
        uint256 numerator = _amount * eETH.totalShares();
        return (numerator + totalPooledEther - 1) / totalPooledEther;
    }

    function amountForShare(uint256 _share) public view returns (uint256) {
        uint256 totalShares = eETH.totalShares();
        if (totalShares == 0) {
            return 0;
        }
        return (_share * getTotalPooledEther()) / totalShares;
    }

    function getImplementation() external view returns (address) {return _getImplementation();}

    function _requireAdmin() internal view virtual {
        require(admins[msg.sender], "Not admin");
    }

    function _requireNotPaused() internal view virtual {
        require(!paused, "Pausable: paused");
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyAdmin() {
        _requireAdmin();
        _;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }
}


================================================================================
// FILE: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}


================================================================================
// FILE: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/IERC721ReceiverUpgradeable.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721ReceiverUpgradeable {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}


================================================================================
// FILE: lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.1) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}


================================================================================
// FILE: lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../ERC1967/ERC1967UpgradeUpgradeable.sol";
import "./Initializable.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822ProxiableUpgradeable, ERC1967UpgradeUpgradeable {
    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }

    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


================================================================================
// FILE: lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}


================================================================================
// FILE: src/interfaces/IRegulationsManager.sol
================================================================================

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IRegulationsManager {
    function initialize() external;

    function confirmEligibility(bytes32 hash) external;

    function removeFromWhitelist(address _user) external;

    function initializeNewWhitelist(bytes32 _newVersionHash) external;

    function isEligible(uint32 _whitelistVersion, address _user) external view returns (bool);

    function whitelistVersion() external view returns (uint32);

}


================================================================================
// FILE: src/interfaces/IStakingManager.sol
================================================================================

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./ILiquidityPool.sol";

interface IStakingManager {
    struct DepositData {
        bytes publicKey;
        bytes signature;
        bytes32 depositDataRoot;
        string ipfsHashForEncryptedValidatorKey;
    }

    struct StakerInfo {
        address staker;
        ILiquidityPool.SourceOfFunds sourceOfFund;
    }

    function bidIdToStaker(uint256 id) external view returns (address);

    function getEtherFiNodeBeacon() external view returns (address);

    function initialize(address _auctionAddress, address _depositContractAddress) external;
    function setEtherFiNodesManagerAddress(address _managerAddress) external;
    function setLiquidityPoolAddress(address _liquidityPoolAddress) external;
    function batchDepositWithBidIds(uint256[] calldata _candidateBidIds, address _staker, ILiquidityPool.SourceOfFunds source, bool _enableRestaking) external payable returns (uint256[] memory);
    function batchDepositWithBidIds(uint256[] calldata _candidateBidIds, bool _enableRestaking) external payable returns (uint256[] memory);

    function batchRegisterValidators(bytes32 _depositRoot, uint256[] calldata _validatorId, DepositData[] calldata _depositData) external;

    function batchRegisterValidators(bytes32 _depositRoot, uint256[] calldata _validatorId, address _bNftRecipient, address _tNftRecipient, DepositData[] calldata _depositData, address _user) external;

    function batchApproveRegistration(uint256[] memory _validatorId, bytes[] calldata _pubKey, bytes[] calldata _signature, bytes32[] calldata _depositDataRootApproval) external;

    function batchCancelDeposit(uint256[] calldata _validatorIds) external;

    function batchCancelDepositAsBnftHolder(uint256[] calldata _validatorIds, address _caller) external;

    function updateAdmin(address _address, bool _isAdmin) external;
    function pauseContract() external;
    function unPauseContract() external;
}


================================================================================
// FILE: src/interfaces/IEtherFiNodesManager.sol
================================================================================

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IEtherFiNode.sol";
import "@eigenlayer/contracts/interfaces/IEigenPodManager.sol";
import "@eigenlayer/contracts/interfaces/IDelayedWithdrawalRouter.sol";

interface IEtherFiNodesManager {

    struct RewardsSplit {
        uint64 treasury;
        uint64 nodeOperator;
        uint64 tnft;
        uint64 bnft;
    }

    enum ValidatorRecipientType {
        TNFTHOLDER,
        BNFTHOLDER,
        TREASURY,
        OPERATOR
    }

    // VIEW functions
    function calculateTVL(uint256 _validatorId, uint256 _beaconBalance) external view returns (uint256, uint256, uint256, uint256);
    function calculateWithdrawableTVL(uint256 _validatorId, uint256 _beaconBalance) external view returns (uint256, uint256, uint256, uint256);
    function delayedWithdrawalRouter() external view returns (IDelayedWithdrawalRouter);
    function eigenPodManager() external view returns (IEigenPodManager);
    function generateWithdrawalCredentials(address _address) external view returns (bytes memory);
    function getFullWithdrawalPayouts(uint256 _validatorId) external view returns (uint256, uint256, uint256, uint256);
    function getNonExitPenalty(uint256 _validatorId) external view returns (uint256);
    function getRewardsPayouts(uint256 _validatorId, uint256 _beaconBalance) external view returns (uint256, uint256, uint256, uint256);
    function getWithdrawalCredentials(uint256 _validatorId) external view returns (bytes memory);
    function ipfsHashForEncryptedValidatorKey(uint256 _validatorId) external view returns (string memory);
    function nonExitPenaltyDailyRate() external view returns (uint64);
    function nonExitPenaltyPrincipal() external view returns (uint64);
    function numberOfValidators() external view returns (uint64);
    function phase(uint256 _validatorId) external view returns (IEtherFiNode.VALIDATOR_PHASE phase);

    // Non-VIEW functions
    function initialize(
        address _treasuryContract,
        address _auctionContract,
        address _stakingManagerContract,
        address _tnftContract,
        address _bnftContract
    ) external;

    function batchQueueRestakedWithdrawal(uint256[] calldata _validatorIds) external;
    function batchSendExitRequest(uint256[] calldata _validatorIds) external;
    function fullWithdrawBatch(uint256[] calldata _validatorIds) external;
    function fullWithdraw(uint256 _validatorId) external;
    function getUnusedWithdrawalSafesLength() external view returns (uint256);
    function incrementNumberOfValidators(uint64 _count) external;
    function markBeingSlashed(uint256[] calldata _validatorIds) external;
    function partialWithdrawBatch(uint256[] calldata _validatorIds) external;
    function partialWithdraw(uint256 _validatorId) external;
    function processNodeExit(uint256[] calldata _validatorIds, uint32[] calldata _exitTimestamp) external;
    function registerEtherFiNode(uint256 _validatorId, bool _enableRestaking) external returns (address);
    function sendExitRequest(uint256 _validatorId) external;
    function setEtherFiNodeIpfsHashForEncryptedValidatorKey(uint256 _validatorId, string calldata _ipfs) external;
    function setEtherFiNodePhase(uint256 _validatorId, IEtherFiNode.VALIDATOR_PHASE _phase) external;
    function setNonExitPenalty(uint64 _nonExitPenaltyDailyRate, uint64 _nonExitPenaltyPrincipal) external;
    function setStakingRewardsSplit(uint64 _treasury, uint64 _nodeOperator, uint64 _tnft, uint64 _bnf) external;
    function unregisterEtherFiNode(uint256 _validatorId) external;
    function updateAdmin(address _address, bool _isAdmin) external;
    function admins(address _address) external view returns (bool);
    function pauseContract() external;
    function unPauseContract() external;

    function treasuryContract() external view returns (address);
    function maxEigenlayerWithdrawals() external view returns (uint8);
}


================================================================================
// FILE: src/interfaces/IeETH.sol
================================================================================

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IeETH {
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalShares() external view returns (uint256);

    function shares(address _user) external view returns (uint256);
    function balanceOf(address _user) external view returns (uint256);

    function initialize(address _liquidityPool) external;
    function mintShares(address _user, uint256 _share) external;
    function burnShares(address _user, uint256 _share) external;
    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool);
    function transfer(address _recipient, uint256 _amount) external returns (bool);
    function approve(address _spender, uint256 _amount) external returns (bool);
    function increaseAllowance(address _spender, uint256 _increaseAmount) external returns (bool);
    function decreaseAllowance(address _spender, uint256 _decreaseAmount) external returns (bool);

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
}


================================================================================
// FILE: src/interfaces/IMembershipManager.sol
================================================================================

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IMembershipManager {

    struct TokenDeposit {
        uint128 amounts;
        uint128 shares;
    }

    struct TokenData {
        uint96 vaultShare;
        uint40 baseLoyaltyPoints;
        uint40 baseTierPoints;
        uint32 prevPointsAccrualTimestamp;
        uint32 prevTopUpTimestamp;
        uint8  tier;
        uint8  version;
    }

    // Used for V1
    struct TierVault {
        uint128 totalPooledEEthShares; // total share of eEth in the tier vault
        uint128 totalVaultShares; // total share of the tier vault
    }

    // Used for V0
    struct TierDeposit {
        uint128 amounts; // total pooled eth amount
        uint128 shares; // total pooled eEth shares
    }

    struct TierData {
        uint96 rewardsGlobalIndex;
        uint40 requiredTierPoints;
        uint24 weight;
        uint96  __gap;
    }

    // State-changing functions
    function wrapEthForEap(uint256 _amount, uint256 _amountForPoint, uint32  _eapDepositBlockNumber, uint256 _snapshotEthAmount, uint256 _points, bytes32[] calldata _merkleProof) external payable returns (uint256);
    function wrapEth(uint256 _amount, uint256 _amountForPoint) external payable returns (uint256);
    function wrapEth(uint256 _amount, uint256 _amountForPoint, address _referral) external payable returns (uint256);

    function topUpDepositWithEth(uint256 _tokenId, uint128 _amount, uint128 _amountForPoints) external payable;

    function requestWithdraw(uint256 _tokenId, uint256 _amount) external returns (uint256);
    function requestWithdrawAndBurn(uint256 _tokenId) external returns (uint256);

    function claim(uint256 _tokenId) external;

    function migrateFromV0ToV1(uint256 _tokenId) external;

    // Getter functions
    function tokenDeposits(uint256) external view returns (uint128, uint128);
    function tokenData(uint256) external view returns (uint96, uint40, uint40, uint32, uint32, uint8, uint8);
    function tierDeposits(uint256) external view returns (uint128, uint128);
    function tierData(uint256) external view returns (uint96, uint40, uint24, uint96);

    function rewardsGlobalIndex(uint8 _tier) external view returns (uint256);
    function allTimeHighDepositAmount(uint256 _tokenId) external view returns (uint256);
    function tierForPoints(uint40 _tierPoints) external view returns (uint8);
    function canTopUp(uint256 _tokenId, uint256 _totalAmount, uint128 _amount, uint128 _amountForPoints) external view returns (bool);
    function pointsBoostFactor() external view returns (uint16);
    function pointsGrowthRate() external view returns (uint16);
    function maxDepositTopUpPercent() external view returns (uint8);
    function numberOfTiers() external view returns (uint8);
    function getImplementation() external view returns (address);
    function minimumAmountForMint() external view returns (uint256);

    function eEthShareForVaultShare(uint8 _tier, uint256 _vaultShare) external view returns (uint256);
    function vaultShareForEEthShare(uint8 _tier, uint256 _eEthShare) external view returns (uint256);
    function ethAmountForVaultShare(uint8 _tier, uint256 _vaultShare) external view returns (uint256);
    function vaultShareForEthAmount(uint8 _tier, uint256 _ethAmount) external view returns (uint256);

    // only Owner
    function initializeOnUpgrade(address _etherFiAdminAddress, uint256 _fanBoostThresholdAmount, uint16 _burnFeeWaiverPeriodInDays) external;

    function setWithdrawalLockBlocks(uint32 _blocks) external;
    function updatePointsParams(uint16 _newPointsBoostFactor, uint16 _newPointsGrowthRate) external;
    function rebase(int128 _accruedRewards) external;
    function addNewTier(uint40 _requiredTierPoints, uint24 _weight) external;
    function updateTier(uint8 _tier, uint40 _requiredTierPoints, uint24 _weight) external;
    function setPoints(uint256 _tokenId, uint40 _loyaltyPoints, uint40 _tierPoints) external;
    function setDepositAmountParams(uint56 _minDepositGwei, uint8 _maxDepositTopUpPercent) external;
    function setTopUpCooltimePeriod(uint32 _newWaitTime) external;
    function updateAdmin(address _address, bool _isAdmin) external;
    function pauseContract() external;
    function unPauseContract() external;
}


================================================================================
// FILE: src/interfaces/ITNFT.sol
================================================================================

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC721/IERC721Upgradeable.sol";

interface ITNFT is IERC721Upgradeable {

    function burnFromWithdrawal(uint256 _validatorId) external;
    function initialize() external;
    function initializeOnUpgrade(address _etherFiNodesManagerAddress) external;
    function mint(address _receiver, uint256 _validatorId) external;
    function burnFromCancelBNftFlow(uint256 _validatorId) external;
    function upgradeTo(address _newImplementation) external;
}


================================================================================
// FILE: src/interfaces/IWithdrawRequestNFT.sol
================================================================================

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWithdrawRequestNFT {
    struct WithdrawRequest {
        uint96  amountOfEEth;
        uint96  shareOfEEth;
        bool    isValid;
        uint32  feeGwei;
    }

    function initialize(address _liquidityPoolAddress, address _eEthAddress, address _membershipManager) external;
    function requestWithdraw(uint96 amountOfEEth, uint96 shareOfEEth, address requester, uint256 fee) external payable returns (uint256);
    function claimWithdraw(uint256 requestId) external;

    function getRequest(uint256 requestId) external view returns (WithdrawRequest memory);
    function isFinalized(uint256 requestId) external view returns (bool);

    function invalidateRequest(uint256 requestId) external;
    function finalizeRequests(uint256 upperBound) external;
    function updateAdmin(address _address, bool _isAdmin) external;
}


================================================================================
// FILE: src/interfaces/ILiquidityPool.sol
================================================================================

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IStakingManager.sol";

interface ILiquidityPool {

    struct PermitInput {
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    } 

    enum SourceOfFunds {
        UNDEFINED,
        EETH,
        ETHER_FAN,
        DELEGATED_STAKING
    }

    struct FundStatistics {
        uint32 numberOfValidators;
        uint32 targetWeight;
    }

    // Necessary to preserve "statelessness" of dutyForWeek().
    // Handles case where new users join/leave holder list during an active slot
    struct HoldersUpdate {
        uint32 timestamp;
        uint32 startOfSlotNumOwners;
    }

    struct BnftHolder {
        address holder;
        uint32 timestamp;
    }

    struct BnftHoldersIndex {
        bool registered;
        uint32 index;
    }

    function initialize(address _eEthAddress, address _stakingManagerAddress, address _nodesManagerAddress, address _membershipManagerAddress, address _tNftAddress) external;

    function numPendingDeposits() external view returns (uint32);
    function totalValueOutOfLp() external view returns (uint128);
    function totalValueInLp() external view returns (uint128);
    function getTotalEtherClaimOf(address _user) external view returns (uint256);
    function getTotalPooledEther() external view returns (uint256);
    function sharesForAmount(uint256 _amount) external view returns (uint256);
    function sharesForWithdrawalAmount(uint256 _amount) external view returns (uint256);
    function amountForShare(uint256 _share) external view returns (uint256);

    function deposit() external payable returns (uint256);
    function deposit(address _referral) external payable returns (uint256);
    function deposit(address _user, address _referral) external payable returns (uint256);
    function withdraw(address _recipient, uint256 _amount) external returns (uint256);
    function requestWithdraw(address recipient, uint256 amount) external returns (uint256);
    function requestWithdrawWithPermit(address _owner, uint256 _amount, PermitInput calldata _permit) external returns (uint256);
    function requestMembershipNFTWithdraw(address recipient, uint256 amount, uint256 fee) external returns (uint256);

    function batchDepositAsBnftHolder(uint256[] calldata _candidateBidIds, uint256 _numberOfValidators) external payable returns (uint256[] memory);
    function batchRegisterAsBnftHolder(bytes32 _depositRoot, uint256[] calldata _validatorIds, IStakingManager.DepositData[] calldata _registerValidatorDepositData, bytes32[] calldata _depositDataRootApproval, bytes[] calldata _signaturesForApprovalDeposit) external;
    function batchApproveRegistration(uint256[] memory _validatorIds, bytes[] calldata _pubKey, bytes[] calldata _signature) external;
    function batchCancelDeposit(uint256[] calldata _validatorIds) external;
    function sendExitRequests(uint256[] calldata _validatorIds) external;

    function rebase(int128 _accruedRewards) external;
    function addEthAmountLockedForWithdrawal(uint128 _amount) external;
    
    function setStakingTargetWeights(uint32 _eEthWeight, uint32 _etherFanWeight) external;
    function updateAdmin(address _newAdmin, bool _isAdmin) external;
    function pauseContract() external;
    function unPauseContract() external;
    
    function decreaseSourceOfFundsValidators(uint32 numberOfEethValidators, uint32 numberOfEtherFanValidators) external;
}


================================================================================
// FILE: src/interfaces/IEtherFiAdmin.sol
================================================================================

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IEtherFiAdmin {
    function lastHandledReportRefSlot() external view returns (uint32);
    function lastHandledReportRefBlock() external view returns (uint32);
    function numValidatorsToSpinUp() external view returns (uint32);
}


================================================================================
// FILE: lib/openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}


================================================================================
// FILE: lib/openzeppelin-contracts-upgradeable/contracts/interfaces/draft-IERC1822Upgradeable.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822ProxiableUpgradeable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}


================================================================================
// FILE: lib/openzeppelin-contracts-upgradeable/contracts/proxy/ERC1967/ERC1967UpgradeUpgradeable.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeaconUpgradeable.sol";
import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/StorageSlotUpgradeable.sol";
import "../utils/Initializable.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967UpgradeUpgradeable is Initializable {
    function __ERC1967Upgrade_init() internal onlyInitializing {
    }

    function __ERC1967Upgrade_init_unchained() internal onlyInitializing {
    }
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(AddressUpgradeable.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822ProxiableUpgradeable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(AddressUpgradeable.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            AddressUpgradeable.isContract(IBeaconUpgradeable(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(IBeaconUpgradeable(newBeacon).implementation(), data);
        }
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


================================================================================
// FILE: lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


================================================================================
// FILE: src/interfaces/IEtherFiNode.sol
================================================================================

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IEtherFiNodesManager.sol";

interface IEtherFiNode {
    // State Transition Diagram for StateMachine contract:
    //
    //      NOT_INITIALIZED
    //              |
    //      READY_FOR_DEPOSIT
    //              ↓
    //      STAKE_DEPOSITED
    //           /      \
    //          /        \
    //         ↓          ↓
    //         LIVE    CANCELLED
    //         |  \ \ 
    //         |   \ \
    //         |   ↓  --> EVICTED
    //         |  BEING_SLASHED
    //         |    /
    //         |   /
    //         ↓  ↓
    //         EXITED
    //           |
    //           ↓
    //      FULLY_WITHDRAWN
    // Transitions are only allowed as directed above.
    // For instance, a transition from STAKE_DEPOSITED to either LIVE or CANCELLED is allowed,
    // but a transition from STAKE_DEPOSITED to NOT_INITIALIZED, BEING_SLASHED, or EXITED is not.
    //
    // All phase transitions should be made through the setPhase function,
    // which validates transitions based on these rules.
    //
    // Fully_WITHDRAWN or CANCELLED nodes can be recycled via resetWithdrawalSafe()
    enum VALIDATOR_PHASE {
        NOT_INITIALIZED,
        STAKE_DEPOSITED,
        LIVE,
        EXITED,
        FULLY_WITHDRAWN,
        CANCELLED,
        BEING_SLASHED,
        EVICTED,
        WAITING_FOR_APPROVAL,
        READY_FOR_DEPOSIT
    }

    // VIEW functions
    function calculateTVL(uint256 _beaconBalance, uint256 _executionBalance, IEtherFiNodesManager.RewardsSplit memory _SRsplits, uint256 _scale) external view returns (uint256, uint256, uint256, uint256);
    function eigenPod() external view returns (address);
    function exitRequestTimestamp() external view returns (uint32);
    function exitTimestamp() external view returns (uint32);
    function getNonExitPenalty(uint32 _tNftExitRequestTimestamp, uint32 _bNftExitRequestTimestamp) external view returns (uint256);
    function getStakingRewardsPayouts(uint256 _beaconBalance, IEtherFiNodesManager.RewardsSplit memory _splits, uint256 _scale) external view returns (uint256, uint256, uint256, uint256);
    function ipfsHashForEncryptedValidatorKey() external view returns (string memory);
    function phase() external view returns (VALIDATOR_PHASE);
    function stakingStartTimestamp() external view returns (uint32);

    // Non-VIEW functions
    function claimQueuedWithdrawals(uint256 maxNumWithdrawals) external;
    function createEigenPod() external;
    function hasOutstandingEigenLayerWithdrawals() external view returns (bool);
    function isRestakingEnabled() external view returns (bool);
    function markExited(uint32 _exitTimestamp) external;
    function markBeingSlashed() external;
    function moveRewardsToManager(uint256 _amount) external;
    function queueRestakedWithdrawal() external;
    function recordStakingStart(bool _enableRestaking) external;
    function resetWithdrawalSafe() external;
    function setExitRequestTimestamp(uint32 _timestamp) external;
    function setIpfsHashForEncryptedValidatorKey(string calldata _ipfs) external;
    function setIsRestakingEnabled(bool _enabled) external;
    function setPhase(VALIDATOR_PHASE _phase) external;
    function splitBalanceInExecutionLayer() external view returns (uint256 _withdrawalSafe, uint256 _eigenPod, uint256 _delayedWithdrawalRouter);
    function totalBalanceInExecutionLayer() external view returns (uint256);
    function withdrawableBalanceInExecutionLayer() external view returns (uint256);

    function withdrawFunds(
        address _treasury,
        uint256 _treasuryAmount,
        address _operator,
        uint256 _operatorAmount,
        address _tnftHolder,
        uint256 _tnftAmount,
        address _bnftHolder,
        uint256 _bnftAmount
    ) external;


}


================================================================================
// FILE: lib/eigenlayer-contracts/src/contracts/interfaces/IEigenPodManager.sol
================================================================================

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import "./IETHPOSDeposit.sol";
import "./IStrategyManager.sol";
import "./IEigenPod.sol";
import "./IBeaconChainOracle.sol";
import "./IPausable.sol";
import "./ISlasher.sol";
import "./IStrategy.sol";

/**
 * @title Interface for factory that creates and manages solo staking pods that have their withdrawal credentials pointed to EigenLayer.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 */

interface IEigenPodManager is IPausable {
    /**
     * Struct type used to specify an existing queued withdrawal. Rather than storing the entire struct, only a hash is stored.
     * In functions that operate on existing queued withdrawals -- e.g. `startQueuedWithdrawalWaitingPeriod` or `completeQueuedWithdrawal`,
     * the data is resubmitted and the hash of the submitted data is computed by `calculateWithdrawalRoot` and checked against the
     * stored hash in order to confirm the integrity of the submitted data.
     */
    struct BeaconChainQueuedWithdrawal {
        // @notice Number of "beacon chain ETH" virtual shares in the withdrawal.
        uint256 shares;
        // @notice Owner of the EigenPod who initiated the withdrawal.
        address podOwner;
        // @notice Nonce of the podOwner when the withdrawal was queued. Used to help ensure uniqueness of the hash of the withdrawal.
        uint96 nonce;
        // @notice Block number at which the withdrawal was initiated.
        uint32 withdrawalStartBlock;
        // @notice The operator to which the podOwner was delegated in EigenLayer when the withdrawal was created.
        address delegatedAddress;
        // @notice The address that can complete the withdrawal and receive the withdrawn funds.
        address withdrawer;
    }

    /**
     * @notice Struct used to track a pod owner's "undelegation limbo" status and associated variables.
     * @dev Undelegation limbo is a mode which a staker can enter into, in which they remove their virtual "beacon chain ETH shares" from EigenLayer's delegation
     * system but do not necessarily withdraw the associated ETH from EigenLayer itself. This mode allows users who have restaked native ETH a route via
     * which they can undelegate from an operator without needing to exit any of their validators from the Consensus Layer.
     */
    struct UndelegationLimboStatus {
        // @notice Whether or not the pod owner is in the "undelegation limbo" mode.
        bool active;
        // @notice The block at which the pod owner entered "undelegation limbo". Should be zero if `podOwnerIsInUndelegationLimbo` is marked as 'false'
        uint32 startBlock;
        // @notice The address which the pod owner was delegated to at the time that they entered "undelegation limbo".
        address delegatedAddress;
    }

    /// @notice Emitted to notify the update of the beaconChainOracle address
    event BeaconOracleUpdated(address indexed newOracleAddress);

    /// @notice Emitted to notify the deployment of an EigenPod
    event PodDeployed(address indexed eigenPod, address indexed podOwner);

    /// @notice Emitted to notify a deposit of beacon chain ETH recorded in the strategy manager
    event BeaconChainETHDeposited(address indexed podOwner, uint256 amount);

    /// @notice Emitted when `maxPods` value is updated from `previousValue` to `newValue`
    event MaxPodsUpdated(uint256 previousValue, uint256 newValue);

    /// @notice Emitted when a withdrawal of beacon chain ETH is queued
    event BeaconChainETHWithdrawalQueued(
        address indexed podOwner,
        uint256 shares,
        uint96 nonce,
        address delegatedAddress,
        address withdrawer,
        bytes32 withdrawalRoot
    );

    /// @notice Emitted when a withdrawal of beacon chain ETH is completed
    event BeaconChainETHWithdrawalCompleted(
        address indexed podOwner,
        uint256 shares,
        uint96 nonce,
        address delegatedAddress,
        address withdrawer,
        bytes32 withdrawalRoot
    );

    // @notice Emitted when `podOwner` enters the "undelegation limbo" mode
    event UndelegationLimboEntered(address indexed podOwner);

    // @notice Emitted when `podOwner` exits the "undelegation limbo" mode
    event UndelegationLimboExited(address indexed podOwner);

    /**
     * @notice Creates an EigenPod for the sender.
     * @dev Function will revert if the `msg.sender` already has an EigenPod.
     */
    function createPod() external;

    /**
     * @notice Stakes for a new beacon chain validator on the sender's EigenPod.
     * Also creates an EigenPod for the sender if they don't have one already.
     * @param pubkey The 48 bytes public key of the beacon chain validator.
     * @param signature The validator's signature of the deposit data.
     * @param depositDataRoot The root/hash of the deposit data for the validator's deposit.
     */
    function stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) external payable;

    /**
     * @notice Deposits/Restakes beacon chain ETH in EigenLayer on behalf of the owner of an EigenPod.
     * @param podOwner The owner of the pod whose balance must be deposited.
     * @param amount The amount of ETH to 'deposit' (i.e. be credited to the podOwner).
     * @dev Callable only by the podOwner's EigenPod contract.
     */
    function restakeBeaconChainETH(address podOwner, uint256 amount) external;

    /**
     * @notice Records an update in beacon chain strategy shares in the strategy manager
     * @param podOwner is the pod owner whose shares are to be updated,
     * @param sharesDelta is the change in podOwner's beaconChainETHStrategy shares
     * @dev Callable only by the podOwner's EigenPod contract.
     */
    function recordBeaconChainETHBalanceUpdate(address podOwner, int256 sharesDelta) external;

    /**
     * @notice Called by a podOwner to queue a withdrawal of some (or all) of their virtual beacon chain ETH shares.
     * @param amountWei The amount of ETH to withdraw.
     * @param withdrawer The address that can complete the withdrawal and receive the withdrawn funds.
     */
    function queueWithdrawal(uint256 amountWei, address withdrawer) external returns (bytes32);

    /**
     * @notice Completes an existing BeaconChainQueuedWithdrawal by sending the ETH to the 'withdrawer'
     * @param queuedWithdrawal is the queued withdrawal to be completed
     * @param middlewareTimesIndex is the index in the operator that the staker who triggered the withdrawal was delegated to's middleware times array
     */
    function completeQueuedWithdrawal(
        BeaconChainQueuedWithdrawal memory queuedWithdrawal,
        uint256 middlewareTimesIndex
    ) external;

    /**
     * @notice forces the podOwner into the "undelegation limbo" mode, and returns the number of virtual 'beacon chain ETH shares'
     * that the podOwner has, which were entered into undelegation limbo.
     * @param podOwner is the staker to be forced into undelegation limbo
     * @param delegatedTo is the operator the staker is currently delegated to
     * @dev This function can only be called by the DelegationManager contract
     */
    function forceIntoUndelegationLimbo(
        address podOwner,
        address delegatedTo
    ) external returns (uint256 sharesRemovedFromDelegation);

    /**
     * @notice Updates the oracle contract that provides the beacon chain state root
     * @param newBeaconChainOracle is the new oracle contract being pointed to
     * @dev Callable only by the owner of this contract (i.e. governance)
     */
    function updateBeaconChainOracle(IBeaconChainOracle newBeaconChainOracle) external;

    /// @notice Returns the address of the `podOwner`'s EigenPod if it has been deployed.
    function ownerToPod(address podOwner) external view returns (IEigenPod);

    /// @notice Returns the address of the `podOwner`'s EigenPod (whether it is deployed yet or not).
    function getPod(address podOwner) external view returns (IEigenPod);

    /// @notice The ETH2 Deposit Contract
    function ethPOS() external view returns (IETHPOSDeposit);

    /// @notice Beacon proxy to which the EigenPods point
    function eigenPodBeacon() external view returns (IBeacon);

    /// @notice Oracle contract that provides updates to the beacon chain's state
    function beaconChainOracle() external view returns (IBeaconChainOracle);

    /// @notice Returns the beacon block root at `timestamp`. Reverts if the Beacon block root at `timestamp` has not yet been finalized.
    function getBlockRootAtTimestamp(uint64 timestamp) external view returns (bytes32);

    /// @notice EigenLayer's StrategyManager contract
    function strategyManager() external view returns (IStrategyManager);

    /// @notice EigenLayer's Slasher contract
    function slasher() external view returns (ISlasher);

    function hasPod(address podOwner) external view returns (bool);

    /// @notice returns shares of provided podOwner
    function podOwnerShares(address podOwner) external returns (uint256);

    /// @notice returns canonical, virtual beaconChainETH strategy
    function beaconChainETHStrategy() external view returns (IStrategy);

    /// @notice Returns the keccak256 hash of `queuedWithdrawal`.
    function calculateWithdrawalRoot(
        BeaconChainQueuedWithdrawal memory queuedWithdrawal
    ) external pure returns (bytes32);

    /**
     * @notice Returns 'false' if `staker` has removed all of their beacon chain ETH "shares" from delegation, either by queuing a
     * withdrawal for them OR by going into "undelegation limbo", and 'true' otherwise
     */
    function podOwnerHasActiveShares(address staker) external view returns (bool);

    // @notice Getter function for the internal `_podOwnerUndelegationLimboStatus` mapping.
    function podOwnerUndelegationLimboStatus(address podOwner) external view returns (UndelegationLimboStatus memory);

    // @notice Getter function for `_podOwnerUndelegationLimboStatus.undelegationLimboActive`.
    function isInUndelegationLimbo(address podOwner) external view returns (bool);
}


================================================================================
// FILE: lib/eigenlayer-contracts/src/contracts/interfaces/IDelayedWithdrawalRouter.sol
================================================================================

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

interface IDelayedWithdrawalRouter {
    // struct used to pack data into a single storage slot
    struct DelayedWithdrawal {
        uint224 amount;
        uint32 blockCreated;
    }

    // struct used to store a single users delayedWithdrawal data
    struct UserDelayedWithdrawals {
        uint256 delayedWithdrawalsCompleted;
        DelayedWithdrawal[] delayedWithdrawals;
    }

     /// @notice event for delayedWithdrawal creation
    event DelayedWithdrawalCreated(address podOwner, address recipient, uint256 amount, uint256 index);

    /// @notice event for the claiming of delayedWithdrawals
    event DelayedWithdrawalsClaimed(address recipient, uint256 amountClaimed, uint256 delayedWithdrawalsCompleted);

    /// @notice Emitted when the `withdrawalDelayBlocks` variable is modified from `previousValue` to `newValue`.
    event WithdrawalDelayBlocksSet(uint256 previousValue, uint256 newValue);

    /**
     * @notice Creates an delayed withdrawal for `msg.value` to the `recipient`.
     * @dev Only callable by the `podOwner`'s EigenPod contract.
     */
    function createDelayedWithdrawal(address podOwner, address recipient) external payable;

    /**
     * @notice Called in order to withdraw delayed withdrawals made to the `recipient` that have passed the `withdrawalDelayBlocks` period.
     * @param recipient The address to claim delayedWithdrawals for.
     * @param maxNumberOfWithdrawalsToClaim Used to limit the maximum number of withdrawals to loop through claiming.
     */
    function claimDelayedWithdrawals(address recipient, uint256 maxNumberOfWithdrawalsToClaim) external;

    /**
     * @notice Called in order to withdraw delayed withdrawals made to the caller that have passed the `withdrawalDelayBlocks` period.
     * @param maxNumberOfWithdrawalsToClaim Used to limit the maximum number of withdrawals to loop through claiming.
     */
    function claimDelayedWithdrawals(uint256 maxNumberOfWithdrawalsToClaim) external;

    /// @notice Owner-only function for modifying the value of the `withdrawalDelayBlocks` variable.
    function setWithdrawalDelayBlocks(uint256 newValue) external;

    /// @notice Getter function for the mapping `_userWithdrawals`
    function userWithdrawals(address user) external view returns (UserDelayedWithdrawals memory);

    /// @notice Getter function to get all delayedWithdrawals of the `user`
    function getUserDelayedWithdrawals(address user) external view returns (DelayedWithdrawal[] memory);

    /// @notice Getter function to get all delayedWithdrawals that are currently claimable by the `user`
    function getClaimableUserDelayedWithdrawals(address user) external view returns (DelayedWithdrawal[] memory);

    /// @notice Getter function for fetching the delayedWithdrawal at the `index`th entry from the `_userWithdrawals[user].delayedWithdrawals` array
    function userDelayedWithdrawalByIndex(address user, uint256 index) external view returns (DelayedWithdrawal memory);

    /// @notice Getter function for fetching the length of the delayedWithdrawals array of a specific user
    function userWithdrawalsLength(address user) external view returns (uint256);

    /// @notice Convenience function for checking whether or not the delayedWithdrawal at the `index`th entry from the `_userWithdrawals[user].delayedWithdrawals` array is currently claimable
    function canClaimDelayedWithdrawal(address user, uint256 index) external view returns (bool);

    /**
     * @notice Delay enforced by this contract for completing any delayedWithdrawal. Measured in blocks, and adjustable by this contract's owner,
     * up to a maximum of `MAX_WITHDRAWAL_DELAY_BLOCKS`. Minimum value is 0 (i.e. no delay enforced).
     */
    function withdrawalDelayBlocks() external view returns (uint256);
}


================================================================================
// FILE: lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/IERC721Upgradeable.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}


================================================================================
// FILE: lib/openzeppelin-contracts-upgradeable/contracts/proxy/beacon/IBeaconUpgradeable.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeaconUpgradeable {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}


================================================================================
// FILE: lib/openzeppelin-contracts-upgradeable/contracts/utils/StorageSlotUpgradeable.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlotUpgradeable {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}


================================================================================
// FILE: lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}


================================================================================
// FILE: lib/eigenlayer-contracts/src/contracts/interfaces/IETHPOSDeposit.sol
================================================================================

// ┏━━━┓━┏┓━┏┓━━┏━━━┓━━┏━━━┓━━━━┏━━━┓━━━━━━━━━━━━━━━━━━━┏┓━━━━━┏━━━┓━━━━━━━━━┏┓━━━━━━━━━━━━━━┏┓━
// ┃┏━━┛┏┛┗┓┃┃━━┃┏━┓┃━━┃┏━┓┃━━━━┗┓┏┓┃━━━━━━━━━━━━━━━━━━┏┛┗┓━━━━┃┏━┓┃━━━━━━━━┏┛┗┓━━━━━━━━━━━━┏┛┗┓
// ┃┗━━┓┗┓┏┛┃┗━┓┗┛┏┛┃━━┃┃━┃┃━━━━━┃┃┃┃┏━━┓┏━━┓┏━━┓┏━━┓┏┓┗┓┏┛━━━━┃┃━┗┛┏━━┓┏━┓━┗┓┏┛┏━┓┏━━┓━┏━━┓┗┓┏┛
// ┃┏━━┛━┃┃━┃┏┓┃┏━┛┏┛━━┃┃━┃┃━━━━━┃┃┃┃┃┏┓┃┃┏┓┃┃┏┓┃┃━━┫┣┫━┃┃━━━━━┃┃━┏┓┃┏┓┃┃┏┓┓━┃┃━┃┏┛┗━┓┃━┃┏━┛━┃┃━
// ┃┗━━┓━┃┗┓┃┃┃┃┃┃┗━┓┏┓┃┗━┛┃━━━━┏┛┗┛┃┃┃━┫┃┗┛┃┃┗┛┃┣━━┃┃┃━┃┗┓━━━━┃┗━┛┃┃┗┛┃┃┃┃┃━┃┗┓┃┃━┃┗┛┗┓┃┗━┓━┃┗┓
// ┗━━━┛━┗━┛┗┛┗┛┗━━━┛┗┛┗━━━┛━━━━┗━━━┛┗━━┛┃┏━┛┗━━┛┗━━┛┗┛━┗━┛━━━━┗━━━┛┗━━┛┗┛┗┛━┗━┛┗┛━┗━━━┛┗━━┛━┗━┛
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┃┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┗┛━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// SPDX-License-Identifier: CC0-1.0

pragma solidity >=0.5.0;

// This interface is designed to be compatible with the Vyper version.
/// @notice This is the Ethereum 2.0 deposit contract interface.
/// For more information see the Phase 0 specification under https://github.com/ethereum/eth2.0-specs
interface IETHPOSDeposit {
    /// @notice A processed deposit event.
    event DepositEvent(bytes pubkey, bytes withdrawal_credentials, bytes amount, bytes signature, bytes index);

    /// @notice Submit a Phase 0 DepositData object.
    /// @param pubkey A BLS12-381 public key.
    /// @param withdrawal_credentials Commitment to a public key for withdrawals.
    /// @param signature A BLS12-381 signature.
    /// @param deposit_data_root The SHA-256 hash of the SSZ-encoded DepositData object.
    /// Used as a protection against malformed input.
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable;

    /// @notice Query the current deposit root hash.
    /// @return The deposit root hash.
    function get_deposit_root() external view returns (bytes32);

    /// @notice Query the current deposit count.
    /// @return The deposit count encoded as a little endian 64-bit number.
    function get_deposit_count() external view returns (bytes memory);
}


================================================================================
// FILE: lib/eigenlayer-contracts/src/contracts/interfaces/IStrategyManager.sol
================================================================================

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "./IStrategy.sol";
import "./ISlasher.sol";
import "./IDelegationManager.sol";
import "./IEigenPodManager.sol";

/**
 * @title Interface for the primary entrypoint for funds into EigenLayer.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice See the `StrategyManager` contract itself for implementation details.
 */
interface IStrategyManager {
    // packed struct for queued withdrawals; helps deal with stack-too-deep errors
    struct WithdrawerAndNonce {
        address withdrawer;
        uint96 nonce;
    }

    /**
     * Struct type used to specify an existing queued withdrawal. Rather than storing the entire struct, only a hash is stored.
     * In functions that operate on existing queued withdrawals -- e.g. `startQueuedWithdrawalWaitingPeriod` or `completeQueuedWithdrawal`,
     * the data is resubmitted and the hash of the submitted data is computed by `calculateWithdrawalRoot` and checked against the
     * stored hash in order to confirm the integrity of the submitted data.
     */
    struct QueuedWithdrawal {
        IStrategy[] strategies;
        uint256[] shares;
        address depositor;
        WithdrawerAndNonce withdrawerAndNonce;
        uint32 withdrawalStartBlock;
        address delegatedAddress;
    }

    /**
     * @notice Emitted when a new deposit occurs on behalf of `depositor`.
     * @param depositor Is the staker who is depositing funds into EigenLayer.
     * @param strategy Is the strategy that `depositor` has deposited into.
     * @param token Is the token that `depositor` deposited.
     * @param shares Is the number of new shares `depositor` has been granted in `strategy`.
     */
    event Deposit(address depositor, IERC20 token, IStrategy strategy, uint256 shares);

    /**
     * @notice Emitted when a new withdrawal occurs on behalf of `depositor`.
     * @param depositor Is the staker who is queuing a withdrawal from EigenLayer.
     * @param nonce Is the withdrawal's unique identifier (to the depositor).
     * @param strategy Is the strategy that `depositor` has queued to withdraw from.
     * @param shares Is the number of shares `depositor` has queued to withdraw.
     */
    event ShareWithdrawalQueued(address depositor, uint96 nonce, IStrategy strategy, uint256 shares);

    /**
     * @notice Emitted when a new withdrawal is queued by `depositor`.
     * @param depositor Is the staker who is withdrawing funds from EigenLayer.
     * @param nonce Is the withdrawal's unique identifier (to the depositor).
     * @param withdrawer Is the party specified by `staker` who will be able to complete the queued withdrawal and receive the withdrawn funds.
     * @param delegatedAddress Is the party who the `staker` was delegated to at the time of creating the queued withdrawal
     * @param withdrawalRoot Is a hash of the input data for the withdrawal.
     */
    event WithdrawalQueued(
        address depositor,
        uint96 nonce,
        address withdrawer,
        address delegatedAddress,
        bytes32 withdrawalRoot
    );

    /// @notice Emitted when a queued withdrawal is completed
    event WithdrawalCompleted(
        address indexed depositor,
        uint96 nonce,
        address indexed withdrawer,
        bytes32 withdrawalRoot
    );

    /// @notice Emitted when the `strategyWhitelister` is changed
    event StrategyWhitelisterChanged(address previousAddress, address newAddress);

    /// @notice Emitted when a strategy is added to the approved list of strategies for deposit
    event StrategyAddedToDepositWhitelist(IStrategy strategy);

    /// @notice Emitted when a strategy is removed from the approved list of strategies for deposit
    event StrategyRemovedFromDepositWhitelist(IStrategy strategy);

    /// @notice Emitted when the `withdrawalDelayBlocks` variable is modified from `previousValue` to `newValue`.
    event WithdrawalDelayBlocksSet(uint256 previousValue, uint256 newValue);

    /**
     * @notice Deposits `amount` of `token` into the specified `strategy`, with the resultant shares credited to `msg.sender`
     * @param strategy is the specified strategy where deposit is to be made,
     * @param token is the denomination in which the deposit is to be made,
     * @param amount is the amount of token to be deposited in the strategy by the depositor
     * @return shares The amount of new shares in the `strategy` created as part of the action.
     * @dev The `msg.sender` must have previously approved this contract to transfer at least `amount` of `token` on their behalf.
     * @dev Cannot be called by an address that is 'frozen' (this function will revert if the `msg.sender` is frozen).
     *
     * WARNING: Depositing tokens that allow reentrancy (eg. ERC-777) into a strategy is not recommended.  This can lead to attack vectors
     *          where the token balance and corresponding strategy shares are not in sync upon reentrancy.
     */
    function depositIntoStrategy(IStrategy strategy, IERC20 token, uint256 amount) external returns (uint256 shares);

    /**
     * @notice Used for depositing an asset into the specified strategy with the resultant shares credited to `staker`,
     * who must sign off on the action.
     * Note that the assets are transferred out/from the `msg.sender`, not from the `staker`; this function is explicitly designed
     * purely to help one address deposit 'for' another.
     * @param strategy is the specified strategy where deposit is to be made,
     * @param token is the denomination in which the deposit is to be made,
     * @param amount is the amount of token to be deposited in the strategy by the depositor
     * @param staker the staker that the deposited assets will be credited to
     * @param expiry the timestamp at which the signature expires
     * @param signature is a valid signature from the `staker`. either an ECDSA signature if the `staker` is an EOA, or data to forward
     * following EIP-1271 if the `staker` is a contract
     * @return shares The amount of new shares in the `strategy` created as part of the action.
     * @dev The `msg.sender` must have previously approved this contract to transfer at least `amount` of `token` on their behalf.
     * @dev A signature is required for this function to eliminate the possibility of griefing attacks, specifically those
     * targeting stakers who may be attempting to undelegate.
     * @dev Cannot be called on behalf of a staker that is 'frozen' (this function will revert if the `staker` is frozen).
     *
     *  WARNING: Depositing tokens that allow reentrancy (eg. ERC-777) into a strategy is not recommended.  This can lead to attack vectors
     *          where the token balance and corresponding strategy shares are not in sync upon reentrancy
     */
    function depositIntoStrategyWithSignature(
        IStrategy strategy,
        IERC20 token,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external returns (uint256 shares);

    /// @notice Returns the current shares of `user` in `strategy`
    function stakerStrategyShares(address user, IStrategy strategy) external view returns (uint256 shares);

    /**
     * @notice Get all details on the depositor's deposits and corresponding shares
     * @return (depositor's strategies, shares in these strategies)
     */
    function getDeposits(address depositor) external view returns (IStrategy[] memory, uint256[] memory);

    /// @notice Simple getter function that returns `stakerStrategyList[staker].length`.
    function stakerStrategyListLength(address staker) external view returns (uint256);

    /**
     * @notice Called by a staker to queue a withdrawal of the given amount of `shares` from each of the respective given `strategies`.
     * @dev Stakers will complete their withdrawal by calling the 'completeQueuedWithdrawal' function.
     * User shares are decreased in this function, but the total number of shares in each strategy remains the same.
     * The total number of shares is decremented in the 'completeQueuedWithdrawal' function instead, which is where
     * the funds are actually sent to the user through use of the strategies' 'withdrawal' function. This ensures
     * that the value per share reported by each strategy will remain consistent, and that the shares will continue
     * to accrue gains during the enforced withdrawal waiting period.
     * @param strategyIndexes is a list of the indices in `stakerStrategyList[msg.sender]` that correspond to the strategies
     * for which `msg.sender` is withdrawing 100% of their shares
     * @param strategies The Strategies to withdraw from
     * @param shares The amount of shares to withdraw from each of the respective Strategies in the `strategies` array
     * @param withdrawer The address that can complete the withdrawal and will receive any withdrawn funds or shares upon completing the withdrawal
     * @return The 'withdrawalRoot' of the newly created Queued Withdrawal
     * @dev Strategies are removed from `stakerStrategyList` by swapping the last entry with the entry to be removed, then
     * popping off the last entry in `stakerStrategyList`. The simplest way to calculate the correct `strategyIndexes` to input
     * is to order the strategies *for which `msg.sender` is withdrawing 100% of their shares* from highest index in
     * `stakerStrategyList` to lowest index
     */
    function queueWithdrawal(
        uint256[] calldata strategyIndexes,
        IStrategy[] calldata strategies,
        uint256[] calldata shares,
        address withdrawer
    ) external returns (bytes32);

    /**
     * @notice Used to complete the specified `queuedWithdrawal`. The function caller must match `queuedWithdrawal.withdrawer`
     * @param queuedWithdrawal The QueuedWithdrawal to complete.
     * @param tokens Array in which the i-th entry specifies the `token` input to the 'withdraw' function of the i-th Strategy in the `strategies` array
     * of the `queuedWithdrawal`. This input can be provided with zero length if `receiveAsTokens` is set to 'false' (since in that case, this input will be unused)
     * @param middlewareTimesIndex is the index in the operator that the staker who triggered the withdrawal was delegated to's middleware times array
     * @param receiveAsTokens If true, the shares specified in the queued withdrawal will be withdrawn from the specified strategies themselves
     * and sent to the caller, through calls to `queuedWithdrawal.strategies[i].withdraw`. If false, then the shares in the specified strategies
     * will simply be transferred to the caller directly.
     * @dev middlewareTimesIndex should be calculated off chain before calling this function by finding the first index that satisfies `slasher.canWithdraw`
     */
    function completeQueuedWithdrawal(
        QueuedWithdrawal calldata queuedWithdrawal,
        IERC20[] calldata tokens,
        uint256 middlewareTimesIndex,
        bool receiveAsTokens
    ) external;

    /**
     * @notice Used to complete the specified `queuedWithdrawals`. The function caller must match `queuedWithdrawals[...].withdrawer`
     * @param queuedWithdrawals The QueuedWithdrawals to complete.
     * @param tokens Array of tokens for each QueuedWithdrawal. See `completeQueuedWithdrawal` for the usage of a single array.
     * @param middlewareTimesIndexes One index to reference per QueuedWithdrawal. See `completeQueuedWithdrawal` for the usage of a single index.
     * @param receiveAsTokens If true, the shares specified in the queued withdrawal will be withdrawn from the specified strategies themselves
     * and sent to the caller, through calls to `queuedWithdrawal.strategies[i].withdraw`. If false, then the shares in the specified strategies
     * will simply be transferred to the caller directly.
     * @dev Array-ified version of `completeQueuedWithdrawal`
     * @dev middlewareTimesIndex should be calculated off chain before calling this function by finding the first index that satisfies `slasher.canWithdraw`
     */
    function completeQueuedWithdrawals(
        QueuedWithdrawal[] calldata queuedWithdrawals,
        IERC20[][] calldata tokens,
        uint256[] calldata middlewareTimesIndexes,
        bool[] calldata receiveAsTokens
    ) external;

    /**
     * @notice Called by the DelegationManager as part of the forced undelegation of the @param staker from their delegated operator.
     * This function queues a withdrawal of all of the `staker`'s shares in EigenLayer to the staker themself, and then undelegates the staker.
     * The staker will consequently be able to complete this withdrawal by calling the `completeQueuedWithdrawal` function.
     * @param staker The staker to force-undelegate.
     * @dev Returns: an array of strategies withdrawn from, the shares withdrawn from each strategy, and the root of the newly queued withdrawal.
     */
    function forceTotalWithdrawal(address staker) external returns (IStrategy[] memory, uint256[] memory, bytes32);

    /**
     * @notice Owner-only function that adds the provided Strategies to the 'whitelist' of strategies that stakers can deposit into
     * @param strategiesToWhitelist Strategies that will be added to the `strategyIsWhitelistedForDeposit` mapping (if they aren't in it already)
     */
    function addStrategiesToDepositWhitelist(IStrategy[] calldata strategiesToWhitelist) external;

    /**
     * @notice Owner-only function that removes the provided Strategies from the 'whitelist' of strategies that stakers can deposit into
     * @param strategiesToRemoveFromWhitelist Strategies that will be removed to the `strategyIsWhitelistedForDeposit` mapping (if they are in it)
     */
    function removeStrategiesFromDepositWhitelist(IStrategy[] calldata strategiesToRemoveFromWhitelist) external;

    /// @notice Returns the keccak256 hash of `queuedWithdrawal`.
    function calculateWithdrawalRoot(QueuedWithdrawal memory queuedWithdrawal) external pure returns (bytes32);

    /// @notice Returns the single, central Delegation contract of EigenLayer
    function delegation() external view returns (IDelegationManager);

    /// @notice Returns the single, central Slasher contract of EigenLayer
    function slasher() external view returns (ISlasher);

    /// @notice Returns the EigenPodManager contract of EigenLayer
    function eigenPodManager() external view returns (IEigenPodManager);

    /// @notice Returns the number of blocks that must pass between the time a withdrawal is queued and the time it can be completed
    function withdrawalDelayBlocks() external view returns (uint256);

    /// @notice Mapping: staker => cumulative number of queued withdrawals they have ever initiated. only increments (doesn't decrement)
    function numWithdrawalsQueued(address staker) external view returns (uint256);
}


================================================================================
// FILE: lib/eigenlayer-contracts/src/contracts/interfaces/IEigenPod.sol
================================================================================

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "../libraries/BeaconChainProofs.sol";
import "./IEigenPodManager.sol";
import "./IBeaconChainOracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title The implementation contract used for restaking beacon chain ETH on EigenLayer
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice The main functionalities are:
 * - creating new ETH validators with their withdrawal credentials pointed to this contract
 * - proving from beacon chain state roots that withdrawal credentials are pointed to this contract
 * - proving from beacon chain state roots the balances of ETH validators with their withdrawal credentials
 *   pointed to this contract
 * - updating aggregate balances in the EigenPodManager
 * - withdrawing eth when withdrawals are initiated
 * @dev Note that all beacon chain balances are stored as gwei within the beacon chain datastructures. We choose
 *   to account balances in terms of gwei in the EigenPod contract and convert to wei when making calls to other contracts
 */
interface IEigenPod {
    enum VALIDATOR_STATUS {
        INACTIVE, // doesnt exist
        ACTIVE, // staked on ethpos and withdrawal credentials are pointed to the EigenPod
        WITHDRAWN // withdrawn from the Beacon Chain
    }

    struct ValidatorInfo {
        // index of the validator in the beacon chain
        uint64 validatorIndex;
        // amount of beacon chain ETH restaked on EigenLayer in gwei
        uint64 restakedBalanceGwei;
        //timestamp of the validator's most recent balance update
        uint64 mostRecentBalanceUpdateTimestamp;
        // status of the validator
        VALIDATOR_STATUS status;
    }

    /**
     * @notice struct used to store amounts related to proven withdrawals in memory. Used to help
     * manage stack depth and optimize the number of external calls, when batching withdrawal operations.
     */
    struct VerifiedWithdrawal {
        // amount to send to a podOwner from a proven withdrawal
        uint256 amountToSend;
        // difference in shares to be recorded in the eigenPodManager, as a result of the withdrawal
        int256 sharesDelta;
    }


    enum PARTIAL_WITHDRAWAL_CLAIM_STATUS {
        REDEEMED,
        PENDING,
        FAILED
    }

    /// @notice Emitted when an ETH validator stakes via this eigenPod
    event EigenPodStaked(bytes pubkey);

    /// @notice Emitted when an ETH validator's withdrawal credentials are successfully verified to be pointed to this eigenPod
    event ValidatorRestaked(uint40 validatorIndex);

    /// @notice Emitted when an ETH validator's  balance is proven to be updated.  Here newValidatorBalanceGwei
    //  is the validator's balance that is credited on EigenLayer.
    event ValidatorBalanceUpdated(uint40 validatorIndex, uint64 balanceTimestamp, uint64 newValidatorBalanceGwei);

    /// @notice Emitted when an ETH validator is prove to have withdrawn from the beacon chain
    event FullWithdrawalRedeemed(
        uint40 validatorIndex,
        uint64 withdrawalTimestamp,
        address indexed recipient,
        uint64 withdrawalAmountGwei
    );

    /// @notice Emitted when a partial withdrawal claim is successfully redeemed
    event PartialWithdrawalRedeemed(
        uint40 validatorIndex,
        uint64 withdrawalTimestamp,
        address indexed recipient,
        uint64 partialWithdrawalAmountGwei
    );

    /// @notice Emitted when restaked beacon chain ETH is withdrawn from the eigenPod.
    event RestakedBeaconChainETHWithdrawn(address indexed recipient, uint256 amount);

    /// @notice Emitted when podOwner enables restaking
    event RestakingActivated(address indexed podOwner);

    /// @notice Emitted when ETH is received via the `receive` fallback
    event NonBeaconChainETHReceived(uint256 amountReceived);

    /// @notice Emitted when ETH that was previously received via the `receive` fallback is withdrawn
    event NonBeaconChainETHWithdrawn(address indexed recipient, uint256 amountWithdrawn);


    /// @notice The max amount of eth, in gwei, that can be restaked per validator
    function MAX_VALIDATOR_BALANCE_GWEI() external view returns (uint64);

    /// @notice the amount of execution layer ETH in this contract that is staked in EigenLayer (i.e. withdrawn from beaconchain but not EigenLayer),
    function withdrawableRestakedExecutionLayerGwei() external view returns (uint64);

    /// @notice Used to initialize the pointers to contracts crucial to the pod's functionality, in beacon proxy construction from EigenPodManager
    function initialize(address owner) external;

    /// @notice Called by EigenPodManager when the owner wants to create another ETH validator.
    function stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) external payable;

    /**
     * @notice Transfers `amountWei` in ether from this contract to the specified `recipient` address
     * @notice Called by EigenPodManager to withdrawBeaconChainETH that has been added to the EigenPod's balance due to a withdrawal from the beacon chain.
     * @dev Called during withdrawal or slashing.
     * @dev Note that this function is marked as non-reentrant to prevent the recipient calling back into it
     */
    function withdrawRestakedBeaconChainETH(address recipient, uint256 amount) external;

    /// @notice The single EigenPodManager for EigenLayer
    function eigenPodManager() external view returns (IEigenPodManager);

    /// @notice The owner of this EigenPod
    function podOwner() external view returns (address);

    /// @notice an indicator of whether or not the podOwner has ever "fully restaked" by successfully calling `verifyCorrectWithdrawalCredentials`.
    function hasRestaked() external view returns (bool);

    /**
     * @notice The latest timestamp at which the pod owner withdrew the balance of the pod, via calling `withdrawBeforeRestaking`.
     * @dev This variable is only updated when the `withdrawBeforeRestaking` function is called, which can only occur before `hasRestaked` is set to true for this pod.
     * Proofs for this pod are only valid against Beacon Chain state roots corresponding to timestamps after the stored `mostRecentWithdrawalTimestamp`.
     */
    function mostRecentWithdrawalTimestamp() external view returns (uint64);

    /// @notice Returns the validatorInfo struct for the provided pubkeyHash
    function validatorPubkeyHashToInfo(bytes32 validatorPubkeyHash) external view returns (ValidatorInfo memory);

    ///@notice mapping that tracks proven withdrawals
    function provenWithdrawal(bytes32 validatorPubkeyHash, uint64 slot) external view returns (bool);

    /// @notice This returns the status of a given validator
    function validatorStatus(bytes32 pubkeyHash) external view returns (VALIDATOR_STATUS);

    /**
     * @notice This function verifies that the withdrawal credentials of validator(s) owned by the podOwner are pointed to
     * this contract. It also verifies the effective balance  of the validator.  It verifies the provided proof of the ETH validator against the beacon chain state
     * root, marks the validator as 'active' in EigenLayer, and credits the restaked ETH in Eigenlayer.
     * @param oracleTimestamp is the Beacon Chain timestamp whose state root the `proof` will be proven against.
     * @param validatorIndices is the list of indices of the validators being proven, refer to consensus specs
     * @param withdrawalCredentialProofs is an array of proofs, where each proof proves each ETH validator's balance and withdrawal credentials
     * against a beacon chain state root
     * @param validatorFields are the fields of the "Validator Container", refer to consensus specs
     * for details: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator
     */
    function verifyWithdrawalCredentials(
        uint64 oracleTimestamp,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        uint40[] calldata validatorIndices,
        bytes[] calldata withdrawalCredentialProofs,
        bytes32[][] calldata validatorFields
    )
        external;

    /**
     * @notice This function records an update (either increase or decrease) in the pod's balance in the StrategyManager.  
               It also verifies a merkle proof of the validator's current beacon chain balance.  
     * @param oracleTimestamp The oracleTimestamp whose state root the `proof` will be proven against.
     *        Must be within `VERIFY_BALANCE_UPDATE_WINDOW_SECONDS` of the current block.
     * @param validatorIndex is the index of the validator being proven, refer to consensus specs 
     * @param balanceUpdateProof is the proof of the validator's balance and validatorFields in the balance tree and the balanceRoot to prove for
     *                                    the StrategyManager in case it must be removed from the list of the podOwner's strategies
     * @param validatorFields are the fields of the "Validator Container", refer to consensus specs
     * @dev For more details on the Beacon Chain spec, see: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator
     */
    function verifyBalanceUpdate(
        uint64 oracleTimestamp,
        uint40 validatorIndex,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        BeaconChainProofs.BalanceUpdateProof calldata balanceUpdateProof,
        bytes32[] calldata validatorFields
    ) external;

    /**
     * @notice This function records full and partial withdrawals on behalf of one of the Ethereum validators for this EigenPod
     * @param oracleTimestamp is the timestamp of the oracle slot that the withdrawal is being proven against
     * @param withdrawalProofs is the information needed to check the veracity of the block numbers and withdrawals being proven
     * @param validatorFieldsProofs is the proof of the validator's fields' in the validator tree
     * @param withdrawalFields are the fields of the withdrawals being proven
     * @param validatorFields are the fields of the validators being proven
     */
    function verifyAndProcessWithdrawals(
        uint64 oracleTimestamp,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        BeaconChainProofs.WithdrawalProof[] calldata withdrawalProofs,
        bytes[] calldata validatorFieldsProofs,
        bytes32[][] calldata validatorFields,
        bytes32[][] calldata withdrawalFields
    ) external;

    /**
     * @notice Called by the pod owner to activate restaking by withdrawing
     * all existing ETH from the pod and preventing further withdrawals via
     * "withdrawBeforeRestaking()"
     */
    function activateRestaking() external;

    /// @notice Called by the pod owner to withdraw the balance of the pod when `hasRestaked` is set to false
    function withdrawBeforeRestaking() external;

    /// @notice called by the eigenPodManager to decrement the withdrawableRestakedExecutionLayerGwei
    /// in the pod, to reflect a queued withdrawal from the beacon chain strategy
    function decrementWithdrawableRestakedExecutionLayerGwei(uint256 amountWei) external;

    /// @notice called by the eigenPodManager to increment the withdrawableRestakedExecutionLayerGwei
    /// in the pod, to reflect a completion of a queued withdrawal as shares
    function incrementWithdrawableRestakedExecutionLayerGwei(uint256 amountWei) external;

    /// @notice Called by the pod owner to withdraw the nonBeaconChainETHBalanceWei
    function withdrawNonBeaconChainETHBalanceWei(address recipient, uint256 amountToWithdraw) external;

    /// @notice called by owner of a pod to remove any ERC20s deposited in the pod
    function recoverTokens(IERC20[] memory tokenList, uint256[] memory amountsToWithdraw, address recipient) external;
}


================================================================================
// FILE: lib/eigenlayer-contracts/src/contracts/interfaces/IBeaconChainOracle.sol
================================================================================

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

/**
 * @title Interface for the BeaconStateOracle contract.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 */
interface IBeaconChainOracle {
    /// @notice The block number to state root mapping.
    function timestampToBlockRoot(uint256 timestamp) external view returns (bytes32);
}


================================================================================
// FILE: lib/eigenlayer-contracts/src/contracts/interfaces/IPausable.sol
================================================================================

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "../interfaces/IPauserRegistry.sol";

/**
 * @title Adds pausability to a contract, with pausing & unpausing controlled by the `pauser` and `unpauser` of a PauserRegistry contract.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice Contracts that inherit from this contract may define their own `pause` and `unpause` (and/or related) functions.
 * These functions should be permissioned as "onlyPauser" which defers to a `PauserRegistry` for determining access control.
 * @dev Pausability is implemented using a uint256, which allows up to 256 different single bit-flags; each bit can potentially pause different functionality.
 * Inspiration for this was taken from the NearBridge design here https://etherscan.io/address/0x3FEFc5A4B1c02f21cBc8D3613643ba0635b9a873#code.
 * For the `pause` and `unpause` functions we've implemented, if you pause, you can only flip (any number of) switches to on/1 (aka "paused"), and if you unpause,
 * you can only flip (any number of) switches to off/0 (aka "paused").
 * If you want a pauseXYZ function that just flips a single bit / "pausing flag", it will:
 * 1) 'bit-wise and' (aka `&`) a flag with the current paused state (as a uint256)
 * 2) update the paused state to this new value
 * @dev We note as well that we have chosen to identify flags by their *bit index* as opposed to their numerical value, so, e.g. defining `DEPOSITS_PAUSED = 3`
 * indicates specifically that if the *third bit* of `_paused` is flipped -- i.e. it is a '1' -- then deposits should be paused
 */

interface IPausable {
    /// @notice Emitted when the `pauserRegistry` is set to `newPauserRegistry`.
    event PauserRegistrySet(IPauserRegistry pauserRegistry, IPauserRegistry newPauserRegistry);

    /// @notice Emitted when the pause is triggered by `account`, and changed to `newPausedStatus`.
    event Paused(address indexed account, uint256 newPausedStatus);

    /// @notice Emitted when the pause is lifted by `account`, and changed to `newPausedStatus`.
    event Unpaused(address indexed account, uint256 newPausedStatus);
    
    /// @notice Address of the `PauserRegistry` contract that this contract defers to for determining access control (for pausing).
    function pauserRegistry() external view returns (IPauserRegistry);

    /**
     * @notice This function is used to pause an EigenLayer contract's functionality.
     * It is permissioned to the `pauser` address, which is expected to be a low threshold multisig.
     * @param newPausedStatus represents the new value for `_paused` to take, which means it may flip several bits at once.
     * @dev This function can only pause functionality, and thus cannot 'unflip' any bit in `_paused` from 1 to 0.
     */
    function pause(uint256 newPausedStatus) external;

    /**
     * @notice Alias for `pause(type(uint256).max)`.
     */
    function pauseAll() external;

    /**
     * @notice This function is used to unpause an EigenLayer contract's functionality.
     * It is permissioned to the `unpauser` address, which is expected to be a high threshold multisig or governance contract.
     * @param newPausedStatus represents the new value for `_paused` to take, which means it may flip several bits at once.
     * @dev This function can only unpause functionality, and thus cannot 'flip' any bit in `_paused` from 0 to 1.
     */
    function unpause(uint256 newPausedStatus) external;

    /// @notice Returns the current paused status as a uint256.
    function paused() external view returns (uint256);

    /// @notice Returns 'true' if the `indexed`th bit of `_paused` is 1, and 'false' otherwise
    function paused(uint8 index) external view returns (bool);

    /// @notice Allows the unpauser to set a new pauser registry
    function setPauserRegistry(IPauserRegistry newPauserRegistry) external;
}


================================================================================
// FILE: lib/eigenlayer-contracts/src/contracts/interfaces/ISlasher.sol
================================================================================

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "./IStrategyManager.sol";
import "./IDelegationManager.sol";

/**
 * @title Interface for the primary 'slashing' contract for EigenLayer.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice See the `Slasher` contract itself for implementation details.
 */
interface ISlasher {
    // struct used to store information about the current state of an operator's obligations to middlewares they are serving
    struct MiddlewareTimes {
        // The update block for the middleware whose most recent update was earliest, i.e. the 'stalest' update out of all middlewares the operator is serving
        uint32 stalestUpdateBlock;
        // The latest 'serveUntilBlock' from all of the middleware that the operator is serving
        uint32 latestServeUntilBlock;
    }

    // struct used to store details relevant to a single middleware that an operator has opted-in to serving
    struct MiddlewareDetails {
        // the block at which the contract begins being able to finalize the operator's registration with the service via calling `recordFirstStakeUpdate`
        uint32 registrationMayBeginAtBlock;
        // the block before which the contract is allowed to slash the user
        uint32 contractCanSlashOperatorUntilBlock;
        // the block at which the middleware's view of the operator's stake was most recently updated
        uint32 latestUpdateBlock;
    }

    /// @notice Emitted when a middleware times is added to `operator`'s array.
    event MiddlewareTimesAdded(
        address operator,
        uint256 index,
        uint32 stalestUpdateBlock,
        uint32 latestServeUntilBlock
    );

    /// @notice Emitted when `operator` begins to allow `contractAddress` to slash them.
    event OptedIntoSlashing(address indexed operator, address indexed contractAddress);

    /// @notice Emitted when `contractAddress` signals that it will no longer be able to slash `operator` after the `contractCanSlashOperatorUntilBlock`.
    event SlashingAbilityRevoked(
        address indexed operator,
        address indexed contractAddress,
        uint32 contractCanSlashOperatorUntilBlock
    );

    /**
     * @notice Emitted when `slashingContract` 'freezes' the `slashedOperator`.
     * @dev The `slashingContract` must have permission to slash the `slashedOperator`, i.e. `canSlash(slasherOperator, slashingContract)` must return 'true'.
     */
    event OperatorFrozen(address indexed slashedOperator, address indexed slashingContract);

    /// @notice Emitted when `previouslySlashedAddress` is 'unfrozen', allowing them to again move deposited funds within EigenLayer.
    event FrozenStatusReset(address indexed previouslySlashedAddress);

    /**
     * @notice Gives the `contractAddress` permission to slash the funds of the caller.
     * @dev Typically, this function must be called prior to registering for a middleware.
     */
    function optIntoSlashing(address contractAddress) external;

    /**
     * @notice Used for 'slashing' a certain operator.
     * @param toBeFrozen The operator to be frozen.
     * @dev Technically the operator is 'frozen' (hence the name of this function), and then subject to slashing pending a decision by a human-in-the-loop.
     * @dev The operator must have previously given the caller (which should be a contract) the ability to slash them, through a call to `optIntoSlashing`.
     */
    function freezeOperator(address toBeFrozen) external;

    /**
     * @notice Removes the 'frozen' status from each of the `frozenAddresses`
     * @dev Callable only by the contract owner (i.e. governance).
     */
    function resetFrozenStatus(address[] calldata frozenAddresses) external;

    /**
     * @notice this function is a called by middlewares during an operator's registration to make sure the operator's stake at registration
     *         is slashable until serveUntil
     * @param operator the operator whose stake update is being recorded
     * @param serveUntilBlock the block until which the operator's stake at the current block is slashable
     * @dev adds the middleware's slashing contract to the operator's linked list
     */
    function recordFirstStakeUpdate(address operator, uint32 serveUntilBlock) external;

    /**
     * @notice this function is a called by middlewares during a stake update for an operator (perhaps to free pending withdrawals)
     *         to make sure the operator's stake at updateBlock is slashable until serveUntil
     * @param operator the operator whose stake update is being recorded
     * @param updateBlock the block for which the stake update is being recorded
     * @param serveUntilBlock the block until which the operator's stake at updateBlock is slashable
     * @param insertAfter the element of the operators linked list that the currently updating middleware should be inserted after
     * @dev insertAfter should be calculated offchain before making the transaction that calls this. this is subject to race conditions,
     *      but it is anticipated to be rare and not detrimental.
     */
    function recordStakeUpdate(
        address operator,
        uint32 updateBlock,
        uint32 serveUntilBlock,
        uint256 insertAfter
    ) external;

    /**
     * @notice this function is a called by middlewares during an operator's deregistration to make sure the operator's stake at deregistration
     *         is slashable until serveUntil
     * @param operator the operator whose stake update is being recorded
     * @param serveUntilBlock the block until which the operator's stake at the current block is slashable
     * @dev removes the middleware's slashing contract to the operator's linked list and revokes the middleware's (i.e. caller's) ability to
     * slash `operator` once `serveUntil` is reached
     */
    function recordLastStakeUpdateAndRevokeSlashingAbility(address operator, uint32 serveUntilBlock) external;

    /// @notice The StrategyManager contract of EigenLayer
    function strategyManager() external view returns (IStrategyManager);

    /// @notice The DelegationManager contract of EigenLayer
    function delegation() external view returns (IDelegationManager);

    /**
     * @notice Used to determine whether `staker` is actively 'frozen'. If a staker is frozen, then they are potentially subject to
     * slashing of their funds, and cannot cannot deposit or withdraw from the strategyManager until the slashing process is completed
     * and the staker's status is reset (to 'unfrozen').
     * @param staker The staker of interest.
     * @return Returns 'true' if `staker` themselves has their status set to frozen, OR if the staker is delegated
     * to an operator who has their status set to frozen. Otherwise returns 'false'.
     */
    function isFrozen(address staker) external view returns (bool);

    /// @notice Returns true if `slashingContract` is currently allowed to slash `toBeSlashed`.
    function canSlash(address toBeSlashed, address slashingContract) external view returns (bool);

    /// @notice Returns the block until which `serviceContract` is allowed to slash the `operator`.
    function contractCanSlashOperatorUntilBlock(
        address operator,
        address serviceContract
    ) external view returns (uint32);

    /// @notice Returns the block at which the `serviceContract` last updated its view of the `operator`'s stake
    function latestUpdateBlock(address operator, address serviceContract) external view returns (uint32);

    /// @notice A search routine for finding the correct input value of `insertAfter` to `recordStakeUpdate` / `_updateMiddlewareList`.
    function getCorrectValueForInsertAfter(address operator, uint32 updateBlock) external view returns (uint256);

    /**
     * @notice Returns 'true' if `operator` can currently complete a withdrawal started at the `withdrawalStartBlock`, with `middlewareTimesIndex` used
     * to specify the index of a `MiddlewareTimes` struct in the operator's list (i.e. an index in `operatorToMiddlewareTimes[operator]`). The specified
     * struct is consulted as proof of the `operator`'s ability (or lack thereof) to complete the withdrawal.
     * This function will return 'false' if the operator cannot currently complete a withdrawal started at the `withdrawalStartBlock`, *or* in the event
     * that an incorrect `middlewareTimesIndex` is supplied, even if one or more correct inputs exist.
     * @param operator Either the operator who queued the withdrawal themselves, or if the withdrawing party is a staker who delegated to an operator,
     * this address is the operator *who the staker was delegated to* at the time of the `withdrawalStartBlock`.
     * @param withdrawalStartBlock The block number at which the withdrawal was initiated.
     * @param middlewareTimesIndex Indicates an index in `operatorToMiddlewareTimes[operator]` to consult as proof of the `operator`'s ability to withdraw
     * @dev The correct `middlewareTimesIndex` input should be computable off-chain.
     */
    function canWithdraw(
        address operator,
        uint32 withdrawalStartBlock,
        uint256 middlewareTimesIndex
    ) external returns (bool);

    /**
     * operator =>
     *  [
     *      (
     *          the least recent update block of all of the middlewares it's serving/served,
     *          latest time that the stake bonded at that update needed to serve until
     *      )
     *  ]
     */
    function operatorToMiddlewareTimes(
        address operator,
        uint256 arrayIndex
    ) external view returns (MiddlewareTimes memory);

    /// @notice Getter function for fetching `operatorToMiddlewareTimes[operator].length`
    function middlewareTimesLength(address operator) external view returns (uint256);

    /// @notice Getter function for fetching `operatorToMiddlewareTimes[operator][index].stalestUpdateBlock`.
    function getMiddlewareTimesIndexStalestUpdateBlock(address operator, uint32 index) external view returns (uint32);

    /// @notice Getter function for fetching `operatorToMiddlewareTimes[operator][index].latestServeUntil`.
    function getMiddlewareTimesIndexServeUntilBlock(address operator, uint32 index) external view returns (uint32);

    /// @notice Getter function for fetching `_operatorToWhitelistedContractsByUpdate[operator].size`.
    function operatorWhitelistedContractsLinkedListSize(address operator) external view returns (uint256);

    /// @notice Getter function for fetching a single node in the operator's linked list (`_operatorToWhitelistedContractsByUpdate[operator]`).
    function operatorWhitelistedContractsLinkedListEntry(
        address operator,
        address node
    ) external view returns (bool, uint256, uint256);
}


================================================================================
// FILE: lib/eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol
================================================================================

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Minimal interface for an `Strategy` contract.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice Custom `Strategy` implementations may expand extensively on this interface.
 */
interface IStrategy {
    /**
     * @notice Used to deposit tokens into this Strategy
     * @param token is the ERC20 token being deposited
     * @param amount is the amount of token being deposited
     * @dev This function is only callable by the strategyManager contract. It is invoked inside of the strategyManager's
     * `depositIntoStrategy` function, and individual share balances are recorded in the strategyManager as well.
     * @return newShares is the number of new shares issued at the current exchange ratio.
     */
    function deposit(IERC20 token, uint256 amount) external returns (uint256);

    /**
     * @notice Used to withdraw tokens from this Strategy, to the `depositor`'s address
     * @param depositor is the address to receive the withdrawn funds
     * @param token is the ERC20 token being transferred out
     * @param amountShares is the amount of shares being withdrawn
     * @dev This function is only callable by the strategyManager contract. It is invoked inside of the strategyManager's
     * other functions, and individual share balances are recorded in the strategyManager as well.
     */
    function withdraw(address depositor, IERC20 token, uint256 amountShares) external;

    /**
     * @notice Used to convert a number of shares to the equivalent amount of underlying tokens for this strategy.
     * @notice In contrast to `sharesToUnderlyingView`, this function **may** make state modifications
     * @param amountShares is the amount of shares to calculate its conversion into the underlying token
     * @return The amount of underlying tokens corresponding to the input `amountShares`
     * @dev Implementation for these functions in particular may vary significantly for different strategies
     */
    function sharesToUnderlying(uint256 amountShares) external returns (uint256);

    /**
     * @notice Used to convert an amount of underlying tokens to the equivalent amount of shares in this strategy.
     * @notice In contrast to `underlyingToSharesView`, this function **may** make state modifications
     * @param amountUnderlying is the amount of `underlyingToken` to calculate its conversion into strategy shares
     * @return The amount of underlying tokens corresponding to the input `amountShares`
     * @dev Implementation for these functions in particular may vary significantly for different strategies
     */
    function underlyingToShares(uint256 amountUnderlying) external returns (uint256);

    /**
     * @notice convenience function for fetching the current underlying value of all of the `user`'s shares in
     * this strategy. In contrast to `userUnderlyingView`, this function **may** make state modifications
     */
    function userUnderlying(address user) external returns (uint256);

    /**
     * @notice convenience function for fetching the current total shares of `user` in this strategy, by
     * querying the `strategyManager` contract
     */
    function shares(address user) external view returns (uint256);

    /**
     * @notice Used to convert a number of shares to the equivalent amount of underlying tokens for this strategy.
     * @notice In contrast to `sharesToUnderlying`, this function guarantees no state modifications
     * @param amountShares is the amount of shares to calculate its conversion into the underlying token
     * @return The amount of shares corresponding to the input `amountUnderlying`
     * @dev Implementation for these functions in particular may vary significantly for different strategies
     */
    function sharesToUnderlyingView(uint256 amountShares) external view returns (uint256);

    /**
     * @notice Used to convert an amount of underlying tokens to the equivalent amount of shares in this strategy.
     * @notice In contrast to `underlyingToShares`, this function guarantees no state modifications
     * @param amountUnderlying is the amount of `underlyingToken` to calculate its conversion into strategy shares
     * @return The amount of shares corresponding to the input `amountUnderlying`
     * @dev Implementation for these functions in particular may vary significantly for different strategies
     */
    function underlyingToSharesView(uint256 amountUnderlying) external view returns (uint256);

    /**
     * @notice convenience function for fetching the current underlying value of all of the `user`'s shares in
     * this strategy. In contrast to `userUnderlying`, this function guarantees no state modifications
     */
    function userUnderlyingView(address user) external view returns (uint256);

    /// @notice The underlying token for shares in this Strategy
    function underlyingToken() external view returns (IERC20);

    /// @notice The total number of extant shares in this Strategy
    function totalShares() external view returns (uint256);

    /// @notice Returns either a brief string explaining the strategy's goal & purpose, or a link to metadata that explains in more detail.
    function explanation() external view returns (string memory);
}


================================================================================
// FILE: lib/openzeppelin-contracts-upgradeable/contracts/utils/introspection/IERC165Upgradeable.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


================================================================================
// FILE: lib/eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol
================================================================================

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "./IStrategy.sol";

/**
 * @title DelegationManager
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 * @notice  This is the contract for delegation in EigenLayer. The main functionalities of this contract are
 * - enabling anyone to register as an operator in EigenLayer
 * - allowing operators to specify parameters related to stakers who delegate to them
 * - enabling any staker to delegate its stake to the operator of its choice (a given staker can only delegate to a single operator at a time)
 * - enabling a staker to undelegate its assets from the operator it is delegated to (performed as part of the withdrawal process, initiated through the StrategyManager)
 */
interface IDelegationManager {
    // @notice Struct used for storing information about a single operator who has registered with EigenLayer
    struct OperatorDetails {
        // @notice address to receive the rewards that the operator earns via serving applications built on EigenLayer.
        address earningsReceiver;
        /**
         * @notice Address to verify signatures when a staker wishes to delegate to the operator, as well as controlling "forced undelegations".
         * @dev Signature verification follows these rules:
         * 1) If this address is left as address(0), then any staker will be free to delegate to the operator, i.e. no signature verification will be performed.
         * 2) If this address is an EOA (i.e. it has no code), then we follow standard ECDSA signature verification for delegations to the operator.
         * 3) If this address is a contract (i.e. it has code) then we forward a call to the contract and verify that it returns the correct EIP-1271 "magic value".
         */
        address delegationApprover;
        /**
         * @notice A minimum delay -- measured in blocks -- enforced between:
         * 1) the operator signalling their intent to register for a service, via calling `Slasher.optIntoSlashing`
         * and
         * 2) the operator completing registration for the service, via the service ultimately calling `Slasher.recordFirstStakeUpdate`
         * @dev note that for a specific operator, this value *cannot decrease*, i.e. if the operator wishes to modify their OperatorDetails,
         * then they are only allowed to either increase this value or keep it the same.
         */
        uint32 stakerOptOutWindowBlocks;
    }

    /**
     * @notice Abstract struct used in calculating an EIP712 signature for a staker to approve that they (the staker themselves) delegate to a specific operator.
     * @dev Used in computing the `STAKER_DELEGATION_TYPEHASH` and as a reference in the computation of the stakerDigestHash in the `delegateToBySignature` function.
     */
    struct StakerDelegation {
        // the staker who is delegating
        address staker;
        // the operator being delegated to
        address operator;
        // the staker's nonce
        uint256 nonce;
        // the expiration timestamp (UTC) of the signature
        uint256 expiry;
    }

    /**
     * @notice Abstract struct used in calculating an EIP712 signature for an operator's delegationApprover to approve that a specific staker delegate to the operator.
     * @dev Used in computing the `DELEGATION_APPROVAL_TYPEHASH` and as a reference in the computation of the approverDigestHash in the `_delegate` function.
     */
    struct DelegationApproval {
        // the staker who is delegating
        address staker;
        // the operator being delegated to
        address operator;
        // the operator's provided salt
        bytes32 salt;
        // the expiration timestamp (UTC) of the signature
        uint256 expiry;
    }

    // @notice Struct that bundles together a signature and an expiration time for the signature. Used primarily for stack management.
    struct SignatureWithExpiry {
        // the signature itself, formatted as a single bytes object
        bytes signature;
        // the expiration timestamp (UTC) of the signature
        uint256 expiry;
    }

    // @notice Emitted when a new operator registers in EigenLayer and provides their OperatorDetails.
    event OperatorRegistered(address indexed operator, OperatorDetails operatorDetails);

    // @notice Emitted when an operator updates their OperatorDetails to @param newOperatorDetails
    event OperatorDetailsModified(address indexed operator, OperatorDetails newOperatorDetails);

    /**
     * @notice Emitted when @param operator indicates that they are updating their MetadataURI string
     * @dev Note that these strings are *never stored in storage* and are instead purely emitted in events for off-chain indexing
     */
    event OperatorMetadataURIUpdated(address indexed operator, string metadataURI);

    /// @notice Emitted whenever an operator's shares are increased for a given strategy. Note that shares is the delta in the operator's shares.
    event OperatorSharesIncreased(address indexed operator, address staker, IStrategy strategy, uint256 shares);

    /// @notice Emitted whenever an operator's shares are decreased for a given strategy. Note that shares is the delta in the operator's shares.
    event OperatorSharesDecreased(address indexed operator, address staker, IStrategy strategy, uint256 shares);

    /// @notice Emitted when @param staker delegates to @param operator.
    event StakerDelegated(address indexed staker, address indexed operator);

    /// @notice Emitted when @param staker undelegates from @param operator.
    event StakerUndelegated(address indexed staker, address indexed operator);

    // @notice Emitted when @param staker is undelegated via a call not originating from the staker themself
    event StakerForceUndelegated(address indexed staker, address indexed operator);

    /**
     * @notice Registers the caller as an operator in EigenLayer.
     * @param registeringOperatorDetails is the `OperatorDetails` for the operator.
     * @param metadataURI is a URI for the operator's metadata, i.e. a link providing more details on the operator.
     *
     * @dev Once an operator is registered, they cannot 'deregister' as an operator, and they will forever be considered "delegated to themself".
     * @dev This function will revert if the caller attempts to set their `earningsReceiver` to address(0).
     * @dev Note that the `metadataURI` is *never stored * and is only emitted in the `OperatorMetadataURIUpdated` event
     */
    function registerAsOperator(
        OperatorDetails calldata registeringOperatorDetails,
        string calldata metadataURI
    ) external;

    /**
     * @notice Updates an operator's stored `OperatorDetails`.
     * @param newOperatorDetails is the updated `OperatorDetails` for the operator, to replace their current OperatorDetails`.
     *
     * @dev The caller must have previously registered as an operator in EigenLayer.
     * @dev This function will revert if the caller attempts to set their `earningsReceiver` to address(0).
     */
    function modifyOperatorDetails(OperatorDetails calldata newOperatorDetails) external;

    /**
     * @notice Called by an operator to emit an `OperatorMetadataURIUpdated` event indicating the information has updated.
     * @param metadataURI The URI for metadata associated with an operator
     */
    function updateOperatorMetadataURI(string calldata metadataURI) external;

    /**
     * @notice Caller delegates their stake to an operator.
     * @param operator The account (`msg.sender`) is delegating its assets to for use in serving applications built on EigenLayer.
     * @param approverSignatureAndExpiry Verifies the operator approves of this delegation
     * @param approverSalt A unique single use value tied to an individual signature.
     * @dev The approverSignatureAndExpiry is used in the event that:
     *          1) the operator's `delegationApprover` address is set to a non-zero value.
     *                  AND
     *          2) neither the operator nor their `delegationApprover` is the `msg.sender`, since in the event that the operator
     *             or their delegationApprover is the `msg.sender`, then approval is assumed.
     * @dev In the event that `approverSignatureAndExpiry` is not checked, its content is ignored entirely; it's recommended to use an empty input
     * in this case to save on complexity + gas costs
     */
    function delegateTo(
        address operator,
        SignatureWithExpiry memory approverSignatureAndExpiry,
        bytes32 approverSalt
    ) external;

    /**
     * @notice Caller delegates a staker's stake to an operator with valid signatures from both parties.
     * @param staker The account delegating stake to an `operator` account
     * @param operator The account (`staker`) is delegating its assets to for use in serving applications built on EigenLayer.
     * @param stakerSignatureAndExpiry Signed data from the staker authorizing delegating stake to an operator
     * @param approverSignatureAndExpiry is a parameter that will be used for verifying that the operator approves of this delegation action in the event that:
     * @param approverSalt Is a salt used to help guarantee signature uniqueness. Each salt can only be used once by a given approver.
     *
     * @dev If `staker` is an EOA, then `stakerSignature` is verified to be a valid ECDSA stakerSignature from `staker`, indicating their intention for this action.
     * @dev If `staker` is a contract, then `stakerSignature` will be checked according to EIP-1271.
     * @dev the operator's `delegationApprover` address is set to a non-zero value.
     * @dev neither the operator nor their `delegationApprover` is the `msg.sender`, since in the event that the operator or their delegationApprover
     * is the `msg.sender`, then approval is assumed.
     * @dev This function will revert if the current `block.timestamp` is equal to or exceeds the expiry
     * @dev In the case that `approverSignatureAndExpiry` is not checked, its content is ignored entirely; it's recommended to use an empty input
     * in this case to save on complexity + gas costs
     */
    function delegateToBySignature(
        address staker,
        address operator,
        SignatureWithExpiry memory stakerSignatureAndExpiry,
        SignatureWithExpiry memory approverSignatureAndExpiry,
        bytes32 approverSalt
    ) external;

    /**
     * @notice Undelegates the staker from the operator who they are delegated to. Puts the staker into the "undelegation limbo" mode of the EigenPodManager
     * and queues a withdrawal of all of the staker's shares in the StrategyManager (to the staker), if necessary.
     * @param staker The account to be undelegated.
     * @return withdrawalRoot The root of the newly queued withdrawal, if a withdrawal was queued. Otherwise just bytes32(0).
     *
     * @dev Reverts if the `staker` is also an operator, since operators are not allowed to undelegate from themselves.
     * @dev Reverts if the caller is not the staker, nor the operator who the staker is delegated to, nor the operator's specified "delegationApprover"
     * @dev Reverts if the `staker` is already undelegated.
     */
    function undelegate(address staker) external returns (bytes32 withdrawalRoot);

    /**
     * @notice Increases a staker's delegated share balance in a strategy.
     * @param staker The address to increase the delegated shares for their operator.
     * @param strategy The strategy in which to increase the delegated shares.
     * @param shares The number of shares to increase.
     *
     * @dev *If the staker is actively delegated*, then increases the `staker`'s delegated shares in `strategy` by `shares`. Otherwise does nothing.
     * @dev Callable only by the StrategyManager.
     */
    function increaseDelegatedShares(address staker, IStrategy strategy, uint256 shares) external;

    /**
     * @notice Decreases a staker's delegated share balance in a strategy.
     * @param staker The address to decrease the delegated shares for their operator.
     * @param strategies An array of strategies to crease the delegated shares.
     * @param shares An array of the number of shares to decrease for a operator and strategy.
     *
     * @dev *If the staker is actively delegated*, then decreases the `staker`'s delegated shares in each entry of `strategies` by its respective `shares[i]`. Otherwise does nothing.
     * @dev Callable only by the StrategyManager or EigenPodManager.
     */
    function decreaseDelegatedShares(
        address staker,
        IStrategy[] calldata strategies,
        uint256[] calldata shares
    ) external;

    /**
     * @notice returns the address of the operator that `staker` is delegated to.
     * @notice Mapping: staker => operator whom the staker is currently delegated to.
     * @dev Note that returning address(0) indicates that the staker is not actively delegated to any operator.
     */
    function delegatedTo(address staker) external view returns (address);

    /**
     * @notice Returns the OperatorDetails struct associated with an `operator`.
     */
    function operatorDetails(address operator) external view returns (OperatorDetails memory);

    /*
     * @notice Returns the earnings receiver address for an operator
     */
    function earningsReceiver(address operator) external view returns (address);

    /**
     * @notice Returns the delegationApprover account for an operator
     */
    function delegationApprover(address operator) external view returns (address);

    /**
     * @notice Returns the stakerOptOutWindowBlocks for an operator
     */
    function stakerOptOutWindowBlocks(address operator) external view returns (uint256);

    /**
     * @notice returns the total number of shares in `strategy` that are delegated to `operator`.
     * @notice Mapping: operator => strategy => total number of shares in the strategy delegated to the operator.
     */
    function operatorShares(address operator, IStrategy strategy) external view returns (uint256);

    /**
     * @notice Returns 'true' if `staker` *is* actively delegated, and 'false' otherwise.
     */
    function isDelegated(address staker) external view returns (bool);

    /**
     * @notice Returns true is an operator has previously registered for delegation.
     */
    function isOperator(address operator) external view returns (bool);

    /// @notice Mapping: staker => number of signed delegation nonces (used in `delegateToBySignature`) from the staker that the contract has already checked
    function stakerNonce(address staker) external view returns (uint256);

    /**
     * @notice Mapping: delegationApprover => 32-byte salt => whether or not the salt has already been used by the delegationApprover.
     * @dev Salts are used in the `delegateTo` and `delegateToBySignature` functions. Note that these functions only process the delegationApprover's
     * signature + the provided salt if the operator being delegated to has specified a nonzero address as their `delegationApprover`.
     */
    function delegationApproverSaltIsSpent(address _delegationApprover, bytes32 salt) external view returns (bool);

    /**
     * @notice Calculates the digestHash for a `staker` to sign to delegate to an `operator`
     * @param staker The signing staker
     * @param operator The operator who is being delegated to
     * @param expiry The desired expiry time of the staker's signature
     */
    function calculateCurrentStakerDelegationDigestHash(
        address staker,
        address operator,
        uint256 expiry
    ) external view returns (bytes32);

    /**
     * @notice Calculates the digest hash to be signed and used in the `delegateToBySignature` function
     * @param staker The signing staker
     * @param _stakerNonce The nonce of the staker. In practice we use the staker's current nonce, stored at `stakerNonce[staker]`
     * @param operator The operator who is being delegated to
     * @param expiry The desired expiry time of the staker's signature
     */
    function calculateStakerDelegationDigestHash(
        address staker,
        uint256 _stakerNonce,
        address operator,
        uint256 expiry
    ) external view returns (bytes32);

    /**
     * @notice Calculates the digest hash to be signed by the operator's delegationApprove and used in the `delegateTo` and `delegateToBySignature` functions.
     * @param staker The account delegating their stake
     * @param operator The account receiving delegated stake
     * @param _delegationApprover the operator's `delegationApprover` who will be signing the delegationHash (in general)
     * @param approverSalt A unique and single use value associated with the approver signature.
     * @param expiry Time after which the approver's signature becomes invalid
     */
    function calculateDelegationApprovalDigestHash(
        address staker,
        address operator,
        address _delegationApprover,
        bytes32 approverSalt,
        uint256 expiry
    ) external view returns (bytes32);

    /// @notice The EIP-712 typehash for the contract's domain
    function DOMAIN_TYPEHASH() external view returns (bytes32);

    /// @notice The EIP-712 typehash for the StakerDelegation struct used by the contract
    function STAKER_DELEGATION_TYPEHASH() external view returns (bytes32);

    /// @notice The EIP-712 typehash for the DelegationApproval struct used by the contract
    function DELEGATION_APPROVAL_TYPEHASH() external view returns (bytes32);

    /**
     * @notice Getter function for the current EIP-712 domain separator for this contract.
     *
     * @dev The domain separator will change in the event of a fork that changes the ChainID.
     * @dev By introducing a domain separator the DApp developers are guaranteed that there can be no signature collision.
     * for more detailed information please read EIP-712.
     */
    function domainSeparator() external view returns (bytes32);
}


================================================================================
// FILE: lib/eigenlayer-contracts/src/contracts/libraries/BeaconChainProofs.sol
================================================================================

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./Merkle.sol";
import "../libraries/Endian.sol";

//Utility library for parsing and PHASE0 beacon chain block headers
//SSZ Spec: https://github.com/ethereum/consensus-specs/blob/dev/ssz/simple-serialize.md#merkleization
//BeaconBlockHeader Spec: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#beaconblockheader
//BeaconState Spec: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#beaconstate
library BeaconChainProofs {
    // constants are the number of fields and the heights of the different merkle trees used in merkleizing beacon chain containers
    uint256 internal constant NUM_BEACON_BLOCK_HEADER_FIELDS = 5;
    uint256 internal constant BEACON_BLOCK_HEADER_FIELD_TREE_HEIGHT = 3;

    uint256 internal constant NUM_BEACON_BLOCK_BODY_FIELDS = 11;
    uint256 internal constant BEACON_BLOCK_BODY_FIELD_TREE_HEIGHT = 4;

    uint256 internal constant NUM_BEACON_STATE_FIELDS = 21;
    uint256 internal constant BEACON_STATE_FIELD_TREE_HEIGHT = 5;

    uint256 internal constant NUM_ETH1_DATA_FIELDS = 3;
    uint256 internal constant ETH1_DATA_FIELD_TREE_HEIGHT = 2;

    uint256 internal constant NUM_VALIDATOR_FIELDS = 8;
    uint256 internal constant VALIDATOR_FIELD_TREE_HEIGHT = 3;

    uint256 internal constant NUM_EXECUTION_PAYLOAD_HEADER_FIELDS = 15;
    uint256 internal constant EXECUTION_PAYLOAD_HEADER_FIELD_TREE_HEIGHT = 4;

    uint256 internal constant NUM_EXECUTION_PAYLOAD_FIELDS = 15;
    uint256 internal constant EXECUTION_PAYLOAD_FIELD_TREE_HEIGHT = 4;

    // HISTORICAL_ROOTS_LIMIT	 = 2**24, so tree height is 24
    uint256 internal constant HISTORICAL_ROOTS_TREE_HEIGHT = 24;

    // HISTORICAL_BATCH is root of state_roots and block_root, so number of leaves =  2^1
    uint256 internal constant HISTORICAL_BATCH_TREE_HEIGHT = 1;

    // SLOTS_PER_HISTORICAL_ROOT = 2**13, so tree height is 13
    uint256 internal constant STATE_ROOTS_TREE_HEIGHT = 13;
    uint256 internal constant BLOCK_ROOTS_TREE_HEIGHT = 13;

    //HISTORICAL_ROOTS_LIMIT = 2**24, so tree height is 24
    uint256 internal constant HISTORICAL_SUMMARIES_TREE_HEIGHT = 24;

    //Index of block_summary_root in historical_summary container
    uint256 internal constant BLOCK_SUMMARY_ROOT_INDEX = 0;

    uint256 internal constant NUM_WITHDRAWAL_FIELDS = 4;
    // tree height for hash tree of an individual withdrawal container
    uint256 internal constant WITHDRAWAL_FIELD_TREE_HEIGHT = 2;

    uint256 internal constant VALIDATOR_TREE_HEIGHT = 40;
    //refer to the eigenlayer-cli proof library.  Despite being the same dimensions as the validator tree, the balance tree is merkleized differently
    uint256 internal constant BALANCE_TREE_HEIGHT = 38;

    // MAX_WITHDRAWALS_PER_PAYLOAD = 2**4, making tree height = 4
    uint256 internal constant WITHDRAWALS_TREE_HEIGHT = 4;

    //in beacon block body
    uint256 internal constant EXECUTION_PAYLOAD_INDEX = 9;

    // in beacon block header
    uint256 internal constant STATE_ROOT_INDEX = 3;
    uint256 internal constant PROPOSER_INDEX_INDEX = 1;
    uint256 internal constant SLOT_INDEX = 0;
    uint256 internal constant BODY_ROOT_INDEX = 4;
    // in beacon state
    uint256 internal constant STATE_ROOTS_INDEX = 6;
    uint256 internal constant BLOCK_ROOTS_INDEX = 5;
    uint256 internal constant HISTORICAL_ROOTS_INDEX = 7;
    uint256 internal constant ETH_1_ROOT_INDEX = 8;
    uint256 internal constant VALIDATOR_TREE_ROOT_INDEX = 11;
    uint256 internal constant BALANCE_INDEX = 12;
    uint256 internal constant EXECUTION_PAYLOAD_HEADER_INDEX = 24;
    uint256 internal constant HISTORICAL_SUMMARIES_INDEX = 27;
    uint256 internal constant HISTORICAL_BATCH_STATE_ROOT_INDEX = 1;
    uint256 internal constant BEACON_STATE_SLOT_INDEX = 2;
    uint256 internal constant LATEST_BLOCK_HEADER_ROOT_INDEX = 4;

    // in validator
    uint256 internal constant VALIDATOR_PUBKEY_INDEX = 0;
    uint256 internal constant VALIDATOR_WITHDRAWAL_CREDENTIALS_INDEX = 1;
    uint256 internal constant VALIDATOR_BALANCE_INDEX = 2;
    uint256 internal constant VALIDATOR_SLASHED_INDEX = 3;
    uint256 internal constant VALIDATOR_WITHDRAWABLE_EPOCH_INDEX = 7;

    // in execution payload header
    uint256 internal constant TIMESTAMP_INDEX = 9;
    uint256 internal constant WITHDRAWALS_ROOT_INDEX = 14;

    //in execution payload
    uint256 internal constant WITHDRAWALS_INDEX = 14;

    // in withdrawal
    uint256 internal constant WITHDRAWAL_VALIDATOR_INDEX_INDEX = 1;
    uint256 internal constant WITHDRAWAL_VALIDATOR_AMOUNT_INDEX = 3;

    //In historicalBatch
    uint256 internal constant HISTORICALBATCH_STATEROOTS_INDEX = 1;

    //Misc Constants
    uint256 internal constant SLOTS_PER_EPOCH = 32;

    bytes8 internal constant UINT64_MASK = 0xffffffffffffffff;

    /// @notice This struct contains the merkle proofs and leaves needed to verify a partial/full withdrawal
    struct WithdrawalProof {
        bytes withdrawalProof;
        bytes slotProof;
        bytes executionPayloadProof;
        bytes timestampProof;
        bytes historicalSummaryBlockRootProof;
        uint64 blockRootIndex;
        uint64 historicalSummaryIndex;
        uint64 withdrawalIndex;
        bytes32 blockRoot;
        bytes32 slotRoot;
        bytes32 timestampRoot;
        bytes32 executionPayloadRoot;
    }

    /// @notice This struct contains the merkle proofs and leaves needed to verify a balance update
    struct BalanceUpdateProof {
        bytes validatorBalanceProof;
        bytes validatorFieldsProof;
        bytes32 balanceRoot;
    }

    /// @notice This struct contains the root and proof for verifying the state root against the oracle block root
    struct StateRootProof {
        bytes32 beaconStateRoot;
        bytes proof;
    }

    /**
     *
     * @notice This function is parses the balanceRoot to get the uint64 balance of a validator.  During merkleization of the
     * beacon state balance tree, four uint64 values (making 32 bytes) are grouped together and treated as a single leaf in the merkle tree. Thus the
     * validatorIndex mod 4 is used to determine which of the four uint64 values to extract from the balanceRoot.
     * @param validatorIndex is the index of the validator being proven for.
     * @param balanceRoot is the combination of 4 validator balances being proven for.
     * @return The validator's balance, in Gwei
     */
    function getBalanceFromBalanceRoot(uint40 validatorIndex, bytes32 balanceRoot) internal pure returns (uint64) {
        uint256 bitShiftAmount = (validatorIndex % 4) * 64;
        bytes32 validatorBalanceLittleEndian = bytes32((uint256(balanceRoot) << bitShiftAmount));
        uint64 validatorBalance = Endian.fromLittleEndianUint64(validatorBalanceLittleEndian);
        return validatorBalance;
    }

    /**
     * @notice This function verifies merkle proofs of the fields of a certain validator against a beacon chain state root
     * @param validatorIndex the index of the proven validator
     * @param beaconStateRoot is the beacon chain state root to be proven against.
     * @param validatorFieldsProof is the data used in proving the validator's fields
     * @param validatorFields the claimed fields of the validator
     */
    function verifyValidatorFields(
        bytes32 beaconStateRoot,
        bytes32[] calldata validatorFields,
        bytes calldata validatorFieldsProof,
        uint40 validatorIndex
    ) internal view {
        require(
            validatorFields.length == 2 ** VALIDATOR_FIELD_TREE_HEIGHT,
            "BeaconChainProofs.verifyValidatorFields: Validator fields has incorrect length"
        );

        /**
         * Note: the length of the validator merkle proof is BeaconChainProofs.VALIDATOR_TREE_HEIGHT + 1.
         * There is an additional layer added by hashing the root with the length of the validator list
         */
        require(
            validatorFieldsProof.length == 32 * ((VALIDATOR_TREE_HEIGHT + 1) + BEACON_STATE_FIELD_TREE_HEIGHT),
            "BeaconChainProofs.verifyValidatorFields: Proof has incorrect length"
        );
        uint256 index = (VALIDATOR_TREE_ROOT_INDEX << (VALIDATOR_TREE_HEIGHT + 1)) | uint256(validatorIndex);
        // merkleize the validatorFields to get the leaf to prove
        bytes32 validatorRoot = Merkle.merkleizeSha256(validatorFields);

        // verify the proof of the validatorRoot against the beaconStateRoot
        require(
            Merkle.verifyInclusionSha256({
                proof: validatorFieldsProof,
                root: beaconStateRoot,
                leaf: validatorRoot,
                index: index
            }),
            "BeaconChainProofs.verifyValidatorFields: Invalid merkle proof"
        );
    }

    /**
     * @notice This function verifies merkle proofs of the balance of a certain validator against a beacon chain state root
     * @param validatorIndex the index of the proven validator
     * @param beaconStateRoot is the beacon chain state root to be proven against.
     * @param validatorBalanceProof is the proof of the balance against the beacon chain state root
     * @param balanceRoot is the serialized balance used to prove the balance of the validator (refer to `getBalanceFromBalanceRoot` above for detailed explanation)
     */
    function verifyValidatorBalance(
        bytes32 beaconStateRoot,
        bytes32 balanceRoot,
        bytes calldata validatorBalanceProof,
        uint40 validatorIndex
    ) internal view {
        require(
            validatorBalanceProof.length == 32 * ((BALANCE_TREE_HEIGHT + 1) + BEACON_STATE_FIELD_TREE_HEIGHT),
            "BeaconChainProofs.verifyValidatorBalance: Proof has incorrect length"
        );

        /**
         * the beacon state's balance list is a list of uint64 values, and these are grouped together in 4s when merkleized.
         * Therefore, the index of the balance of a validator is validatorIndex/4
         */
        uint256 balanceIndex = uint256(validatorIndex / 4);
        /**
         * Note: Merkleization of the balance root tree uses MerkleizeWithMixin, i.e., the length of the array is hashed with the root of
         * the array.  Thus we shift the BALANCE_INDEX over by BALANCE_TREE_HEIGHT + 1 and not just BALANCE_TREE_HEIGHT.
         */
        balanceIndex = (BALANCE_INDEX << (BALANCE_TREE_HEIGHT + 1)) | balanceIndex;

        require(
            Merkle.verifyInclusionSha256({
                proof: validatorBalanceProof,
                root: beaconStateRoot,
                leaf: balanceRoot,
                index: balanceIndex
            }),
            "BeaconChainProofs.verifyValidatorBalance: Invalid merkle proof"
        );
    }

    /**
     * @notice This function verifies the latestBlockHeader against the state root. the latestBlockHeader is
     * a tracked in the beacon state.
     * @param beaconStateRoot is the beacon chain state root to be proven against.
     * @param stateRootProof is the provided merkle proof
     * @param latestBlockRoot is hashtree root of the latest block header in the beacon state
     */
    function verifyStateRootAgainstLatestBlockRoot(
        bytes32 latestBlockRoot,
        bytes32 beaconStateRoot,
        bytes calldata stateRootProof
    ) internal view {
        require(
            stateRootProof.length == 32 * (BEACON_BLOCK_HEADER_FIELD_TREE_HEIGHT),
            "BeaconChainProofs.verifyStateRootAgainstLatestBlockRoot: Proof has incorrect length"
        );
        //Next we verify the slot against the blockRoot
        require(
            Merkle.verifyInclusionSha256({
                proof: stateRootProof,
                root: latestBlockRoot,
                leaf: beaconStateRoot,
                index: STATE_ROOT_INDEX
            }),
            "BeaconChainProofs.verifyStateRootAgainstLatestBlockRoot: Invalid latest block header root merkle proof"
        );
    }

    /**
     * @notice This function verifies the slot and the withdrawal fields for a given withdrawal
     * @param withdrawalProof is the provided set of merkle proofs
     * @param withdrawalFields is the serialized withdrawal container to be proven
     */
    function verifyWithdrawal(
        bytes32 beaconStateRoot,
        bytes32[] calldata withdrawalFields,
        WithdrawalProof calldata withdrawalProof
    ) internal view {
        require(
            withdrawalFields.length == 2 ** WITHDRAWAL_FIELD_TREE_HEIGHT,
            "BeaconChainProofs.verifyWithdrawal: withdrawalFields has incorrect length"
        );

        require(
            withdrawalProof.blockRootIndex < 2 ** BLOCK_ROOTS_TREE_HEIGHT,
            "BeaconChainProofs.verifyWithdrawal: blockRootIndex is too large"
        );
        require(
            withdrawalProof.withdrawalIndex < 2 ** WITHDRAWALS_TREE_HEIGHT,
            "BeaconChainProofs.verifyWithdrawal: withdrawalIndex is too large"
        );

        require(
            withdrawalProof.withdrawalProof.length ==
                32 * (EXECUTION_PAYLOAD_HEADER_FIELD_TREE_HEIGHT + WITHDRAWALS_TREE_HEIGHT + 1),
            "BeaconChainProofs.verifyWithdrawal: withdrawalProof has incorrect length"
        );
        require(
            withdrawalProof.executionPayloadProof.length ==
                32 * (BEACON_BLOCK_HEADER_FIELD_TREE_HEIGHT + BEACON_BLOCK_BODY_FIELD_TREE_HEIGHT),
            "BeaconChainProofs.verifyWithdrawal: executionPayloadProof has incorrect length"
        );
        require(
            withdrawalProof.slotProof.length == 32 * (BEACON_BLOCK_HEADER_FIELD_TREE_HEIGHT),
            "BeaconChainProofs.verifyWithdrawal: slotProof has incorrect length"
        );
        require(
            withdrawalProof.timestampProof.length == 32 * (EXECUTION_PAYLOAD_HEADER_FIELD_TREE_HEIGHT),
            "BeaconChainProofs.verifyWithdrawal: timestampProof has incorrect length"
        );

        require(
            withdrawalProof.historicalSummaryBlockRootProof.length ==
                32 *
                    (BEACON_STATE_FIELD_TREE_HEIGHT +
                        (HISTORICAL_SUMMARIES_TREE_HEIGHT + 1) +
                        1 +
                        (BLOCK_ROOTS_TREE_HEIGHT)),
            "BeaconChainProofs.verifyWithdrawal: historicalSummaryBlockRootProof has incorrect length"
        );
        /**
         * Note: Here, the "1" in "1 + (BLOCK_ROOTS_TREE_HEIGHT)" signifies that extra step of choosing the "block_root_summary" within the individual
         * "historical_summary". Everywhere else it signifies merkelize_with_mixin, where the length of an array is hashed with the root of the array,
         * but not here.
         */
        uint256 historicalBlockHeaderIndex = (HISTORICAL_SUMMARIES_INDEX <<
            ((HISTORICAL_SUMMARIES_TREE_HEIGHT + 1) + 1 + (BLOCK_ROOTS_TREE_HEIGHT))) |
            (uint256(withdrawalProof.historicalSummaryIndex) << (1 + (BLOCK_ROOTS_TREE_HEIGHT))) |
            (BLOCK_SUMMARY_ROOT_INDEX << (BLOCK_ROOTS_TREE_HEIGHT)) |
            uint256(withdrawalProof.blockRootIndex);

        require(
            Merkle.verifyInclusionSha256({
                proof: withdrawalProof.historicalSummaryBlockRootProof,
                root: beaconStateRoot,
                leaf: withdrawalProof.blockRoot,
                index: historicalBlockHeaderIndex
            }),
            "BeaconChainProofs.verifyWithdrawal: Invalid historicalsummary merkle proof"
        );

        //Next we verify the slot against the blockRoot
        require(
            Merkle.verifyInclusionSha256({
                proof: withdrawalProof.slotProof,
                root: withdrawalProof.blockRoot,
                leaf: withdrawalProof.slotRoot,
                index: SLOT_INDEX
            }),
            "BeaconChainProofs.verifyWithdrawal: Invalid slot merkle proof"
        );

        {
            // Next we verify the executionPayloadRoot against the blockRoot
            uint256 executionPayloadIndex = (BODY_ROOT_INDEX << (BEACON_BLOCK_BODY_FIELD_TREE_HEIGHT)) |
                EXECUTION_PAYLOAD_INDEX;
            require(
                Merkle.verifyInclusionSha256({
                    proof: withdrawalProof.executionPayloadProof,
                    root: withdrawalProof.blockRoot,
                    leaf: withdrawalProof.executionPayloadRoot,
                    index: executionPayloadIndex
                }),
                "BeaconChainProofs.verifyWithdrawal: Invalid executionPayload merkle proof"
            );
        }

        // Next we verify the timestampRoot against the executionPayload root
        require(
            Merkle.verifyInclusionSha256({
                proof: withdrawalProof.timestampProof,
                root: withdrawalProof.executionPayloadRoot,
                leaf: withdrawalProof.timestampRoot,
                index: TIMESTAMP_INDEX
            }),
            "BeaconChainProofs.verifyWithdrawal: Invalid blockNumber merkle proof"
        );

        {
            /**
             * Next we verify the withdrawal fields against the blockRoot:
             * First we compute the withdrawal_index relative to the blockRoot by concatenating the indexes of all the
             * intermediate root indexes from the bottom of the sub trees (the withdrawal container) to the top, the blockRoot.
             * Then we calculate merkleize the withdrawalFields container to calculate the the withdrawalRoot.
             * Finally we verify the withdrawalRoot against the executionPayloadRoot.
             *
             *
             * Note: Merkleization of the withdrawals root tree uses MerkleizeWithMixin, i.e., the length of the array is hashed with the root of
             * the array.  Thus we shift the WITHDRAWALS_INDEX over by WITHDRAWALS_TREE_HEIGHT + 1 and not just WITHDRAWALS_TREE_HEIGHT.
             */
            uint256 withdrawalIndex = (WITHDRAWALS_INDEX << (WITHDRAWALS_TREE_HEIGHT + 1)) |
                uint256(withdrawalProof.withdrawalIndex);
            bytes32 withdrawalRoot = Merkle.merkleizeSha256(withdrawalFields);
            require(
                Merkle.verifyInclusionSha256({
                    proof: withdrawalProof.withdrawalProof,
                    root: withdrawalProof.executionPayloadRoot,
                    leaf: withdrawalRoot,
                    index: withdrawalIndex
                }),
                "BeaconChainProofs.verifyWithdrawal: Invalid withdrawal merkle proof"
            );
        }
    }

    /**
     * @notice This function replicates the ssz hashing of a validator's pubkey, outlined below:
     *  hh := ssz.NewHasher()
     *  hh.PutBytes(validatorPubkey[:])
     *  validatorPubkeyHash := hh.Hash()
     *  hh.Reset()
     */
    function hashValidatorBLSPubkey(bytes memory validatorPubkey) internal pure returns (bytes32 pubkeyHash) {
        require(validatorPubkey.length == 48, "Input should be 48 bytes in length");
        return sha256(abi.encodePacked(validatorPubkey, bytes16(0)));
    }
}


================================================================================
// FILE: lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}


================================================================================
// FILE: lib/eigenlayer-contracts/src/contracts/interfaces/IPauserRegistry.sol
================================================================================

// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

/**
 * @title Interface for the `PauserRegistry` contract.
 * @author Layr Labs, Inc.
 * @notice Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service
 */
interface IPauserRegistry {
    event PauserStatusChanged(address pauser, bool canPause);

    event UnpauserChanged(address previousUnpauser, address newUnpauser);
    
    /// @notice Mapping of addresses to whether they hold the pauser role.
    function isPauser(address pauser) external view returns (bool);

    /// @notice Unique address that holds the unpauser role. Capable of changing *both* the pauser and unpauser addresses.
    function unpauser() external view returns (address);
}


================================================================================
// FILE: lib/eigenlayer-contracts/src/contracts/libraries/Merkle.sol
================================================================================

// SPDX-License-Identifier: BUSL-1.1
// Adapted from OpenZeppelin Contracts (last updated v4.8.0) (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Tree proofs.
 *
 * The tree and the proofs can be generated using our
 * https://github.com/OpenZeppelin/merkle-tree[JavaScript library].
 * You will find a quickstart guide in the readme.
 *
 * WARNING: You should avoid using leaf values that are 64 bytes long prior to
 * hashing, or use a hash function other than keccak256 for hashing leaves.
 * This is because the concatenation of a sorted pair of internal nodes in
 * the merkle tree could be reinterpreted as a leaf value.
 * OpenZeppelin's JavaScript library generates merkle trees that are safe
 * against this attack out of the box.
 */
library Merkle {
    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. The tree is built assuming `leaf` is
     * the 0 indexed `index`'th leaf from the bottom left of the tree.
     *
     * Note this is for a Merkle tree using the keccak/sha3 hash function
     */
    function verifyInclusionKeccak(
        bytes memory proof,
        bytes32 root,
        bytes32 leaf,
        uint256 index
    ) internal pure returns (bool) {
        return processInclusionProofKeccak(proof, leaf, index) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. The tree is built assuming `leaf` is
     * the 0 indexed `index`'th leaf from the bottom left of the tree.
     *
     * _Available since v4.4._
     *
     * Note this is for a Merkle tree using the keccak/sha3 hash function
     */
    function processInclusionProofKeccak(
        bytes memory proof,
        bytes32 leaf,
        uint256 index
    ) internal pure returns (bytes32) {
        require(
            proof.length != 0 && proof.length % 32 == 0,
            "Merkle.processInclusionProofKeccak: proof length should be a non-zero multiple of 32"
        );
        bytes32 computedHash = leaf;
        for (uint256 i = 32; i <= proof.length; i += 32) {
            if (index % 2 == 0) {
                // if ith bit of index is 0, then computedHash is a left sibling
                assembly {
                    mstore(0x00, computedHash)
                    mstore(0x20, mload(add(proof, i)))
                    computedHash := keccak256(0x00, 0x40)
                    index := div(index, 2)
                }
            } else {
                // if ith bit of index is 1, then computedHash is a right sibling
                assembly {
                    mstore(0x00, mload(add(proof, i)))
                    mstore(0x20, computedHash)
                    computedHash := keccak256(0x00, 0x40)
                    index := div(index, 2)
                }
            }
        }
        return computedHash;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. The tree is built assuming `leaf` is
     * the 0 indexed `index`'th leaf from the bottom left of the tree.
     *
     * Note this is for a Merkle tree using the sha256 hash function
     */
    function verifyInclusionSha256(
        bytes memory proof,
        bytes32 root,
        bytes32 leaf,
        uint256 index
    ) internal view returns (bool) {
        return processInclusionProofSha256(proof, leaf, index) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. The tree is built assuming `leaf` is
     * the 0 indexed `index`'th leaf from the bottom left of the tree.
     *
     * _Available since v4.4._
     *
     * Note this is for a Merkle tree using the sha256 hash function
     */
    function processInclusionProofSha256(
        bytes memory proof,
        bytes32 leaf,
        uint256 index
    ) internal view returns (bytes32) {
        require(
            proof.length != 0 && proof.length % 32 == 0,
            "Merkle.processInclusionProofSha256: proof length should be a non-zero multiple of 32"
        );
        bytes32[1] memory computedHash = [leaf];
        for (uint256 i = 32; i <= proof.length; i += 32) {
            if (index % 2 == 0) {
                // if ith bit of index is 0, then computedHash is a left sibling
                assembly {
                    mstore(0x00, mload(computedHash))
                    mstore(0x20, mload(add(proof, i)))
                    if iszero(staticcall(sub(gas(), 2000), 2, 0x00, 0x40, computedHash, 0x20)) {
                        revert(0, 0)
                    }
                    index := div(index, 2)
                }
            } else {
                // if ith bit of index is 1, then computedHash is a right sibling
                assembly {
                    mstore(0x00, mload(add(proof, i)))
                    mstore(0x20, mload(computedHash))
                    if iszero(staticcall(sub(gas(), 2000), 2, 0x00, 0x40, computedHash, 0x20)) {
                        revert(0, 0)
                    }
                    index := div(index, 2)
                }
            }
        }
        return computedHash[0];
    }

    /**
     @notice this function returns the merkle root of a tree created from a set of leaves using sha256 as its hash function
     @param leaves the leaves of the merkle tree
     @return The computed Merkle root of the tree.
     @dev A pre-condition to this function is that leaves.length is a power of two.  If not, the function will merkleize the inputs incorrectly.
     */
    function merkleizeSha256(bytes32[] memory leaves) internal pure returns (bytes32) {
        //there are half as many nodes in the layer above the leaves
        uint256 numNodesInLayer = leaves.length / 2;
        //create a layer to store the internal nodes
        bytes32[] memory layer = new bytes32[](numNodesInLayer);
        //fill the layer with the pairwise hashes of the leaves
        for (uint i = 0; i < numNodesInLayer; i++) {
            layer[i] = sha256(abi.encodePacked(leaves[2 * i], leaves[2 * i + 1]));
        }
        //the next layer above has half as many nodes
        numNodesInLayer /= 2;
        //while we haven't computed the root
        while (numNodesInLayer != 0) {
            //overwrite the first numNodesInLayer nodes in layer with the pairwise hashes of their children
            for (uint i = 0; i < numNodesInLayer; i++) {
                layer[i] = sha256(abi.encodePacked(layer[2 * i], layer[2 * i + 1]));
            }
            //the next layer above has half as many nodes
            numNodesInLayer /= 2;
        }
        //the first node in the layer is the root
        return layer[0];
    }
}


================================================================================
// FILE: lib/eigenlayer-contracts/src/contracts/libraries/Endian.sol
================================================================================

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library Endian {
    /**
     * @notice Converts a little endian-formatted uint64 to a big endian-formatted uint64
     * @param lenum little endian-formatted uint64 input, provided as 'bytes32' type
     * @return n The big endian-formatted uint64
     * @dev Note that the input is formatted as a 'bytes32' type (i.e. 256 bits), but it is immediately truncated to a uint64 (i.e. 64 bits)
     * through a right-shift/shr operation.
     */
    function fromLittleEndianUint64(bytes32 lenum) internal pure returns (uint64 n) {
        // the number needs to be stored in little-endian encoding (ie in bytes 0-8)
        n = uint64(uint256(lenum >> 192));
        return
            (n >> 56) |
            ((0x00FF000000000000 & n) >> 40) |
            ((0x0000FF0000000000 & n) >> 24) |
            ((0x000000FF00000000 & n) >> 8) |
            ((0x00000000FF000000 & n) << 8) |
            ((0x0000000000FF0000 & n) << 24) |
            ((0x000000000000FF00 & n) << 40) |
            ((0x00000000000000FF & n) << 56);
    }
}
