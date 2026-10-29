// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title MockUSDC
/// @notice Test-only 6-decimal payment token. It has no monetary value.
contract MockUSDC is ERC20, ERC20Permit {
    uint256 public constant FAUCET_LIMIT = 10_000 * 10 ** 6;

    error FaucetAmountTooLarge(uint256 requested, uint256 maximum);

    constructor() ERC20("Mock USDC", "mUSDC") ERC20Permit("Mock USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function faucetMint(address to, uint256 amount) external {
        if (amount > FAUCET_LIMIT) revert FaucetAmountTooLarge(amount, FAUCET_LIMIT);
        _mint(to, amount);
    }
}
