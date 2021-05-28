// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.6 <0.8.0;

import './utils/SafeMath.sol';
import './UniswapV2Library.sol';
import './interfaces/IUniswapV2Router02.sol';
import './interfaces/IUniswapV2Pair.sol';
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IERC20.sol';

contract Flashswap {
    using SafeMath for uint;
    uint constant deadline = 10 days;

    address private owner;
    address constant pancakeFactory = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address constant bakery = 0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F;
    IUniswapV2Router02 bakeryRouter = IUniswapV2Router02(bakery);

    constructor() {
        owner = msg.sender;
    }

    function startArbitrage(
        address token0,
        address token1,
        uint amount0,
        uint amount1
    ) external {
        address pairAddress = IUniswapV2Factory(pancakeFactory).getPair(token0, token1);
        require(pairAddress != address(0), 'This pool does not exist');

        IUniswapV2Pair(pairAddress).swap(
            amount0,
            amount1,
            address(this),
            bytes('not empty')
        );
    }

    function pancakeCall(
        address _sender,
        uint _amount0,
        uint _amount1,
        bytes calldata _data
    ) external {
        address[] memory path = new address[](2);

        // obtain an amout of token that you exchanged
        uint amountToken = _amount0 == 0 ? _amount1 : _amount0;

        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        require(msg.sender == UniswapV2Library.pairFor(pancakeFactory, token0, token1));
        require(_amount0 == 0 || _amount1 == 0);

        // if _amount0 is zero sell token1 for token0
        // else sell token0 for token1 as a result
        path[0] = _amount0 == 0 ? token1 : token0;
        path[1] = _amount0 == 0 ? token0 : token1;

        // IERC20 token that we will sell for otherToken
        IERC20 token = IERC20(_amount0 == 0 ? token1 : token0);
        token.approve(address(bakeryRouter), amountToken);

        // calculate the amount of token how much input token should be reimbursed
        uint amountRequired = UniswapV2Library.getAmountsIn(
            pancakeFactory,
            amountToken,
            path
        )[0];

        // swap token and obtain equivalent otherToken amountRequired as a result
        uint amountReceived = bakeryRouter.swapExactTokensForTokens(
            amountToken,
            amountRequired,
            path,
            msg.sender,
            deadline
        )[1];

        require(amountReceived > amountRequired); // fail if we didn't get enough tokens
        IERC20 otherToken = IERC20(_amount0 == 0 ? token0 : token1);
        otherToken.transfer(msg.sender, amountRequired);
        otherToken.transfer(owner, amountReceived.sub(amountRequired));
    }
}

