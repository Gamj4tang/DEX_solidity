// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
// console.log
import "forge-std/console.sol";

contract Dex is ERC20 {
    address _addrX;
    address _addrY;
    uint _amountX;
    uint _amountY;
    ERC20 _tokenX;
    ERC20 _tokenY;

    uint _decimal;
    // might need this if both Token Decimals are not 18
    // uint _decimalX;
    // uint _decimalY;

    constructor(address addrX, address addrY) ERC20("LPToken", "LP") {
        _addrX = addrX;
        _addrY = addrY;
        _tokenX = ERC20(_addrX);
        _tokenY = ERC20(_addrY);
        _decimal = 10 ** 18;
    }

    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) public returns (uint256){
        require(((tokenXAmount == 0) && (tokenYAmount > 0)) || ((tokenXAmount > 0) && (tokenYAmount == 0)), "only one amount should be zero");
        require(_amountX > 0 && _amountY > 0, "no token to swap");

        updateTokenBalance();
        
        uint256 amount_;
        if(tokenXAmount > 0){
            amount_ = _amountY * (tokenXAmount * 999 / 1000) / (_amountX + (tokenXAmount * 999 / 1000));
            
            require(amount_ >= tokenMinimumOutputAmount, "less than minimum swap amount");
            _amountY -= amount_ ;
            _amountX += tokenXAmount;
            _tokenX.transferFrom(msg.sender, address(this), tokenXAmount);
            _tokenY.transfer(msg.sender, amount_ );
        }
        else{
            amount_ = _amountX * (tokenYAmount * 999 / 1000) / (_amountY + (tokenYAmount * 999 / 1000));

            require(amount_ >= tokenMinimumOutputAmount, "less than minimum swap amount");
            _amountX -= amount_;
            _amountY += tokenXAmount;
            _tokenY.transferFrom(msg.sender, address(this), tokenYAmount);
            _tokenX.transfer(msg.sender, amount_);
        }
        return amount_;
    }
    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) public returns (uint256){
        require(tokenXAmount > 0, "token x amount is 0");
        require(tokenYAmount > 0, "token y amount is 0");
        require(_tokenX.allowance(msg.sender, address(this)) >= tokenXAmount, "ERC20: insufficient allowance");
        require(_tokenY.allowance(msg.sender, address(this)) >= tokenYAmount, "ERC20: insufficient allowance");
        require(_tokenX.balanceOf(msg.sender) >= tokenXAmount, "ERC20: transfer amount exceeds balance");
        require(_tokenY.balanceOf(msg.sender) >= tokenYAmount, "ERC20: transfer amount exceeds balance");
        
        updateTokenBalance();

        // what if _amountX/_amountY and tokenXAmount/tokenYAmount is different?
        uint lpAmount;
        if(totalSupply() == 0){
            lpAmount = tokenXAmount * tokenYAmount / _decimal; // is amount best? no overflow?
        }
        else{
            require(_decimal * tokenXAmount / tokenYAmount == _decimal * _amountX / _amountY, "amount breaks the pool ratio");
            lpAmount = totalSupply() * tokenXAmount / _amountX;
        }
        require(lpAmount >= minimumLPTokenAmount, "less than minimum lp token amount");
        _amountX += tokenXAmount;
        _amountY += tokenYAmount;
        _tokenX.transferFrom(msg.sender, address(this), tokenXAmount);
        _tokenY.transferFrom(msg.sender, address(this), tokenYAmount);
        _mint(msg.sender, lpAmount);
        return lpAmount;
    }
    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) public returns(uint, uint){
        require(balanceOf(msg.sender) >= LPTokenAmount, "more remove than owning");
        updateTokenBalance();
        // console.log("totalSupply: %s", totalSupply());
        // console.log("LPTokenAmount: %s", LPTokenAmount);
        // console.log("amountX: %s", _amountX);
        // console.log("amountY: %s", _amountY);
        
        uint returnAmountX = _amountX * LPTokenAmount / totalSupply();
        uint returnAmountY = _amountY * LPTokenAmount / totalSupply();
        // console.log("returnAmountX: %s", returnAmountX);
        // console.log("returnAmountY: %s", returnAmountY);
        require(returnAmountX >= minimumTokenXAmount, "less than minimum tokenX amount");
        require(returnAmountY >= minimumTokenYAmount, "less than minimum tokenY amount");
        _amountX -= returnAmountX;
        _amountY -= returnAmountY;
        _burn(msg.sender, LPTokenAmount);
        _tokenX.transfer(msg.sender, returnAmountX);
        _tokenY.transfer(msg.sender, returnAmountY);
        return (returnAmountX, returnAmountY);
    }
    function transfer(address to, uint256 lpAmount) override public returns (bool){
        require(to != address(0), "no transfer allowed to address 0");
        require(balanceOf(msg.sender) >= lpAmount, "more remove than owning");
        if(to == address(this)){
            _burn(msg.sender, lpAmount);
        }
        else{
            _transfer(msg.sender, to, lpAmount);
        }
        return true;
    }

    function updateTokenBalance() internal { // might be donated tokens
        _amountX = _tokenX.balanceOf(address(this));
        _amountY = _tokenY.balanceOf(address(this));
    }
}