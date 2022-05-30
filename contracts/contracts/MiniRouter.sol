// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract MiniRouter is Ownable, Pausable, ReentrancyGuard {
    IERC20 public empire;

    mapping(address => bool) public supportedRouters;
    ///@notice router addr + second token addr = pair addr
    mapping(address => mapping(address => address)) public pairAddr;
    mapping(address => bool) public pairExists;

    event LogSetRouter(address router, bool enabled);
    event LogSetEmpire(address empire);
    // event LogSetPair(address pair);
    // event LogDeletePair(address pair);
    event LogAddLiquidityETH(
        address recipient,
        uint256 empireAmount,
        uint256 ethAmount,
        address router
    );
    event LogAddLiquidityTokens(
        address recipient,
        address tokenB,
        uint256 empireAmount,
        uint256 tokenBAmount,
        address router
    );

    // event LogRemoveLiquidityETH(address recipient, uint256 liquidity, address router);
    // event LogRemoveLiquidityTokens(address recipient, uint256 liquidity, address router, address tokenB);

    constructor(address empire_, address router) {
        empire = IERC20(empire_);

        setRouter(router, true);
    }

    function addLiquidityTokens(
        address tokenB,
        uint256 empireAmount,
        uint256 tokenBAmount,
        address router,
        address to,
        uint256 deadline
    ) external whenNotPaused nonReentrant {
        address recipient = _msgSender();
        require(
            supportedRouters[router] == true,
            "MiniRouter: The Router is not supported"
        );
        require(
            empire.transferFrom(msg.sender, address(this), empireAmount),
            "MiniRouter: TransferFrom failed"
        );
        require(
            empire.approve(router, empireAmount),
            "MiniRouter: Approve failed"
        );
        require(
            IERC20(tokenB).transferFrom(
                msg.sender,
                address(this),
                tokenBAmount
            ),
            "MiniRouter: TransferFrom failed"
        );
        require(
            IERC20(tokenB).approve(router, tokenBAmount),
            "MiniRouter: Approve failed"
        );
        IUniswapV2Router02(router).addLiquidity(
            address(empire),
            tokenB,
            empireAmount,
            tokenBAmount,
            0,
            0,
            recipient,
            block.timestamp
        );

        emit LogAddLiquidityTokens(
            recipient,
            tokenB,
            empireAmount,
            tokenBAmount,
            router
        );
    }

    function addLiquidityETH(
        uint256 empireAmount,
        uint256 ethAmount,
        address router,
        address to,
        uint256 deadline
    ) external payable whenNotPaused nonReentrant {
        address recipient = _msgSender();
        require(
            supportedRouters[router] == true,
            "MiniRouter: The Router is not supported"
        );
        require(
            empire.approve(router, empireAmount),
            "MiniRouter: Approve failed"
        );
        require(
            empire.transferFrom(msg.sender, address(this), empireAmount),
            "MiniRouter: TransferFrom failed"
        );
        IUniswapV2Router02(router).addLiquidityETH{value: ethAmount}(
            address(empire),
            empireAmount,
            0,
            0,
            recipient,
            block.timestamp
        );

        emit LogAddLiquidityETH(recipient, empireAmount, ethAmount, router);
    }

    receive() external payable {
        emit LogReceive(msg.sender, msg.value);
    }

    fallback() external payable {
        emit LogFallback(msg.sender, msg.value);
    }

    function setPause() external onlyOwner {
        _pause();
    }

    function setUnpause() external onlyOwner {
        _unpause();
    }

    function setEmpire(address empire_) external onlyOwner {
        empire = IERC20(empire_);
        emit LogSetEmpire(empire_);
    }

    function setRouter(address router, bool enabled) public onlyOwner {
        supportedRouters[router] == enabled;

        emit LogSetRouter(router, enabled);
    }

    function withdrawETH(address payable recipient, uint256 amount)
        external
        onlyOwner
    {
        require(amount <= (address(this)).balance, "Incufficient funds");
        recipient.transfer(amount);
        emit LogWithdrawalETH(recipient, amount);
    }

    /**
     * @notice  Should not be withdrawn scam token.
     */
    function withdrawToken(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        require(amount <= token.balanceOf(address(this)), "Incufficient funds");
        require(token.transfer(recipient, amount), "Transfer Fail");

        emit LogWithdrawToken(address(token), recipient, amount);
    }

    // function setPair(address tokenB, address router, address pair) public onlyOwner{
    //     pairAddr[router][tokenB] = pair;
    //     pairExists[pair] == true;
    // }

    // function deletePair(address pair) external onlyOwner{
    //     pairExists[pair] == false;
    //     emit LogDeletePair(pair);
    // }

    // function removeLiquidityTokens(address tokenB, uint256 liquidity, address router) external {
    //     address recipient = _msgSender();
    //     address pair = pairAddr[router][tokenB];
    //     require(pairExists[pair] == true, "MiniRouter: Pair does not exist");
    //     require(supportedRouters[router] == true, "MiniRouter: The Router is not supported");
    //     require(IUniswapV2Pair(pair).transferFrom(msg.sender, address(this), liquidity), "MiniRouter: TransferFrom failed");
    //     require(IUniswapV2Pair(pair).approve(router, liquidity), "MiniRouter: Approve failed");
    //     IUniswapV2Router02(router).removeLiquidity(
    //         address(empire),
    //         tokenB,
    //         liquidity,
    //         0,
    //         0,
    //         recipient,
    //         block.timestamp
    //     );

    //     emit LogRemoveLiquidityTokens(recipient, liquidity, router, tokenB);
    // }

    // function removeLiquidityETH(uint256 liquidity, address router) external {
    //     address recipient = _msgSender();
    //     address pair = pairAddr[router][IUniswapV2Router02(router).WETH()];
    //     require(pairExists[pair] == true, "MiniRouter: Pair does not exist");
    //     require(IUniswapV2Pair(pair).transferFrom(msg.sender, address(this), liquidity), "MiniRouter: TransferFrom failed");
    //     require(IUniswapV2Pair(pair).approve(router, liquidity), "MiniRouter: Approve failed");
    //     IUniswapV2Router02(router).removeLiquidityETH(
    //         address(empire),
    //         liquidity,
    //         0,
    //         0,
    //         recipient,
    //         block.timestamp
    //     );

    //     emit LogRemoveLiquidityETH(recipient, liquidity, router);
    // }
}
