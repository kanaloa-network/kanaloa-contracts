// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./LibRefractionEngine.sol";
import "./IRefractionEngine.sol";

contract RefractionProxy {

    constructor(address op, address rE) {
        (bool success, ) = rE.delegatecall(
            abi.encodeWithSignature("initialize(address,address)", op, rE)
        );
        require(success, "RefractionProxy: Could not initialize RefractionEngine.");
    }

    fallback() external payable {
        RefractionEngineStorage storage state =
            LibRefractionEngine.getRefractionEngineStorage();

        address impl = state.selectorToContract[msg.sig];
        require(impl != address(0), "RefractionProxy: function signature not found");
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0,0, returndatasize())
            switch result
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
        }
    }

    receive() external payable {}
}
