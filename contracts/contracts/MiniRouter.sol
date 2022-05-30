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
    mapping(address => bool) public supportedTokens;
    ///@notice router addr + second token addr = pair addr
    mapping(address => mapping(address => address)) public pairAddr;
    mapping(address => bool) public pairExists;

    event LogUpdateSupportedRouters(address router, bool enabled);
    event LogUpdateSupportedTokens(address token, bool enabled);
    event LogSetEmpire(address empire);
    event LogFallback(address from, uint256 amount);
    event LogReceive(address from, uint256 amount);
    event LogWithdrawalETH(address indexed recipient, uint256 amount);
    event LogWithdrawToken(
        address indexed token,
        address indexed recipient,
        uint256 amount
    );
    event LogAddLiquidityTokens(
        address indexed from,
        address indexed router,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity,
        address to
    );

    // event LogSetPair(address pair);
    // event LogDeletePair(address pair);
    // event LogAddLiquidityETH(
    //     address recipient,
    //     uint256 amountEmpireDesired,
    //     uint256 ethAmount,
    //     address router
    // );

    // event LogRemoveLiquidityETH(address recipient, uint256 liquidity, address router);
    // event LogRemoveLiquidityTokens(address recipient, uint256 liquidity, address router, address tokenB);

    constructor(address empire_, address router) {
        empire = IERC20(empire_);

        updateSupportedRouters(router, true);
    }

    function beforeAddLiquidityTokens(
        address router,
        address tokenB,
        uint256 amountEmpireDesired,
        uint256 amountTokenBDesired
    ) private returns (uint256 amountEmpire, uint256 amountTokenB) {
        require(
            supportedRouters[router] == true,
            "MiniRouter: The Router is not supported"
        );

        require(
            supportedTokens[tokenB] == true,
            "MiniRouter: The TokenB is not supported"
        );

        amountEmpire = empire.balanceOf(address(this));
        require(
            empire.transferFrom(msg.sender, address(this), amountEmpireDesired),
            "MiniRouter: TransferFrom failed"
        );
        amountEmpire = amountEmpire - empire.balanceOf(address(this));

        require(
            empire.approve(router, amountEmpire),
            "MiniRouter: Approve failed"
        );

        amountTokenB = IERC20(tokenB).balanceOf(address(this));
        require(
            IERC20(tokenB).transferFrom(
                msg.sender,
                address(this),
                amountTokenBDesired
            ),
            "MiniRouter: TransferFrom failed"
        );
        amountTokenB = amountTokenB - IERC20(tokenB).balanceOf(address(this));

        require(
            IERC20(tokenB).approve(router, amountTokenB),
            "MiniRouter: Approve failed"
        );
    }

    function _addLiquidityTokens(
        address router,
        address tokenB,
        uint256 amountEmpire,
        uint256 amountTokenB,
        address to,
        uint256 deadline
    )
        private
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        uint256 amountEmpireAdded = empire.balanceOf(address(this));
        uint256 amountTokenBAdded = IERC20(tokenB).balanceOf(address(this));

        (amountA, amountB, liquidity) = IUniswapV2Router02(router).addLiquidity(
            address(empire),
            tokenB,
            amountEmpire,
            amountTokenB,
            0,
            0,
            to,
            deadline
        );

        amountEmpireAdded = amountEmpireAdded - empire.balanceOf(address(this));
        amountTokenBAdded =
            amountTokenBAdded -
            IERC20(tokenB).balanceOf(address(this));

        require(
            amountEmpireAdded == amountA,
            "MiniRouter: AddLiquidity failed"
        );
        require(
            amountTokenBAdded == amountB,
            "MiniRouter: AddLiquidity failed"
        );
    }

    function addLiquidityTokens(
        address router,
        address tokenB,
        uint256 amountEmpireDesired,
        uint256 amountTokenBDesired,
        address to,
        uint256 deadline
    )
        external
        whenNotPaused
        nonReentrant
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        (uint256 amountEmpire, uint256 amountTokenB) = beforeAddLiquidityTokens(
            router,
            tokenB,
            amountEmpireDesired,
            amountTokenBDesired
        );

        (amountA, amountB, liquidity) = _addLiquidityTokens(
            router,
            tokenB,
            amountEmpire,
            amountTokenB,
            to,
            deadline
        );

        uint256 amountEmpireRefund = amountEmpire - amountA;
        uint256 amountTokenBRefund = amountTokenB - amountB;

        require(amountEmpireRefund >= 0, "Empire: Insufficient funds");
        require(amountTokenBRefund >= 0, "TokenB: Insufficient funds");

        if (amountEmpireRefund > 0) {
            require(
                empire.transfer(msg.sender, amountEmpireRefund),
                "Transfer fail"
            );
        }

        if (amountTokenBRefund > 0) {
            require(
                IERC20(tokenB).transfer(msg.sender, amountTokenBRefund),
                "Transfer fail"
            );
        }

        emit LogAddLiquidityTokens(
            msg.sender,
            router,
            tokenB,
            amountA,
            amountB,
            liquidity,
            to
        );
    }

    // function addLiquidityETH(
    //     uint256 amountEmpireDesired,
    //     uint256 ethAmount,
    //     address router,
    //     address to,
    //     uint256 deadline
    // ) external payable whenNotPaused nonReentrant {
    //     address recipient = _msgSender();
    //     require(
    //         supportedRouters[router] == true,
    //         "MiniRouter: The Router is not supported"
    //     );
    //     require(
    //         empire.approve(router, amountEmpireDesired),
    //         "MiniRouter: Approve failed"
    //     );
    //     require(
    //         empire.transferFrom(msg.sender, address(this), amountEmpireDesired),
    //         "MiniRouter: TransferFrom failed"
    //     );
    //     IUniswapV2Router02(router).addLiquidityETH{value: ethAmount}(
    //         address(empire),
    //         amountEmpireDesired,
    //         0,
    //         0,
    //         recipient,
    //         block.timestamp
    //     );

    //     emit LogAddLiquidityETH(recipient, amountEmpireDesired, ethAmount, router);
    // }

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

    function updateSupportedRouters(address router, bool enabled)
        public
        onlyOwner
    {
        supportedRouters[router] = enabled;

        emit LogUpdateSupportedRouters(router, enabled);
    }

    function updateSupportedTokens(address token, bool enabled)
        public
        onlyOwner
    {
        supportedTokens[token] = enabled;

        emit LogUpdateSupportedTokens(token, enabled);
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
