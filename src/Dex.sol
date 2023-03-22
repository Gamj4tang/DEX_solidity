
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IDex.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

/**
 * @title DEX STUDY
 * @author @Gamj4tang
 * @notice CPMM (xy=k) 방식의 AMM을 사용하는 DEX를 구현하세요.
 * 
 */
contract Dex is IDex, ERC20, ReentrancyGuard {
    ERC20 public tokenX;
    ERC20 public tokenY;
    ERC20 public lpToken;

    uint8 constant TOKEN_DECIMALS = 18;

    uint public totalLiquidity;
    mapping(address => uint) public liquidity; // @Gamj4tang 사용자 유동성 추적용

    constructor(address _tokenX, address _tokenY) ERC20("LPToken", "LPT")  {
        tokenX = ERC20(_tokenX);
        tokenY = ERC20(_tokenY);
        lpToken = ERC20(address(this));
    }

    /**
     * @dev ERC-20 기반 LP 토큰을 사용해야 합니다. 수수료 수입과 Pool에 기부된 금액을 제외하고는 더 많은 토큰을 회수할 수 있는 취약점이 없어야 합니다. Concentrated Liquidity는 필요 없습니다.
     * deadline?
     * @param tokenXAmount 토큰 X의 수량
     * @param tokenYAmount 토큰 Y의 수량
     * @param tokenMinimumOutputAmount 토큰 
     */
    function addLiquidity(uint tokenXAmount, uint tokenYAmount, uint tokenMinimumOutputAmount) external override nonReentrant returns (uint) {
        require(tokenXAmount > 0 && tokenYAmount > 0, "Amounts must be greater than zero.");    // @Gamj4tang ✅ test
        
        uint lpTokenCreated;
        uint tokenXReserve;
        uint tokenYReserve;
        uint liquidityX;
        uint liquidityY;

        if (totalLiquidity == 0) {
            // 정밀도 
            lpTokenCreated = _sqrt(tokenXAmount * tokenYAmount); // @Gamj4tang CPMM 모델 기반 a:b = b:√(a*b), 따로 유틸 로?
            require(lpTokenCreated >= tokenMinimumOutputAmount, "Minimum liquidity not met."); // @Gamj4tang ✅ test
            totalLiquidity = lpTokenCreated;
        } else {
            {
                tokenXReserve = tokenX.balanceOf(address(this));
                tokenYReserve = tokenY.balanceOf(address(this));
            
                // @Gamj4tang 정수 취약성 추가 검중?, 유동성 비례 b:√(a*b) 계산 
                // L_x = X*P_x, L_y = Y*P_y (유동성 가치의 토큰 가치 비례) => P_x = L_x/X
                liquidityX = _div(_mul(tokenXAmount, totalLiquidity), tokenXReserve);
                liquidityY = _div(_mul(tokenYAmount, totalLiquidity), tokenYReserve);
    
    
            }
            // 최소 수량 유동성 공급 검증
            lpTokenCreated = (liquidityX < liquidityY) ? liquidityX : liquidityY;
            require(lpTokenCreated >= tokenMinimumOutputAmount, "Minimum liquidity not met."); // @Gamj4tang ✅ test
            totalLiquidity += lpTokenCreated;
        }

        liquidity[msg.sender] += lpTokenCreated;
        tokenX.transferFrom(msg.sender, address(this), tokenXAmount);
        tokenY.transferFrom(msg.sender, address(this), tokenYAmount);

        transfer(msg.sender, lpTokenCreated);
        emit AddLiquidity(msg.sender, tokenXAmount, tokenYAmount);
        // @Gamj4tang 유동성 공급시 LP 토큰이 CPMM 모델 구조에 따라 비율 검증, 유동성 공금, 프로토콜 도네일 경우만 유동성 공급 처리 
        return lpTokenCreated;
    }

    /**
     * @dev ERC-20 기반 LP 토큰을 사용해야 합니다. 수수료 수입과 Pool에 기부된 금액을 제외하고는 더 많은 토큰을 회수할 수 있는 취약점이 없어야 합니다. Concentrated Liquidity는 필요 없습니다.
     * @param LPTokenAmount 공급 받은 LP 토큰의 수량
     * @param minimumTokenXAmount 최소 토큰 X의 수량
     * @param minimumTokenYAmount 최소 토큰 Y의 수량
     * @return 토큰 공급량 
     * @return 
     */
    function removeLiquidity(uint LPTokenAmount, uint minimumTokenXAmount, uint minimumTokenYAmount) external override nonReentrant returns (uint, uint) {
        require(LPTokenAmount > 0, "Amounts must be greater than zero.");    // @Gamj4tang ✅ test
        require(liquidity[msg.sender] >= LPTokenAmount, "Insufficient liquidity."); // @Gamj4tang ✅ test
        // 유동성 기반 토큰 가격, => P_x = L_x/X ,  P_y = L_y/Y 
        uint tokenXAmount = _div(_mul(LPTokenAmount, tokenX.balanceOf(address(this))), totalLiquidity); // $(\sqrt{(t_x * t_y)} *t_x) / total(t_x) = LP_x$ => 토큰 페어 검증 조건 성립, 계산
        uint tokenYAmount = _div(_mul(LPTokenAmount, tokenY.balanceOf(address(this))), totalLiquidity); // $t_x = (LP*total_{t_x}) / LP_f)$, $t_y = (LP*total_{t_y}) / LP_f)$
        require(tokenXAmount >= minimumTokenXAmount && tokenYAmount >= minimumTokenYAmount, "Minimum liquidity not met."); // @Gamj4tang ✅ test

        liquidity[msg.sender] -= LPTokenAmount; // @Gamj4tang 사용자 유동성 추적 상태 업데이트
        totalLiquidity -= LPTokenAmount;    // 전체 유동성 업데이트

        tokenX.transfer(msg.sender, tokenXAmount);
        tokenY.transfer(msg.sender, tokenYAmount);

        _burn(msg.sender, LPTokenAmount);
        emit RemoveLiquidity(msg.sender, tokenXAmount, tokenYAmount);
        
        return (tokenXAmount, tokenYAmount);
    }

    /**
     * @dev
     *  - Pool 생성 시 지정된 두 종류의 토큰을 서로 교환할 수 있어야 합니다. Input 토큰과 Input 수량, 최소 Output 요구량을 받아서 Output 토큰으로 바꿔주고 최소 요구량에 미달할 경우 revert 해야합니다. 수수료는 0.1%로 하세요.
     *  - tokenXAmount / tokenYAmount 중 하나는 무조건 0이어야 합d니다. 수량이 0인 토큰으로 스왑됨.
     *  - 스왑 과정중에 유동성은 변하면 안됨!!
     *  - Protocol Fee: 0.1% check (Pi = 0.1% ( = 10 bp) = ø = 0.999 = 99.9% )
     * @param tokenXAmount 토큰 X의 수량
     * @param tokenYAmount 토큰 Y의 수량
     * @param tokenMinimumOutputAmount 최소 토큰 출력 수량
     */
    function swap(uint tokenXAmount, uint tokenYAmount, uint tokenMinimumOutputAmount) external override nonReentrant returns (uint) {
        require(tokenXAmount >= 0 || tokenYAmount >= 0, "Amounts must be greater than zero."); // @Gamj4tang ✅ test
        require(tokenXAmount == 0 || tokenYAmount == 0, "Only one token can be swapped at a time."); // @Gamj4tang ✅ test
    
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
        uint amountInMulFee = _mul(inputAmount, (999));
        uint nm = _mul(amountInMulFee, (outputReserve));
        uint dm = _add(_mul(inputReserve, 1000), amountInMulFee);

        outputAmount = _div(nm, dm);


        require(outputAmount >= tokenMinimumOutputAmount, "Minimum output amount not met");

        inputToken.transferFrom(msg.sender, address(this), inputAmount);
        outputToken.transfer(msg.sender, outputAmount);

        emit Swap(msg.sender, inputAmount, outputAmount);
        return outputAmount;
    }

    /**
     * @dev 테스트 중
     * @param to 유동성 토큰을 받을 주소
     * @param lpAmount : 유동성 토큰의 수량
     */
    function transfer(address to, uint256 lpAmount) public override(ERC20, IDex) returns (bool) {
        _mint(to, lpAmount);
        return true;
    }

    /**
     * @dev ERC-20 토큰을 받을 수 있어야 합니다. ETH를 바로 받을 수 없도록 구현 
     */
    receive() external payable {
        revert("This contract does not accept ETH Only ERC20 tokens");
    }

    /**
     * @dev overflow? check?
     * @param x 제곱근을 구할 숫자
     */
    function _sqrt(uint x) internal pure returns (uint) {
        uint z = _div(_add(x, 1), 2);
        uint y = x;
        while (z < y) {
            y = z;
            z = _div(_add(_div(x, z), z), 2);
        }
        return y;
    }
    

    /**
     * safe Math
     */
    function _mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function _div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        return c;
    }

    function _sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;
        return c;
    }

    function _add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
}

