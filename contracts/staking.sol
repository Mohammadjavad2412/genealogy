pragma solidity ^0.8.7;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenFarm is Ownable,ReentrancyGuard {

    using Address for address;

    struct TransactionHistory{
        string transactionType;
        uint256 transactionTimeStamp;
        uint256 amountOfTransaction; 
    }

    struct AdminLog{
        address stakerAddress;
        string transactionType;
        uint256 transactionTimeStamp;
        uint256 amountOfTransaction;
    }

    string public name;
    ERC20 public dappToken;
    uint256 public minimumDeposit;
    uint256 public maximumDeposit;
    uint256 public totalDurationContract;
    uint8 public rateOfReward;
    uint256 public rewardDurationInSecond;
    address[] private stakers;
    AdminLog[] private adminLogs;
    mapping(address => uint256) private InitialBalance;
    mapping(address => uint256) private stakingTimeStamp;
    mapping(address => uint256) private LastRewardTimeStamp;
    mapping(address => uint256) private TotalRewardsUpToNow;
    mapping(address => TransactionHistory[]) private TransactionHistories;

    constructor(address _dappTokenAddress,string memory contractName,uint8 _rateOfRewards,uint256 _rewardDurationInSecond,uint256 _totalDurationContract,uint256 _minimumDeposit,uint256 _maximumDeposit) public{
        dappToken = ERC20(_dappTokenAddress);
        name = contractName;
        rateOfReward = _rateOfRewards;
        rewardDurationInSecond = _rewardDurationInSecond;
        minimumDeposit = _minimumDeposit;
        maximumDeposit = _maximumDeposit;
        totalDurationContract = _totalDurationContract;
    }

    event stakeEvent(address staker,uint amount);

    event unstakeEvent(address staker,uint amount);

    event forcewithdrawEvent(address staker,uint amount);

    event rewardEvent(address staker,uint amount);
    

    // call when user want to cash balance before contract duration end and user dont get any reward

    function ForceWithdraw() public {
        address stakerAddress = msg.sender;
        uint remainBalance = InitialBalance[stakerAddress]-TotalRewardsUpToNow[stakerAddress];
        bool success = dappToken.transfer(stakerAddress,remainBalance);
        if (success==true){
            for (uint256 i=0;i<stakers.length;i++){
                if (stakers[i]==msg.sender){
                    delete stakers[i];
                }
            }
            AdminLog memory log = AdminLog(msg.sender,"force withdraw",block.timestamp,remainBalance);
            adminLogs.push(log);
            TransactionHistory memory transactionHist = TransactionHistory("force withdraw",block.timestamp,remainBalance);
            TransactionHistories[msg.sender].push(transactionHist);
            delete stakingTimeStamp[msg.sender];
            delete InitialBalance[msg.sender];
            delete TotalRewardsUpToNow[msg.sender];
            emit forcewithdrawEvent(msg.sender,remainBalance);
            }
        }

    // only owner can calcualte reward for all stakers and update total reward state.

    function calcualteRewards() internal onlyOwner{
        for (uint256 i=0;i<stakers.length;i++){
            address stakerAddress = stakers[i];
            if ((LastRewardTimeStamp[stakerAddress]+rewardDurationInSecond)<block.timestamp){
            uint rewardDurationTime = (block.timestamp - LastRewardTimeStamp[stakerAddress])/rewardDurationInSecond;
            for (uint256 j=0;j<rewardDurationTime;j++){
                uint256 reward = (InitialBalance[stakerAddress]*rateOfReward/100);
                TotalRewardsUpToNow[stakerAddress]+=reward;
                }
            }
        }
    }

    // an internal method for checking if user is staker or not and return boolean.

    function IsStaker() internal view returns(bool result){
        bool result = false;
        for (uint256 i=0;i<stakers.length;i++){
            if (stakers[i]==msg.sender){
                bool result = true;
                return result;
            }
        }
        return result;
    }

    // this funciton is used when user wants to now how much reward he/she gave in all contract duration.

    function calculateTotalReward()public view returns(uint256 totalReward){
        if(IsStaker()==true){
            uint256 stakingTime = stakingTimeStamp[msg.sender];
            uint256 thisTime = block.timestamp;
            uint256 stakingDuration = thisTime-stakingTime;
            uint256 countRewards = stakingDuration/rewardDurationInSecond;
            uint256 totalRewardStaker = countRewards*(InitialBalance[msg.sender]*rateOfReward/100);
            return totalRewardStaker;
        }
        else{
            uint256 totalRewardStaker = 0;
            return totalRewardStaker;
        }
    }

    // this method is only call by owner to issue reward.
    //NOTE: run this method periodically
    function IssueRewards() public onlyOwner{
        calcualteRewards();
        for (uint256 i=0;i<stakers.length;i++){
            address stakerAddress = stakers[i];
            uint256 reward = TotalRewardsUpToNow[stakerAddress];
            AdminLog memory log = AdminLog(stakerAddress,"reward",block.timestamp,reward);
            adminLogs.push(log);
            TransactionHistory memory transactionHist = TransactionHistory("reward",block.timestamp,reward);
            TransactionHistories[stakerAddress].push(transactionHist);
            dappToken.approve(stakerAddress,reward);
            bool success = dappToken.transfer(stakerAddress,reward);
            if (success){
                LastRewardTimeStamp[stakerAddress] = block.timestamp;
                emit rewardEvent(stakerAddress,reward);
            }
        }
    }

    // when user wants to see his/her  staking balance.

    function myBalance()public view returns(uint256 stakerBalance){
        uint256 balance=InitialBalance[msg.sender];
        return balance;
    }

    //called when user wants to stake token.

    function stakeTokens(uint256 _amount) public {
        require(_amount > 0, "amount cannot be 0");
        require(_amount>=minimumDeposit,"amount must be greater than minimum deposit");
        require(_amount<=maximumDeposit,"amount must be little than maximum deposit");
        require(dappToken.balanceOf(msg.sender)>_amount,"not enough token in your wallet!");
        bool success = dappToken.transferFrom(msg.sender, address(this), _amount);
        if (success==true){
            if (IsStaker()==false){
                stakers.push(msg.sender);
            }
            AdminLog memory log = AdminLog(msg.sender,"stake",block.timestamp,_amount);
            adminLogs.push(log);
            TransactionHistory memory transactionHist = TransactionHistory("stake",block.timestamp,_amount);
            TransactionHistories[msg.sender].push(transactionHist);
            InitialBalance[msg.sender] =InitialBalance[msg.sender] + _amount;
            stakingTimeStamp[msg.sender]=block.timestamp;
            LastRewardTimeStamp[msg.sender]=block.timestamp;
            emit stakeEvent(msg.sender,_amount);
            }
        }
    // Unstaking Tokens (Withdraw)
    function unstakeTokens() public onlyOwner{
        IssueRewards();
        // Fetch staking balance
        for (uint i=0;i<stakers.length;i++){
            address stakerAddress = stakers[i];
            uint256 balance = InitialBalance[stakerAddress];
            require(balance > 0, "staking balance cannot be 0");
            if (stakingTimeStamp[stakerAddress]<block.timestamp-totalDurationContract){
                bool success = dappToken.transfer(stakerAddress, balance);
                if (success==true){
                    AdminLog memory log = AdminLog(stakerAddress,"unstaking",block.timestamp,balance);
                    adminLogs.push(log);
                    TransactionHistory memory transactionHist = TransactionHistory("unstaking",block.timestamp,balance);
                    TransactionHistories[msg.sender].push(transactionHist);
                    delete stakers[i];
                    delete stakingTimeStamp[stakerAddress];
                    delete InitialBalance[stakerAddress];
                    delete TotalRewardsUpToNow[stakerAddress];
                    emit unstakeEvent(msg.sender,balance);
                   }
                }
            }
        }

    //list all transactions of user in this contract
    function myTransactions() public view returns (TransactionHistory[] memory){
        uint transCount = TransactionHistories[msg.sender].length;
        TransactionHistory[] memory lTrans = new TransactionHistory[](transCount);
        for (uint i = 0; i < transCount; i++) {
          TransactionHistory storage thisTrans = TransactionHistories[msg.sender][i];
          lTrans[i] = thisTrans;
            }
        return lTrans;
        }
    
    //admin can call this function to see all transactions.
    function getAdminlog() public view onlyOwner returns(AdminLog[] memory){
        AdminLog[] memory transactions = adminLogs;
        return transactions;
        }  

    // admin can call this function when want to have history of filtered transaction.
    // NOTE: type should be "stake" or "unstake" , "reward" , "force withdraw".
    function filterAdminlog(string memory typeOfTransaction,uint256 startDate,uint256 endDate) public  view onlyOwner returns(AdminLog[] memory){
        uint count = getFilteredCount(typeOfTransaction,startDate,endDate);
        AdminLog[] memory filteredResults = new AdminLog[](count);
        uint j = 0;
        for(uint256 i=0;i<adminLogs.length;i++){
            AdminLog memory thisTrans = adminLogs[i];
            if (keccak256(bytes(thisTrans.transactionType)) == keccak256(bytes(typeOfTransaction)) && thisTrans.transactionTimeStamp>startDate && thisTrans.transactionTimeStamp<endDate){
                filteredResults[j]=thisTrans;
                j++;
                }
            }
        return(filteredResults);
        }

    //this is internal method to get count of transactions that passed filtering.
    function getFilteredCount(string memory typeOfTransaction,uint256 startDate,uint256 endDate) internal view onlyOwner returns(uint){
        uint j =1;
        for(uint256 i=0;i<adminLogs.length;i++){
            AdminLog memory thisTrans = adminLogs[i];
            if (keccak256(bytes(thisTrans.transactionType)) == keccak256(bytes(typeOfTransaction)) && thisTrans.transactionTimeStamp>startDate && thisTrans.transactionTimeStamp<endDate){
                j++;
                }
            }
        return(j-1);  
    }
}