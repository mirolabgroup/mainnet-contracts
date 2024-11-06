pragma solidity ^0.8.0;

import '../interfaces/protocol/core/IMLPair.sol';
import '../libraries/protocol/MLLibrary.sol';
import '../libraries/token/ERC20/utils/TransferHelper.sol';

abstract contract MLRouterInternal {

    modifier ensureNotExpired(uint deadline) {
        require(block.timestamp <= deadline, 'EXPIRED');
        _;
    }

    function _quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA != 0, 'INSUFFICIENT_AMOUNT');
        amountB = amountA * reserveB / reserveA;
    }

    function _getReserves(address pair, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (uint reserve0, uint reserve1) = IMLPair(pair).getReservesSimple();
        (reserveA, reserveB) = tokenA < tokenB ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function _getOptimalAmountsInForAddLiquidity(
        address pair,
        address tokenA,
        address tokenB,
        uint amountAInExpected,
        uint amountBInExpected,
        uint amountAInMin,
        uint amountBInMin
    ) internal view returns (uint amountAIn, uint amountBIn) {
         (uint reserveA, uint reserveB) = _getReserves(pair, tokenA, tokenB);

        if (reserveA == 0 && reserveB == 0) {
            (amountAIn, amountBIn) = (amountAInExpected, amountBInExpected);
        } else {
            uint amountBInOptimal = _quote(amountAInExpected, reserveA, reserveB);

            if (amountBInOptimal <= amountBInExpected) {
                require(amountBInOptimal >= amountBInMin, 'INSUFFICIENT_B_AMOUNT');
                (amountAIn, amountBIn) = (amountAInExpected, amountBInOptimal);
            } else {
                uint amountAInOptimal = _quote(amountBInExpected, reserveB, reserveA);
                require(amountAInOptimal >= amountAInMin, 'INSUFFICIENT_A_AMOUNT');
                (amountAIn, amountBIn) = (amountAInOptimal, amountBInExpected);
            }
        }
    }

    function _burnLiquidity(
        address pair,
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAOutMin,
        uint amountBOutMin,
        address to
    ) internal returns (uint amountAOut, uint amountBOut) {
        IMLPair(pair).transferFrom(msg.sender, pair, liquidity);
        (uint amount0, uint amount1) = IMLPair(pair).burn(to);

        (amountAOut, amountBOut) = tokenA < tokenB ? (amount0, amount1) : (amount1, amount0);
        require(amountAOut >= amountAOutMin, 'INSUFFICIENT_A_AMOUNT');
        require(amountBOut >= amountBOutMin, 'INSUFFICIENT_B_AMOUNT');
    }


    function _swap(address initialPair, uint[] memory amounts, address[] memory path, address to) internal { // not in use
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);

            uint amountOut = amounts[i + 1]; // output amount of current sub swap.
            (uint amount0Out, uint amount1Out) = input < output ? (uint(0), amountOut) : (amountOut, uint(0));

            address currentTo = i < path.length - 2 ? MLLibrary.pairFor(_factory, output, path[i + 2]) : to;

            address pair = i == 0 ? initialPair :MLLibrary.pairFor(_factory, input, output);
            ILiquidityPair(pair).swap(amount0Out, amount1Out, currentTo, new bytes(0));
        }
    }

    function _swapCached(address _factory, address initialPair, uint[] memory amounts, address[] calldata path, address to) internal {
        address nextPair = initialPair;

        for (uint i; i < path.length - 1; ) {
            (address input, address output) = (path[i], path[i + 1]);
            uint amountOut = amounts[i + 1];
            if (i < path.length - 2) {
                address pair = nextPair;
                nextPair = MLLibrary.pairFor(_factory, output, path[i + 2]);

                _swapSingle(pair, amountOut, input, output, nextPair);
            } else {
                _swapSingle(nextPair, amountOut, input, output, to);
            }

            unchecked {
                ++i;
            }
        }
    }

    function _swapSingle(address pair, uint amountOut, address tokenIn, address tokenOut, address to) internal {
        if (tokenIn < tokenOut) { 
            IMLPair(pair).swapFor1(amountOut, to);
        } else {
            IMLPair(pair).swapFor0(amountOut, to);
        }
    }
}
