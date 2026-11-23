//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


/*   
                       #@#                                                #@#
                      #@%#@                                              #@%#@
                     #@?++@#                                             @?;*#@
                   #@#*?++##                                            #@*;?*S@#
                  #@S*++;*@#                                             @%;+++%@@#
                #@#??*+;;S@                                              ##;;;+%?S@#
               @@%++*+;:;##                                              #@*:;++++?#@#
              @S?%*;++;:+@#                                               @?:;++;+?%%@#
             @%?%+;+++;:+@#                                               @?::;++++?%?@#
            ##++++++++;:;S@SS##########S%%%%?**?*;;+?**?%%%%SS#########SS#@+::+++++;++%@
            @%+%++++++;::+S@@@SS%SS%S#S+;;+;;;;;;;;;+;;;+++;;%#S%SS%SS#@@#*::;+++++;??*@#
            @%*S;++++++;::;*%#SSS%%%SS#S*;;+++++++++++++;;;+%##S%%%SSS#S?+::;;+++++;?S*@#
            @#+*+;++++++;:::;%#S########*++++++++++++++++++*S########S#;:::;+++++++;*+%@
             @%;?*;++++++;;;+#S######S#@@?;+;;;;+;;+;;;;+++#@########%@*;;;++++++;+%+*@#
              @?*S*;;+++++++%#%##########SSS?S%%#S%S%%S??#%##########SS#+;+++++;;+S?*#@
               @%*++*+;++;+SS%##########S#@##@########@###@###########S%#*;;++;+*+*?@#
                @@%*??*;+%#SS###############S##########################S%#S*++??*?#@#
                  @@S??S##SS###########S#SS#@@#######S#@#S%#SS###########S#@#%?%#@#
                  ##@@@#############@S?%+;:;?S@########?+:::;+?@@#############@@@##
          ######SS##SS##############%%@@@?:::+S@####@@*;:::::;+?###############S###S######
          #@####SS#################S;?##%;;;+++#####@?;+;;;?S*+;?@#################S#####@
           #@@##############@######@?;++;++++++#####@?+++;?@@@%*#@#######@#############@@#
            #@#############@#######@?;;;++;;;+#@#####@?;;;*##S++###S####@#############@#
              #@@#@@@##@@@@@##@###SSS??*;;***S#######S#?**;;+?*SSS####@#@@@@@###@@#@@##
                #########SS@@######SS#@S%%#@#SS######SSS@#%%S@#SS###S###@#S#########
                            #@##########SSSS###############SS#S#########@@
                            #@#@##########S%?%S#######S%%S##########@#@@
                             @@#@#######S+:;;;;+%%?%*;;+;:;%@########@@#
                              @@########:;S#@@S+;;;;;%#@@#*:?@######@@#
                               @@#@##S@?;+#@@@#++++++%@@@@?;+@###@#@@#
                                #@@###@S;++*?*++++++++*?*+;;*@####@@#
                                 #@@@#*++;*%%*S%??%??S??S?+;++S@@@#
                                  #@@%+;+%#@#S##%SS%S@##@@S*;;*@@#
                                    #@#?S%%%S@#@####@##S%%%#%S@#
                                      #@@?%??S???S#*??%??%?S@@
                                        #@#%+??*+?%*+??+?S@##
                                          ##@?;+;+++;++#@#
                                            #@*+%?*S*+S#
                                             #@#####@@#




PFP collection of 250 evolutionary bulls enabled by ERC404.  
https://twitter.com/ConfusedBulls 
*/

import "./ERC404/ERC404.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// import IERC20 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import String
import {Strings} from  "@openzeppelin/contracts/utils/Strings.sol";

interface IUniswapV3Pool {
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
}

contract CBulls is ERC404 {
    string public dataURI;
    string public baseTokenURI;


    IERC20 public weth;

    address public poolAddress;
    bool public priceMode = false;

    uint256 public manualPrice;

    constructor(
        address _owner,
        address _team,
        address _marketing,
        address _dev1,
        address _dev2,
        address _weth
    ) ERC404("CBulls", "CBULLS", 18, 250, _owner) {
        balanceOf[_owner] = 215 ether;
        balanceOf[_team] = 6.5 ether;
        balanceOf[_marketing] = 22.5 ether;
        balanceOf[_dev1] = 3 ether;
        balanceOf[_dev2] = 3 ether;
        weth = IERC20(_weth);
    }

    function setDataURI(string memory _dataURI) public onlyOwner {
        dataURI = _dataURI;
    }

    function setTokenURI(string memory _tokenURI) public onlyOwner {
        baseTokenURI = _tokenURI;
    }

    function setNameSymbol(
        string memory _name,
        string memory _symbol
    ) public onlyOwner {
        _setNameSymbol(_name, _symbol);
    }

    function getCBullsPrice() public view returns (uint256){
        if(!priceMode){
            IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
            (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        
            uint256 priceRatioX96 = uint256(sqrtPriceX96) ** 2;
        
            if (priceRatioX96 > 2**192) {
                return priceRatioX96 / (2**192);
            } else {
                return (priceRatioX96 * 10**18) / (2**192);
            }
        } else {
            return manualPrice;
        }
    }

    function setpoolAddress(address _poolAddress) public onlyOwner {
        poolAddress = _poolAddress;
    }

    function setManualPrice(uint256 _price) public onlyOwner {
        priceMode = true;
        manualPrice = _price;
    }

    function setPriceMode(bool _priceMode) public onlyOwner {
        priceMode = _priceMode;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        if (bytes(baseTokenURI).length > 0) {
            return string.concat(baseTokenURI, Strings.toString(id));
        } else {
            string memory image;
            string memory bullType;
            string memory idStr = Strings.toString(id);
            uint256 cBullsPrice = getCBullsPrice();
            // turn id to string
            if(cBullsPrice <= 4 ether){
                image = string.concat(idStr, ".jpeg");
                bullType = "Sad";
            } else if (cBullsPrice <= 20 ether){
                image = string.concat(idStr, "-2", ".jpeg");
                bullType = "Normal";
            } else {
                image = string.concat(idStr, "-3", ".jpg");
                bullType = "Happy";
            }

            string memory jsonPreImage = string.concat(
                string.concat(
                    string.concat('{"name": "CBulls #', Strings.toString(id)),
                    '","description":"A collection of 250 evolutive Confused Bulls enabled by ERC404, an experimental token standard.","external_url":"https://ipfs.io/ipfs/QmQn6xah15UgdKYMDfP3afAGfoJqPw1ospNDrAg3RgrRYh/","image":"'
                ),
                string.concat(dataURI, image)
            );
            string memory jsonPostImage = string.concat(
                '","attributes":[{"trait_type":"Type","value":"',
                bullType
            );
            string memory jsonPostTrait = '"}]}';

            return
                string.concat(
                    "data:application/json;utf8,",
                    string.concat(
                        string.concat(jsonPreImage, jsonPostImage),
                        jsonPostTrait
                    )
                );
        }
    }
}