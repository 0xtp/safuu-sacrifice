// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SafuuXSacrifice is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private nextSacrificeId;

    address payable public wallet1;
    address payable public wallet2;
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

    constructor(address payable _wallet1, address payable _wallet2) {
        wallet1 = _wallet1;
        wallet2 = _wallet2;
    }

    function depositETH() external payable nonReentrant {
        require(isSacrificeActive == true, "depositETH: Sacrifice not active");
        require(msg.value > 0, "depositETH: Amount must be greater than ZERO");
        nextSacrificeId.increment();
        sacrifice storage newSacrifice = Sacrifice[nextSacrificeId.current()];
        newSacrifice.id = nextSacrificeId.current();
        newSacrifice.tokenSymbol = "ETH";
        newSacrifice.accountAddress = msg.sender;
        newSacrifice.tokenAmount = msg.value;
        newSacrifice.tokenPriceUSD = 0; //Replaced with ChainLink price feed
        newSacrifice.timestamp = block.timestamp;
        newSacrifice.bonus = 0; //Replaced with real data

        ETHDeposit[msg.sender] += msg.value;
        wallet1.transfer(msg.value); //Payment split comes here

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
        sacrifice storage newSacrifice = Sacrifice[nextSacrificeId.current()];
        newSacrifice.id = nextSacrificeId.current();
        newSacrifice.tokenSymbol = _symbol;
        newSacrifice.accountAddress = msg.sender;
        newSacrifice.tokenAmount = _amount;
        newSacrifice.tokenPriceUSD = 0; //Replaced with ChainLink price feed
        newSacrifice.timestamp = block.timestamp;
        newSacrifice.bonus = 0; //Replaced with real data

        address tokenAddress = AllowedTokens[_symbol];
        ERC20Deposit[msg.sender][tokenAddress] += _amount;
        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, wallet1, _amount); //Payment split comes here

        emit ERC20Deposited(_symbol, msg.sender, _amount);
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

    // function getChainLinkPrice(address contractAddress) public view returns (int) {
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
}
