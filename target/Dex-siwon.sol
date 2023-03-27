pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/utils/math/Math.sol";
// console.log
import "forge-std/console.sol";
contract Dex is ERC20 {
    address tokenX_contract;
    address tokenY_contract;
    uint tokenX_in_LP;
    uint tokenY_in_LP;
    ERC20 tokenX;
    ERC20 tokenY;
    bool first_LP;
    uint decimal;

    constructor(address _tokenX_contract, address _tokenY_contract) ERC20("LPToken", "LP") {
        tokenX_contract = _tokenX_contract;
        tokenY_contract = _tokenY_contract;
        tokenX = ERC20(tokenX_contract);
        tokenY = ERC20(tokenY_contract);
        decimal = 10 ** 18;
        first_LP = true;
    }
    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) public returns (uint256 LPTokenAmount){
        require(!(tokenXAmount == 0 && tokenYAmount == 0), "AddLiquidity invalid initialization check error - 1");
        require(tokenXAmount != 0, "AddLiquidity invalid initialization check error - 2");
        require(tokenYAmount != 0, "AddLiquidity invalid initialization check error - 3");
        require(tokenX.allowance(msg.sender, address(this)) >= tokenXAmount, "ERC20: insufficient allowance");
        require(tokenY.allowance(msg.sender, address(this)) >= tokenYAmount, "ERC20: insufficient allowance");
        require(tokenX.balanceOf(msg.sender) >= tokenXAmount, "ERC20: transfer amount exceeds balance");
        require(tokenY.balanceOf(msg.sender) >= tokenYAmount, "ERC20: transfer amount exceeds balance");
        
        tokenX_in_LP = tokenX.balanceOf(address(this));
        tokenY_in_LP = tokenY.balanceOf(address(this));

        if(first_LP){
            LPTokenAmount = Math.sqrt((tokenXAmount + tokenX_in_LP) * (tokenYAmount + tokenY_in_LP) / decimal);
            first_LP = false;
        }
        else{
            console.log("[add] tokenX_in_LP: %s", tokenX_in_LP);
            console.log("[add] tokenY_in_LP: %s", tokenY_in_LP);
            console.log("[add] tokenXAmount: %s", tokenXAmount);
            console.log("[add] tokenYAmount: %s", tokenYAmount);
            console.log("[add] totalSupply: %s", totalSupply());

            require(tokenX_in_LP * tokenYAmount == tokenY_in_LP * tokenXAmount, "AddLiquidity imbalance add liquidity test error");
            LPTokenAmount = Math.min(
                totalSupply() * tokenXAmount / tokenX_in_LP,
                totalSupply() * tokenYAmount / tokenY_in_LP
            );
        }
        require(LPTokenAmount >= minimumLPTokenAmount, "AddLiquidity minimum LP return Error");
        _mint(msg.sender, LPTokenAmount);
        tokenX_in_LP += tokenXAmount;
        tokenY_in_LP += tokenYAmount;
        tokenX.transferFrom(msg.sender, address(this), tokenXAmount);
        tokenY.transferFrom(msg.sender, address(this), tokenYAmount);
        return LPTokenAmount;
    }
    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) public returns(uint, uint){
        require(balanceOf(msg.sender) >= LPTokenAmount, "RemoveLiquidity exceeds balance check error");
        tokenX_in_LP = tokenX.balanceOf(address(this));
        tokenY_in_LP = tokenY.balanceOf(address(this));
        console.log("[remove] tokenX_in_LP: %s", tokenX_in_LP);
        console.log("[remove] tokenY_in_LP: %s", tokenY_in_LP);
        console.log("[remove] totalSupply: %s", totalSupply());
        console.log("[remove] LPTokenAmount: %s", LPTokenAmount);
        console.log("[remove] minimumTokenXAmount: %s", minimumTokenXAmount);
        console.log("[remove] minimumTokenYAmount: %s", minimumTokenYAmount);

        uint remove_tokenXAmount_in_LP = tokenX_in_LP * LPTokenAmount / totalSupply();
        uint remove_tokenYAmount_in_LP = tokenY_in_LP * LPTokenAmount / totalSupply();
        require(remove_tokenXAmount_in_LP >= minimumTokenXAmount, "RemoveLiquidity minimum return error");
        require(remove_tokenYAmount_in_LP >= minimumTokenYAmount, "RemoveLiquidity minimum return error");
        _burn(msg.sender, LPTokenAmount);
        tokenX_in_LP -= remove_tokenXAmount_in_LP;
        tokenY_in_LP -= remove_tokenYAmount_in_LP;
        tokenX.transfer(msg.sender, remove_tokenXAmount_in_LP);
        tokenY.transfer(msg.sender, remove_tokenYAmount_in_LP);
        return (remove_tokenXAmount_in_LP, remove_tokenYAmount_in_LP);
    }


// SWAP logic
// (totalX + deltaX)(totalY - deltaY) = totalX * totalY = k
// ...
// deltaY = totalY - (totalX * totalY) / (totalX + deltaX)
// deltaY = totalY * (1 - totalX / (totalX + deltaX))
// deltaY = totalY * deltaX / (totalX + deltaX)

    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) public returns (uint256 outputAmount){
        require(!(tokenXAmount == 0 && tokenYAmount == 0), "invalid input");
        require(!(tokenXAmount != 0 && tokenYAmount != 0), "invalid input");

        tokenX_in_LP = tokenX.balanceOf(address(this));
        tokenY_in_LP = tokenY.balanceOf(address(this));
        
        if(tokenXAmount != 0){
            outputAmount = tokenY_in_LP * (tokenXAmount * 999 / 1000) / (tokenX_in_LP + (tokenXAmount * 999 / 1000));

            require(outputAmount >= tokenMinimumOutputAmount, "minimum ouput amount check failed");
            tokenY_in_LP -= outputAmount ;
            tokenX_in_LP += tokenXAmount;
            tokenX.transferFrom(msg.sender, address(this), tokenXAmount);
            tokenY.transfer(msg.sender, outputAmount );
        }
        else{
            outputAmount = tokenX_in_LP * (tokenYAmount * 999 / 1000) / (tokenY_in_LP + (tokenYAmount * 999 / 1000));

            require(outputAmount >= tokenMinimumOutputAmount, "minimum ouput amount check failed");
            tokenX_in_LP -= outputAmount;
            tokenY_in_LP += tokenXAmount;
            tokenY.transferFrom(msg.sender, address(this), tokenYAmount);
            tokenX.transfer(msg.sender, outputAmount);
        }
        return outputAmount;
    }
    function transfer(address to, uint256 lpAmount) public virtual override returns (bool){}

}