import { GmxStorage } from "../libraries/GmxStorage.sol";

interface IGMI {
    function indexAssets() external view returns (address[] memory);
    function indexAssetsLength() external view returns (uint256);
    function tvl(GmxStorage.MarketPrices[] memory prices) external view returns (uint256);
    function pps(GmxStorage.MarketPrices[] memory prices) external view returns (uint256);
    function previewMint(uint256 shares, address asset, GmxStorage.MarketPrices[] memory prices)
        external
        view
        returns (uint256[] memory);
    function redeem(uint256 shares, address receiver, address owner, GmxStorage.MarketPrices[] memory prices)
        external
        returns (uint256[] memory assets);
    function deposit(uint256[] memory assets, GmxStorage.MarketPrices[] memory prices, address receiver)
        external
        returns (uint256 shares);
    function sharesToMarketTokens(uint256 shares, GmxStorage.MarketPrices[] memory prices)
        external
        view
        returns (uint256[] memory);
    function getWeights() external view returns (uint256[] memory);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface IGMIWithERC20 is IGMI, IERC20 { }
