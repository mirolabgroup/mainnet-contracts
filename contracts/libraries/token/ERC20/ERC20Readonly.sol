pragma solidity ^0.8.0;

import '../../../interfaces/ERC20/IERC20Metadata.sol';
import '../../../interfaces/ERC20/IERC20Balance.sol';

abstract contract ERC20Readonly is IERC20Metadata, IERC20Balance {
    string public override name;

    string public override symbol;

    uint8 public override decimals;

    uint256 public _totalSupply;

    mapping (address => uint256) private _balances;

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function _setMetadata(string memory _name, string memory _symbol, uint8 _decimals) internal {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function _increaseBalance(address account, uint256 value) internal {
        _totalSupply += value;
        _balances[account] += value;
    }

    function _decreaseBalance(address account, uint256 value) internal {
        _totalSupply -= value;
        _balances[account] -= value;
    }
}
