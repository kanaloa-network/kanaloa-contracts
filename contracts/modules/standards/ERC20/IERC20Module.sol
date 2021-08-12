// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../kanaloa/module/IModule.sol";
import "./IERC20.sol";


struct ERC20Storage {
    InitLevel init;
    address deployer;
    uint256 stateVersion;

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;
    uint256 totalSupply;
    uint256 maxSupply;

    string name;
    string symbol;
    uint8 decimals;
}

interface IERC20Module is IERC20, IModule {
    function initialize(
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        uint256 supply,
        address mintTo) external;
}
