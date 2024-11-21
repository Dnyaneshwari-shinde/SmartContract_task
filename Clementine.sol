// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Clementine is Ownable {
    string public constant name = "CLMN";       
    string public constant symbol = "CLMN";        
    uint8 public constant decimals = 18;         
    uint256 public totalSupply = 3000000000 * (10 ** uint256(decimals));

    mapping(address => uint256) private balances; 
    mapping(address => mapping(address => uint256)) private allowances; 

    mapping(address => uint256) private lockedBalances;
    mapping(address => uint256) private vestingStart;
    mapping(address => uint256) private vestingDuration;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(
        address ecosystem,
        address team,
        address marketing,
        address earlyAdopters,
        address presale1,
        address companyReserve,
        address _owner
    ) Ownable(_owner) {
        uint256 oneMonth = 30 * 24 * 60 * 60; // 1 month in sec.
        uint256 oneYear = 365 * 24 * 60 * 60; // 1 year in sec.

        _tokendistribution(ecosystem, 450000000, 6 * oneMonth, 3 * oneYear);
        _tokendistribution(team, 150000000, 12 * oneMonth, 2 * oneYear);
        _tokendistribution(marketing, 300000000, oneMonth, oneYear);
        _tokendistribution(earlyAdopters, 300000000, 0, 0); // TGE unlock
        _tokendistribution(presale1, 600000000, 0, 0); // TGE unlock
        balances[companyReserve] = 660000000 * (10 ** uint256(decimals)); // Reserve allocation
        emit Transfer(address(0), msg.sender, 660000000 * (10 ** uint256(decimals)));
    }

    function _tokendistribution(address beneficiary, uint256 amount, uint256 lockPeriod, uint256 vestingPeriod) private {
        uint256 tokenAmount = amount * (10 ** uint256(decimals));
        balances[beneficiary] = tokenAmount;
        lockedBalances[beneficiary] = tokenAmount;
        vestingStart[beneficiary] = block.timestamp + lockPeriod;
        vestingDuration[beneficiary] = vestingPeriod;
        emit Transfer(address(0), beneficiary, tokenAmount);
    }

    function claimTokens() public {
        uint256 unlockedTokens = _calculateUnlockedTokens(msg.sender);
        require(unlockedTokens > 0, "No tokens available for claiming");

        lockedBalances[msg.sender] -= unlockedTokens;
        balances[msg.sender] += unlockedTokens;  // Move to the sender’s balance after unlock
        emit Transfer(address(this), msg.sender, unlockedTokens);
    }

    function _calculateUnlockedTokens(address beneficiary) private view returns (uint256) {
        uint256 lockedAmount = lockedBalances[beneficiary];
        uint256 start = vestingStart[beneficiary];
        uint256 duration = vestingDuration[beneficiary];

        if (block.timestamp < start) return 0; // Still in lock period
        if (duration == 0 || block.timestamp >= start + duration) return lockedAmount; // Fully unlocked

        uint256 elapsedTime = block.timestamp - start;
        return (lockedAmount * elapsedTime) / duration;
    }

    function balanceOf(address _account) public view returns (uint256) {
        return balances[_account];
    }

    function transfer(address _to, uint256 _amount) public returns (bool) {
        require(_to != address(0), "Transfer to zero address");
        uint256 senderBalance = balances[msg.sender]; // Cache the balance
        require(senderBalance >= _amount, "Insufficient balance");

        balances[msg.sender] = senderBalance - _amount;  // Update in one step
        balances[_to] += _amount;
        emit Transfer(msg.sender, _to, _amount);
        return true;
    }

    function approve(address _spender, uint256 _amount) public returns (bool) {
        require(_spender != address(0), "Approve to zero address");

        allowances[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowances[_owner][_spender];
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public returns (bool) {
        require(_to != address(0), "Transfer to zero address");
        uint256 fromBalance = balances[_from];  // Cache the balance
        uint256 spenderAllowance = allowances[_from][msg.sender]; // Cache the allowance
        require(fromBalance >= _amount, "Insufficient balance");
        require(spenderAllowance >= _amount, "Allowance exceeded");

        balances[_from] = fromBalance - _amount;  // Update in one step
        balances[_to] += _amount;
        allowances[_from][msg.sender] = spenderAllowance - _amount;
        emit Transfer(_from, _to, _amount);
        return true;
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        require(_to != address(0), "Mint to zero address");

        uint256 mintedAmount = _amount * (10 ** uint256(decimals));
        totalSupply += mintedAmount;
        balances[_to] += mintedAmount;
        emit Transfer(address(0), _to, mintedAmount);
    }
}
