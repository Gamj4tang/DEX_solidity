// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract Dex is ERC20 {
    ERC20 public tokenX;
    ERC20 public tokenY;

    uint256 public totalLiquidity;   // 토큰 유동성


    // [이벤트 정의]
    event AddLiquidity(address indexed provider, uint256 indexed tokenXAmount, uint256 indexed tokenYAmount);
    event RemoveLiquidity(address indexed remover, uint256 indexed tokenXAmount, uint256 indexed tokenYAmount);
    event Swap(address indexed trader, address indexed inputToken, address indexed outputToken, uint256 inputAmount, uint256 outputAmount);



    // [생성자]
    constructor(address _token1, address _token2) public ERC20("Dream Exchange Token", "DET") {
        tokenX = ERC20(_token1);
        tokenY = ERC20(_token2);
        totalLiquidity = 0;
    }


    // [유동성 공급]
    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external returns (uint256) {
        console.log("[+] addLiquidity()");
        
        require(tokenXAmount > 0);
        require(tokenYAmount > 0);

        uint256 LPTokenAmount = 0;

        if(totalLiquidity == 0) { 
            LPTokenAmount = sqrt((tokenXAmount) * (tokenYAmount));
        } else { 
            uint tokenXReserve = tokenX.balanceOf(address(this));
            uint tokenYReserve = tokenY.balanceOf(address(this));

            uint256 priceX = tokenXAmount * totalLiquidity / tokenXReserve;                 // LiquidityX / ReserveX
            uint256 priceY = tokenYAmount * totalLiquidity / tokenYReserve;                 // LiquidityY / ReserveY

            require(priceX == priceY);

            LPTokenAmount = priceX;
        }


        require(LPTokenAmount >= minimumLPTokenAmount );

        tokenX.transferFrom(msg.sender, address(this), tokenXAmount);
        tokenY.transferFrom(msg.sender, address(this), tokenYAmount);

        _mint(msg.sender, LPTokenAmount);
        totalLiquidity += LPTokenAmount;

        emit AddLiquidity(msg.sender, tokenXAmount, tokenYAmount);

        return LPTokenAmount;
    }


    // [유동성 제거]
    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external returns (uint, uint) {
        console.log("[+] removeLiquidity()");
        require(LPTokenAmount > 0);

        uint tokenXReserve = tokenX.balanceOf(address(this));
        uint tokenYReserve = tokenY.balanceOf(address(this));

        uint tokenXAmount = LPTokenAmount * tokenXReserve / totalLiquidity; 
        uint tokenYAmount = LPTokenAmount * tokenYReserve / totalLiquidity; 
        
        require(tokenXAmount >= minimumTokenXAmount && tokenYAmount >= minimumTokenYAmount); 
        require(totalLiquidity >= LPTokenAmount);
        require(balanceOf(msg.sender) >= LPTokenAmount);

        tokenX.transfer(msg.sender, tokenXAmount);
        tokenY.transfer(msg.sender, tokenYAmount);

        _burn(msg.sender, LPTokenAmount);
        totalLiquidity -= LPTokenAmount;    

        emit RemoveLiquidity(msg.sender, tokenXAmount, tokenYAmount);
        
        return (tokenXAmount, tokenYAmount);
    }


    // [환전]
    function swap(uint tokenXAmount, uint tokenYAmount, uint tokenMinimumOutputAmount) public returns (uint) {
        console.log("[+] swap()");
        require(tokenXAmount == 0 || tokenYAmount == 0);
        require((tokenXAmount > 0 && tokenYAmount == 0) || (tokenYAmount > 0 || tokenXAmount == 0));


        ERC20 inputToken;
        ERC20 outputToken;

        uint inputReserve;      // pool에 존재하는 입력토큰의 양
        uint outputReserve;     // pool에 존재하는 반환토큰의 양

        uint inputAmount;
        uint outputAmount;
        

        if (tokenXAmount == 0) {
            inputToken = tokenY;
            outputToken = tokenX;
            
            inputAmount = tokenYAmount;
        } else {
            inputToken = tokenX;
            outputToken = tokenY;
            
            inputAmount = tokenXAmount;
        }
        

        inputReserve = inputToken.balanceOf(address(this));
        outputReserve = outputToken.balanceOf(address(this));

        outputAmount = (outputReserve - (inputReserve * outputReserve / (inputReserve + inputAmount))) * 999 / 1000;

        require(outputAmount >= tokenMinimumOutputAmount);
        require(outputToken.balanceOf(address(this)) >= outputAmount);            
        require(inputToken.allowance(msg.sender, address(this)) >= inputAmount); 

        inputToken.transferFrom(msg.sender, address(this), inputAmount);
        outputToken.transfer(msg.sender, outputAmount);


        emit Swap(msg.sender, address(inputToken), address(outputToken), inputAmount, outputAmount);


        return outputAmount;
    }


    // 전체 유동성에는 변화가 없어야 한다.
    function transfer(address to, uint256 tokenAmount) override public returns (bool){
        require(to != address(0));
        require(to != address(this));

        
        require(balanceOf(msg.sender) >= tokenAmount);
        _transfer(msg.sender, to, tokenAmount);
        
        return true;
    }


    // 계산 관련 라이브러리
    // https://github.com/Uniswap/solidity-lib/blob/master/contracts/libraries/Babylonian.sol
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        // this block is equivalent to r = uint256(1) << (BitMath.mostSignificantBit(x) / 2);
        // however that code costs significantly more gas
        uint256 xx = x;
        uint256 r = 1;
        if (xx >= 0x100000000000000000000000000000000) {
            xx >>= 128;
            r <<= 64;
        }
        if (xx >= 0x10000000000000000) {
            xx >>= 64;
            r <<= 32;
        }
        if (xx >= 0x100000000) {
            xx >>= 32;
            r <<= 16;
        }
        if (xx >= 0x10000) {
            xx >>= 16;
            r <<= 8;
        }
        if (xx >= 0x100) {
            xx >>= 8;
            r <<= 4;
        }
        if (xx >= 0x10) {
            xx >>= 4;
            r <<= 2;
        }
        if (xx >= 0x8) {
            r <<= 1;
        }
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1; 

        uint256 r1 = x / r;

        return (r < r1 ? r : r1);
    }
}