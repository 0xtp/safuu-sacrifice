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
    Counters.Counter private nextSacrificeId;

    address payable public safuuWallet;
    address payable public serviceWallet;
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
    mapping(uint256 => string) public sacrificeStatus;
    mapping(uint256 => uint256) public bonusPercentage;
    mapping(address => uint256) public ETHDeposit;
    mapping(address => mapping(address => uint256)) public ERC20Deposit;

    event ETHDeposited(address indexed accountAddress, uint256 amount);
    event ERC20Deposited(
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

    function depositETH() external payable nonReentrant {
        require(isSacrificeActive == true, "depositETH: Sacrifice not active");
        require(msg.value > 0, "depositETH: Amount must be greater than ZERO");

        ETHDeposit[msg.sender] += msg.value;
        uint256 priceFeed = getChainLinkPrice(AllowedTokens["ETH"]);
        uint256 tokenPriceUSD = priceFeed / 1e8;
        nextSacrificeId.increment();
        _createNewSacrifice(
            "ETH",
            msg.sender,
            msg.value,
            tokenPriceUSD,
            block.timestamp,
            0, //Replaced with real data
            sacrificeStatus[2]
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
        uint256 priceFeed = getChainLinkPrice(AllowedTokens[_symbol]);
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
            sacrificeStatus[2]
        );

        uint256 safuuSplit = (amount * 998) / 1000;
        uint256 serviceSplit = (amount * 2) / 1000;

        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, safuuWallet, safuuSplit);
        token.transferFrom(msg.sender, serviceWallet, serviceSplit);

        emit ERC20Deposited(_symbol, msg.sender, amount);
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
