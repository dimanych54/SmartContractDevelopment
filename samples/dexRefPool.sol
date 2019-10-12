pragma solidity 0.5.11; /*


    ___________________________________________________________________
      _      _                                        ______           
      |  |  /          /                                /              
    --|-/|-/-----__---/----__----__---_--_----__-------/-------__------
      |/ |/    /___) /   /   ' /   ) / /  ) /___)     /      /   )     
    __/__|____(___ _/___(___ _(___/_/_/__/_(___ _____/______(___/__o_o_                    
    
    
    ██████╗ ███████╗██╗  ██╗   ██████╗ ███████╗███████╗███████╗██████╗ ██████╗  █████╗ ██╗           
    ██╔══██╗██╔════╝╚██╗██╔╝   ██╔══██╗██╔════╝██╔════╝██╔════╝██╔══██╗██╔══██╗██╔══██╗██║            
    ██║  ██║█████╗   ╚███╔╝    ██████╔╝█████╗  █████╗  █████╗  ██████╔╝██████╔╝███████║██║           
    ██║  ██║██╔══╝   ██╔██╗    ██╔══██╗██╔══╝  ██╔══╝  ██╔══╝  ██╔══██╗██╔══██╗██╔══██║██║          
    ██████╔╝███████╗██╔╝ ██╗   ██║  ██║███████╗██║     ███████╗██║  ██║██║  ██║██║  ██║███████╗   
    ╚═════╝ ╚══════╝╚═╝  ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝   
                                                                                                     
                                                                                                          

----------------------------------------------------------------------------------------------------

=== MAIN FEATURES ===
    => Fund gets transferred into this contract while dividend distribution from dividend contracts
    => Dividend contracts get fund from game contracts while dividend distribution
    => This is global referral pool for all games.
    => SafeMath Implemetation
    => Higher degree of control by contract owner



------------------------------------------------------------------------------------------------------
 Copyright (c) 2019 onwards TRONtopia Inc. ( https://trontopia.co )
 Contract designed with ❤ by EtherAuthority  ( https://EtherAuthority.io )
------------------------------------------------------------------------------------------------------
*/ 


//*******************************************************************//
//------------------------ SafeMath Library -------------------------//
//*******************************************************************//
/**
    * @title SafeMath
    * @dev Math operations with safety checks that throw on error
    */
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
        return 0;
    }
    uint256 c = a * b;
    require(c / a == b, 'SafeMath mul failed');
    return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a, 'SafeMath sub failed');
    return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, 'SafeMath add failed');
    return c;
    }
}





//*******************************************************************//
//------------------ Contract to Manage Ownership -------------------//
//*******************************************************************//
    

contract owned {
    address payable internal owner;
    address payable internal newOwner;

    /**
        Signer is deligated admin wallet, which can do sub-owner functions.
        Signer calls following four functions:
            => request fund from game contract
    */
    address internal signer;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
        signer = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier onlySigner {
        require(msg.sender == signer);
        _;
    }

    function changeSigner(address _signer) public onlyOwner {
        signer = _signer;
    }

    function transferOwnership(address payable _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }

    //this flow is to prevent transferring ownership to wrong wallet by mistake
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}




    
//**************************************************************************//
//---------------------  REF POOL MAIN CODE STARTS HERE --------------------//
//**************************************************************************//

contract TRONtopia_Referral_Pool is owned{

    /* Public variables of the contract */
    using SafeMath for uint256;
    uint256 public refPool;             //this will get 1% of the div distribution to pay for the referrers.
    address[] public whitelistCallerArray;
    bool public globalHalt; //when this variabe will be true, it will stop main functionality!




    mapping (address => bool) public whitelistCaller;
    mapping (address => uint256) internal whitelistCallerArrayIndex;
    /* Mapping to track referrer. The second address is the address of referrer, the Up-line/ Sponsor */
    mapping (address => address) public referrers;
    /* Mapping to track referrer bonus for all the referrers */
    mapping (address => uint) public referrerBonusBalance;
    /* Mapping all time referrer bonus. Referrer address => all time bonus from all his downline referrals */
    mapping (address => uint256) public referralsWageredAllTime;
    


    // Events to track ether transfer to referrers
    event ReferrerBonus(address indexed referer, address indexed player, uint256 betAmount , uint256 etherReceived, uint256 timestamp );
    event ReferrerBonusWithdrawn(address indexed referrer, uint256 indexed amount);

    /*========================================
    =           STANDARD FUNCTIONS           =
    =========================================*/

    /**
        Fallback function. It accepts incoming TRX and add that into referral pool
        This is the only way for TRX to entre into the refPool contract
    */
    function () payable external {
        refPool += msg.value;
    }



    /** 
        * Add whitelist address who can call Mint function. Usually, they are other games contract
    */
    function addWhitelistAddress(address _newAddress) public onlyOwner returns(string memory){
        
        require(!whitelistCaller[_newAddress], 'No same Address again');

        whitelistCaller[_newAddress] = true;
        whitelistCallerArray.push(_newAddress);
        whitelistCallerArrayIndex[_newAddress] = whitelistCallerArray.length - 1;

        return "Whitelisting Address added";
    }

    /**
        * To remove any whilisted address
    */
    function removeWhitelistAddress(address _address) public onlyOwner returns(string memory){
        
        require(_address != address(0), 'Invalid Address');
        require(whitelistCaller[_address], 'This Address does not exist');

        whitelistCaller[_address] = false;
        uint256 arrayIndex = whitelistCallerArrayIndex[_address];
        address lastElement = whitelistCallerArray[whitelistCallerArray.length - 1];
        whitelistCallerArray[arrayIndex] = lastElement;
        whitelistCallerArrayIndex[lastElement] = arrayIndex;
        whitelistCallerArray.length--;

        return "Whitelisting Address removed";
    }

    
    /**
        If global halt is off, then this funtion will on it. And vice versa
    */
    function changeGlobalHalt() onlySigner public returns(string memory) {
        if (globalHalt == false){
            globalHalt = true;
        }
        else{
            globalHalt = false;  
        }
        return "globalHalt status changed";
    }


    /*=====================================
    =         REFERRALS FUNCTIONS         =
    ======================================*/



    /**
        * Owner can claim any left-over TRX from this contract 
    */
    function claimOwnerRefRake(uint256 amount) public onlyOwner returns (string memory){
        uint256 refPoolLocal = refPool;
        require(amount <= refPoolLocal, 'Owner can not withdraw more than refPool value');
        refPool = refPoolLocal - amount;
        address(owner).transfer(amount);
        return "TRX withdrawn to owner wallet";
    }

    /**
        * Function will allow users to withdraw their referrer bonus  
    */
    function claimReferrerBonus() public {
        
        address payable msgSender = msg.sender;
        
        uint256 referralBonus = referrerBonusBalance[msgSender];
        
        require(referralBonus > 0, 'Insufficient referrer bonus');
        referrerBonusBalance[msgSender] = 0;
        
        
        //transfer the referrer bonus
        msgSender.transfer(referralBonus);
        
        //fire event
        emit ReferrerBonusWithdrawn(msgSender, referralBonus);
    }

    /**
        * This function only be called by whitelisted addresses, so basically, 
        * the purpose to call this function is by the games contracts.
        * admin can also remove some of the referrers by setting 0x0 address
    */
    function updateReferrer(address _user, address _referrer) public returns(bool){
        require(whitelistCaller[msg.sender] || msg.sender == signer, 'Caller is not authorized');
        //this does not check for the presence of existing referer.. 
        referrers[_user] = _referrer;
        return true;
    }

    /*
        * This function will allow to add referrer bonus only, without updating the referrer.
        * This function is called assuming already existing referrer of user
    */
    function payReferrerBonusOnly(address _user, uint256 _etherAmount ) public returns(bool){
        
        //this does not check for the presence of existing referer.. to save gas. 
        //In the rare event of existing 0x0 referrer does not have much harm.
        require(whitelistCaller[msg.sender], 'Caller is not authorized');
        
        address referrer = referrers[_user];

        
        //calculate final referrer bonus, considering its tiers: bronze - siver - gold
        //final ref bonus = total winning * ref bonus percentage according to tiers / 100
        //the reason to put 100000, which is three extra zeros, is because we multiplied with 1000 while calculating ref bonus percetange
        uint256 _finalRefBonus = _etherAmount / 100000;

        referrerBonusBalance[referrers[_user]] += _finalRefBonus;
        if(referrer != address(0)) referralsWageredAllTime[referrer] += _etherAmount;

        emit ReferrerBonus(referrer, _user, _etherAmount , _finalRefBonus, now );
        return true;
    }

    /*
        * This function will allow to add referrer bonus and add new referrer.
        * This function is called when using referrer link first time only.
    */
    function payReferrerBonusAndAddReferrer(address _user, address _referrer, uint256 _etherAmount) public returns(bool){
        
        //this does not check for the presence of existing referer.. to save gas. 
        //In the rare event of existing 0x0 referrer does not have much harm.
        require(whitelistCaller[msg.sender], 'Caller is not authorized');
    

        //calculate final referrer bonus, considering its tiers: bronze - siver - gold
        //final ref bonus = total winning * ref bonus percentage according to tiers / 100
        //the reason to put 100000, which is three extra zeros, is because we multiplied with 1000 while calculating ref bonus percetange
        uint256 _finalRefBonus = _etherAmount  / 100000;
  
        referrers[_user] = _referrer;
        referrerBonusBalance[_referrer] += _finalRefBonus;
        referralsWageredAllTime[_referrer] += _etherAmount;
    
        emit ReferrerBonus(_referrer, _user, _etherAmount , _finalRefBonus, now );
        return true;
    }

}
