//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC404Upgradeable} from "src/ERC404Upgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Sample404 is Initializable, ERC404Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
  string public baseTokenURI;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    string calldata name_,
    string calldata symbol_,
    string calldata baseTokenURI_,
    uint8 decimals_,
    uint16 rate_,
    address initialOwner_
  ) public initializer {
    __ERC404_init_unchained(name_, symbol_, decimals_, rate_);
    __Ownable_init(initialOwner_);
    __UUPSUpgradeable_init();

    baseTokenURI = baseTokenURI_;
  }

  function mintERC20(address account_, uint256 value_) external onlyOwner {
    _mintERC20(account_, value_);
  }

  function setBaseTokenURI(string calldata baseTokenURI_) external onlyOwner {
    baseTokenURI = baseTokenURI_;
  }

  function tokenURI(uint256 id_) public view override returns (string memory) {
    return string.concat(baseTokenURI, Strings.toString(id_));
  }

  function setERC721TransferExempt(address account_, bool value_) external onlyOwner {
    _setERC721TransferExempt(account_, value_);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
