// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StakingContract {
    address payable public owner;
    mapping(address => uint) public balances;
    mapping(address =>uint)stakedtime;
    uint public totalStaked;
    uint rewards;

    event Stake(address staker, uint amount);
    event Withdrawal(address staker, uint amount);

    // constructor() {
    //     owner = payable(msg.sender);
    // }

    function stake() public payable {
        require(msg.value > 0, "Staking amount must be greater than 0");
        balances[msg.sender] += msg.value;
        totalStaked += msg.value;
        stakedtime[msg.sender]=block.timestamp;
        emit Stake(msg.sender, msg.value);
    }

    function unstake(uint amount) public {
        require(amount > 0 && amount <= balances[msg.sender], "Invalid withdrawal amount");
         (bool success,)=msg.sender.call{value:amount}("");
        require(success,"transfer failed.");
        balances[msg.sender] -= amount;
        totalStaked -= amount;
       emit Withdrawal(msg.sender, amount);
    }

    function reward()public  {
        require(totalStaked>0,"amount is less than zero");
        uint secondStaked = block.timestamp - stakedtime[msg.sender];
         rewards=totalStaked * secondStaked/3.154e7;
        stakedtime[msg.sender]=block.timestamp;
    //    return rewards;
        
    }
    function withdraw()public{
        (bool success,)=msg.sender.call{value:rewards}("");
        require(success,"transfer failed.");
    }

    function viewreward() public view returns (uint) {
        if( totalStaked >0){
            return rewards;
        }
        else{
            return 0;
        }
        
    }

   

    // function getTotalStaked() public view returns (uint) {
    //     return totalStaked;
    // }
}