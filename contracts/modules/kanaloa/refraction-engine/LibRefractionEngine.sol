// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { RefractionEngineStorage } from "./IRefractionEngine.sol";

library LibRefractionEngine {
    bytes32 constant REFRACTION_ENGINE_STORAGE = keccak256("modules.kanaloa.refraction-engine");

    function
        getRefractionEngineStorage()
        internal pure
        returns (RefractionEngineStorage storage state) {
        bytes32 position = REFRACTION_ENGINE_STORAGE;
        assembly {
            state.slot := position
        }
    }
}
