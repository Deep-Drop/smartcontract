// SPDX-License-Identifier: GNU General Public License v3.0
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20Pausable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface Points {
    function getPoints(address _user) external view returns (uint256);
    function usedPoints(address _user, uint256 _amount) external;
}

contract DDPTS is ERC20, Ownable, ERC20Pausable, ReentrancyGuard {
    Points public pointsContract;

    event Redeemed(address user, uint256 amount);

    constructor() ERC20("DDPTS", "DDPTS") Ownable(msg.sender) {
        pointsContract = Points(0xF7c8869269136B59AC479638b508D5A45123da1C); // v1
    }

    function redeemDDPTS(uint256 amount) public nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(amount % 1 == 0, "Amount must be a whole number");
        uint256 point = pointsContract.getPoints(msg.sender);
        require(point >= amount, "Not enough points");
        pointsContract.usedPoints(msg.sender, amount);
        _mint(msg.sender, amount * 10 ** 18);
        emit Redeemed(msg.sender, amount);
    }

    function setPointsContract(address _pointsContract) external onlyOwner {
        require(_pointsContract != address(0), "Invalid address");
        pointsContract = Points(_pointsContract);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _update(address from, address to, uint256 value) internal override (ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}
