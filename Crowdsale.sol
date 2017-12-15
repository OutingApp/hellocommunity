@pragma solidity ^0.4.18;

library SafeMath {

    /*
        @return sum of a and b
    */
    function ADD (uint256 a, uint256 b) pure internal returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }

    /*
        @return difference of a and b
    */
    function SUB (uint256 a, uint256 b) pure internal returns (uint256) {
        assert(a >= b);
        return a - b;
    }
    
}

interface token {
    function transfer(address receiver, uint amount) external;
    function burn(uint256 _value) external;
}

contract Crowdsale {

    using SafeMath for uint256;

    address public beneficiary;
    uint256 public constant hardCapInTokens = 20160000000000000; //
    uint256 public fundingGoal;       								 //SoftCap
    uint256 public amountRaised;
    uint256 public deadline;
    uint256 public price;
    token public tokenReward;
    uint256 public soldTokens;  								//Count Outing Tokens sold
    uint256 public restTokens = (hardCapInTokens - soldTokens);
    
    uint256 public constant MIN_ETHER = 0.2 ether;     //Min amount of Ether 
    uint256 public constant MAX_ETHER = 125 ether;              //Max amount of Ether

    uint256 public START = now;                        //Start crowdsale

    uint256 public TIER2 = now + 20160 minutes;        //Start + 14 days

    uint256 public TIER3 = now + 40320 minutes;        //Start + 28 days ( 14 days + 14 days)

    uint256 public TIER4 = now + 50400 minutes;        //Start + 35 days ( 14 days + 14 days + 7 days)


    uint256 public constant TIER1_PRICE = 1032800;      //Price in 1st tier
    uint256 public constant TIER2_PRICE = 1180300;      //Price in 2nd tier
    uint256 public constant TIER3_PRICE = 1327800;      //Price in 3rd tier
    uint256 public constant TIER4_PRICE = 1475400;      //Price in 4th tier


    mapping(address => uint256) public balanceOf;
    bool fundingGoalReached = false;
    bool crowdsaleClosed = false;

    event GoalReached(address recipient, uint totalAmountRaised);
    event FundTransfer(address backer, uint amount, bool isContribution);

    function Crowdsale (address ifSuccessfulSendTo, uint fundingGoalInEthers, uint durationInMinutes, address addressOfTokenUsedAsReward)
    public
    {
        beneficiary = ifSuccessfulSendTo;
        fundingGoal = fundingGoalInEthers * 1 ether;
        deadline = now + durationInMinutes * 1 minutes;
        price = getPrice();
        tokenReward = token(addressOfTokenUsedAsReward);
    }

    function () public payable {
        require(!crowdsaleClosed);
        uint amount = msg.value;
        require(amount >= MIN_ETHER);
        require (amount <= MAX_ETHER);
        balanceOf[msg.sender] += amount;
        amountRaised += amount;
        soldTokens += amount / price;
        tokenReward.transfer(msg.sender, amount / price);
        FundTransfer(msg.sender, amount, true);

    }

    modifier afterDeadline() { if (now >= deadline) _; }

    /**
     * Check if goal was reached
     *
     * Checks if the goal or time limit has been reached and ends the campaign
     */
    function checkGoalReached() afterDeadline public {
        if (amountRaised >= fundingGoal){
            fundingGoalReached = true;
            GoalReached(beneficiary, amountRaised);
        }

       	 if (soldTokens >= hardCapInTokens)   {
        crowdsaleClosed = true;

        tokenReward.burn(hardCapInTokens - soldTokens);

        	}
    }

        /* Change tier taking block numbers as time */
    function getPrice()
        internal
        constant
        returns (uint256)
    {
        if (now <= TIER2) {
            return TIER1_PRICE;
        } else if (now < TIER3) {
            return TIER2_PRICE;
        } else if (now < TIER4) {
            return TIER3_PRICE;
        }
        return TIER4_PRICE;
    }


    /**
     * Withdraw the funds
     *
     * Checks to see if goal or time limit has been reached, and if so, and the funding goal was reached,
     * sends the entire amount to the beneficiary. If goal was not reached, each contributor can withdraw
     * the amount they contributed.
     */
    function safeWithdrawal() afterDeadline public {
        if (!fundingGoalReached) {
            uint amount = balanceOf[msg.sender];
            balanceOf[msg.sender] = 0;
            if (amount > 0) {
                if (msg.sender.send(amount)) {
                    FundTransfer(msg.sender, amount, false);
                } else {
                    balanceOf[msg.sender] = amount;
                }
            }
        }

        if (fundingGoalReached && beneficiary == msg.sender) {
            if (beneficiary.send(amountRaised)) {
                FundTransfer(beneficiary, amountRaised, false);
            } else {
                //If we fail to send the funds to beneficiary, unlock funders balance
                fundingGoalReached = false;
            }
        }
    }
}

