// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract Dex is ERC20 {
    ERC20 public tokenX;
    ERC20 public tokenY;
    uint256 tokenXpool;
    uint256 tokenYpool;
    uint256 _amountLPT;

    constructor(address _tokenX, address _tokenY) ERC20("LPT", "LPT") {
        tokenX = ERC20(_tokenX);
        tokenY = ERC20(_tokenY);        
    }

    /*
    * Swap
    * Pool 생성 시 지정된 두 종류의 토큰을 서로 교환할 수 있어야 합니다.
    * Input 토큰과 Input 수량, 최소 Output 요구량을 받아서 Output 토큰으로 바꿔주고
    * 최소 요구량에 미달할 경우 revert 해야합니다. 수수료는 0.1%로 하세요
    * tokenXAmount / tokenYAmount 중 하나는 무조건 0이어야 합니다.
    * 수량이 0인 토큰으로 스왑됨
    */
    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount){
        //둘 중 하나는 무조건 0이어야 함
        require(tokenXAmount == 0 || tokenYAmount == 0, "must have 0 amount token");
        require(tokenXpool > 0 && tokenYpool > 0, "can't swap");

        update();

        /* tokenXAmount가 0
        * 사용자 기준 : y를 주고 x를 받아오는 것
        * dex 기준 : y를 받고 x를 돌려주는 것
        * xy = (x-dx)(y+dy) -> dx = (x * dy) / (y + dy)
        */
        if(tokenXAmount == 0) {      
            // 선행 수수료
            outputAmount = (tokenXpool * (tokenYAmount * 999 / 1000)) / (tokenYpool + (tokenYAmount * 999 / 1000));
            
            // 최소값 검증
            require(outputAmount >= tokenMinimumOutputAmount, "less than Minimum");

            // output만큼 빼주고 받아온만큼 더해주기
            tokenXpool -= outputAmount;
            tokenYpool += tokenYAmount;

            // 보내기
            tokenY.transferFrom(msg.sender, address(this), tokenYAmount);
            tokenX.transfer(msg.sender, outputAmount);
        } 
        /* tokenXAmount가 0이 아니면? -> tokenYAmount가 0일 것
        * 사용자 기준 : x를 주고 y를 받아오는 것
        * dex 기준 : x를 받고 y를 돌려주는 것
        * xy = (x+dx)(y-dy) -> (y * dx) / (x + dx)
        */
        else {
            outputAmount = (tokenYpool * (tokenXAmount * 999 / 1000)) / (tokenXpool + (tokenXAmount * 999 / 1000));

            require(outputAmount >= tokenMinimumOutputAmount, "less than Minimum");

            tokenYpool -= outputAmount;
            tokenXpool += tokenXAmount;

            tokenX.transferFrom(msg.sender, address(this), tokenXAmount);
            tokenY.transfer(msg.sender, outputAmount);
        }
}

    /*
    * addLiquidit
    * ERC-20 기반 LP 토큰을 사용해야 합니다. 
    */ 
    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external returns (uint256 LPTokenAmount){
        // 0개 공급은 안됨
        require(tokenXAmount > 0, "tokenXAmount is 0");
        require(tokenYAmount > 0, "tokenYAmount is 0");
        // msg.sender가 dex한테 tokenX와 tokenB에 대한 권한을 줘야함 -> pool에 공급하는 양 만큼!
        require(tokenX.allowance(msg.sender, address(this)) >= tokenXAmount, "ERC20: insufficient allowance");
        require(tokenY.allowance(msg.sender, address(this)) >= tokenYAmount, "ERC20: insufficient allowance");
        // msg.sender의 token 보유량이 공급하려는 양보다 많아야 함
        require(tokenX.balanceOf(msg.sender) >= tokenXAmount, "ERC20: transfer amount exceeds balance");
        require(tokenY.balanceOf(msg.sender) >= tokenYAmount, "ERC20: transfer amount exceeds balance");

        update();

        // 같은 양을 넣더라도 넣는 시점의 상황(수수료 등등)을 고려해서 reward를 해줘야 함 -> totalSupply 값을 이용해서 LPT 계산
        if (totalSupply() == 0) {
            LPTokenAmount = tokenXAmount * tokenYAmount;
        } else {
            LPTokenAmount = tokenXAmount * totalSupply() / tokenXpool;
        }

        // 인자로 받은 LP토큰 최소값보다 작으면 안됨
        require(LPTokenAmount >= minimumLPTokenAmount, "less than minimum");
        // 만족하는 경우 msg.sender한테 LPT 토큰 발행해줌
        _mint(msg.sender, LPTokenAmount);

        // msg.sender가 공급해준만큼 amountX(Y)를 추가해줌
        tokenXpool += tokenXAmount;
        tokenYpool += tokenYAmount;

        //transferFrom으로 msg.sender의 토큰을 DEX로 가져옴
        tokenX.transferFrom(msg.sender, address(this), tokenXAmount);
        tokenY.transferFrom(msg.sender, address(this), tokenYAmount);
    }


    /*
    * removeLiquidity
    * ERC-20 기반 LP 토큰을 사용해야 합니다. 
    * 수수료 수입과 Pool에 기부된 금액을 제외하고는    
    * 더 많은 토큰을 회수할 수 있는 취약점이 없어야 합니다.
    */
    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) public returns (uint _receiveX, uint _receiveY) {        
        // require(LPTokenAmount > 0, "less LPToken");
        // require(balanceOf(msg.sender) >= LPTokenAmount, "less LPToken");

        update();

        //return = pool에 있는 토큰 양 * 갖고 있는 LP 양 / total LP 양
        _receiveX = tokenXpool * LPTokenAmount / totalSupply();
        _receiveY = tokenYpool * LPTokenAmount / totalSupply();

        require(minimumTokenXAmount<= _receiveX, "less than minimum");
        require(minimumTokenYAmount<= _receiveY, "less than minimun");

        tokenXpool -= _receiveX;
        tokenYpool -= _receiveY;

        _burn(msg.sender, LPTokenAmount);

        tokenX.transfer(msg.sender, _receiveX);
        tokenY.transfer(msg.sender, _receiveY);
    }

    function transfer(address to, uint256 lpAmount) public override returns (bool){
    }

    function update() public {
        tokenXpool = tokenX.balanceOf(address(this));
        tokenYpool = tokenY.balanceOf(address(this));
    }

    receive() external payable{}
}