// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SafuuXSacrificeETH is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter public nextSacrificeId;
    Counters.Counter public nextBTCIndex;

    address payable public safuuWallet;
    address payable public serviceWallet;
    bool public isSacrificeActive;
    bool public isBonusActive;
    uint256 public bonusStart;
    uint256 public totalSacrifice;

    struct sacrifice {
        uint256 id;
        string txHash;
        string tokenSymbol;
        address accountAddress;
        uint256 tokenAmount;
        uint256 tokenPriceUSD;
        uint256 timestamp;
        uint256 bonus;
        uint256 btcIndex;
        string status;
    }

    mapping(uint256 => sacrifice) public Sacrifice;
    mapping(address => uint256) public BTCPledge;
    mapping(address => uint256) public ETHDeposit;
    mapping(address => mapping(address => uint256)) public ERC20Deposit;
    mapping(address => mapping(string => uint256[])) private AccountDeposits;

    mapping(string => address) public AllowedTokens;
    mapping(string => address) public ChainlinkContracts;
    mapping(uint256 => string) public SacrificeStatus;
    mapping(uint256 => uint256) public BonusPercentage;

    event BTCPledged(address indexed accountAddress, uint256 amount);
    event ETHDeposited(address indexed accountAddress, uint256 amount);
    event ERC20Deposited(
        string indexed symbol,
        address indexed accountAddress,
        uint256 amount
    );

    constructor(address payable _safuuWallet, address payable _serviceWallet) {
        safuuWallet = _safuuWallet;
        serviceWallet = _serviceWallet;
        _init();
    }

    function depositETH() external payable nonReentrant {
        require(isSacrificeActive == true, "depositETH: Sacrifice not active");
        require(msg.value > 0, "depositETH: Amount must be greater than ZERO");

        nextSacrificeId.increment();
        uint256 priceFeed = getChainLinkPrice(ChainlinkContracts["ETH"]);
        ETHDeposit[msg.sender] += msg.value;
        AccountDeposits[msg.sender]["ETH"].push(nextSacrificeId.current());

        uint256 tokenPriceUSD = priceFeed / 1e4;
        totalSacrifice += tokenPriceUSD * (msg.value / 1e14);

        _createNewSacrifice(
            "ETH",
            msg.sender,
            msg.value,
            priceFeed,
            block.timestamp,
            getBonus(),
            0,
            SacrificeStatus[2]
        );

        uint256 safuuSplit = (msg.value * 998) / 1000;
        uint256 serviceSplit = (msg.value * 2) / 1000;
        safuuWallet.transfer(safuuSplit);
        serviceWallet.transfer(serviceSplit);

        emit ETHDeposited(msg.sender, msg.value);
    }

    function depositERC20(string memory _symbol, uint256 _amount)
        external
        nonReentrant
    {
        require(
            isSacrificeActive == true,
            "depositERC20: Sacrifice not active"
        );
        require(
            AllowedTokens[_symbol] != address(0),
            "depositERC20: Address not part of allowed token list"
        );
        require(_amount > 0, "depositERC20: Amount must be greater than ZERO");

        nextSacrificeId.increment();
        uint256 amount = _amount * 1e18;
        uint256 priceFeed = getChainLinkPrice(ChainlinkContracts[_symbol]);
        address tokenAddress = AllowedTokens[_symbol];
        ERC20Deposit[msg.sender][tokenAddress] += amount;
        AccountDeposits[msg.sender][_symbol].push(nextSacrificeId.current());

        uint256 tokenPriceUSD = priceFeed / 1e4;
        totalSacrifice += tokenPriceUSD * (amount / 1e14);

        _createNewSacrifice(
            _symbol,
            msg.sender,
            amount,
            priceFeed,
            block.timestamp,
            getBonus(),
            0,
            SacrificeStatus[2]
        );

        uint256 safuuSplit = (amount * 998) / 1000;
        uint256 serviceSplit = (amount * 2) / 1000;

        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, safuuWallet, safuuSplit);
        token.transferFrom(msg.sender, serviceWallet, serviceSplit);

        emit ERC20Deposited(_symbol, msg.sender, amount);
    }

    function pledgeBTC(uint256 _amount)
        external
        nonReentrant
        returns (uint256)
    {
        require(isSacrificeActive == true, "pledgeBTC: Sacrifice not active");
        require(_amount > 0, "pledgeBTC: Amount must be greater than ZERO");

        nextBTCIndex.increment();
        nextSacrificeId.increment();
        BTCPledge[msg.sender] += _amount;
        uint256 priceFeed = getChainLinkPrice(ChainlinkContracts["BTC"]);
        AccountDeposits[msg.sender]["BTC"].push(nextSacrificeId.current());

        uint256 tokenPriceUSD = priceFeed / 1e4;
        totalSacrifice += tokenPriceUSD * (_amount * 1e4);

        _createNewSacrifice(
            "BTC",
            msg.sender,
            _amount,
            priceFeed,
            block.timestamp,
            getBonus(),
            nextBTCIndex.current(),
            SacrificeStatus[1]
        );

        emit BTCPledged(msg.sender, _amount);
        return nextBTCIndex.current();
    }

    function _createNewSacrifice(
        string memory _symbol,
        address _account,
        uint256 _amount,
        uint256 _priceUSD,
        uint256 _timestamp,
        uint256 _bonus,
        uint256 _btcIndex,
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
        newSacrifice.btcIndex = _btcIndex;
        newSacrifice.status = _status;
    }

    function updateSacrificeData(
        uint256 sacrificeId,
        string memory _txHash,
        uint256 _bonus,
        uint256 _status
    ) external onlyOwner {
        sacrifice storage updateSacrifice = Sacrifice[sacrificeId];
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

    function recoverETH() external onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }

    function recoverERC20(IERC20 tokenContract, address to) external onlyOwner {
        tokenContract.transfer(to, tokenContract.balanceOf(address(this)));
    }

    function getCurrentSacrificeID() external view returns (uint256) {
        return nextSacrificeId.current();
    }

    function getCurrentBTCIndex() external view returns (uint256) {
        return nextBTCIndex.current();
    }

    function getAccountDeposits(address _account, string memory _symbol)
        public
        view
        returns (uint256[] memory)
    {
        return AccountDeposits[_account][_symbol];
    }

    function getChainLinkPrice(address contractAddress)
        public
        view
        returns (uint256)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            contractAddress
        );
        (
            ,
            /*uint80 roundID*/
            int256 price, /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/
            ,
            ,

        ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function getPriceBySymbol(string memory _symbol)
        public
        view
        returns (uint256)
    {
        require(
            ChainlinkContracts[_symbol] != address(0),
            "getChainLinkPrice: Address not part of Chainlink token list"
        );

        return getChainLinkPrice(ChainlinkContracts[_symbol]);
    }

    function getBonus() public view returns (uint256) {
        uint256 noOfDays = (block.timestamp - bonusStart) / 86400 + 1;
        uint256 bonus = BonusPercentage[noOfDays];
        return bonus;
    }

    function _init() internal {
        isSacrificeActive = false;
        isBonusActive = false;

        SacrificeStatus[1] = "pending";
        SacrificeStatus[2] = "completed";
        SacrificeStatus[3] = "cancelled";

        // ****** Mainnet Data ******
        setAllowedTokens("BUSD", 0x4Fabb145d64652a948d72533023f6E7A623C7C53);
        setAllowedTokens("USDC", 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        setAllowedTokens("USDT", 0xdAC17F958D2ee523a2206206994597C13D831ec7);

        setChainlink("ETH", 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        setChainlink("BTC", 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);
        setChainlink("BUSD", 0x833D8Eb16D306ed1FbB5D7A2E019e106B960965A);
        setChainlink("USDC", 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
        setChainlink("USDT", 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);
    }

    function activateBonus() external onlyOwner {
        require(
            isBonusActive == false,
            "activateBonus: Bonus already activated"
        );

        isBonusActive = true;
        bonusStart = block.timestamp;
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
