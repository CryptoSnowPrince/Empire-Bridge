// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IBridgeToken {
    function mint(address account, uint256 tAmount) external;

    function burn(address account, uint256 tAmount) external;

    function decimals() external pure returns (uint8);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);
}

contract Bridge is Ownable, Pausable, ReentrancyGuard {
    // state variables

    address private validator;
    uint256 public fee = 1 * 10**(18 - 2); // 0.01 Ether
    address payable public TREASURY;

    uint256 public minAmount = 1;
    uint256 public maxAmount = 10000;

    uint256 private currentNonce = 0;

    mapping(uint256 => bool) public isActiveChain;
    mapping(address => mapping(uint256 => address)) public bridgeTokenPair;
    mapping(bytes32 => bool) public processedRedeem;

    // events list

    event LogSetFee(uint256 fee);
    event LogSetValidator(address validator);
    event LogSetTreasury(address indexed treasury);
    event LogSetMinAmount(uint256 minAmount);
    event LogSetMaxAmount(uint256 maxAmount);
    event LogUpdateActiveChainList(uint256 chainId, bool state);
    event LogUpdateBridgeTokenPairList(
        address fromToken,
        uint256 toChainId,
        address toToken
    );
    event LogFallback(address from, uint256 amount);
    event LogReceive(address from, uint256 amount);
    event LogWithdrawalETH(address indexed recipient, uint256 amount);
    event LogWithdrawalERC20(
        address indexed token,
        address indexed recipient,
        uint256 amount
    );
    event LogSwap(
        uint256 indexed nonce,
        address indexed from,
        uint256 fromChainId,
        address fromToken,
        address to,
        uint256 toChainId,
        address toToken,
        uint256 amount
    );
    event LogRedeem(
        bytes32 txs,
        address token,
        uint256 amount,
        address to,
        uint256 fromChainId
    );

    constructor(address _validator, address payable _treasury, address _pool) {
        validator = _validator;
        TREASURY = _treasury;
        POOL = _pool;
    }

    function swap(
        address token,
        uint256 amount,
        address to,
        uint256 toChainId,
        uint256 deadline
    ) external payable whenNotPaused nonReentrant nonContract {
        require(deadline >= block.timestamp, "Bridge: EXPIRED");
        require(toChainId != cID(), "Invalid Bridge");
        require(isActiveChain[toChainId], "toChainId is not Active");
        require(
            bridgeTokenPair[token][toChainId] != address(0),
            "Invalid Bridge Token"
        );
        require(
            amount >= minAmount * (10**IBridgeToken(token).decimals()) &&
                amount <= maxAmount * (10**IBridgeToken(token).decimals()),
            "Wrong amount"
        );
        require(msg.value >= fee, "Fee is not fulfilled");

        uint256 nonce = currentNonce;
        currentNonce++;

        // send fee to TREASURY address
        TREASURY.transfer(msg.value);
        IBridgeToken(token).burn(msg.sender, amount);

        emit LogSwap(
            nonce,
            msg.sender,
            cID(),
            token,
            to,
            toChainId,
            bridgeTokenPair[token][toChainId],
            amount
        );
    }

    function redeem(
        bytes32 txs,
        address token,
        uint256 amount,
        address to,
        uint256 fromChainId
    ) external onlyValidator whenNotPaused nonReentrant {
        require(
            amount >= minAmount * (10**IBridgeToken(token).decimals()) &&
                amount <= maxAmount * (10**IBridgeToken(token).decimals()),
            "Wrong amount"
        );
        require(fromChainId != cID(), "Invalid Bridge");

        bytes32 hash_ = keccak256(abi.encodePacked(txs, fromChainId));
        require(processedRedeem[hash_] != true, "Redeem already processed");
        processedRedeem[hash_] = true;

        IBridgeToken(token).mint(to, amount);

        emit LogRedeem(txs, token, amount, to, fromChainId);
    }

    function isValidator() internal view returns (bool) {
        return (validator == msg.sender);
    }

    modifier onlyValidator() {
        require(isValidator(), "DENIED : Not Validator");
        _;
    }

    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    modifier nonContract() {
        require(!isContract(msg.sender), "contract not allowed");
        require(msg.sender == tx.origin, "proxy contract not allowed");
        _;
    }

    function cID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    // Set functions

    function setMinAmount(uint256 _minAmount) external onlyOwner {
        require(_minAmount <= maxAmount, "MinAmount <= MaxAmount");
        minAmount = _minAmount;

        emit LogSetMinAmount(minAmount);
    }

    function setMaxAmount(uint256 _maxAmount) external onlyOwner {
        require(_maxAmount >= minAmount, "MaxAmount >= MinAmount");
        maxAmount = _maxAmount;

        emit LogSetMaxAmount(maxAmount);
    }

    function updateActiveChainList(uint256 chainId, bool isActive)
        external
        onlyOwner
    {
        isActiveChain[chainId] = isActive;
        emit LogUpdateActiveChainList(chainId, isActive);
    }

    function updateBridgeTokenPairList(
        address fromToken,
        uint256 toChainId,
        address toToken
    ) external onlyOwner {
        bridgeTokenPair[fromToken][toChainId] = toToken;
        emit LogUpdateBridgeTokenPairList(fromToken, toChainId, toToken);
    }

    function setPause() external onlyOwner {
        _pause();
    }

    function setUnpause() external onlyOwner {
        _unpause();
    }

    function setValidator(address _validator) external onlyOwner {
        validator = _validator;
        emit LogSetValidator(validator);
    }

    function setTreasury(address payable _treasury) external onlyOwner {
        TREASURY = _treasury;
        emit LogSetTreasury(TREASURY);
    }

    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
        emit LogSetFee(fee);
    }

    // Withdraw functions
    function withdrawETH(address payable recipient) external onlyOwner {
        require(address(this).balance > 0, "Incufficient funds");

        uint256 amount = (address(this)).balance;
        recipient.transfer(amount);

        emit LogWithdrawalETH(recipient, amount);
    }

    /**
     * @notice Should not be withdrawn scam token.
     */
    function withdrawERC20(IERC20 token, address recipient) external onlyOwner {
        uint256 amount = token.balanceOf(address(this));

        require(amount > 0, "Incufficient funds");

        require(token.transfer(recipient, amount), "WithdrawERC20 Fail");

        emit LogWithdrawalERC20(address(token), recipient, amount);
    }

    // Receive and Fallback functions
    receive() external payable {
        emit LogReceive(msg.sender, msg.value);
    }

    fallback() external payable {
        emit LogFallback(msg.sender, msg.value);
    }
}
