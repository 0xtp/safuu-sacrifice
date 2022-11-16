// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SafuuXSacrificeWBTC is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter public nextSacrificeId;

    address payable public safuuWallet;
    address payable public serviceWallet;
    bool public isSacrificeActive;
    uint256 public totalSacrifice;

    struct sacrifice {
        uint256 id;
        string tokenSymbol;
        address accountAddress;
        uint256 tokenAmount;
        uint256 tokenPriceUSD;
        uint256 timestamp;
        string status;
    }

    mapping(uint256 => sacrifice) public Sacrifice;
    mapping(address => mapping(address => uint256)) public BTCDeposit;
    mapping(address => mapping(string => uint256[])) private AccountDeposits;

    mapping(string => address) public AllowedTokens;
    mapping(string => uint256) public TokenDecimals;
    mapping(string => address) public ChainlinkContracts;
    mapping(uint256 => string) public SacrificeStatus;

    event BTCDeposited(
        string indexed symbol,
        address indexed accountAddress,
        uint256 amount
    );

    constructor(address payable _safuuWallet, address payable _serviceWallet) {
        safuuWallet = _safuuWallet;
        serviceWallet = _serviceWallet;
        _init();
    }

    function depositBTC(string memory _symbol, uint256 _amount)
        external
        nonReentrant returns (uint256)
    {
        require(
            isSacrificeActive == true,
            "depositBTC: Sacrifice not active"
        );
        require(
            AllowedTokens[_symbol] != address(0),
            "depositBTC: Address not part of allowed token list"
        );
        require(_amount > 0, "depositBTC: Amount must be greater than ZERO");

        nextSacrificeId.increment();

        uint256 amount = _amount * TokenDecimals[_symbol];
        uint256 priceFeed = getChainLinkPrice(ChainlinkContracts[_symbol]);

        address tokenAddress = AllowedTokens[_symbol];
        BTCDeposit[msg.sender][tokenAddress] += amount;
        AccountDeposits[msg.sender][_symbol].push(nextSacrificeId.current());

        uint256 tokenPriceUSD = priceFeed / 1e4;
        totalSacrifice += tokenPriceUSD * (_amount * 1e4);

        _createNewSacrifice(
            _symbol,
            msg.sender,
            amount,
            priceFeed,
            block.timestamp,
            SacrificeStatus[2]
        );

        uint256 safuuSplit = (amount * 998) / 1000;
        uint256 serviceSplit = (amount * 2) / 1000;

        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, safuuWallet, safuuSplit);
        token.transferFrom(msg.sender, serviceWallet, serviceSplit);

        emit BTCDeposited(_symbol, msg.sender, amount);

        return nextSacrificeId.current();
    }

    function _createNewSacrifice(
        string memory _symbol,
        address _account,
        uint256 _amount,
        uint256 _priceUSD,
        uint256 _timestamp,
        string memory _status
    ) internal {
        sacrifice storage newSacrifice = Sacrifice[nextSacrificeId.current()];
        newSacrifice.id = nextSacrificeId.current();
        newSacrifice.tokenSymbol = _symbol;
        newSacrifice.accountAddress = _account;
        newSacrifice.tokenAmount = _amount;
        newSacrifice.tokenPriceUSD = _priceUSD;
        newSacrifice.timestamp = _timestamp;
        newSacrifice.status = _status;
    }

    function updateSacrificeData(
        uint256 sacrificeId,
        uint256 _status,
        string memory _symbol,
        address _account,
        uint256 _amount,
        uint256 _priceUSD,
        uint256 _timestamp
    ) external onlyOwner {
        sacrifice storage updateSacrifice = Sacrifice[sacrificeId];
        updateSacrifice.tokenSymbol = _symbol;
        updateSacrifice.accountAddress = _account;
        updateSacrifice.tokenAmount = _amount;
        updateSacrifice.tokenPriceUSD = _priceUSD;
        updateSacrifice.timestamp = _timestamp;
        updateSacrifice.status = SacrificeStatus[_status];
    }

    function setAllowedTokens(string memory _symbol, address _tokenAddress)
        public
        onlyOwner
    {
        AllowedTokens[_symbol] = _tokenAddress;
    }

    function setTokenDecimals(string memory _symbol, uint256 _decimals)
        public
        onlyOwner
    {
        TokenDecimals[_symbol] = _decimals;
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

    function recoverETH() external onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }

    function recoverERC20(IERC20 tokenContract, address to) external onlyOwner {
        tokenContract.transfer(to, tokenContract.balanceOf(address(this)));
    }

    function getCurrentSacrificeID() external view returns (uint256) {
        return nextSacrificeId.current();
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

    function _init() internal {
        isSacrificeActive = false;

        SacrificeStatus[1] = "pending";
        SacrificeStatus[2] = "completed";
        SacrificeStatus[3] = "cancelled";

        // ****** Testnet Data ******
        setAllowedTokens("BTC", 0xeaF4b7eDb253FE2d43C756be81DEC4c273301200);
        setChainlink("BTC", 0xA39434A63A52E749F02807ae27335515BA4b07F7);

        // ****** Mainnet Data ******
        // setAllowedTokens("BTC", 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
        // setChainlink("BTC", 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);

        setTokenDecimals("BTC", 1e8);

    }
}
