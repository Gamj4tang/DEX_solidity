
pragma solidity ^0.8.0;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract Dex is ERC20{
    ERC20 public tokenX;
    ERC20 public tokenY;
    ERC20 public LPToken;
    uint256 public totalSupply_ = totalSupply();
    uint8 constant _decimals = 18;
    uint private amountX;
    uint private amountY;

    constructor(address addrX, address addrY) ERC20("LPtoken","LPT"){
        tokenX = ERC20(addrX);
        tokenY = ERC20(addrY);
        LPToken = ERC20(address(this));
    }
    function transfer_(address to, uint256 lpAmount) internal virtual returns (bool){
        _mint(to, lpAmount);
        return true;
}

function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) public returns (uint256 LPTokenAmount){
    require(tokenXAmount > 0, "Less TokenA Supply");
    require(tokenYAmount > 0, "Less TokenB Supply");
    require(tokenX.allowance(msg.sender, address(this)) >= tokenXAmount, "ERC20: insufficient allowance");
    require(tokenY.allowance(msg.sender, address(this)) >= tokenYAmount, "ERC20: insufficient allowance");
    uint256 liqX; //liquidity of x
    uint256 liqY; //liquidity of y
    amountX = tokenX.balanceOf(address(this));// token X amount udpate
    amountY = tokenY.balanceOf(address(this));// token Y amount update
    
    if(totalSupply_ ==0 ){ //if first supply 
        LPTokenAmount = _sqrt(tokenXAmount*tokenYAmount);
    }
    else{// calculate over the before
        liqX = _mul(tokenXAmount ,totalSupply_)/amountX;
        liqY = _mul(tokenYAmount ,totalSupply_)/amountY;
        LPTokenAmount = (liqX<liqY) ? liqX:liqY; 
    }
    require(LPTokenAmount >= minimumLPTokenAmount, "Less LP Token Supply");
    transfer_(msg.sender,LPTokenAmount);
    totalSupply_ += LPTokenAmount;
    amountX += tokenXAmount;
    amountY += tokenYAmount;
    tokenX.transferFrom(msg.sender, address(this), tokenXAmount);
    tokenY.transferFrom(msg.sender, address(this), tokenYAmount);
    return LPTokenAmount;
}

function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) public returns (uint256 tokenXAmount_,uint256 tokenYAmount_){
    require(LPTokenAmount > 0, "Less LP Token Supply");
    amountX = tokenX.balanceOf(address(this));// token X amount udpate
    amountY = tokenY.balanceOf(address(this));// token Y amount update
    tokenXAmount_ = _mul(amountX,LPTokenAmount)/totalSupply_;
    tokenYAmount_ = _mul(amountY,LPTokenAmount)/totalSupply_;
    require(tokenXAmount_ >= minimumTokenXAmount, "TokenX amount below minimum");
    require(tokenYAmount_ >= minimumTokenYAmount, "TokenY amount below minimum");
    amountX -= tokenXAmount_;
    amountY -= tokenYAmount_;
    _burn(msg.sender,LPTokenAmount);
    tokenX.transfer(msg.sender,tokenXAmount_);
    tokenY.transfer(msg.sender,tokenYAmount_);

    return (tokenXAmount_,tokenYAmount_);
 
}
function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outAmount){
    //x*y=k, => if x-> y
    //x*y =k = > (X+x)(Y-y) =K
    // => xY -Xy -xy = 0
    // y = (X+x)/xY
    // y= 0.999x + X /0.999xY
    require(tokenXAmount > 0 || tokenYAmount > 0, "no zero.");
    require(tokenXAmount == 0 || tokenYAmount == 0, "only one");
    amountX = tokenX.balanceOf(address(this));// token X amount udpate
    amountY = tokenY.balanceOf(address(this));// token Y amount update
    require(amountX > 0 && amountY >0,"no token");
    uint256 outAmount;
    if(tokenXAmount > 0){
        outAmount = amountY *(tokenXAmount * 999 /1000) / (amountX + (tokenXAmount * 999 / 1000));
        require(outAmount >= tokenMinimumOutputAmount);
    amountY -= outAmount;
    amountX += tokenXAmount;
    tokenX.transferFrom(msg.sender,address(this),tokenXAmount);
    tokenY.transfer(msg.sender,outAmount);
    }
    else{
        outAmount =  amountX *(tokenYAmount * 999 /1000) / (amountY+ (tokenYAmount * 999 / 1000));
        require(outAmount >= tokenMinimumOutputAmount);
        amountX -= outAmount;
        amountY += tokenYAmount;
        tokenY.transferFrom(msg.sender,address(this),tokenYAmount);
        tokenX.transfer(msg.sender,outAmount);

    }
    return outAmount;
}


function _sqrt(uint x) public pure returns (uint y) {
    uint z = (x + 1) / 2;
    y = x;
    while (z < y) {
        y = z;
        z = (x / z + z) / 2;
    }
}

function _mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
}