// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity  ^0.8.0;

import "./IERC20Module.sol";

library LibERC20Module {
    bytes32 constant ERC20_STORAGE = keccak256("modules.standards.erc20");

    function getERC20Storage() internal pure returns (ERC20Storage storage state) {
        bytes32 position = ERC20_STORAGE;
        assembly {
            state.slot := position
        }
    }
}
