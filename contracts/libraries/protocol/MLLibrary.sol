pragma solidity ^0.8.0;

import '../utils/math/Math.sol';
import '../../interfaces/protocol/core/IMLPair.sol';
import '../../interfaces/protocol/core/IMLFactory.sol';

library MLLibrary {
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'ZERO_ADDRESS');
    }

    function pairFor(address factory, address tokenA, address tokenB) internal view returns (address pair) {
        return IMLFactory(factory).getPair(tokenA, tokenB);
    }

    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint112 reserveA, uint112 reserveB, uint16 swapFee) {
        address pair = pairFor(factory, tokenA, tokenB);
        if (pair != address(0)) {
            (uint112 reserve0, uint112 reserve1, uint16 _swapFee) = IMLPair(pair).getReservesAndParameters();
            (reserveA, reserveB) = tokenA < tokenB ? (reserve0, reserve1) : (reserve1, reserve0);
            swapFee = _swapFee;
        }
    }

    function getReservesWithPair(address pair, address tokenA, address tokenB) internal view returns (uint112 reserveA, uint112 reserveB, uint16 swapFee) {
        (uint112 reserve0, uint112 reserve1, uint16 _swapFee) = IMLPair(pair).getReservesAndParameters();
        (reserveA, reserveB) = tokenA < tokenB ? (reserve0, reserve1) : (reserve1, reserve0);
        swapFee = _swapFee;
    }

    function getPairAndReserves(address factory, address tokenA, address tokenB) internal view returns (address pair, uint112 reserveA, uint112 reserveB, uint16 swapFee) {
        pair = pairFor(factory, tokenA, tokenB);
        if (pair != address(0)) { 
            (uint112 reserve0, uint112 reserve1, uint16 _swapFee) = IMLPair(pair).getReservesAndParameters();
            (reserveA, reserveB) = tokenA < tokenB ? (reserve0, reserve1) : (reserve1, reserve0);
            swapFee = _swapFee;
        }
    }

    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'INSUFFICIENT_LIQUIDITY');
        amountB = amountA * reserveB / reserveA;
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint swapFee) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'INSUFFICIENT_LIQUIDITY');
        uint amountInAfterFee = amountIn * (10000 - swapFee);
        uint numerator = amountInAfterFee * reserveOut;
        uint denominator = (reserveIn * 10000) + amountInAfterFee;
        amountOut = numerator / denominator;
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, uint swapFee) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn * amountOut * 10000;
        uint denominator = (reserveOut - amountOut) * (10000 - swapFee);
        amountIn = (numerator / denominator) + 1;
    }

    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'INVALID_PATH');
        amounts = getAmountsOutUnchecked(factory, amountIn, path);
    }

    function getAmountsOutUnchecked(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[0] = amountIn;

        for (uint i; i < path.length - 1; ) {
            (uint112 reserveIn, uint112 reserveOut, uint16 swapFee) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, swapFee);

            unchecked {
                ++i;
            }
        }
    }

    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'INVALID_PATH');
        amounts = getAmountsInUnchecked(factory, amountOut, path);
    }

    function getAmountsInUnchecked(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;

        for (uint i = path.length - 1; i > 0; ) {
            (uint112 reserveIn, uint112 reserveOut, uint16 swapFee) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, swapFee);

            unchecked {
                --i;
            }
        }
    }
}
