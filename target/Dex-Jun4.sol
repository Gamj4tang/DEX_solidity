// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
// console.log
import "forge-std/console.sol";

contract Dex is  ERC20{
    address private owner;
    address public token_x;
    address public token_y;
    uint public reserve_x;
    uint public reserve_y;
    uint public token_liquidity_L;
    uint public fee_y;
    uint public fee_x;

    function sqrt(uint y) public pure returns(uint z){
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
    constructor (address tokenX, address tokenY) ERC20("DRM", "DREAM_TOKEN"){
        require(tokenX != tokenY, "same token x, y");
        require(address(tokenX) != address(0) && address(tokenY) != address(0), "zero address token x or y");
        owner = msg.sender;
        token_x = tokenX;
        token_y = tokenY;
    }

    // imbalance check지우고 새로운 lp생성방법으로 변경
    // 만약 풀에 존재하는 페어의 가격이 변경된다면?
    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external returns (uint256 LPTokenAmount){
        require(tokenXAmount > 0, "tokenXAmount must exceed 0");
        require(tokenYAmount > 0, "tokenYAmount must exceed 0");
        require(ERC20(token_x).allowance(msg.sender, address(this)) >= tokenXAmount,"ERC20: insufficient allowance");
        require(ERC20(token_y).allowance(msg.sender, address(this)) >= tokenYAmount,"ERC20: insufficient allowance");
        require(ERC20(token_x).balanceOf(msg.sender) >= tokenXAmount,"ERC20: transfer amount exceeds balance");
        require(ERC20(token_y).balanceOf(msg.sender) >= tokenYAmount,"ERC20: transfer amount exceeds balance");
        
        // reserve를 항상 최신화
        reserve_x = ERC20(token_x).balanceOf(address(this));
        reserve_y = ERC20(token_y).balanceOf(address(this));
        
        // LP token 발급
        // uniswap v2 => 처음 이후 lp: 넣을 토큰의 개수 * 원래 있었던 lP수 / 토큰 넣기전 리저브
        // 그냥 dex에 transfer시 다음에 유동성 공급하는사람은 lp 지분에 손해를 보는 구조...?????
        uint token_amount;
        if(totalSupply() == 0){
            token_liquidity_L = sqrt(reserve_x * reserve_y);
            token_amount = sqrt((tokenXAmount * tokenYAmount));
        } else{
            token_amount = (tokenXAmount * 10  ** 18 * totalSupply() / reserve_x) / 10 ** 18;
        }
        require(token_amount > minimumLPTokenAmount, "token_amount > minimumLPTokenAmount");

        require(ERC20(token_x).transferFrom(msg.sender, address(this), tokenXAmount));
        require(ERC20(token_y).transferFrom(msg.sender, address(this), tokenYAmount));
        _mint(msg.sender, token_amount);

        return token_amount;
    }
    
    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external returns(uint rx, uint ry){
        // LPTokenAmount만큼을 가지고 있는지 체크
        // 굳이 minimuTokenXAmount가 0인지 확인해야 할까?? => 어차피 LP token 지분만큼 유동성 빼겠다는건데 흠..... 음수가 온다면?? => value out of bounds 나와서 상관없을듯?
        require(balanceOf(msg.sender) >= LPTokenAmount, "RemoveLiquidity exceeds balance check error");
        
        // uint stake = LPTokenAmount / totalSupply();
        reserve_x = ERC20(token_x).balanceOf(address(this));
        reserve_y = ERC20(token_y).balanceOf(address(this));
        rx = ((reserve_x * 10 ** 18) * LPTokenAmount / totalSupply()) / 10 ** 18;
        ry = ((reserve_y * 10 ** 18) * LPTokenAmount / totalSupply()) / 10 ** 18;

        require(rx >= minimumTokenXAmount, "RemoveLiquidity minimum return error");
        require(ry >= minimumTokenYAmount, "RemoveLiquidity minimum return error");
        console.log("%d", 1000 ether);
        console.log("%d, %d", reserve_x, reserve_y);
        _burn(msg.sender, LPTokenAmount);

        require(ERC20(token_x).transfer(msg.sender, rx));
        require(ERC20(token_y).transfer(msg.sender, ry));
    }
    
    // 처음 제공된 유동성이 곧 토큰의 가치 비율
    // fee가 리저브에 포함되어 있기 때문에 K를 계산할 때 빼준다.
    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount){
        require((tokenXAmount > 0 && tokenYAmount == 0 ) || (tokenYAmount > 0 && tokenXAmount == 0));
        reserve_x = ERC20(token_x).balanceOf(address(this)) - fee_x;
        reserve_y = ERC20(token_y).balanceOf(address(this)) - fee_y;
        
        uint tmp_reserve_y;
        uint tmp_reserve_x;
        // transferFrom에서 allowance, tokenAmount 체크를 해주긴 하는데, 굳이 allowance체크를 해야할까?
        // 스왑 이후의 X'
        // K / X' = Y'
        // 스왑 이후의 Y'
        // Y-Y' => 스왑으로 얻는 y토큰 => 수수료 0.1%
        // 여기서는 자리수 올려서 계산하는게 의미가 없는듯??????
        if(tokenXAmount == 0){
            require(ERC20(token_x).allowance(msg.sender, address(this)) >= tokenXAmount,"ERC20: insufficient allowance");
            
            tmp_reserve_y = reserve_y + tokenYAmount;
            tmp_reserve_x = (reserve_x * reserve_y) / tmp_reserve_y;
            outputAmount = (reserve_x - tmp_reserve_x) * 999 / 1000;
            fee_x += (reserve_x - tmp_reserve_x) / 1000;

            require(outputAmount >= tokenMinimumOutputAmount, "tokenMinimumOutputAmount");
            require(ERC20(token_y).transferFrom(msg.sender, address(this), tokenYAmount));
            require(ERC20(token_x).transfer(msg.sender, outputAmount));
        }else if(tokenYAmount == 0){
            require(ERC20(token_y).allowance(msg.sender, address(this)) >= tokenYAmount,"ERC20: insufficient allowance");
            
            tmp_reserve_x = reserve_x + tokenXAmount;
            tmp_reserve_y = (reserve_x * reserve_y) / tmp_reserve_x;
            outputAmount = (reserve_y - tmp_reserve_y) * 999 / 1000;
            fee_y += (reserve_y - tmp_reserve_y) / 1000;

            require(outputAmount >= tokenMinimumOutputAmount, "tokenMinimumOutputAmount");
            require(ERC20(token_x).transferFrom(msg.sender, address(this), tokenXAmount));
            require(ERC20(token_y).transfer(msg.sender, outputAmount));
        }
    }
}