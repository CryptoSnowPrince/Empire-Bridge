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

interface IEmpire {
    function isExcludedFromFee(address account) external view returns (bool);
}

contract MiniRouter is Ownable, Pausable, ReentrancyGuard {
    ///@notice MiniRouter must be excluded from Empire buy/sell fee
    address public empire;

    ///@notice The only owner can add or remove new router, but before add, owner must check its contract.
    mapping(address => bool) public supportedRouters;

    ///@notice The only owner can add or remove new token, but before add, owner must check token contract.
    mapping(address => bool) public supportedTokens;

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
        uint256 amountEmpire,
        uint256 amountTokenB,
        uint256 liquidity,
        address to
    );
    event LogAddLiquidityETH(
        address indexed from,
        address indexed router,
        uint256 amountEmpire,
        uint256 amountETH,
        uint256 liquidity,
        address to
    );
    event LogRemoveLiquidityTokens(
        address indexed from,
        address indexed router,
        address indexed tokenB,
        uint256 liquidity,
        uint256 amountEmpire,
        uint256 amountTokenB,
        address to
    );
    event LogRemoveLiquidityETH(
        address indexed from,
        address indexed router,
        uint256 liquidity,
        uint256 amountEmpire,
        uint256 amountETH,
        address to
    );

    constructor(address empire_, address router) {
        setEmpire(empire_);

        updateSupportedRouters(router, true);
    }

    function ensure(address router) private view {
        require(
            IEmpire(empire).isExcludedFromFee(address(this)) == true,
            "MiniRouter: The Router must be excluded from fee"
        );

        require(
            supportedRouters[router] == true,
            "MiniRouter: The Router is not supported"
        );
    }

    modifier ensureAddLiquidity(address router, uint256 amountEmpireDesired) {
        ensure(router);

        require(
            IERC20(empire).transferFrom(
                msg.sender,
                address(this),
                amountEmpireDesired
            ),
            "MiniRouter: TransferFrom failed"
        );

        require(
            IERC20(empire).approve(router, amountEmpireDesired),
            "MiniRouter: Approve failed"
        );

        _;
    }

    modifier ensureRemoveLiquidity(
        address router,
        address tokenB,
        uint256 liquidity
    ) {
        ensure(router);

        require(
            supportedTokens[tokenB] == true,
            "MiniRouter: The TokenB is not supported"
        );

        address pair = IUniswapV2Factory(IUniswapV2Router02(router).factory())
            .getPair(empire, tokenB);

        require(pair != address(0), "MiniRouter: Pair does not exist");

        require(
            IERC20(pair).transferFrom(msg.sender, address(this), liquidity),
            "MiniRouter: TransferFrom failed"
        );

        require(
            IERC20(pair).approve(router, liquidity),
            "MiniRouter: Approve failed"
        );

        _;
    }

    function beforeAddLiquidityTokens(
        address router,
        address tokenB,
        uint256 amountTokenBDesired
    ) private {
        require(
            supportedTokens[tokenB] == true,
            "MiniRouter: The TokenB is not supported"
        );

        require(
            IERC20(tokenB).transferFrom(
                msg.sender,
                address(this),
                amountTokenBDesired
            ),
            "MiniRouter: TransferFrom failed"
        );

        require(
            IERC20(tokenB).approve(router, amountTokenBDesired),
            "MiniRouter: Approve failed"
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
        ensureAddLiquidity(router, amountEmpireDesired)
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        beforeAddLiquidityTokens(router, tokenB, amountTokenBDesired);

        (amountA, amountB, liquidity) = IUniswapV2Router02(router).addLiquidity(
            empire,
            tokenB,
            amountEmpireDesired,
            amountTokenBDesired,
            0,
            0,
            to,
            deadline
        );

        uint256 amountEmpireRefund = amountEmpireDesired - amountA;
        uint256 amountTokenBRefund = amountTokenBDesired - amountB;

        if (amountEmpireRefund > 0) {
            require(
                IERC20(empire).transfer(msg.sender, amountEmpireRefund),
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

    function addLiquidityETH(
        address router,
        uint256 amountEmpireDesired,
        address to,
        uint256 deadline
    )
        external
        payable
        whenNotPaused
        nonReentrant
        ensureAddLiquidity(router, amountEmpireDesired)
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        )
    {
        (amountToken, amountETH, liquidity) = IUniswapV2Router02(router)
            .addLiquidityETH{value: msg.value}(
            empire,
            amountEmpireDesired,
            0,
            0,
            to,
            deadline
        );

        uint256 amountEmpireRefund = amountEmpireDesired - amountToken;
        uint256 amountETHRefund = msg.value - amountETH;

        if (amountEmpireRefund > 0) {
            require(
                IERC20(empire).transfer(msg.sender, amountEmpireRefund),
                "Transfer fail"
            );
        }

        if (amountETHRefund > 0) {
            (bool success, ) = msg.sender.call{value: amountETHRefund}(
                new bytes(0)
            );
            require(success, "ETH Refund fail");
        }

        emit LogAddLiquidityETH(
            msg.sender,
            router,
            amountToken,
            amountETH,
            liquidity,
            to
        );
    }

    function removeLiquidityTokens(
        address router,
        address tokenB,
        uint256 liquidity,
        address to,
        uint256 deadline
    )
        external
        whenNotPaused
        nonReentrant
        ensureRemoveLiquidity(router, tokenB, liquidity)
        returns (uint256 amountA, uint256 amountB)
    {
        (amountA, amountB) = IUniswapV2Router02(router).removeLiquidity(
            empire,
            tokenB,
            liquidity,
            0,
            0,
            to,
            deadline
        );

        emit LogRemoveLiquidityTokens(
            msg.sender,
            router,
            tokenB,
            liquidity,
            amountA,
            amountB,
            to
        );
    }

    function removeLiquidityETH(
        address router,
        uint256 liquidity,
        address to,
        uint256 deadline
    )
        external
        whenNotPaused
        nonReentrant
        ensureRemoveLiquidity(
            router,
            IUniswapV2Router02(router).WETH(),
            liquidity
        )
        returns (uint256 amountToken, uint256 amountETH)
    {
        (amountToken, amountETH) = IUniswapV2Router02(router)
            .removeLiquidityETH(empire, liquidity, 0, 0, to, deadline);

        emit LogRemoveLiquidityETH(
            msg.sender,
            router,
            liquidity,
            amountToken,
            amountETH,
            to
        );
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

    function setEmpire(address empire_) public onlyOwner {
        empire = empire_;
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
}
