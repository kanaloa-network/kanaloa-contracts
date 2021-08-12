// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

abstract contract AccessControl {
    event OperatorChanged(address indexed newOperator);

    function _msgSender() public view virtual returns (address user) {
        return msg.sender;
    }

    function isOperator(address user) public view virtual returns (bool);
    function setOperator(address) external virtual {
        revert("AccessControl: setOperator unsupported by this contract");
    }

    modifier operatorsOnly {
        require(isOperator(_msgSender()), "AccessControl: user is not an operator"); 
        _;
    }
}
