// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SafuuXSacrificeBSC is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private nextSacrificeId;

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
    mapping(uint256 => string) sacrificeStatus;
    mapping(uint256 => uint256) bonusPercentage;
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
        isSacrificeActive = false;
        isBonusActive = false;
        sacrificeStatus[1] = "pending";
        sacrificeStatus[2] = "completed";
        sacrificeStatus[3] = "cancelled";
    }

    function depositBNB() external payable nonReentrant {
        require(isSacrificeActive == true, "depositBNB: Sacrifice not active");
        require(msg.value > 0, "depositBNB: Amount must be greater than ZERO");

        uint256 tokenPriceUSD = getChainLinkPrice(AllowedTokens["BNB"]);
        nextSacrificeId.increment();
        _createNewSacrifice(
            "BNB",
            msg.sender,
            msg.value,
            tokenPriceUSD, //Replaced with ChainLink price feed
            block.timestamp,
            0, //Replaced with real data
            sacrificeStatus[2]
        );

        uint256 safuuSplit = (msg.value * 998) / 1000;
        uint256 serviceSplit = (msg.value * 2) / 1000;

        BNBDeposit[msg.sender] += msg.value;
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
        uint256 tokenPriceUSD = getChainLinkPrice(AllowedTokens[_symbol]);
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
            sacrificeStatus[2]
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
        uint256 tokenPriceUSD = getChainLinkPrice(AllowedTokens["SAFUU"]);
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
            sacrificeStatus[2]
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
        updateSacrifice.bonus = bonusPercentage[_bonus];
        updateSacrifice.status = sacrificeStatus[_status];
    }

    function setAllowedTokens(string memory _symbol, address _tokenAddress)
        external
        onlyOwner
    {
        AllowedTokens[_symbol] = _tokenAddress;
    }

    function setSacrificeStatus(bool _isActive) external onlyOwner {
        isSacrificeActive = _isActive;
    }

    function recoverBNB() external onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }

    function recoverBEP20(IERC20 tokenContract, address to) external onlyOwner {
        tokenContract.transfer(to, tokenContract.balanceOf(address(this)));
    }

    function getChainLinkPrice(address contractAddress)
        public
        view
        returns (uint256)
    {
        return 1000;
    }

    // function _getChainLinkPrice(address contractAddress)
    //     public
    //     view
    //     returns (int256)
    // {
    //     AggregatorV3Interface priceFeed = AggregatorV3Interface(contractAddress);
    //     (
    //         /*uint80 roundID*/,
    //         int price,
    //         /*uint startedAt*/,
    //         /*uint timeStamp*/,
    //         /*uint80 answeredInRound*/
    //     ) = priceFeed.latestRoundData();
    //     return price;
    // }

    function updateBonus(uint256 _day, uint256 _percentage) external onlyOwner {
        bonusPercentage[_day] = _percentage;
    }

    function activateBonus() external onlyOwner {
        require(
            isBonusActive == false,
            "activateBonus: Bonus already activated"
        );

        isBonusActive = true;
        bonusPercentage[1] = 5000; // 5000 equals 50%
        bonusPercentage[2] = 4500;
        bonusPercentage[3] = 4000;
        bonusPercentage[4] = 3500;
        bonusPercentage[5] = 3000;
        bonusPercentage[6] = 2500;
        bonusPercentage[7] = 2000;
        bonusPercentage[8] = 1500;
        bonusPercentage[9] = 1400;
        bonusPercentage[10] = 1300;
        bonusPercentage[11] = 1200;
        bonusPercentage[12] = 1100;
        bonusPercentage[13] = 1000;
        bonusPercentage[14] = 900;
        bonusPercentage[15] = 800;
        bonusPercentage[16] = 700;
        bonusPercentage[17] = 600;
        bonusPercentage[18] = 500;
        bonusPercentage[19] = 400;
        bonusPercentage[20] = 300;
        bonusPercentage[21] = 200;
        bonusPercentage[22] = 100;
        bonusPercentage[23] = 90;
        bonusPercentage[24] = 80;
        bonusPercentage[25] = 70;
        bonusPercentage[26] = 60;
        bonusPercentage[27] = 50;
        bonusPercentage[28] = 40;
        bonusPercentage[29] = 30;
        bonusPercentage[30] = 20;
        bonusPercentage[31] = 10;
        bonusPercentage[32] = 0;
    }
}
