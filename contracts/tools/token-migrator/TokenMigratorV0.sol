// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../modules/standards/ERC20/IERC20.sol";
import "../../modules/utils/access-control/AccessControl.sol";
import "../../modules/utils/reentrancy-guard/ReentrancyGuard.sol";
import "../uniswap/IUniswapV2Pair.sol";
import "../uniswap/IUniswapV2Router02.sol";
import "../uniswap/IUniswapV2Factory.sol";
import "../uniswap/IWETH.sol";

/*
 * @dev
 * This contract allows one-way migration of an old ERC20 token of the
 * deployer's choosing to any other ERC20 token this contract can hold.
 * It supports migration from reflection tokens, and it will ignore any
 * taxes the old token had before sending back the equivalent in new tokens.
 *
 * The first version of this contract allows migration from IUniswapV2Pair
 * compatible LP tokens consisting of the old token and the provided
 * IUniswapV2Router's WETH(). By calculating the tax deducted on removing
 * liquidity, this contract can return all of the WETH() and the expected
 * equivalent in the new token.
 */
contract TokenMigratorV0 is AccessControl, ReentrancyGuard {

    IERC20 public immutable migrate;
    IERC20 public immutable migrateTo;
    IUniswapV2Router02 public immutable uniswapRouter;
    int256 public immutable ratio;
    uint8 public immutable migrateTaxPercent;
    bool public locked = false;

    address private operator;

    modifier lockable {
        require(locked == false,
                "TokenMigratorV0: migrator is in lockdown. Further swaps are disallowed.");
        _;
    }

    event TokensSwapped(
        uint256 oldAmount,
        uint256 newAmount,
        address indexed issuer
    );

    event LiquidityWithdrawn(
        uint256 oldAmount,
        uint256 newAmount,
        uint256 withdrawnETH,
        address indexed issuer
    );

    event LockdownInitiated();
    event MigratorPurged(uint256 purgedAmount);

    constructor(
        IERC20 _migrate,
        IERC20 _migrateTo,
        IUniswapV2Router02 _uniswapRouter,
        int256 _ratio,
        uint8 _migrateTaxPercent,
        address _operator
    ) {
        require(address(_migrate) != address(0),
                "TokenMigratorV0: you can't migrate the zero address");
        require(address(_migrateTo) != address(0),
                "TokenMigratorV0: you can't migrate to the zero address");
        require(_ratio != 0,
                "TokenMigratorV0: ratio can't be zero. Use 1 if you want a 1:1 ratio.");
        migrate = _migrate;
        migrateTo = _migrateTo;
        uniswapRouter = _uniswapRouter;
        ratio = _ratio;
        migrateTaxPercent = _migrateTaxPercent;

        operator = _operator;
    }

    function calcNewAmount(uint256 oldAmount) public view returns (uint256) {
        if (ratio < 0) {
            // If ratio is negative, redenomination requires division. Due to
            // integer division limitations, this means some dust could be lost
            // in the process.
            return oldAmount / uint256(-ratio);
        } else {
            // If ratio is positive (because it can't be zero), redenomination
            // requires multiplication.
            return oldAmount * uint256(ratio);
        }
    }

    function adjustDecimals(uint256 amount) public view returns (uint256) {
        // While we could cache this result for more efficient gas usage,
        // there are no guarantees the IERC20 operators could change the
        // decimals amount at any given time.
        int8 decimalsDelta =
            int8(migrate.decimals()) - int8(migrateTo.decimals());

        if (decimalsDelta == 0) {
            return amount;
        } else if (decimalsDelta > 0) {
            // Redenomination to a contract with less decimals. Division
            // required.
            return amount / 10 ** uint8(decimalsDelta);
        } else {
            // Redenomination to a contract with more decimals. Multiplication
            // required.
            return amount * 10 ** uint8(-decimalsDelta);
        }
    }

    function rebaseTokens(uint256 amount) public view returns (uint256) {
        return calcNewAmount(adjustDecimals(amount));
    }

    function recoverAmountBeforeTax(uint256 amount) public view returns (uint256) {
        // Using burn() in the IUniswapV2Pair returns the "real" amount of tokens
        // withdrawn, so this function is not used in this contract.
        return amount * 100 / (100  - migrateTaxPercent);
    }

    /*
     * @dev TokenMigratorV0 only supports all-in migrations. Transfer the tokens
     * you may want to save to another wallet before proceeding.
     */
    function swapTokens() external lockable nonReentrant {
        uint256 balance = migrate.balanceOf(msg.sender);
        require(balance != 0, "TokenMigratorV0: you don't have any tokens to migrate");

        migrate.transferFrom(msg.sender, address(this), balance);

        uint256 newBalance = rebaseTokens(balance);
        require(newBalance != 0,
                "TokenMigratorV0: rebasing of the tokens would result in 0 new tokens");

        migrateTo.transfer(msg.sender, newBalance);

        emit TokensSwapped(balance, newBalance, msg.sender);
    }

    function unwrapLiquidity() external lockable nonReentrant {
        // UniswapV2Routers transfer liquidity to themselves before transferring
        // it to the users, so the tax is applied twice if the router is not
        // excluded from tax. We will call the lower level burn() function from
        // IUniswapV2Pair instead
        address weth = uniswapRouter.WETH();
        IUniswapV2Pair lpt =
            IUniswapV2Pair(
                IUniswapV2Factory(uniswapRouter.factory())
                    .getPair(address(migrate), weth)
            );

        lpt.transferFrom(msg.sender, address(lpt), lpt.balanceOf(msg.sender));

        assert(lpt.token0() == weth || lpt.token1() == weth);

        uint256 amountWETH;
        uint256 amountMigrate;
        uint256 amountMigrateTo;
        if (lpt.token0() == weth) {
            (amountWETH, amountMigrate) = lpt.burn(address(this));
        } else {
            (amountMigrate, amountWETH) = lpt.burn(address(this));
        }

        amountMigrateTo = rebaseTokens(amountMigrate);

        IWETH(weth).withdraw(amountWETH);
        payable(msg.sender).transfer(amountWETH);
        migrateTo.transfer(msg.sender, amountMigrateTo);

        emit LiquidityWithdrawn(
            amountMigrate,
            amountMigrateTo,
            amountWETH,
            msg.sender
        );
    }

    /*
     * BEGIN AccessControl
     */
    function isOperator(address user) public view override returns (bool) {
        return user == operator;
    }

    function setOperator(address newOperator) external override operatorsOnly {
        operator = newOperator;
        emit OperatorChanged(newOperator);
    }
    /*
     * END AccessControl
     */

    /*
     * @dev BLOCK THE MIGRATOR FOREVER. This will make it impossible for
     * anyone to swap more tokens using this migrator. USE ONLY WHEN YOU
     * ARE SURE YOU WANT TO STOP THE MIGRATION.
     */
    function lockdown() external operatorsOnly {
        locked = true;
        emit LockdownInitiated();
    }

    /*
     * @dev The Exterminatus option.
     */
    function purgeMigrator() external operatorsOnly {
        uint256 currentHodlings = migrateTo.balanceOf(address(this));
        migrateTo
            .transfer(
                0x000000000000000000000000000000000000dEaD,
                currentHodlings);

        this.lockdown();
        operator = address(0);

        emit MigratorPurged(currentHodlings);
    }

    receive() external payable { }

}
