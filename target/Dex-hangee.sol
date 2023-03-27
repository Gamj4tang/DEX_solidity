
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IDex.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/utils/math/Math.sol";
contract DreamOracle {
   address public operator;
   mapping(address=>uint256) prices;


   constructor() {
       operator = msg.sender;
   }


   function getPrice(address token) external view returns (uint256) {
       require(prices[token] != 0, "the price cannot be zero");
       return prices[token];
   }


   function setPrice(address token, uint256 price) external returns (uint) {
       require(msg.sender == operator, "only operator can set the price");
       return prices[token] = price;
   }
}

contract LPT is ERC20("LPT", "LPT") {
    address _admin;
    constructor() {
        _admin = msg.sender;
    }

    modifier onlyAdmin {
        require(_admin == msg.sender, "only Admin");

        _;
    }

    function mint(address account, uint256 amount) onlyAdmin external {
        _mint(account, amount);
    }
}

contract Dex {
    address _tokenX;
    address _tokenY;

    LPT lpt = new LPT();
    DreamOracle oracle = new DreamOracle();

    uint decimals = 10 ** 18;

    uint public amountOfX;
    uint public amountOfY;
    uint K;

    constructor(address tokenX, address tokenY) {
        _tokenX = tokenX;
        _tokenY = tokenY;

        oracle.setPrice(_tokenX, 1 ether);
        oracle.setPrice(_tokenY, 1 ether);
    }

    function addLiquidity(
        uint256 tokenXAmount,
        uint256 tokenYAmount,
        uint256 minimumLPTokenAmount
    ) external returns (uint256 LPTokenAmount) {
        require(tokenXAmount > 0);
        require(tokenYAmount > 0);

        uint lptTotalSupply = lpt.totalSupply();
        uint priceOfX;
        uint priceOfY;
        (uint balanceOfX, uint balanceOfY) = pairTokenBalance();

        if (lptTotalSupply < 1) {
            priceOfX = oracle.setPrice(_tokenX, tokenXAmount / decimals);
            priceOfY = oracle.setPrice(_tokenY, tokenYAmount / decimals);
        }
        else {
            priceOfX = oracle.getPrice(_tokenX);
            priceOfY = oracle.getPrice(_tokenY);

            require((priceOfX * tokenXAmount) * 1 ether / (priceOfY * tokenYAmount) == (priceOfX * balanceOfX) * 1 ether / (priceOfY * balanceOfY), "invalid ratio");
        }

        IERC20(_tokenX).transferFrom(msg.sender, address(this), tokenXAmount);
        IERC20(_tokenY).transferFrom(msg.sender, address(this), tokenYAmount);

        if (lptTotalSupply > 0){
            LPTokenAmount = lptTotalSupply * (priceOfX * tokenXAmount + priceOfY * tokenYAmount) / (priceOfX * balanceOfX + priceOfY * balanceOfY);
        }
        else{
            //     K =        sqrt((a가격     * (이전 a개수   + 추가된 a개수))      * (b가격     * (이전 b개수    + 추가된 b개수)))
        LPTokenAmount = Math.sqrt((priceOfX * (balanceOfX + tokenXAmount)) * (priceOfY * (balanceOfY + tokenYAmount)), Math.Rounding.Up);
        }

        require(LPTokenAmount >= minimumLPTokenAmount);

        console.log("LPTokenAmount: %s", LPTokenAmount);
        address(this).call(abi.encodeWithSelector(this.transfer.selector, msg.sender, LPTokenAmount));
    }

    function swap(
        uint256 tokenXAmount,
        uint256 tokenYAmount,
        uint256 tokenMinimumOutputAmount
    ) external returns (uint256 outputAmount) {
        (uint balanceOfX, uint balanceOfY) = pairTokenBalance();
        uint K = balanceOfX * balanceOfY;

        if (tokenXAmount > 0) {
            require(tokenYAmount == 0);
                            // 원래있던 Y - (상수 K / (원래 있던 X + 새로넣은 X)  )    * 0.1%
            outputAmount = (balanceOfY - (K / (balanceOfX + tokenXAmount))) * 999 / 1000;
            IERC20(_tokenX).transferFrom(msg.sender, address(this), tokenXAmount);
            IERC20(_tokenY).transfer( msg.sender, outputAmount);
        }
        else if (tokenYAmount > 0) {
            require(tokenXAmount == 0);

            outputAmount = (balanceOfX - (K / (balanceOfY + tokenYAmount))) * 999 / 1000;
            IERC20(_tokenY).transferFrom(msg.sender, address(this), tokenYAmount);
            IERC20(_tokenX).transfer(msg.sender, outputAmount);
        }
        else {
            revert();
        }

        require(outputAmount >= tokenMinimumOutputAmount);
    }

    function removeLiquidity(
        uint256 LPTokenAmount,
        uint256 minimumTokenXAmount,
        uint256 minimumTokenYAmount
    ) external returns (uint rx, uint ry) {
        require(LPTokenAmount > 0);
        require(minimumTokenXAmount >= 0);
        require(minimumTokenYAmount >= 0);
        require(lpt.balanceOf(msg.sender) >= LPTokenAmount);

        (uint balanceOfX, uint balanceOfY) = pairTokenBalance();

        uint lptTotalSupply = lpt.totalSupply();

        rx = balanceOfX * LPTokenAmount / lptTotalSupply;
        ry = balanceOfY * LPTokenAmount / lptTotalSupply;

        require(rx >= minimumTokenXAmount);
        require(rx >= minimumTokenYAmount);
    }

    function transfer(address to, uint256 lpAmount) external returns (bool) {
        require(lpAmount > 0);

        lpt.mint(payable(address(this)), lpAmount);
        lpt.transfer(payable(to), lpAmount);

        return true;
    }

    function pairTokenBalance() internal returns (uint x, uint y) {
        x = IERC20(_tokenX).balanceOf(address(this));
        y = IERC20(_tokenY).balanceOf(address(this));
    }
}