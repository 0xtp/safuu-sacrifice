// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SafuuXSacrificeETH is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private nextSacrificeId;

    address payable public safuuWallet;
    address payable public serviceWallet;
    bool public isSacrificeActive = false;

    struct sacrifice {
        uint256 id;
        string tokenSymbol;
        address accountAddress;
        uint256 tokenAmount;
        uint256 tokenPriceUSD;
        uint256 timestamp;
        uint256 bonus;
    }

    mapping(uint256 => sacrifice) public Sacrifice;
    mapping(string => address) public AllowedTokens;
    mapping(address => uint256) public ETHDeposit;
    mapping(address => mapping(address => uint256)) public ERC20Deposit;

    event ETHDeposited(address indexed accountAddress, uint256 indexed amount);
    event ERC20Deposited(
        string indexed symbol,
        address indexed accountAddress,
        uint256 indexed amount
    );

    constructor(address payable _safuuWallet, address payable _serviceWallet) {
        safuuWallet = _safuuWallet;
        serviceWallet = _serviceWallet;
    }

    function depositETH() external payable nonReentrant {
        require(isSacrificeActive == true, "depositETH: Sacrifice not active");
        require(msg.value > 0, "depositETH: Amount must be greater than ZERO");

        ETHDeposit[msg.sender] += msg.value;
        nextSacrificeId.increment();
        _createNewSacrifice(
            "ETH",
            msg.sender,
            msg.value,
            0, //Replaced with ChainLink price feed
            block.timestamp,
            0 //Replaced with real data
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

        nextSacrificeId.increment();
        _createNewSacrifice(
            _symbol,
            msg.sender,
            _amount,
            0, //Replaced with ChainLink price feed
            block.timestamp,
            0 //Replaced with real data
        );
        address tokenAddress = AllowedTokens[_symbol];
        ERC20Deposit[msg.sender][tokenAddress] += _amount;

        uint256 safuuSplit = (_amount * 998) / 1000;
        uint256 serviceSplit = (_amount * 2) / 1000;

        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, safuuWallet, safuuSplit);
        token.transferFrom(msg.sender, serviceWallet, serviceSplit);

        emit ERC20Deposited(_symbol, msg.sender, _amount);
    }

    function _createNewSacrifice(
        string memory _symbol,
        address _account,
        uint256 _amount,
        uint256 _priceUSD,
        uint256 _timestamp,
        uint256 _bonus
    ) internal {
        sacrifice storage newSacrifice = Sacrifice[nextSacrificeId.current()];
        newSacrifice.id = nextSacrificeId.current();
        newSacrifice.tokenSymbol = _symbol;
        newSacrifice.accountAddress = _account;
        newSacrifice.tokenAmount = _amount;
        newSacrifice.tokenPriceUSD = _priceUSD;
        newSacrifice.timestamp = _timestamp;
        newSacrifice.bonus = _bonus;
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

    function recoverETH() external onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }

    function recoverERC20(IERC20 tokenContract, address to) external onlyOwner {
        tokenContract.transfer(to, tokenContract.balanceOf(address(this)));
    }

    // function getChainLinkPrice(address contractAddress)
    //     public
    //     view
    //     returns (int256)
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
    //     return price;
    // }
}
