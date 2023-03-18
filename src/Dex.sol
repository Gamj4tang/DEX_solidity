
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IDex.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

/**
 * @title DEX STUDY
 * @author @Gamj4tang
 * @notice CPMM (xy=k) 방식의 AMM을 사용하는 DEX를 구현하세요.
 */
contract Dex is IDex, ERC20 {
    ERC20 public tokenX;
    ERC20 public tokenY;
    ERC20 public lpToken;

    uint public totalLiquidity;
    mapping(address => uint) public liquidity; // @Gamj4tang 사용자 유동성 추적용

    constructor(address _tokenX, address _tokenY) ERC20("LPToken", "LPT")  {
        tokenX = ERC20(_tokenX);
        tokenY = ERC20(_tokenY);
    }

    /**
     * @dev ERC-20 기반 LP 토큰을 사용해야 합니다. 수수료 수입과 Pool에 기부된 금액을 제외하고는 더 많은 토큰을 회수할 수 있는 취약점이 없어야 합니다. Concentrated Liquidity는 필요 없습니다.
     * @param tokenXAmount 토큰 X의 수량
     * @param tokenYAmount 토큰 Y의 수량
     * @param tokenMinimumOutputAmount 토큰 
     */
    function addLiquidity(uint tokenXAmount, uint tokenYAmount, uint tokenMinimumOutputAmount) external override returns (uint) {
        require(tokenXAmount > 0 && tokenYAmount > 0, "Amounts must be greater than zero.");    // @Gamj4tang ✅ test
        uint lpTokenCreated;
        if (totalLiquidity == 0) {
            lpTokenCreated = sqrt(tokenXAmount * tokenYAmount); // @Gamj4tang CPMM 모델 기반 a:b = b:√(a*b), 따로 유틸 로?
            require(lpTokenCreated >= tokenMinimumOutputAmount, "Minimum liquidity not met."); // @Gamj4tang ✅ test
            totalLiquidity = lpTokenCreated;
        } else {
            // @Gamj4tang 정수 취약성 추가 검중?, 유동성 비례 b:√(a*b) 계산 
            uint liquidityX = tokenXAmount * totalLiquidity / tokenX.balanceOf(address(this));
            uint liquidityY = tokenYAmount * totalLiquidity / tokenY.balanceOf(address(this));
            console.log("liquidityX: %s", liquidityX);  
            console.log("liquidityY: %s", liquidityY);

            lpTokenCreated = (liquidityX < liquidityY) ? liquidityX : liquidityY;
            require(lpTokenCreated >= tokenMinimumOutputAmount, "Minimum liquidity not met."); // @Gamj4tang ✅ test
            totalLiquidity += lpTokenCreated;
        }
        console.log("lpTokenCreated: %s", lpTokenCreated);

        liquidity[msg.sender] += lpTokenCreated;
        tokenX.transferFrom(msg.sender, address(this), tokenXAmount);
        tokenY.transferFrom(msg.sender, address(this), tokenYAmount);

        _mint(msg.sender, lpTokenCreated);
        emit AddLiquidity(msg.sender, tokenXAmount, tokenYAmount);
        // @Gamj4tang 유동성 공급시 LP 토큰이 CPMM 모델 구조에 따라 비율 검증, 유동성 공금, 프로토콜 도네일 경우만 유동성 공급 처리 
        return lpTokenCreated;
    }

    function removeLiquidity(uint LPTokenAmount, uint minimumTokenXAmount, uint minimumTokenYAmount) external override returns (uint, uint) {
        uint tokenXAmount = 0x1337;
        uint tokenYAmount = 0x1337;

        return (tokenXAmount, tokenYAmount);
    }

    function swap(uint tokenXAmount, uint tokenYAmount, uint tokenMinimumOutputAmount) external override returns (uint) {
        uint outputAmount = 0x1337;
    
        return outputAmount;
    }

    /**
     * @dev overflow? check?
     * @param x 제곱근을 구할 숫자
     */
    function sqrt(uint x) private pure returns (uint) {
        uint z = (x + 1) / 2;
        uint y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

}

