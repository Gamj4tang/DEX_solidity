// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * CLIENT Required reutrn?
- function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount);
    - tokenXAmount / tokenYAmount 중 하나는 무조건 0이어야 합니다. 수량이 0인 토큰으로 스왑됨.
- function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external returns (uint256 LPTokenAmount);
- function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external;
- function transfer(address to, uint256 lpAmount) external returns (bool);
 */

interface IDex {
    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount);
    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external returns (uint256 LPTokenAmount);
    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external returns(uint256 tokenXAmount, uint256 tokenYAmount);
    function transfer(address to, uint256 lpAmount) external returns (bool);

    // event
    event AddLiquidity(address indexed provider, uint indexed amountX, uint indexed amountY);
    event RemoveLiquidity(address indexed provider, uint indexed amountX, uint indexed amountY);
    event Swap(address indexed trader, uint indexed inputAmount, uint indexed outputAmount);
}




