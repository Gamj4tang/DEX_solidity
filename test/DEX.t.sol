// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {Vm} from "forge-std/Vm.sol";
import {ICheatCodes } from "./utils/ICheatCodes.sol";
import {Utilities} from "./utils/Utilities.sol";


// import "../src/Dex-Sophie00Seo.sol";
import "../src/Dex.sol";
// import "../src/Dex-Jun4.sol";
// import "../src/Dex-siwon.sol";
// import "../src/Dex-kimziwu.sol";
// import "../src/Dex-koor.sol";
// import "../src/Dex-hangee.sol";
// // import "../src/Dex-Moon.sol";
// import "../src/Dex-dlanaraa.sol";
// import "../src/Dex-hyeon.sol";
// import "../src/Dex-seonghwi.sol";
// // import "../src/Dex-jt.sol";
// import "../src/Dex-Namryeong.sol";
// import "../src/Dex-jw.sol";

contract CustomERC20 is ERC20 {
    constructor(string memory tokenName) ERC20(tokenName, tokenName) {
        _mint(msg.sender, type(uint).max);
    }
}

/*
 * Contract에서 필요한 만큼(또는 요청한 만큼)의 자산을 가져가도록 구현되어있다는 것을 가정하였습니다.
 * (transferFrom을 통해)
 */

contract DexTest is Test {
    // Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Dex public dex;
    ERC20 tokenX;
    ERC20 tokenY;

    Utilities internal utils;
    address attacker;
    address attacker1;
    address attacker2;

    address[] users;

    function setUp() public {
        tokenX = new CustomERC20("XXX");
        tokenY = new CustomERC20("YYY");

        dex = new Dex(address(tokenX), address(tokenY));

        tokenX.approve(address(dex), type(uint).max);
        tokenY.approve(address(dex), type(uint).max);

        // attacker setup
        utils = new Utilities();
        users = utils.createUsers(3, 1000 ether);
        attacker = users[0];
        attacker1 = users[1];
        attacker2 = users[2];

        vm.label(attacker, "attacker");
        vm.label(attacker1, "attacker1");
        vm.label(attacker2, "attacker2");

        // owner => attacker token transfer
        tokenX.transfer(attacker, 1000 ether);
        tokenY.transfer(attacker, 1000 ether);
        
        tokenX.transfer(attacker2, 1000 ether);
        tokenY.transfer(attacker2, 1000 ether);
        

    }

    function testAddLiquidity1() external {
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint secondLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        assertEq(firstLPReturn, secondLPReturn, "AddLiquidity Error 1");
    }

    function testAddLiquidity2() external {
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint secondLPReturn = dex.addLiquidity(1000 ether * 2, 1000 ether * 2, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        assertEq(firstLPReturn * 2, secondLPReturn, "AddLiquidity Error 2");
    }

    function testAddLiquidity3() external {
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        (bool success, ) = address(dex).call(abi.encodeWithSelector(dex.addLiquidity.selector, 1000 ether, 1000 ether, firstLPReturn * 10001 / 10000));
        assertTrue(!success, "AddLiquidity minimum LP return error");
    }

    function testAddLiquidity4() external {
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        (bool success, bytes memory alret) = address(dex).call(abi.encodeWithSelector(dex.addLiquidity.selector, 1000 ether, 4000 ether, 0));
        uint256 lpret = uint(bytes32(alret));
        assertTrue((firstLPReturn == lpret) || !success, "AddLiquidity imbalance add liquidity test error");
    }

    function testAddLiquidity5() external {
        address sender = vm.addr(1);
        tokenX.transfer(sender, 100 ether);
        tokenY.transfer(sender, 100 ether);

        vm.expectRevert("ERC20: insufficient allowance");
        vm.startPrank(sender);
        dex.addLiquidity(1000 ether, 1000 ether, 0);

        tokenX.approve(address(dex), type(uint).max);
        tokenY.approve(address(dex), type(uint).max);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        dex.addLiquidity(1000 ether, 1000 ether, 0);

        vm.stopPrank();

    }

    function testAddLiquidity6() external {
        (bool success, ) = address(dex).call(abi.encodeWithSelector(dex.addLiquidity.selector, 0 ether, 0 ether, 0));
        assertTrue(!success, "AddLiquidity invalid initialization check error - 1");
        (success, ) = address(dex).call(abi.encodeWithSelector(dex.addLiquidity.selector, 1 ether, 0 ether, 0));
        assertTrue(!success, "AddLiquidity invalid initialization check error - 2");
        (success, ) = address(dex).call(abi.encodeWithSelector(dex.addLiquidity.selector, 0 ether, 1 ether, 0));
        assertTrue(!success, "AddLiquidity invalid initialization check error - 3");
    }

    function testRemoveLiquidity1() external {
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint secondLPReturn = dex.addLiquidity(1000 ether * 2, 1000 ether * 2, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        (uint tx, uint ty) = dex.removeLiquidity(secondLPReturn, 0, 0);
        assertEq(tx, 1000 ether * 2, "RemoveLiquiidty tx error");
        assertEq(ty, 1000 ether * 2, "RemoveLiquiidty tx error");
    }

    function testRemoveLiquidity2() external {
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint secondLPReturn = dex.addLiquidity(1000 ether * 2, 1000 ether * 2, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        (bool success, ) = address(dex).call(abi.encodeWithSelector(dex.removeLiquidity.selector, secondLPReturn, 2001 ether, 2001 ether));
        assertTrue(!success, "RemoveLiquidity minimum return error");
    }

    function testRemoveLiquidity3() external {
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint secondLPReturn = dex.addLiquidity(1000 ether * 2, 1000 ether * 2, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        (bool success, ) = address(dex).call(abi.encodeWithSelector(dex.removeLiquidity.selector, secondLPReturn*2));
        assertTrue(!success, "RemoveLiquidity exceeds balance check error");
    }

    function testRemoveLiquidity4() external {
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn/10**18);

        uint secondLPReturn = dex.addLiquidity(1000 ether * 2, 1000 ether * 2, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn/10**18);

        uint sumX;
        uint sumY;
        for (uint i=0; i<100; i++) {
            sumY += dex.swap(1000 ether, 0, 0);
            sumX += dex.swap(0, 1000 ether, 0);
            emit log_named_uint("total x -> y swaps", (sumX/10**18));
            emit log_named_uint("total y -> x swaps", (sumY/10**18));

            if (i % 10 == 0) {
                tokenX.transfer(address(dex), 1000 ether);
            }
        }


        // // usedX = 1000 ether * 100
        // // usedY = 1000 ether * 100

        // uint poolAmountX = 1000 ether + 1000 ether * 2; // initial value
        // poolAmountX += 1000 ether * 100;
        // uint poolAmountY = 1000 ether + 1000 ether * 2; // initial value
        // poolAmountY += 1000 ether * 100;

        // poolAmountX -= sumX;
        // poolAmountY -= sumY;

        // emit log_named_uint("remaining poolAmountX", poolAmountX);
        // emit log_named_uint("remaining poolAmountY", poolAmountY);

        (uint rx, uint ry) = dex.removeLiquidity(firstLPReturn, 0, 0);
        emit log_named_uint("rx", rx/10**18);
        emit log_named_uint("ry", ry/10**18);

        // bool successX = rx <= (poolAmountX * 10001 / 10000 / 3) && rx >= (poolAmountX * 9999 / 10000 / 3); // allow 0.01%;
        // bool successY = ry <= (poolAmountY * 10001 / 10000 / 3) && ry >= (poolAmountY * 9999 / 10000 / 3); // allow 0.01%;
        // assertTrue(successX, "remove liquidity after swap error; rx");
        // assertTrue(successY, "remove liquidity after swap error; ry");
    }

    function testSwap1() external {
        dex.addLiquidity(3000 ether, 4000 ether, 0);
        dex.addLiquidity(30000 ether * 2, 40000 ether * 2, 0);

        // x -> y
        uint output = dex.swap(300 ether, 0, 0);

        uint poolAmountX = 60000 ether + 3000 ether;
        uint poolAmountY = 80000 ether + 4000 ether;


        int expectedOutput = -(int(poolAmountX * poolAmountY) / int(poolAmountX + 300 ether)) + int(poolAmountY);
        expectedOutput = expectedOutput * 999 / 1000; // 0.1% fee
        uint uExpectedOutput = uint(expectedOutput);

        emit log_named_int("expected output", expectedOutput);
        emit log_named_uint("real output", output);

        bool success = output <= (uExpectedOutput * 10001 / 10000) && output >= (uExpectedOutput * 9999 / 10000); // allow 0.01%;
        assertTrue(success, "Swap test fail 1; expected != return");
    }

    function testSwap2() external {
        dex.addLiquidity(3000 ether, 4000 ether, 0);
        dex.addLiquidity(30000 ether * 2, 40000 ether * 2, 0);

        // y -> x
        uint output = dex.swap(0, 6000 ether, 0);

        uint poolAmountX = 60000 ether + 3000 ether;
        uint poolAmountY = 80000 ether + 4000 ether;


        int expectedOutput = -(int(poolAmountY * poolAmountX) / int(poolAmountY + 6000 ether)) + int(poolAmountX);
        expectedOutput = expectedOutput * 999 / 1000; // 0.1% fee
        uint uExpectedOutput = uint(expectedOutput);

        emit log_named_int("expected output", expectedOutput);
        emit log_named_uint("real output", output);

        bool success = output <= (uExpectedOutput * 10001 / 10000) && output >= (uExpectedOutput * 9999 / 10000); // allow 0.01%;
        assertTrue(success, "Swap test fail 2; expected != return");
    }

    function testSwap3() external {
        dex.addLiquidity(3000 ether, 4000 ether, 0);
        dex.addLiquidity(30000 ether * 2, 40000 ether * 2, 0);

        // y -> x
        // check invalid swap
        (bool success, ) = address(dex).call(abi.encodeWithSelector(dex.swap.selector, 1, 6000 ether, 0));
        assertTrue(!success, "Swap test fail 3; invalid input test failed");
    }

    function testSwap4() external {
        dex.addLiquidity(3000 ether, 4000 ether, 0);
        dex.addLiquidity(30000 ether * 2, 40000 ether * 2, 0);

        // y -> x
        uint poolAmountX = 60000 ether + 3000 ether;
        uint poolAmountY = 80000 ether + 4000 ether;


        int expectedOutput = -(int(poolAmountY * poolAmountX) / int(poolAmountY + 6000 ether)) + int(poolAmountX);
        expectedOutput = expectedOutput * 999 / 1000; // 0.1% fee
        uint uExpectedOutput = uint(expectedOutput);

        emit log_named_int("expected output", expectedOutput);

        (bool success, ) = address(dex).call(abi.encodeWithSelector(dex.swap.selector, 0, 6000 ether, uExpectedOutput * 1005 / 1000));
        assertTrue(!success, "Swap test fail 4; minimum ouput amount check failed");
    }

    function testAddLiquidity7() external {
        tokenX.transfer(address(dex), 1000 ether);
        uint lp = dex.addLiquidity(3000 ether, 4000 ether, 0);
        emit log_named_uint("LP", lp);

        tokenX.transfer(address(dex), 1000 ether);
        uint lp2 = dex.addLiquidity(5000 ether, 4000 ether, 0);
        emit log_named_uint("LP2", lp2);

        (uint rx, uint ry) = dex.removeLiquidity(lp, 0, 0);
        assertEq(rx, 5000 ether, "rx failed");
        assertEq(ry, 4000 ether, "ry failed");
    }
    function testAddLiquidity8() external {
        tokenX.transfer(address(dex), 1000 ether);
        uint lp = dex.addLiquidity(3000 ether, 4000 ether, 0);
        emit log_named_uint("LP", lp);

        tokenX.transfer(address(dex), 1000 ether);
        uint lp2 = dex.addLiquidity(5000 ether, 4000 ether, 0);
        emit log_named_uint("LP", lp);


        address other_eoa = vm.addr(1);
        tokenX.transfer(other_eoa, 10000 ether);
        tokenY.transfer(other_eoa, 10000 ether);
        vm.startPrank(other_eoa);

        tokenX.approve(address(dex), type(uint).max);
        tokenY.approve(address(dex), type(uint).max);

        uint lp3 = dex.addLiquidity(5000 ether, 4000 ether, 0);
        emit log_named_uint("LP3", lp3);

        vm.stopPrank();

        (uint rx, uint ry) = dex.removeLiquidity(lp, 0, 0);
        assertEq(rx, 5000 ether, "rx failed");
        assertEq(ry, 4000 ether, "ry failed");
    }

    /**
     * [TEST] attack scenario LP token
     * */
    
/*
    function testAttackerSwap() external {
        dex.addLiquidity(3000 ether, 4000 ether, 0);
        dex.addLiquidity(30000 ether * 2, 40000 ether * 2, 0);

        tokenX.transfer(address(attacker), 100000 ether);
        tokenY.transfer(address(attacker), 100000 ether);
        
        vm.startPrank(address(attacker));

        tokenX.approve(address(dex), type(uint).max);
        tokenY.approve(address(dex), type(uint).max);
        
    
        uint sumX;
        uint sumY;
        for (uint i=0; i<100; i++) {
            sumX += dex.swap(0, 1000 ether, 0);
            sumY += dex.swap(1000 ether, 0, 0);

            emit log_named_uint("total x -> y swaps", (sumX/10**18));
            emit log_named_uint("total y -> x swaps", (sumY/10**18));
        }
        bool success = sumX > 0 && sumY > 0;
        assertTrue(success, "Swap test fail 5; multiple swap test");
    }
    
    function testSwapFeeZer0() public {
        vm.startPrank(attacker);
        uint256 lp;
        for (uint i = 0; i <10; i++) {
            
            tokenX.approve(address(dex), 100 ether);
            tokenY.approve(address(dex), 100 ether);
    
            lp = dex.addLiquidity(100 ether, 100 ether, 0);
            emit log_named_uint("lp", lp);
            emit log_named_decimal_uint("lp", lp, 18);
        }

    
        uint lpFee = 100 ether + 999 * 1000;
        vm.stopPrank();

        vm.startPrank(attacker2);
        tokenX.approve(address(dex), 100 ether);
        for (uint i = 0; i < 1000; i++) {
            dex.swap(999, 0, 0);
        }    
        vm.stopPrank();
    

        vm.startPrank(attacker);
        uint256 balanceBefore = tokenX.balanceOf(attacker);
        dex.removeLiquidity(lp, 0, 0);
        uint256 balanceAfter = tokenX.balanceOf(attacker);
        emit log_named_uint("balanceBefore", balanceBefore);
        emit log_named_uint("balanceAfter", balanceAfter);
        emit log_named_uint("diff", balanceAfter - balanceBefore);
        

        assertGt(balanceAfter - balanceBefore, lpFee);
    }
    
    function testMintLPBreak() external {
        // user add liquidity
        uint lp = dex.addLiquidity(3000 ether, 4000 ether, 0);
        emit log_named_uint("[user]LP", lp);

        vm.startPrank(address(attacker));
        
        // attacker tokenX, tokenY balance
        uint tx = tokenX.balanceOf(address(attacker));
        uint ty = tokenY.balanceOf(address(attacker));
        emit log_named_uint("tokenX", tx / 10**18);
        emit log_named_uint("tokenY", ty / 10**18);

        dex.transfer((attacker), lp);

        dex.removeLiquidity(lp, 0, 0);
    
        // get token pair
        uint tx_attack = tokenX.balanceOf(address(attacker));
        uint ty_attack = tokenY.balanceOf(address(attacker));
        emit log_named_uint("tokenX", tx_attack / 10**18);
        emit log_named_uint("tokenY", ty_attack / 10**18);
    }

    // swap testing research flashloan
    function testFlashLoan() external {
    
        // liquidity
        uint lp = dex.addLiquidity(
            10000 ether,
            10000 ether
        , 0);

        // lp 
        emit log_named_uint("LP Token", lp);
        // token flash loan virtual testing
        tokenX.transfer(address(attacker), 5000 ether);
        tokenY.transfer(address(attacker), 5000 ether);

        // attacker flash loan token X, Y
        vm.startPrank(address(attacker));
        tokenX.approve(address(dex), type(uint).max);
        tokenY.approve(address(dex), type(uint).max);

        // trnasfer => pool4996665555185061687229
        tokenX.transfer(address(dex), 5000 ether);

        // flash loan swap => 
        uint _swap = dex.swap(
            0,
            5000 ether,
            0
        );
        emit log_named_uint("swap", _swap);


        uint _tx_balance = tokenX.balanceOf(address(attacker));
        uint _ty_balance = tokenY.balanceOf(address(attacker));
        emit log_named_uint("tokenX", _tx_balance);
        emit log_named_uint("tokenY", _ty_balance);
    }
 

    function testSwapLogicCalc() external {
        uint _lp = dex.addLiquidity(1000 ether, 1000 ether, 0);
        
        tokenX.transfer(address(attacker),(3000 ether + 30000 ether * 10));
        tokenY.transfer(address(attacker),(3000 ether + 30000 ether * 10));

        
        vm.startPrank(address(attacker));
        tokenX.approve(address(dex), type(uint).max);
        tokenY.approve(address(dex), type(uint).max);


        tokenX.transfer(address(dex), (1000 ether));
        uint y_Swap_x;
        for (uint i = 0; i < 100; i++) {
            y_Swap_x += dex.swap(
                0,
                1000 ether,
                0
            );
            
        }
        vm.stopPrank();
        uint lpFee = 1000 ether + 999 * 1000;
        emit log_named_uint("y_Swap_x", y_Swap_x);
        emit log_named_uint("lpFee", lpFee);

        dex.removeLiquidity(_lp, 0, 0);


    
        uint _tx_balance = tokenX.balanceOf(address(dex));
        uint _ty_balance = tokenY.balanceOf(address(dex));
        emit log_named_uint("tokenX", _tx_balance);
        emit log_named_uint("tokenY", _ty_balance);
    }

    function testBurnZer0() external {
        tokenX.transfer(address(attacker), 1000 ether);
        tokenY.transfer(address(attacker), 1000 ether);

        vm.startPrank(attacker);
        tokenX.approve(address(dex), ~uint256(0));
        tokenY.approve(address(dex), ~uint256(0));
        
        // token add liquidity
        uint256 lp = dex.addLiquidity(0.1 ether, 0.1 ether, 0);
        emit log_named_uint("LP", lp);
        // emit log_named_decimal_uint("lp=>", lp, 18);

        uint _tx_balance = tokenX.balanceOf(address(attacker));
        uint _ty_balance = tokenY.balanceOf(address(attacker));
        emit log_named_decimal_uint("tokenX", _tx_balance, 18);
        emit log_named_decimal_uint("tokenY", _ty_balance, 18);

        // uint returnAmountX = _amountX * LPTokenAmount / totalSupply();
        // uint returnAmountY = _amountY * LPTokenAmount / totalSupply();
        // require(returnAmountX >= minimumTokenXAmount, "less than minimum tokenX amount");
        // require(returnAmountY >= minimumTokenYAmount, "less than minimum tokenY amount");
        // _amountX -= returnAmountX;
        // _amountY -= returnAmountY;

        dex.removeLiquidity(1 ether, 0, 0);

        uint _tx_balance_re = tokenX.balanceOf(address(attacker));
        uint _ty_balance_re = tokenY.balanceOf(address(attacker));
        emit log_named_decimal_uint("tokenX_add_remove", _tx_balance_re, 18);
        emit log_named_decimal_uint("tokenY_add_remove", _ty_balance_re, 18);
        // 100000000000
        
    }
    function testSwapBalanceCheck() external {
        dex.addLiquidity(3000 ether, 4000 ether, 0);
        dex.addLiquidity(30000 ether * 2, 40000 ether * 2, 0);

        // y -> x
        uint poolAmountX = 60000 ether + 3000 ether;
        uint poolAmountY = 80000 ether + 4000 ether;


        int expectedOutput = -(int(poolAmountY * poolAmountX) / int(poolAmountY + 6000 ether)) + int(poolAmountX);
        expectedOutput = expectedOutput * 999 / 1000; // 0.1% fee
        uint uExpectedOutput = uint(expectedOutput);

        emit log_named_int("expected output", expectedOutput);

        (bool success, ) = address(dex).call(abi.encodeWithSelector(dex.swap.selector, 0, 6000 ether, uExpectedOutput * 1005 / 1000));
        assertTrue(!success, "Swap test fail 4; minimum ouput amount check failed");
    }


    // lp token increase?
    function testLpTokenImbalance() external {
        tokenX.transfer(address(attacker), (~uint256(0))/2);
        tokenY.transfer(address(attacker), (~uint256(0))/2);

        vm.startPrank(attacker2);
        tokenX.approve(address(dex), ~uint256(0));
        tokenY.approve(address(dex), ~uint256(0));
        vm.stopPrank();

        vm.startPrank(attacker);
        tokenX.approve(address(dex), ~uint256(0));
        tokenY.approve(address(dex), ~uint256(0));
        vm.stopPrank();

        // token add liquidity
        for (uint i = 0; i < 271; i++) {
            vm.startPrank(attacker);
            uint256 lp = dex.addLiquidity(12345 ether, 12345 ether, 0);
            uint _tx_balance_re = tokenX.balanceOf(address(attacker));
            uint _ty_balance_re = tokenY.balanceOf(address(attacker));
            emit log_named_decimal_uint("tokenX_add_remove", _tx_balance_re, 18);
            emit log_named_decimal_uint("tokenY_add_remove", _ty_balance_re, 18);
            emit log_named_uint("LP", lp);
            emit log_named_uint("Count:", i);


            // dex.removeLiquidity(lp, 0, 0);

            vm.stopPrank();
            // uint _tx_balance_re = tokenX.balanceOf(address(attacker));
            // uint _ty_balance_re = tokenY.balanceOf(address(attacker));
            // emit log_named_decimal_uint("tokenX_add_remove", _tx_balance_re, 18);
            // emit log_named_decimal_uint("tokenY_add_remove", _ty_balance_re, 18);
            vm.startPrank(attacker2);
            tokenX.transfer(address(dex), 0.001 ether);
            // tokenY.transfer(address(dex), 1 ether);
            // tokenY.transfer(address(dex), 127 ether);
            vm.stopPrank();
        }
    }

    function testAddAddAdd() external {
        // attacker token transfer
        tokenX.transfer(address(attacker), 10000 ether);
        tokenY.transfer(address(attacker), 10000 ether);
        // attacker => addliquidity call
        vm.startPrank(attacker);
        tokenX.approve(address(dex), ~uint256(0));
        tokenY.approve(address(dex), ~uint256(0));

        for (uint i = 0; i < 20; i++) {
            uint lp = dex.addLiquidity(
                500 ether,
                500 ether,
                0
            );
            // lp token change
            emit log_named_uint("LP", lp);
        }
        // token statking
    }

*/
    // addliquidity lp =>

    // 1000000000000000000000
    // 100000000000000000000
    // 200000000000000000000
    // 10000000000000000000000
    // 902000000000000000000
    // 900000000000000000000
    // 900000000000000000000
    // 100000000000000000000

    // 900000000000000000000
    // 10000000000000000000000
    // 901010000000000000000

    // function testRemoveLiquidity5() external {
    //     uint lpSum = 0;
    //     for (uint i=0; i<5; i++) {
    //         uint lp = dex.addLiquidity(1000 ether, 1000 ether, 0);
    //         lpSum += lp;
    //     }

    //     emit log_named_uint("total LP tokens", lpSum);

    //     (uint rx, uint ry) = dex.removeLiquidity(lpSum, 0, 0);
    //     emit log_named_uint("removed X tokens", rx);
    //     emit log_named_uint("removed Y tokens", ry);

    //     bool success = rx == (1000 ether * 5) && ry == (1000 ether * 5);
    //     assertTrue(success, "RemoveLiquidity test fail 5; multiple addLiquidity test");
    // }


    // function testFlashSwap1() external {
    //     dex.addLiquidity(1000 ether, 1000 ether, 0);

    //     // Test a simple flash swap
    //     bool success = address(dex).flashSwap(100 ether, 0, address(this), abi.encodeWithSignature("flashSwapCallback(address,address,uint256,uint256,bytes)"));
    //     assertTrue(success, "Flash swap failed");

    //     // Check that the borrowed amount was repaid
    //     assertEq(tokenX.balanceOf(address(dex)), 1000 ether, "Flash swap balance not restored");
    // }

    // function flashSwapCallback(address tokenBorrowed, address tokenToRepay, uint256 amountBorrowed, uint256 amountToRepay, bytes memory) public {
    //     require(tokenBorrowed == address(tokenX), "Wrong borrowed token in flashSwapCallback");
    //     require(tokenToRepay == address(tokenY), "Wrong token to repay in flashSwapCallback");
    //     require(amountBorrowed == 100 ether, "Wrong borrowed amount in flashSwapCallback");

    //     uint256 repaidAmount = dex.getAmountToRepay(tokenBorrowed, tokenToRepay, amountBorrowed);
    //     require(repaidAmount == amountToRepay, "Wrong amount to repay in flashSwapCallback");

    //     tokenY.transfer(address(dex), repaidAmount);
    // }

    // function testFlashSwap2() external {
    //     dex.addLiquidity(1000 ether, 1000 ether, 0);

    //     // Test a flash swap with insufficient repayment
    //     (bool success, ) = address(dex).call(abi.encodeWithSignature("flashSwap(uint256,uint256,address,bytes)", 100 ether, 0, address(this), abi.encodeWithSignature("flashSwapCallbackInsufficientRepayment(address,address,uint256,uint256,bytes)")));
    //     assertTrue(!success, "Flash swap should have failed due to insufficient repayment");
    // }

    // function flashSwapCallbackInsufficientRepayment(address tokenBorrowed, address tokenToRepay, uint256 amountBorrowed, uint256 amountToRepay, bytes memory) public {
    //     require(tokenBorrowed == address(tokenX), "Wrong borrowed token in flashSwapCallback");
    //     require(tokenToRepay == address(tokenY), "Wrong token to repay in flashSwapCallback");
    //     require(amountBorrowed == 100 ether, "Wrong borrowed amount in flashSwapCallback");

    //     uint256 repaidAmount = dex.getAmountToRepay(tokenBorrowed, tokenToRepay, amountBorrowed);
    //     require(repaidAmount == amountToRepay, "Wrong amount to repay in flashSwapCallback");

    //     // Repay an insufficient amount
    //     tokenY.transfer(address(dex), repaidAmount - 1 ether);
    // }

    // function testFlashSwap3() external {
    //     dex.addLiquidity(1000 ether, 1000 ether, 0);

    //     // Test a flash swap with too much borrowed amount
    //     (bool success, ) = address(dex).call(abi.encodeWithSignature("flashSwap(uint256,uint256,address,bytes)", 2000 ether, 0, address(this), abi.encodeWithSignature("flashSwapCallback(address,address,uint256,uint256,bytes)")));
    //     assertTrue(!success, "Flash swap should have failed due to too");
    //         // much borrowed amount
    // }

    // function testFlashSwap4() external {
    //     dex.addLiquidity(1000 ether, 1000 ether, 0);

    //     // Test a flash swap with a custom callback function
    //     bool success = dex.flashSwap(100 ether, 0, address(this), abi.encodeWithSignature("customFlashSwapCallback(address,address,uint256,uint256,bytes)"));
    //     assertTrue(success, "Flash swap failed with custom callback");

    //     // Check that the borrowed amount was repaid
    //     assertEq(tokenX.balanceOf(address(dex)), 1000 ether, "Flash swap balance not restored with custom callback");
    // }

    // function customFlashSwapCallback(address tokenBorrowed, address tokenToRepay, uint256 amountBorrowed, uint256 amountToRepay, bytes memory) public {
    //     require(tokenBorrowed == address(tokenX), "Wrong borrowed token in customFlashSwapCallback");
    //     require(tokenToRepay == address(tokenY), "Wrong token to repay in customFlashSwapCallback");
    //     require(amountBorrowed == 100 ether, "Wrong borrowed amount in customFlashSwapCallback");

    //     uint256 repaidAmount = dex.getAmountToRepay(tokenBorrowed, tokenToRepay, amountBorrowed);
    //     require(repaidAmount == amountToRepay, "Wrong amount to repay in customFlashSwapCallback");

    //     // Perform some custom operation
    //     tokenY.transfer(address(this), 10 ether);

    //     // Repay the borrowed amount
    //     tokenY.transfer(address(dex), repaidAmount);
    // }

}



