// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

enum SecurityLevel {
    CRITICAL,
    HIGH,
    MEDIUM,
    LOW
}

struct ModuleMetadata {
    bytes32 signature;
    uint256 version;
    bytes4[] selectors;
    SecurityLevel securityLevel;
}

enum InitLevel {
    NOT_INITIALIZED,
    INITIALIZING,
    INITIALIZED
}

interface IModule {
    function getModuleMetadata() external view returns (ModuleMetadata memory);
    function getStorageAddress() external pure returns (bytes32);
}
