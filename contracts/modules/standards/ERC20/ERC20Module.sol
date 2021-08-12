// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./IERC20Module.sol";
import "./LibERC20Module.sol";
import "../../kanaloa/refraction-engine/LibRefractionEngine.sol";
import "../../utils/access-control/AccessControl.sol";

contract ERC20Module is IERC20Module, AccessControl {

    constructor() {
        ERC20Storage storage state = LibERC20Module.getERC20Storage();

        state.deployer = tx.origin;
        state.init = InitLevel.INITIALIZED;
    }

    /*
     * BEGIN ERC20
     */
    function name() external view override returns (string memory) {
        ERC20Storage storage state = LibERC20Module.getERC20Storage();
        return state.name;
    }

    function symbol() external view override returns (string memory) {
        ERC20Storage storage state = LibERC20Module.getERC20Storage();
        return state.symbol;
    }

    function decimals() external view override returns (uint8) {
        ERC20Storage storage state = LibERC20Module.getERC20Storage();
        return state.decimals;
    }

    function totalSupply() external view override returns (uint256) { 
        ERC20Storage storage state = LibERC20Module.getERC20Storage();
        return state.totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        ERC20Storage storage state = LibERC20Module.getERC20Storage();
        return state.balances[account];
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0),
                "ERC20: transfer from the zero address");
        require(to != address(0),
                "ERC20: transfer to the zero address");

        ERC20Storage storage state = LibERC20Module.getERC20Storage();

        uint256 senderBalance = state.balances[from];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            state.balances[from] = senderBalance - amount;
        }
        state.balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        ERC20Storage storage state = LibERC20Module.getERC20Storage();
        return state.allowances[owner][spender];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        ERC20Storage storage state = LibERC20Module.getERC20Storage();

        state.allowances[owner][spender] = amount;

        emit Approval(owner, spender, amount);
    }

    function approve(
        address spender,
        uint256 amount
    ) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(sender, recipient, amount);

        ERC20Storage storage state = LibERC20Module.getERC20Storage();

        uint256 currentAllowance = state.allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }
    /*
     * END ERC20
     */

    /*
     * BEGIN Module
     */
    function _getModuleMetadata() private pure returns (ModuleMetadata memory) {
        bytes4[] memory s = new bytes4[](10);
        s[0] = IERC20.name.selector;
        s[1] = IERC20.symbol.selector;
        s[2] = IERC20.decimals.selector;
        s[3] = IERC20.totalSupply.selector;
        s[4] = IERC20.balanceOf.selector;
        s[5] = IERC20.transfer.selector;
        s[6] = IERC20.allowance.selector;
        s[7] = IERC20.approve.selector;
        s[8] = IERC20.transferFrom.selector;

        return ModuleMetadata({
            signature: LibERC20Module.ERC20_STORAGE,
            version: 1,
            selectors: s,
            securityLevel: SecurityLevel.CRITICAL
        });
    }

    function getModuleMetadata() external pure override returns (ModuleMetadata memory) {
        return _getModuleMetadata();
    }

    function getStorageAddress() external pure override returns (bytes32) {
        return LibERC20Module.ERC20_STORAGE;
    }
    /*
     *END Module
     */

    /*
     * BEGIN AccessControl
     */

    function isOperator(address user) public view override returns (bool) {
        RefractionEngineStorage storage rEState =
            LibRefractionEngine.getRefractionEngineStorage();

        // This implementation assumes the operator is the same as the
        // RefractionEngine operator, which is likely the deployer of
        // the contract. This vanilla ERC20 contract uses it only for
        // initialization purposes.

        // PLEASE DO NOTE THE DEFAULT _msgSender() FUNCTION EQUALS
        // msg.sender! Calling this from a non-delegated proxy will
        // fail.
        return user == rEState.operator;
    }

    /*
     * END AccessControl
     */

    function initialize(
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals,
        uint256 _supply,
        address _mintTo
    ) external override operatorsOnly {
        if(_mintTo == address(0)) {
            require(_supply == 0,
                    "ERC20Module: can not mint genesis tokens to the zero address");
        }

        ERC20Storage storage state = LibERC20Module.getERC20Storage();

        state.name = _name;
        state.symbol = _symbol;
        state.decimals = _decimals;
        state.totalSupply = _supply;
        state.maxSupply = _supply; // Unused in vanilla ERC20Module

        state.deployer = _msgSender();
        state.balances[_mintTo] = _supply;

        emit Transfer(address(0), _mintTo, _supply);
    }
}
