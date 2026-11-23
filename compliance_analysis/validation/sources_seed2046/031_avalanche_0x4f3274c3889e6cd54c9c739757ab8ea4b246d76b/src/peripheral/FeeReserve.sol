import { Auth, GlobalACL } from "../Auth.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { StorageViewer } from "./StorageViewer.sol";

using SafeTransferLib for ERC20;

contract FeeReserve is GlobalACL {
    error FeeReserve__BalanceNotEnough();
    error FeeReserve__AlreadyClaimed();

    StorageViewer public immutable storageViewer;
    address public immutable longToken;
    address public immutable shortToken;
    uint256 public longTokenFee;
    uint256 public shortTokenFee;
    address public keeper;
    mapping(uint256 => bool) claimed;

    constructor(
        Auth _auth,
        StorageViewer _storageViewer,
        address _longToken,
        address _shortToken,
        uint256 _longTokenFee,
        uint256 _shortTokenFee,
        address _keeper
    ) GlobalACL(_auth) {
        storageViewer = _storageViewer;
        longToken = _longToken;
        shortToken = _shortToken;
        longTokenFee = _longTokenFee;
        shortTokenFee = _shortTokenFee;
        keeper = _keeper;
    }

    function setFeesPerEpoch(uint256 _longTokenFee, uint256 _shortTokenFee) external onlyConfigurator {
        longTokenFee = _longTokenFee;
        shortTokenFee = _shortTokenFee;
    }

    function setKeeper(address _keeper) external onlyConfigurator {
        keeper = _keeper;
    }

    function pullAsset(address _asset, uint256 _amt, bool _revert) external onlyAggregateVault returns (uint256) {
        return _transfer(_asset, msg.sender, _amt, _revert);
    }

    function pullKeeperFees() external onlyAggregateVault {
        uint256 currentEpoch = storageViewer.getEpoch();
        if (claimed[currentEpoch]) {
            revert FeeReserve__AlreadyClaimed();
        }
        claimed[currentEpoch] = true;
        _transfer(longToken, keeper, longTokenFee, false);
        _transfer(shortToken, keeper, shortTokenFee, false);
    }

    function _transfer(address _asset, address _to, uint256 _amt, bool _revert) internal returns (uint256) {
        uint256 balance = ERC20(_asset).balanceOf(address(this));
        if (_amt > balance && _revert) revert FeeReserve__BalanceNotEnough();
        uint256 amtToSend = _amt > balance ? balance : _amt;
        if (amtToSend > 0) {
            ERC20(_asset).safeTransfer(_to, amtToSend);
        }
        return amtToSend;
    }
}
