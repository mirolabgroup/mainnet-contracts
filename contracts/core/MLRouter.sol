pragma solidity ^0.8.0;

import './MLRouterInternal.sol';

import '../interfaces/IWETH.sol';
import '../interfaces/protocol/IMLRouter.sol';
import '../interfaces/protocol/core/IMLFactory.sol';

import '../libraries/protocol/MLLibrary.sol';
import '../libraries/token/ERC20/utils/TransferHelper.sol';

contract MLRouter is IMLRouter, MLRouterInternal {
    address public immutable override factory;
    address public immutable override WETH;

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH);
    }

    mapping(address => mapping(address => bool)) public override isPairIndexed;
    mapping(address => address[]) public override indexedPairs;

    function indexedPairsOf(address account) external view override returns (address[] memory) {
        return indexedPairs[account];
    }

    function indexedPairsRange(address account, uint256 start, uint256 counts) external view override returns (address[] memory) {
        require(counts != 0, "Counts must greater than zero");

        address[] memory pairs = indexedPairs[account];
        require(start + counts <= pairs.length, "Out of bound");

        address[] memory result = new address[](counts);
        for (uint256 i = 0; i < counts; i++) {
            result[i] = pairs[start + i];
        }
        return result;
    }

    function indexedPairsLengthOf(address account) external view override returns (uint256) {
        return indexedPairs[account].length;
    }


    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountAInExpected,
        uint amountBInExpected,
        uint amountAInMin,
        uint amountBInMin
    ) internal virtual returns (address pair, uint amountAInActual, uint amountBInActual) {
        address _factory = factory;
        pair = MLLibrary.pairFor(_factory, tokenA, tokenB);
        if (pair == address(0)) {
            pair = IMLFactory(_factory).createPair(tokenA, tokenB);

            (amountAInActual, amountBInActual) = (amountAInExpected, amountBInExpected);
        } else {
            (amountAInActual, amountBInActual) = _getOptimalAmountsInForAddLiquidity(
                pair, tokenA, tokenB, amountAInExpected, amountBInExpected, amountAInMin, amountBInMin
            );
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountAInExpected,
        uint amountBInExpected,
        uint amountAInMin,
        uint amountBInMin,
        address to,
        uint deadline
    ) external override ensureNotExpired(deadline) returns (uint amountAInActual, uint amountBInActual, uint liquidity) {
        address pair;
        (pair, amountAInActual, amountBInActual) = _addLiquidity(tokenA, tokenB, amountAInExpected, amountBInExpected, amountAInMin, amountBInMin);

        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountAInActual);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountBInActual);

        liquidity = IMLPair(pair).mint(to);

        if (!isPairIndexed[to][pair]) {
            isPairIndexed[to][pair] = true;
            indexedPairs[to].push(pair);
        }
    }

    function addLiquidityETH(
        address token,
        uint amountTokenInExpected,
        uint amountTokenInMin,
        uint amountETHInMin,
        address to,
        uint deadline
    ) external override payable ensureNotExpired(deadline) returns (uint amountTokenInActual, uint amountETHInActual, uint liquidity) {
        address pair;
        (pair, amountTokenInActual, amountETHInActual) = _addLiquidity(token, WETH, amountTokenInExpected, msg.value, amountTokenInMin, amountETHInMin);

        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountTokenInActual);
        IWETH(WETH).deposit{value: amountETHInActual}();
        assert(IWETH(WETH).transfer(pair, amountETHInActual));

        liquidity = IMLPair(pair).mint(to);

        if (msg.value > amountETHInActual) {
            TransferHelper.safeTransferETH(msg.sender, msg.value - amountETHInActual);
        }

        if (!isPairIndexed[to][pair]) {
            isPairIndexed[to][pair] = true;
            indexedPairs[to].push(pair);
        }
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAOutMin,
        uint amountBOutMin,
        address to,
        uint deadline
    ) public override ensureNotExpired(deadline) returns (uint amountAOut, uint amountBOut) {
        address pair = MLLibrary.pairFor(factory, tokenA, tokenB);
        (amountAOut, amountBOut) = _burnLiquidity(
            pair, tokenA, tokenB, liquidity, amountAOutMin, amountBOutMin, to
        );
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public override ensureNotExpired(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function _permit(
        address tokenA,
        address tokenB,
        bool approveMax,
        uint liquidity,
        uint deadline,
        uint8 v, bytes32 r, bytes32 s
    ) internal returns (address) {
        address pair = MLLibrary.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? type(uint).max : liquidity;
        IMLPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        return pair;
    }

    function _removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAOutMin,
        uint amountBOutMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v, bytes32 r, bytes32 s
    ) internal returns (uint amountAOut, uint amountBOut) {
        address pair = _permit(tokenA, tokenB, approveMax, liquidity, deadline, v, r, s);

        (amountAOut, amountBOut) = _burnLiquidity(
            pair, tokenA, tokenB, liquidity, amountAOutMin, amountBOutMin, to
        );
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAOutMin,
        uint amountBOutMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external override returns (uint amountAOut, uint amountBOut) {
        (amountAOut, amountBOut) = _removeLiquidityWithPermit(tokenA, tokenB, liquidity, amountAOutMin, amountBOutMin, to, deadline, approveMax, v, r, s);
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external override returns (uint amountToken, uint amountETH) {
        _permit(token, WETH, approveMax, liquidity, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public override ensureNotExpired(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external override returns (uint amountETH) {
        _permit(token, WETH, approveMax, liquidity, deadline, v, r, s);

        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }


    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensureNotExpired(deadline) returns (uint[] memory amounts) {
        amounts = MLLibrary.getAmountsOutUnchecked(factory, amountIn, path); 
        require(amounts[amounts.length - 1] >= amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');

        address tokenIn = path[0];
        address initialPair = MLLibrary.pairFor(factory, tokenIn, path[1]);
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, initialPair, amounts[0]);
        _swapCached(factory, initialPair, amounts, path, to);
    }

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override payable ensureNotExpired(deadline) returns (uint[] memory amounts) {
        address tokenIn = path[0];
        require(tokenIn == WETH, 'INVALID_PATH');
        amounts = MLLibrary.getAmountsOutUnchecked(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');

        uint256 amountIn = amounts[0];
        IWETH(WETH).deposit{value: amountIn}();

        address initialPair = MLLibrary.pairFor(factory, tokenIn, path[1]);
        assert(IWETH(WETH).transfer(initialPair, amountIn));

        _swapCached(factory, initialPair, amounts, path, to);
    }

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensureNotExpired(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WETH, 'INVALID_PATH');
        amounts = MLLibrary.getAmountsOutUnchecked(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');

        address tokenIn = path[0];
        address initialPair = MLLibrary.pairFor(factory, tokenIn, path[1]);
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, initialPair, amounts[0]);
        _swapCached(factory, initialPair, amounts, path, address(this));

        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensureNotExpired(deadline) returns (uint[] memory amounts) {
        amounts = MLLibrary.getAmountsInUnchecked(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'EXCESSIVE_INPUT_AMOUNT');

        address tokenIn = path[0];
        address initialPair = MLLibrary.pairFor(factory, tokenIn, path[1]);
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, initialPair, amounts[0]);
        _swapCached(factory, initialPair, amounts, path, to);
    }

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override payable ensureNotExpired(deadline) returns (uint[] memory amounts) {
        address tokenIn = path[0];
        require(tokenIn == WETH, 'INVALID_PATH');
        amounts = MLLibrary.getAmountsInUnchecked(factory, amountOut, path);

        uint256 amountIn = amounts[0];
        require(amountIn <= msg.value, 'EXCESSIVE_INPUT_AMOUNT');

        IWETH(WETH).deposit{value: amountIn}();
        address initialPair = MLLibrary.pairFor(factory, tokenIn, path[1]);
        assert(IWETH(WETH).transfer(initialPair, amountIn));
        _swapCached(factory, initialPair, amounts, path, to);

        if (msg.value > amountIn) {
            TransferHelper.safeTransferETH(msg.sender, msg.value - amountIn);
        }
    }

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensureNotExpired(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WETH, 'INVALID_PATH');
        amounts = MLLibrary.getAmountsInUnchecked(factory, amountOut, path);

        uint256 amountIn = amounts[0];
        require(amountIn <= amountInMax, 'EXCESSIVE_INPUT_AMOUNT');

        address tokenIn = path[0];
        address initialPair = MLLibrary.pairFor(factory, tokenIn, path[1]);
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, initialPair, amountIn);
        _swapCached(factory, initialPair, amounts, path, address(this));

        uint256 _amountOut = amounts[amounts.length - 1];
        IWETH(WETH).withdraw(_amountOut);
        TransferHelper.safeTransferETH(to, _amountOut);
    }


    function _swapSupportingFeeOnTransferTokens(address initialPair, address[] calldata path, address _to) internal virtual {
        for (uint i; i < path.length - 1; ) {
            (address input, address output) = (path[i], path[i + 1]);
            
            IMLPair pair = IMLPair(i == 0 ? initialPair : MLLibrary.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;

            {
                (uint reserve0, uint reserve1, uint16 swapFee) = pair.getReservesAndParameters();
                (uint reserveIn, uint reserveOut) = input < output ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveIn;
                amountOutput = MLLibrary.getAmountOut(amountInput, reserveIn, reserveOut, swapFee);
            }

            address to = i < path.length - 2 ? MLLibrary.pairFor(factory, output, path[i + 2]) : _to;

            if (input < output) { 
                pair.swapFor1(amountOutput, to);
            } else {
                pair.swapFor0(amountOutput, to);
            }

            unchecked {
                ++i;
            }
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensureNotExpired(deadline) {
        address tokenIn = path[0];
        address initialPair = MLLibrary.pairFor(factory, tokenIn, path[1]);
        TransferHelper.safeTransferFrom(
            tokenIn, msg.sender, initialPair, amountIn
        );

        address tokenOut = path[path.length - 1];
        uint balanceBefore = IERC20(tokenOut).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(initialPair, path, to);

        require(
            IERC20(tokenOut).balanceOf(to) - balanceBefore >= amountOutMin,
            'INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override payable ensureNotExpired(deadline) {
        address tokenIn = path[0];
        require(tokenIn == WETH, 'INVALID_PATH');

        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        address initialPair = MLLibrary.pairFor(factory, tokenIn, path[1]);
        assert(IWETH(WETH).transfer(initialPair, amountIn));

        address tokenOut = path[path.length - 1];
        uint balanceBefore = IERC20(tokenOut).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(initialPair, path, to);

        require(
            IERC20(tokenOut).balanceOf(to) - balanceBefore >= amountOutMin,
            'INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensureNotExpired(deadline) {
        require(path[path.length - 1] == WETH, 'INVALID_PATH');

        address tokenIn = path[0];
        address initialPair = MLLibrary.pairFor(factory, tokenIn, path[1]);
        TransferHelper.safeTransferFrom(
            tokenIn, msg.sender, initialPair, amountIn
        );
        _swapSupportingFeeOnTransferTokens(initialPair, path, address(this));

        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');

        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    function quote(uint amountA, uint reserveA, uint reserveB) external pure override returns (uint amountB) {
        return MLLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external view override returns (uint amountOut) {
        return MLLibrary.getAmountOut(amountIn, reserveIn, reserveOut, IZFFactory(factory).swapFee());
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external view override returns (uint amountIn) {
        return MLLibrary.getAmountIn(amountOut, reserveIn, reserveOut, IZFFactory(factory).swapFee());
    }

    function getAmountsOut(uint amountIn, address[] calldata path) external view override returns (uint[] memory amounts) {
        return MLLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] calldata path) external view override returns (uint[] memory amounts) {
        return MLLibrary.getAmountsIn(factory, amountOut, path);
    }
}
