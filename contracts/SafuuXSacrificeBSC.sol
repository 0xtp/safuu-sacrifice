// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SafuuXSacrificeBSC is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter public nextSacrificeId;
    Counters.Counter public nextBTCIndex;

    address payable private safuuWallet;
    address payable private serviceWallet;
    bool public isSacrificeActive;
    bool public isBonusActive;

    struct sacrifice {
        uint256 id;
        string txHash;
        string tokenSymbol;
        address accountAddress;
        uint256 tokenAmount;
        uint256 tokenPriceUSD;
        uint256 timestamp;
        uint256 bonus;
        string status;
    }

    mapping(uint256 => sacrifice) public Sacrifice;
    mapping(string => address) public AllowedTokens;
    mapping(string => address) public ChainlinkContracts;
    mapping(uint256 => string) public SacrificeStatus;
    mapping(uint256 => uint256) public BonusPercentage;
    mapping(address => uint256) public BNBDeposit;
    mapping(address => mapping(address => uint256)) public BEP20Deposit;

    event BNBDeposited(address indexed accountAddress, uint256 amount);
    event SAFUUDeposited(address indexed accountAddress, uint256 amount);
    event BEP20Deposited(
        string indexed symbol,
        address indexed accountAddress,
        uint256 amount
    );

    constructor(address payable _safuuWallet, address payable _serviceWallet) {
        safuuWallet = _safuuWallet;
        serviceWallet = _serviceWallet;
        _init();
    }

    function depositBNB() external payable nonReentrant {
        require(isSacrificeActive == true, "depositBNB: Sacrifice not active");
        require(msg.value > 0, "depositBNB: Amount must be greater than ZERO");

        BNBDeposit[msg.sender] += msg.value;
        uint256 priceFeed = getChainLinkPrice(ChainlinkContracts["BNB"]);
        uint256 tokenPriceUSD = priceFeed / 1e8;
        nextSacrificeId.increment();
        _createNewSacrifice(
            "BNB",
            msg.sender,
            msg.value,
            tokenPriceUSD, //Replaced with ChainLink price feed
            block.timestamp,
            0, //Replaced with real data
            SacrificeStatus[2]
        );

        uint256 safuuSplit = (msg.value * 998) / 1000;
        uint256 serviceSplit = (msg.value * 2) / 1000;
        safuuWallet.transfer(safuuSplit);
        serviceWallet.transfer(serviceSplit);

        emit BNBDeposited(msg.sender, msg.value);
    }

    function depositBEP20(string memory _symbol, uint256 _amount)
        external
        nonReentrant
    {
        require(
            isSacrificeActive == true,
            "depositBEP20: Sacrifice not active"
        );
        require(
            AllowedTokens[_symbol] != address(0),
            "depositBEP20: Address not part of allowed token list"
        );
        require(
            AllowedTokens[_symbol] != AllowedTokens["SAFUU"],
            "depositBEP20: SAFUU cannot be deposited here"
        );
        require(_amount > 0, "depositBEP20: Amount must be greater than ZERO");

        uint256 amount = _amount * 1e18;
        uint256 priceFeed = getChainLinkPrice(ChainlinkContracts[_symbol]);
        uint256 tokenPriceUSD = priceFeed / 1e8;
        address tokenAddress = AllowedTokens[_symbol];
        BEP20Deposit[msg.sender][tokenAddress] += amount;

        nextSacrificeId.increment();
        _createNewSacrifice(
            _symbol,
            msg.sender,
            amount,
            tokenPriceUSD, //Replaced with ChainLink price feed
            block.timestamp,
            0, //Replaced with real data
            SacrificeStatus[2]
        );

        uint256 safuuSplit = (amount * 998) / 1000;
        uint256 serviceSplit = (amount * 2) / 1000;

        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, safuuWallet, safuuSplit);
        token.transferFrom(msg.sender, serviceWallet, serviceSplit);

        emit BEP20Deposited(_symbol, msg.sender, amount);
    }

    function depositSafuu(uint256 _amount) external nonReentrant {
        require(
            isSacrificeActive == true,
            "depositSafuu: Sacrifice not active"
        );
        require(
            AllowedTokens["SAFUU"] != address(0),
            "depositSafuu: Address not part of allowed token list"
        );
        require(_amount > 0, "depositSafuu: Amount must be greater than ZERO");
        uint256 amount = _amount * 1e5;
        uint256 tokenPriceUSD = 0;
        //uint256 tokenPriceUSD = getChainLinkPrice(ChainlinkContracts["SAFUU"]);
        address tokenAddress = AllowedTokens["SAFUU"];
        BEP20Deposit[msg.sender][tokenAddress] += amount;

        nextSacrificeId.increment();
        _createNewSacrifice(
            "SAFUU",
            msg.sender,
            amount,
            tokenPriceUSD, //Replaced with ChainLink price feed
            block.timestamp,
            0, //Replaced with real data
            SacrificeStatus[2]
        );

        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, safuuWallet, amount);

        emit SAFUUDeposited(msg.sender, amount);
    }

    function _createNewSacrifice(
        string memory _symbol,
        address _account,
        uint256 _amount,
        uint256 _priceUSD,
        uint256 _timestamp,
        uint256 _bonus,
        string memory _status
    ) internal {
        sacrifice storage newSacrifice = Sacrifice[nextSacrificeId.current()];
        newSacrifice.id = nextSacrificeId.current();
        newSacrifice.tokenSymbol = _symbol;
        newSacrifice.accountAddress = _account;
        newSacrifice.tokenAmount = _amount;
        newSacrifice.tokenPriceUSD = _priceUSD;
        newSacrifice.timestamp = _timestamp;
        newSacrifice.bonus = _bonus;
        newSacrifice.status = _status;
    }

    function updateSacrificeData(
        uint256 sacrificeId,
        string memory _txHash,
        uint256 _bonus,
        uint256 _status
    ) external onlyOwner {
        sacrifice storage updateSacrifice = Sacrifice[sacrificeId];
        //require(condition); // CHECK SACRIFICE EXIST
        updateSacrifice.txHash = _txHash;
        updateSacrifice.bonus = BonusPercentage[_bonus];
        updateSacrifice.status = SacrificeStatus[_status];
    }

    function setAllowedTokens(string memory _symbol, address _tokenAddress)
        public
        onlyOwner
    {
        AllowedTokens[_symbol] = _tokenAddress;
    }

    function setChainlink(string memory _symbol, address _tokenAddress)
        public
        onlyOwner
    {
        ChainlinkContracts[_symbol] = _tokenAddress;
    }

    function setSacrificeStatus(bool _isActive) external onlyOwner {
        isSacrificeActive = _isActive;
    }

    function setSafuuWallet(address payable _safuuWallet) external onlyOwner {
        safuuWallet = _safuuWallet;
    }

    function setServiceWallet(address payable _serviceWallet)
        external
        onlyOwner
    {
        serviceWallet = _serviceWallet;
    }

    function updateBonus(uint256 _day, uint256 _percentage) external onlyOwner {
        BonusPercentage[_day] = _percentage;
    }

    function recoverBNB() external onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }

    function recoverBEP20(IERC20 tokenContract, address to) external onlyOwner {
        tokenContract.transfer(to, tokenContract.balanceOf(address(this)));
    }

    function getCurrentSacrificeID() external view returns (uint256) {
        return nextSacrificeId.current();
    }

    function getChainLinkPrice(address contractAddress)
        public
        view
        returns (uint256)
    {
        return 100000000000;
    }

    // function getChainLinkPrice(address contractAddress)
    //     public
    //     view
    //     returns (uint256)
    // {
    //     AggregatorV3Interface priceFeed = AggregatorV3Interface(
    //         contractAddress
    //     );
    //     (
    //         ,
    //         /*uint80 roundID*/
    //         int256 price, /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/
    //         ,
    //         ,

    //     ) = priceFeed.latestRoundData();
    //     return uint256(price);
    // }

    function _init() internal {
        isSacrificeActive = false;
        isBonusActive = false;

        SacrificeStatus[1] = "pending";
        SacrificeStatus[2] = "completed";
        SacrificeStatus[3] = "cancelled";

        // ****** Mainnet Data ******
        // setAllowedTokens("ETH", 0x2170Ed0880ac9A755fd29B2688956BD959F933F8);
        // setAllowedTokens("BUSD", 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
        // setAllowedTokens("USDC", 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
        // setAllowedTokens("USDT", 0x55d398326f99059fF775485246999027B3197955);
        // setAllowedTokens("SAFUU", 0xE5bA47fD94CB645ba4119222e34fB33F59C7CD90);

        // setChainlink("BNB", 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE);
        // setChainlink("ETH", 0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e);
        // setChainlink("BUSD", 0xcBb98864Ef56E9042e7d2efef76141f15731B82f);
        // setChainlink("USDC", 0x51597f405303C4377E36123cBc172b13269EA163);
        // setChainlink("USDT", 0xB97Ad0E74fa7d920791E90258A6E2085088b4320);
    }

    function activateBonus() external onlyOwner {
        require(
            isBonusActive == false,
            "activateBonus: Bonus already activated"
        );

        isBonusActive = true;
        BonusPercentage[1] = 5000; // 5000 equals 50%
        BonusPercentage[2] = 4500;
        BonusPercentage[3] = 4000;
        BonusPercentage[4] = 3500;
        BonusPercentage[5] = 3000;
        BonusPercentage[6] = 2500;
        BonusPercentage[7] = 2000;
        BonusPercentage[8] = 1500;
        BonusPercentage[9] = 1400;
        BonusPercentage[10] = 1300;
        BonusPercentage[11] = 1200;
        BonusPercentage[12] = 1100;
        BonusPercentage[13] = 1000;
        BonusPercentage[14] = 900;
        BonusPercentage[15] = 800;
        BonusPercentage[16] = 700;
        BonusPercentage[17] = 600;
        BonusPercentage[18] = 500;
        BonusPercentage[19] = 400;
        BonusPercentage[20] = 300;
        BonusPercentage[21] = 200;
        BonusPercentage[22] = 100;
        BonusPercentage[23] = 90;
        BonusPercentage[24] = 80;
        BonusPercentage[25] = 70;
        BonusPercentage[26] = 60;
        BonusPercentage[27] = 50;
        BonusPercentage[28] = 40;
        BonusPercentage[29] = 30;
        BonusPercentage[30] = 20;
        BonusPercentage[31] = 10;
        BonusPercentage[32] = 0;
    }
}
