pragma solidity ^0.8.0;

import "./uniswap/IUniswapV2Pair.sol";

interface IMLPair is IUniswapV2Pair {
    function getPrincipal(address account) external view returns (uint112 principal0, uint112 principal1, uint32 timeLastUpdate);
    function swapFor0(uint amount0Out, address to) external; 
    function swapFor1(uint amount1Out, address to) external; 

    function getReservesAndParameters() external view returns (uint112 reserve0, uint112 reserve1, uint16 swapFee);
    function getReservesSimple() external view returns (uint112, uint112);

    function swapFeeOverride() external view returns (uint16);
    function setSwapFeeOverride(uint16 newSwapFeeOverride) external;
    function getSwapFee() external view returns (uint16);
}