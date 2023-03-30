
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IDex.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

import "openzeppelin-contracts/utils/math/SafeMath.sol";

import "openzeppelin-contracts/access/Ownable.sol";
import "./FixedPointMathLib.sol";

contract Dex is IDex, ERC20, ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    
    ERC20 public tokenX;
    ERC20 public tokenY;
    ERC20 public lpToken;

    uint8 constant TOKEN_DECIMALS = 18;

    uint public totalLiquidity;
    mapping(address => uint) public liquidity; 

    constructor(address _tokenX, address _tokenY) ERC20("LPToken", "LPT")  {
        tokenX = ERC20(_tokenX);
        tokenY = ERC20(_tokenY);
        lpToken = ERC20(address(this));
    }

    function addLiquidity(uint tokenXAmount, uint tokenYAmount, uint tokenMinimumOutputAmount) external override nonReentrant returns (uint) {
        require(tokenXAmount > 0 && tokenYAmount > 0, "Amounts must be greater than zero.");    
        require(tokenX.allowance(msg.sender, address(this)) >= tokenXAmount, "ERC20: insufficient allowance");
        require(tokenY.allowance(msg.sender, address(this)) >= tokenYAmount, "ERC20: insufficient allowance");
        require(tokenX.balanceOf(msg.sender) >= tokenXAmount, "ERC20: transfer amount exceeds balance");
        require(tokenY.balanceOf(msg.sender) >= tokenYAmount, "ERC20: transfer amount exceeds balance");
        

        uint lpTokenCreated;
        uint tokenXReserve;
        uint tokenYReserve;
        uint liquidityX;
        uint liquidityY;

        if (totalSupply() <= 0) {
            
            lpTokenCreated = FixedPointMathLib.sqrt(tokenXAmount * tokenYAmount); 
            require(lpTokenCreated >= tokenMinimumOutputAmount, "Minimum liquidity not met."); 
            totalLiquidity = lpTokenCreated;
        } else {
            {
                totalLiquidity = totalSupply();
                tokenXReserve = tokenX.balanceOf(address(this));
                tokenYReserve = tokenY.balanceOf(address(this));

                liquidityX = FixedPointMathLib.divWadUp(FixedPointMathLib.mulWadUp(tokenXAmount, totalLiquidity), tokenXReserve);
                liquidityY = FixedPointMathLib.divWadUp(FixedPointMathLib.mulWadUp(tokenYAmount, totalLiquidity), tokenYReserve);
            }

            require(FixedPointMathLib.mulWadUp(tokenXAmount, tokenYReserve) == FixedPointMathLib.mulWadUp(tokenXReserve, tokenYAmount), "token reserve x,y");
            
            require(lpTokenCreated >= tokenMinimumOutputAmount, "Minimum liquidity not met."); 
            lpTokenCreated = (liquidityX < liquidityY) ? liquidityX : liquidityY;
            totalLiquidity += lpTokenCreated;
        }

        liquidity[msg.sender] += lpTokenCreated;
        tokenX.transferFrom(msg.sender, address(this), tokenXAmount);
        tokenY.transferFrom(msg.sender, address(this), tokenYAmount);

        _mint(address(msg.sender), lpTokenCreated);
    
        
        emit AddLiquidity(msg.sender, tokenXAmount, tokenYAmount);
        
        return lpTokenCreated;
    }

    function removeLiquidity(uint LPTokenAmount, uint minimumTokenXAmount, uint minimumTokenYAmount) external override nonReentrant returns (uint, uint) {
        require(LPTokenAmount > 0, "Amounts must be greater than zero.");    
        require((liquidity[msg.sender] >= LPTokenAmount) && (totalSupply() >= LPTokenAmount), "fficient liquidity."); 
        require((lpToken.balanceOf(msg.sender) >= LPTokenAmount), "Insufficient token."); 
        
        uint tokenXAmount = FixedPointMathLib.divWadUp(FixedPointMathLib.mulWadUp(LPTokenAmount, tokenX.balanceOf(address(this))), totalLiquidity);
        uint tokenYAmount = FixedPointMathLib.divWadUp(FixedPointMathLib.mulWadUp(LPTokenAmount, tokenY.balanceOf(address(this))), totalLiquidity);
        require(tokenXAmount >= minimumTokenXAmount && tokenYAmount >= minimumTokenYAmount, "Minimum liquidity not met."); 

        liquidity[msg.sender] -= LPTokenAmount; 
        totalLiquidity -= LPTokenAmount;    

        tokenX.transfer(msg.sender, tokenXAmount);
        tokenY.transfer(msg.sender, tokenYAmount);

        _burn(msg.sender, LPTokenAmount);
        emit RemoveLiquidity(msg.sender, tokenXAmount, tokenYAmount);
        
        return (tokenXAmount, tokenYAmount);
    }

    function swap(uint tokenXAmount, uint tokenYAmount, uint tokenMinimumOutputAmount) external override nonReentrant returns (uint) {
        require(tokenXAmount >= 0 || tokenYAmount >= 0, "Amounts must be greater than zero."); 
        require(tokenXAmount == 0 || tokenYAmount == 0, "Only one token can be swapped at a time."); 
        
    
        uint inputAmount;
        uint outputAmount;
        ERC20 inputToken;
        ERC20 outputToken;
        // x*fee->y
        if (tokenXAmount > 0) {
            inputAmount = tokenXAmount;
            inputToken = tokenX;
            outputToken = tokenY;
        // y*fee->x
        } else {
            inputAmount = tokenYAmount;
            inputToken = tokenY;
            outputToken = tokenX;
        }
        // 
        uint inputReserve = inputToken.balanceOf(address(this));
        uint outputReserve = outputToken.balanceOf(address(this));

        // Protocol Fee: 0.1% check (Pi = 0.1% ( = 10 bp) = ø = 0.999 = 99.9% )
        uint amountInMulFee = FixedPointMathLib.mulWadUp(inputAmount, (999));
        uint nm = FixedPointMathLib.mulWadUp(amountInMulFee, (outputReserve));
        uint dm = FixedPointMathLib.mulWadUp(inputReserve, 1000).add(amountInMulFee);

        outputAmount = FixedPointMathLib.divWadUp(nm, dm);


        require(outputAmount >= tokenMinimumOutputAmount, "Minimum output amount not met");

        inputToken.transferFrom(msg.sender, address(this), inputAmount);
        outputToken.transfer(msg.sender, outputAmount);

        emit Swap(msg.sender, inputAmount, outputAmount);
        return outputAmount;
    }

    function transfer(address to, uint256 lpAmount) public override(ERC20, IDex) returns (bool) {
        require(to != address(0), "ERC20: transfer to the zero address");
        require(lpToken.balanceOf(msg.sender) >= lpAmount, "Insufficient token.");
        require(lpAmount <= totalSupply(), "Insufficient liquidity.");

        liquidity[msg.sender] -= lpAmount;
        transfer(to, lpAmount);
        return true;
    }

    receive() external payable {
        revert("This contract does not accept ETH Only ERC20 tokens");
    }

}

