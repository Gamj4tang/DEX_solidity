
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IDex.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract Dex is IDex {
    ERC20 public tokenX;
    ERC20 public tokenY;

    
    constructor(address _tokenX, address _tokenY) {
        tokenX = ERC20(_tokenX);
        tokenY = ERC20(_tokenY);
    }
    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount) {
        outputAmount = 0x1337;
        emit Swap(msg.sender, msg.sender, outputAmount);
    }
    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external returns (uint256 LPTokenAmount) {
        LPTokenAmount = 0x1337;
        emit AddLiquidity(msg.sender, LPTokenAmount);
        
    }
    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external returns(uint256 tokenXAmount, uint256 tokenYAmount) {
        tokenXAmount = 0x1337;
        tokenYAmount = 0x1337;

    }
    function transfer(address to, uint256 lpAmount) external returns (bool) {
        return true;
        
    }
    
}

