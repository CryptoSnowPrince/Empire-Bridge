// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IEmpireToken {
    function mint(address account, uint256 tAmount) external;

    function burn(address account, uint256 tAmount) external;
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract Bridge is Ownable, Pausable, ReentrancyGuard {
    // state variables
    address public validator;
    uint256 public fee = 1 * 10**(18 - 2); // 0.01 Ether
    address payable public TREASURY;

    // events list
    event LogWithdrawalETH(address indexed recipient, uint256 amount);
    event LogWithdrawalERC20(
        address indexed token,
        address indexed recipient,
        uint256 amount
    );
    event LogSetFee(uint256 fee);
    event LogSetValidator(address validator);
    event LogSetTreasury(address indexed treasury);
    event LogFallback(address from, uint256 amount);
    event LogReceive(address from, uint256 amount);

    constructor(address _validator, address payable _treasury) {
        validator = _validator;
        TREASURY = _treasury;
    }

    function isValidator() internal view returns (bool) {
        return (validator == msg.sender);
    }

    modifier onlyValidator() {
        require(isValidator(), "DENIED : Not Validator");
        _;
    }

    function getChainID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    // Set functions
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
