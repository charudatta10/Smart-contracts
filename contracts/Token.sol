// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
    // ------------------------------------------ //
    // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
    // ------------------------------------------ //
    using SafeMath for uint256;
    uint256 public totalSupply;
    uint256 public decimals = 18;
    string public name = "Test token";
    string public symbol = "TEST";
    mapping(address => uint256) public balanceOf;
    // ------------------------------------------ //
    // ----- END: DO NOT EDIT THIS SECTION ------ //
    // ------------------------------------------ //

    // ERC-20 allowances
    mapping(address => mapping(address => uint256)) private _allowance;

    // Active token holders (balance > 0).
    // External API is 1-based: getTokenHolder(1) = first holder.
    // _holderPos[addr] = 1-based index in _holders; 0 means absent.
    address[] private _holders;
    mapping(address => uint256) private _holderPos;

    // Dividends accumulated per address (survives burn / transfer-away)
    mapping(address => uint256) private _dividends;

    // ----------------------------------------------------------------
    // Internal helpers
    // ----------------------------------------------------------------

    function _addHolder(address addr) private {
        // Only track addresses that actually hold tokens
        if (_holderPos[addr] == 0 && balanceOf[addr] > 0) {
            _holders.push(addr);
            _holderPos[addr] = _holders.length; // 1-based
        }
    }

    /// O(1) swap-and-pop removal.
    function _removeHolder(address addr) private {
        uint256 pos = _holderPos[addr]; // 1-based
        if (pos == 0) return;

        uint256 lastIdx = _holders.length - 1; // 0-based
        uint256 thisIdx = pos - 1;             // 0-based

        if (thisIdx != lastIdx) {
            address tail = _holders[lastIdx];
            _holders[thisIdx] = tail;
            _holderPos[tail] = pos; // tail inherits addr's 1-based slot
        }

        _holders.pop();
        _holderPos[addr] = 0;
    }

    function _move(address from, address to, uint256 value) private {
        require(balanceOf[from] >= value, "insufficient balance");

        // Zero-value transfers are a no-op for holder tracking
        if (value == 0) return;

        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to]   = balanceOf[to].add(value);

        // Remove sender if they've exhausted their balance
        if (balanceOf[from] == 0) {
            _removeHolder(from);
        }
        // Add recipient now that their balance has been updated
        _addHolder(to);
    }

    // ----------------------------------------------------------------
    // IERC20
    // ----------------------------------------------------------------

    function allowance(address owner, address spender)
        external view override returns (uint256)
    {
        return _allowance[owner][spender];
    }

    function transfer(address to, uint256 value)
        external override returns (bool)
    {
        _move(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value)
        external override returns (bool)
    {
        _allowance[msg.sender][spender] = value;
        return true;
    }

    function transferFrom(address from, address to, uint256 value)
        external override returns (bool)
    {
        require(_allowance[from][msg.sender] >= value, "allowance exceeded");
        _allowance[from][msg.sender] = _allowance[from][msg.sender].sub(value);
        _move(from, to, value);
        return true;
    }

    // ----------------------------------------------------------------
    // IMintableToken
    // ----------------------------------------------------------------

    function mint() external payable override {
        require(msg.value > 0, "send ETH to mint");
        balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
        totalSupply = totalSupply.add(msg.value);
        _addHolder(msg.sender);
    }

    function burn(address payable dest) external override {
        uint256 amount = balanceOf[msg.sender];
        require(amount > 0, "nothing to burn");
        balanceOf[msg.sender] = 0;
        totalSupply = totalSupply.sub(amount);
        _removeHolder(msg.sender);
        dest.transfer(amount);
    }

    // ----------------------------------------------------------------
    // IDividends
    // ----------------------------------------------------------------

    function getNumTokenHolders() external view override returns (uint256) {
        return _holders.length;
    }

    /// 1-based: getTokenHolder(1) returns the first holder.
    function getTokenHolder(uint256 index) external view override returns (address) {
        require(index >= 1 && index <= _holders.length, "index out of range");
        return _holders[index - 1];
    }

    function recordDividend() external payable override {
        require(msg.value > 0, "no ETH sent");
        require(totalSupply > 0, "no token supply");

        uint256 len = _holders.length;
        uint256 remaining = msg.value;

        for (uint256 i = 0; i < len; i++) {
            address holder = _holders[i];
            uint256 bal = balanceOf[holder];
            if (bal == 0) continue;
            uint256 share = msg.value.mul(bal).div(totalSupply);
            _dividends[holder] = _dividends[holder].add(share);
            remaining = remaining.sub(share);
        }

        // Assign rounding dust to first holder so no ETH is permanently locked
        if (remaining > 0 && len > 0) {
            _dividends[_holders[0]] = _dividends[_holders[0]].add(remaining);
        }
    }

    function getWithdrawableDividend(address payee)
        external view override returns (uint256)
    {
        return _dividends[payee];
    }

    function withdrawDividend(address payable dest) external override {
        uint256 amount = _dividends[msg.sender];
        require(amount > 0, "nothing to withdraw");
        _dividends[msg.sender] = 0;
        dest.transfer(amount);
    }
}
