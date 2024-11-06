pragma solidity ^0.8.0;

import '../../../../interfaces/ERC20/IERC20.sol';

library SafeERC20 {
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'SafeERC20::safeTransfer: transfer failed'
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'SafeERC20::transferFrom: transferFrom failed'
        );
    }

    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0x095ea7b3, spender, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'SafeERC20::safeApprove: approve failed'
        );
    }
}