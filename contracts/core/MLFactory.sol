pragma solidity ^0.8.0;

import './MLPair.sol';
import '../interfaces/protocol/core/IMLFactory.sol';

contract MLFactory is IMLFactory {
    address public override feeTo;

    address public override feeToSetter;

    address public pendingFeeToSetter;

    mapping(address => mapping(address => address)) public override getPair;

    address[] public override allPairs;

    mapping(address => bool) public override isPair;

    uint16 public override swapFee = 30; 

    uint8 public override protocolFeeFactor = 3; // 1/3, 33.3%

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA); 
        require(token0 != address(0), "ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), 'PAIR_EXISTS'); 

        pair = address(new MLPair(token0, token1));

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        isPair[pair] = true;

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    modifier onlyFeeToSetter() {
        require(msg.sender == feeToSetter, 'FORBIDDEN');
        _;
    }

    function setFeeTo(address _feeTo) external override onlyFeeToSetter {
        feeTo = _feeTo;
    }

    function setSwapFee(uint16 newFee) external override onlyFeeToSetter {
        require(newFee <= 1000, "Swap fee point is too high"); 
        swapFee = newFee;
    }

    function setProtocolFeeFactor(uint8 newFactor) external override onlyFeeToSetter {
        require(protocolFeeFactor > 1, "Protocol fee factor is too high");
        protocolFeeFactor = newFactor;
    }

    function setFeeToSetter(address _feeToSetter) external override onlyFeeToSetter {
        pendingFeeToSetter = _feeToSetter;
    }

    function acceptFeeToSetter() external override {
        require(msg.sender == pendingFeeToSetter, 'FORBIDDEN');
        feeToSetter = pendingFeeToSetter;
    }

    function setSwapFeeOverride(address _pair, uint16 _swapFeeOverride) external override onlyFeeToSetter {
        MLPair(_pair).setSwapFeeOverride(_swapFeeOverride);
    }
}
