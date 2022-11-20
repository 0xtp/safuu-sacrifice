// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SafuuXSacrificeBTCB is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter public nextSacrificeId;

    address public safuuWallet;
    address public serviceWallet;
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
    mapping(string => uint256) public totalSacrificeAmount;
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

    constructor(address _safuuWallet, address _serviceWallet) {
        safuuWallet = _safuuWallet;
        serviceWallet = _serviceWallet;
        _init();
    }

    function depositBTC(string memory _symbol, uint256 _amount)
        external
        nonReentrant
        returns (uint256)
    {
        require(isSacrificeActive == true, "depositBTC: Sacrifice not active");
        require(
            AllowedTokens[_symbol] != address(0),
            "depositBTC: Address not part of allowed token list"
        );
        require(_amount > 0, "depositBTC: Amount must be greater than ZERO");

        nextSacrificeId.increment();

        uint256 dec = TokenDecimals[_symbol] / 1e4;
        uint256 amount = _amount * dec;
        uint256 priceFeed = getChainLinkPrice(ChainlinkContracts[_symbol]);

        address tokenAddress = AllowedTokens[_symbol];
        BTCDeposit[msg.sender][tokenAddress] += amount;
        AccountDeposits[msg.sender][_symbol].push(nextSacrificeId.current());

        uint256 tokenPriceUSD = priceFeed / 1e4;
        totalSacrifice += tokenPriceUSD * _amount;
        totalSacrificeAmount[_symbol] += _amount;

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
        address _account,
        uint256 _amount,
        uint256 _priceUSD,
        uint256 _timestamp
    ) external onlyOwner {
        sacrifice storage updateSacrifice = Sacrifice[sacrificeId];
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

    function setSafuuWallet(address _safuuWallet) external onlyOwner {
        safuuWallet = _safuuWallet;
    }

    function setServiceWallet(address _serviceWallet) external onlyOwner {
        serviceWallet = _serviceWallet;
    }

    function setTotalSacrifice(uint256 _totalSacrificeUSD) external onlyOwner {
        totalSacrifice = _totalSacrificeUSD;
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
        setAllowedTokens("BTC", 0x11DAe0Cd6a361e07cC996F054dC7Cc2506Affea2);
        setChainlink("BTC", 0x5741306c21795FdCBb9b265Ea0255F499DFe515C);

        // ****** Mainnet Data ******
        // setAllowedTokens("BTC", 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
        // setChainlink("BTC", 0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf);

        setTokenDecimals("BTC", 1e18);
    }
}
