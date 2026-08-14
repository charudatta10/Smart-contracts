# Changelog

All notable changes to this project will be documented in this file.

## [v0.1.0] - 2026-08-14

### Added

- Initial release: mintable ERC-20 `Token` contract (deposit ETH to mint, burn tokens to withdraw ETH).
- Dividend payments in ETH proportional to token holder balances, with gas-efficient holder tracking.
- Hardhat unit test suite covering token and dividend behaviour.

### Fixed

- Finished the `Token.sol` implementation and cleaned up `token.test.js`.
