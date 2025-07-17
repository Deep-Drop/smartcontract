// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/Drop1155.sol";
import "@thirdweb-dev/contracts/base/ERC1155LazyMint.sol";
import "@thirdweb-dev/contracts/lib/CurrencyTransferLib.sol";

interface Points {
    function getPoints(address _user) external view returns (uint256);
    function usedPoints(address _user, uint256 _amount) external;
}

contract DDNFT is ERC1155LazyMint, Drop1155 {
    Points public pointsContract;
    uint256 public maxMintPerAddress = 1;
    uint256 public currentMintRound = 0;
    uint256 public requiredPoints;

    uint256 private fixedTokenId = 0;
    uint256 private fixedQuantity = 1;
    uint256 private fixedEndTime;
    bool public isMintingEnabled = false;

    uint256 private upgradeTokenIdToBurn;
    uint256 private upgradeQuantityToBurn;
    uint256 private upgradeTokenIdToMint;
    uint256 private upgradeQuantityToMint;
    bool public isUpgradeEnabled = false;

    mapping(uint256 => bool) public isUpgradeEnabledTo;

    mapping(address => mapping(uint256 => uint256)) public mintCount;

    constructor()
        ERC1155LazyMint(
            0x0Af083eB8Aea599b50e53DCD4Af455fb19fF50DC, // Owner
            "DDNFT",
            "DDNFT",
            0x0Af083eB8Aea599b50e53DCD4Af455fb19fF50DC, // Owner
            1000
        )
    {
        pointsContract = Points(0xF7c8869269136B59AC479638b508D5A45123da1C); // DDPoint
        
        isUpgradeEnabledTo[0] = false;
        isUpgradeEnabledTo[1] = false;
        isUpgradeEnabledTo[2] = false;
    }

    function collectPriceOnClaim(
        uint256 _tokenId,
        address _primarySaleRecipient,
        uint256 _quantityToClaim,
        address _currency,
        uint256 _pricePerToken
    ) internal virtual override {}

    function transferTokensOnClaim(
        address _to,
        uint256 _tokenId,
        uint256 _quantityBeingClaimed
    ) internal virtual override {}

    function _collectPriceOnClaim(
        uint256 _tokenId,
        address _primarySaleRecipient,
        uint256 _quantityToClaim,
        address _currency,
        uint256 _pricePerToken
    ) internal virtual {}

    function _transferTokensOnClaim(
        address _to,
        uint256 _tokenId,
        uint256 _quantityBeingClaimed
    ) internal virtual override {
        _mint(_to, _tokenId, _quantityBeingClaimed, "");
    }

    function _canSetClaimConditions() internal view virtual override returns (bool) {
        return msg.sender == owner();
    }

    // --- //
    function setRequiredPoints(uint256 _points) external onlyOwner {
        requiredPoints = _points;
    }

    function setMaxMintPerAddress(uint256 _maxMint) external onlyOwner {
        maxMintPerAddress = _maxMint;
    }

    function setMintRound(uint256 _newRound) external onlyOwner {
        require(_newRound > currentMintRound, "New round must be greater than current");
        currentMintRound = _newRound;
    }

    function setMint(uint256 _tokenId, uint256 _quantity, uint256 _endTime) external onlyOwner {
        require(_endTime > fixedEndTime, "New endTime must be greater than current");
        fixedTokenId = _tokenId;
        fixedQuantity = _quantity;
        fixedEndTime = _endTime;
        currentMintRound++;
    }

    function toggleMint() external onlyOwner {
        isMintingEnabled = !isMintingEnabled;
    }

    function mint() public {
        require(isMintingEnabled, "Minting is currently disabled");
        require(block.timestamp < fixedEndTime, "Mint period has ended");
        require(mintCount[msg.sender][currentMintRound] + fixedQuantity <= maxMintPerAddress, "Mint limit exceeded");

        uint256 point = pointsContract.getPoints(msg.sender);
        require(point >= requiredPoints, "Not enough points");
        pointsContract.usedPoints(msg.sender, requiredPoints);

        mintCount[msg.sender][currentMintRound] += fixedQuantity;
        _mint(msg.sender, fixedTokenId, fixedQuantity, "");
    }

    function mintInfo() external view returns (bool _isMintingEnabled, uint256 _requiredPoints, uint256 _fixedTokenId, uint256 _fixedQuantity, uint256 _fixedEndTime) {
        return (isMintingEnabled, requiredPoints, fixedTokenId, fixedQuantity, fixedEndTime);
    }

    // -------------------------------------------- //
    // Upgrade function
    // -------------------------------------------- //
    function toggleUpgrade() external onlyOwner {
        isUpgradeEnabled = !isUpgradeEnabled;
    }

    function setUpgrade(uint256 _tokenIdToBurn, uint256 _quantityToBurn, uint256 _tokenIdToMint, uint256 _quantityToMint) external onlyOwner {
        upgradeTokenIdToBurn = _tokenIdToBurn;
        upgradeQuantityToBurn = _quantityToBurn;

        upgradeTokenIdToMint = _tokenIdToMint;
        upgradeQuantityToMint = _quantityToMint;
    }

    function upgrade() public {
        require(isUpgradeEnabled, "Upgrade is currently disabled");
        require(upgradeTokenIdToMint >= upgradeTokenIdToBurn, "Token ID to mint must be greater than or equal to token ID to burn");
        require(upgradeQuantityToMint >= upgradeQuantityToBurn, "Mint quantity must be greater than or equal to burn quantity");
        
        _burn(msg.sender, upgradeTokenIdToBurn, upgradeQuantityToBurn);
        _mint(msg.sender, upgradeTokenIdToMint, upgradeQuantityToMint, "");
    }

    function upgradeInfo() external view returns (bool _isUpgradeEnabled, uint256 _upgradeTokenIdToBurn, uint256 _upgradeQuantityToBurn, uint256 _upgradeTokenIdToMint, uint256 _upgradeQuantityToMint) {
        return (isUpgradeEnabled, upgradeTokenIdToBurn, upgradeQuantityToBurn, upgradeTokenIdToMint, upgradeQuantityToMint);
    }

    function setPointsContract(address _pointsContractAddress) external onlyOwner {
        require(_pointsContractAddress != address(0), "Invalid address");
        pointsContract = Points(_pointsContractAddress);
    }

    // ------------------------- //
    function toggleUpgradeTo(uint256 _upgradeIdTo, bool _status) external onlyOwner {
        isUpgradeEnabledTo[_upgradeIdTo] = _status;
    }

    function upgrade0To1() public {
        require(isUpgradeEnabledTo[0], "Upgrade from 0 to 1 is disabled");
        _burn(msg.sender, 0, 1);
        _mint(msg.sender, 1, 1, "");
    }

    function upgrade1To2() public {
        require(isUpgradeEnabledTo[1], "Upgrade from 1 to 2 is disabled");
        _burn(msg.sender, 1, 2);
        _mint(msg.sender, 2, 1, "");
    }

    function upgrade2To3() public {
        require(isUpgradeEnabledTo[2], "Upgrade from 2 to 3 is disabled");
        _burn(msg.sender, 2, 3);
        _mint(msg.sender, 3, 1, "");
    }

}
