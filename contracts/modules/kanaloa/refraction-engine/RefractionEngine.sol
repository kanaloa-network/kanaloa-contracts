// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IRefractionEngine.sol";
import "./LibRefractionEngine.sol";
import "../module/IModule.sol";
import "../../utils/access-control/AccessControl.sol";

contract RefractionEngine is IRefractionEngine, IModule, AccessControl {

    constructor() {
        RefractionEngineStorage storage state =
            LibRefractionEngine.getRefractionEngineStorage();

        state.deployer = tx.origin;
        state.operator = address(0);
        state.init = InitLevel.INITIALIZED;
    }

    /*
     * BEGIN Module
     */
    function _getModuleMetadata() private pure returns (ModuleMetadata memory) {
        bytes4[] memory s = new bytes4[](6);
        s[0] = IRefractionEngine.selectorToContract.selector;
        s[1] = IRefractionEngine.installModule.selector;
        s[2] = IRefractionEngine.installAndInitModule.selector;
        s[3] = IRefractionEngine.installAndInitModules.selector;
        s[4] = IRefractionEngine.editVtable.selector;
        s[5] = AccessControl.setOperator.selector;

        return ModuleMetadata({
            signature: LibRefractionEngine.REFRACTION_ENGINE_STORAGE,
            version: 1,
            selectors: s,
            securityLevel: SecurityLevel.CRITICAL
        });
    }

    function getModuleMetadata() external pure override returns (ModuleMetadata memory) {
        return _getModuleMetadata();
    }

    function getStorageAddress() external pure override returns (bytes32) {
        return LibRefractionEngine.REFRACTION_ENGINE_STORAGE;
    }
    /*
     * END Module
     */

    /*
     * BEGIN AccessControl
     */
    function isOperator(address user) public view override returns (bool) { 
        RefractionEngineStorage storage state =
            LibRefractionEngine.getRefractionEngineStorage();

        return state.operator == user;
    }

    function setOperator(address newOperator) external override operatorsOnly {
        RefractionEngineStorage storage state =
            LibRefractionEngine.getRefractionEngineStorage();

        state.operator = newOperator;

        emit OperatorChanged(newOperator);
    }
    /*
     * END AccessControl
     */


    /*
     * BEGIN IRefractionEngine
     */
    function selectorToContract(bytes4 selector) external view override returns (address) {
        RefractionEngineStorage storage state =
            LibRefractionEngine.getRefractionEngineStorage();

        return state.selectorToContract[selector];
    }

    function _installModule(IModule module) private {
        RefractionEngineStorage storage state =
            LibRefractionEngine.getRefractionEngineStorage();

        address moduleAddress = address(module);
        ModuleMetadata memory metadata = module.getModuleMetadata();
        uint length = metadata.selectors.length;
        VtableActionTaken[] memory actionsTaken = new VtableActionTaken[](length);
        for (uint i = 0; i < metadata.selectors.length; i++) {
            bytes4 selector = metadata.selectors[i];
            address implementation = state.selectorToContract[selector];

            if (implementation == address(0)) {
                state.selectorToContract[selector] = moduleAddress;
                actionsTaken[i] = VtableActionTaken({
                    op: VtableOpCode.ADD,
                    selector: selector
                });
            } else if (implementation == moduleAddress) {
                actionsTaken[i] = VtableActionTaken({
                    op: VtableOpCode.NO_OP,
                    selector: selector
                });
            } else {
                state.selectorToContract[selector] = moduleAddress;
                actionsTaken[i] = VtableActionTaken({
                    op: VtableOpCode.REPLACE,
                    selector: selector
                });
            }
        }

        emit ModuleInstalled(metadata.signature, metadata.version, actionsTaken);
    }

    function installModule(IModule module) external override operatorsOnly {
        _installModule(module);
    }

    function _installAndInitModule(
        IModule module,
        bytes calldata _calldata) private {
        _installModule(module);

        ModuleMetadata memory metadata = module.getModuleMetadata();
        (bool success, ) = address(module).delegatecall(_calldata);
        require(success, "RefractionEngine: could not initialize Module");

        emit ModuleInitialized(
            metadata.signature,
            metadata.version,
            _calldata
        );
    }

    function installAndInitModule(
        IModule module,
        bytes calldata _calldata) external override operatorsOnly {
        _installAndInitModule(module, _calldata);
    }

    function installAndInitModules(
        IModule[] calldata modules,
        bytes[] calldata _calldata) external override operatorsOnly {
        require(modules.length == _calldata.length,
                "RefractionEngine: modules array and call data array lengths do not match");
        uint length = modules.length;

        for (uint i = 0; i < length; i++) {
            // As you can imagine, this is going to emit quite a few events.
            // Load up on the gas, mind the array order (as later modules will
            // override newer modules) and grit your teeth.
            _installAndInitModule(modules[i], _calldata[i]);
        }
    }

    function editVtable(VtableOps[] calldata ops) external override operatorsOnly {
        RefractionEngineStorage storage state =
            LibRefractionEngine.getRefractionEngineStorage();

        for (uint i = 0; i < ops.length; i++) {
            VtableOps calldata op = ops[i];
            if (op.op == VtableOpCode.ADD) {
                for (uint j = 0; j < op.functionSelectors.length; j++) {
                    bytes4 selector = op.functionSelectors[j];
                    require(
                        state.selectorToContract[selector] == address(0),
                        "RefractionEngine: attempted to ADD an already existent selector"
                    );
                    state.selectorToContract[selector] = op.implementation;
                }
            } else if (op.op == VtableOpCode.REPLACE) { 
                for (uint j = 0; j < op.functionSelectors.length; j++) {
                    bytes4 selector = op.functionSelectors[j];
                    require(
                        state.selectorToContract[selector] != address(0),
                        "RefractionEngine: attempted to REPLACE a nonexistent selector"
                    );
                    state.selectorToContract[selector] = op.implementation;
                }
            } else if (op.op == VtableOpCode.REMOVE) { 
                for (uint j = 0; j < op.functionSelectors.length; j++) {
                    bytes4 selector = op.functionSelectors[j];
                    require(
                        state.selectorToContract[selector] != address(0),
                        "RefractionEngine: attempted to DELETE a nonexistent selector"
                    );
                    delete state.selectorToContract[selector];
                }
            }

            emit VtableEdited(msg.sender, ops);
        }
    }

    function initialize(address op, address refractionEngine) external override {
        RefractionEngineStorage storage state =
            LibRefractionEngine.getRefractionEngineStorage();

        require(state.init != InitLevel.INITIALIZED,
                "RefractionEngine: RefractionEngine already initialized in this contract");

        ModuleMetadata memory metadata = _getModuleMetadata();
        state.operator = op;
        // Now that the operator has been set, we can self-install
        _installModule(IModule(refractionEngine));
        state.deployer = tx.origin;
        state.stateVersion = metadata.version;
        state.init = InitLevel.INITIALIZED;

        emit ModuleInitialized(
            metadata.signature,
            metadata.version,
            abi.encode(op, refractionEngine)
        );
    }

    /*
     * END IRefractionEngine
     */
}
