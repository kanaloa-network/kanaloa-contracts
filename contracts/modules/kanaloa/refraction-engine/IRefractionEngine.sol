// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IModule, InitLevel} from "../module/IModule.sol";

struct RefractionEngineStorage {
    InitLevel init;
    address deployer;
    address operator;
    uint256 stateVersion;
    mapping(bytes4 => address) selectorToContract;
}

interface IRefractionEngine {

    enum VtableOpCode {
        NO_OP,
        ADD,
        REPLACE,
        REMOVE
    }

    struct VtableOps {
        address implementation;
        VtableOpCode op;
        bytes4[] functionSelectors;
    }

    event ModuleInitialized(
        bytes32 indexed moduleSignature,
        uint256 moduleVersion,
        bytes initData
    );

    struct VtableActionTaken {
        VtableOpCode op;
        bytes4 selector;
    }

    event VtableEdited(
        address indexed issuer,
        VtableOps[] operations
    );

    event ModuleInstalled(
        bytes32 indexed moduleSignature,
        uint256 moduleVersion,
        VtableActionTaken[] actionsTaken
    );


    function selectorToContract(bytes4 selector) external returns (address);
    function editVtable(VtableOps[] calldata ops) external;
    function installModule(IModule module) external;
    function installAndInitModule(IModule module, bytes calldata _calldata) external;
    function installAndInitModules(IModule[] calldata module, bytes[] calldata _calldata) external;
    function initialize(address op, address refractionEngine) external;
}
