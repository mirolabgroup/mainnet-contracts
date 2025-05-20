pragma solidity ^0.8.0;

interface IERC20Balance {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}
