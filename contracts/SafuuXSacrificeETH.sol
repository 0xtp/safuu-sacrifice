// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SafuuXSacrificeETH is Ownable, ReentrancyGuard {
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
        uint256 btcIndex;
        string status;
    }

    mapping(uint256 => sacrifice) public Sacrifice;
    mapping(string => address) public AllowedTokens;
    mapping(string => address) public ChainlinkContracts;
    mapping(uint256 => string) public SacrificeStatus;
    mapping(uint256 => uint256) public BonusPercentage;
    mapping(address => uint256) public BTCPledge;
    mapping(address => uint256) public ETHDeposit;
    mapping(address => mapping(address => uint256)) public ERC20Deposit;

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

        ETHDeposit[msg.sender] += msg.value;
        uint256 priceFeed = getChainLinkPrice(ChainlinkContracts["ETH"]);
        uint256 tokenPriceUSD = priceFeed / 1e8;
        nextSacrificeId.increment();
        _createNewSacrifice(
            "ETH",
            msg.sender,
            msg.value,
            tokenPriceUSD,
            block.timestamp,
            0, //Replaced with real data
            nextBTCIndex.current(),
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

        uint256 amount = _amount * 1e18;
        uint256 priceFeed = getChainLinkPrice(ChainlinkContracts[_symbol]);
        uint256 tokenPriceUSD = priceFeed / 1e8;
        address tokenAddress = AllowedTokens[_symbol];
        ERC20Deposit[msg.sender][tokenAddress] += amount;

        nextSacrificeId.increment();
        _createNewSacrifice(
            _symbol,
            msg.sender,
            amount,
            tokenPriceUSD,
            block.timestamp,
            0, //Replaced with real data
            nextBTCIndex.current(),
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

        BTCPledge[msg.sender] += _amount;
        uint256 priceFeed = getChainLinkPrice(ChainlinkContracts["BTC"]);
        uint256 tokenPriceUSD = priceFeed / 1e8;

        nextBTCIndex.increment();
        nextSacrificeId.increment();
        _createNewSacrifice(
            "BTC",
            msg.sender,
            _amount,
            tokenPriceUSD, //Replaced with ChainLink price feed
            block.timestamp,
            0, //Replaced with real data
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
        uint256 btcIndex,
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

    function setSacrificeStatus(bool _isActive) external {
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
        // setAllowedTokens("BUSD", 0x4Fabb145d64652a948d72533023f6E7A623C7C53);
        // setAllowedTokens("USDC", 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48);
        // setAllowedTokens("USDT", 0xdac17f958d2ee523a2206206994597c13d831ec7);

        // setChainlink("ETH", 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        // setChainlink("BTC", 0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf);
        // setChainlink("BUSD", 0x833D8Eb16D306ed1FbB5D7A2E019e106B960965A);
        // setChainlink("USDC", 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
        // setChainlink("USDT", 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);
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
