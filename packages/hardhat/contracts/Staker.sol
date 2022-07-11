// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {
    ExampleExternalContract public exampleExternalContract;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTimestamps;

    uint256 public constant rewardRatePerSecond = 0.1 ether;
    uint256 public withdrawalDeadline = block.timestamp + 120 seconds;
    uint256 public claimDeadline = block.timestamp + 240 seconds;
    uint256 public currentBlock = 0;

    event Stake(address indexed sender, uint256 amount);
    event Received(address, uint256);
    event Execute(address indexed sender, uint256 amount);

    modifier withdrawalDeadlineReached(bool requireReached) {
        uint256 timeLeft = withdrawalTimeleft();

        if (requireReached) {
            require(timeLeft == 0, "Withdrawal period is not reached yet");
        } else {
            require(timeLeft > 0, "Withdrawal period has been reached");
        }
        _;
    }

    modifier claimDeadlineReached(bool requireReached) {
        uint256 timeLeft = claimPeriodLeft();
        if (requireReached) {
            require(timeLeft == 0, "Claim period is not reached yet");
        } else {
            require(timeLeft > 0, "Claim period has been reached");
        }
        _;
    }

    modifier notComplete() {
        bool completed = exampleExternalContract.completed();
        require(!completed, "Stake already completed!");
        _;
    }

    constructor(address exampleExternalContractAddress) public {
        exampleExternalContract = ExampleExternalContract(
            exampleExternalContractAddress
        );
    }

    function withdrawalTimeleft()
        public
        view
        returns (uint256 withdrawalTimeleft)
    {
        if (block.timestamp >= withdrawalDeadline) {
            return (0);
        } else {
            return (withdrawalDeadline - block.timestamp);
        }
    }

    function claimPeriodLeft() public view returns (uint256 claimPeriodLeft) {
        if (block.timestamp >= claimDeadline) {
            return (0);
        } else {
            return (claimDeadline - block.timestamp);
        }
    }

    function stake()
        public
        payable
        withdrawalDeadlineReached(false)
        claimDeadlineReached(false)
    {
        balances[msg.sender] = balances[msg.sender] + msg.value;
        depositTimestamps[msg.sender] = block.timestamp;
        emit Stake(msg.sender, msg.value);
    }

    function withdraw()
        public
        withdrawalDeadlineReached(true)
        claimDeadlineReached(true)
    {
        require(balances[msg.sender] > 0, "You have no balance to withdraw!");
        uint256 individualBalance = balances[msg.sender];
        uint256 totalBalance = individualBalance +
            ((block.timestamp - depositTimestamps[msg.sender]) *
                rewardRatePerSecond);
        balances[msg.sender] = 0;
        // Transfer all ETH via call!
        (bool sent, bytes memory data) = msg.sender.call{value: totalBalance}(
            ""
        );
        require(sent, "RIP withdrawal failed");
    }

    function execute() public claimDeadlineReached(true) {
        uint256 contractBalance = address(this).balance;
        exampleExternalContract.complete{value: address(this).balance}();
    }

    /*
  Time to "kill-time" on our local testnet
  */
    function killTime() public {
        currentBlock = block.timestamp;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
