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

    // event LogSetPair(address pair);
    // event LogDeletePair(address pair);

    // event LogRemoveLiquidityETH(address recipient, uint256 liquidity, address router);
    // event LogRemoveLiquidityTokens(address recipient, uint256 liquidity, address router, address tokenB);

    constructor(address empire_, address router) {
        setEmpire(empire_);

        updateSupportedRouters(router, true);
    }

    function beforeAddLiquidityTokens(
        address router,
        address tokenB,
        uint256 amountEmpireDesired,
        uint256 amountTokenBDesired
    ) private {
        require(
            IEmpire(empire).isExcludedFromFee(address(this)) == true,
            "MiniRouter: The Router must be excluded from fee"
        );

        require(
            supportedRouters[router] == true,
            "MiniRouter: The Router is not supported"
        );

        require(
            supportedTokens[tokenB] == true,
            "MiniRouter: The TokenB is not supported"
        );

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
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        beforeAddLiquidityTokens(
            router,
            tokenB,
            amountEmpireDesired,
            amountTokenBDesired
        );

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

    function beforeAddLiquidityETH(address router, uint256 amountEmpireDesired)
        private
        returns (uint256 amountEmpire)
    {
        require(
            supportedRouters[router] == true,
            "MiniRouter: The Router is not supported"
        );

        amountEmpire = IERC20(empire).balanceOf(address(this));
        require(
            IERC20(empire).transferFrom(
                msg.sender,
                address(this),
                amountEmpireDesired
            ),
            "MiniRouter: TransferFrom failed"
        );
        amountEmpire = IERC20(empire).balanceOf(address(this)) - amountEmpire;

        require(
            IERC20(empire).approve(router, amountEmpire),
            "MiniRouter: Approve failed"
        );
    }

    function _addLiquidityETH(
        address router,
        uint256 amountEmpire,
        uint256 ethAmount,
        address to,
        uint256 deadline
    )
        private
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        )
    {
        uint256 amountEmpireAdded = IERC20(empire).balanceOf(address(this));

        (amountToken, amountETH, liquidity) = IUniswapV2Router02(router)
            .addLiquidityETH{value: ethAmount}(
            empire,
            amountEmpire,
            0,
            0,
            to,
            deadline
        );

        amountEmpireAdded =
            amountEmpireAdded -
            IERC20(empire).balanceOf(address(this));

        require(
            amountEmpireAdded == amountToken,
            "MiniRouter: AddLiquidity failed"
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
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        )
    {
        uint256 amountEmpire = beforeAddLiquidityETH(
            router,
            amountEmpireDesired
        );

        (amountToken, amountETH, liquidity) = _addLiquidityETH(
            router,
            amountEmpire,
            msg.value,
            to,
            deadline
        );

        require(amountEmpire >= amountToken, "Empire: Insufficient funds");
        require(msg.value >= amountETH, "ETH: Insufficient funds");

        uint256 amountEmpireRefund = amountEmpire - amountToken;
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
            amountEmpire,
            amountETH,
            liquidity,
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
    //         empire,
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
    //         empire,
    //         liquidity,
    //         0,
    //         0,
    //         recipient,
    //         block.timestamp
    //     );

    //     emit LogRemoveLiquidityETH(recipient, liquidity, router);
    // }
}
