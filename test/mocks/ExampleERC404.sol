//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC404} from "../../src/ERC404.sol";

contract ERC404Example is Ownable, ERC404 {
  constructor(string memory name_, string memory symbol_, uint8 decimals_, uint16 rate_, address initialOwner_)
    ERC404(name_, symbol_, decimals_, rate_)
    Ownable(initialOwner_)
  {}

  function mintERC20(address account_, uint256 value_) external {
    _mintERC20(account_, value_);
  }

  function tokenURI(uint256 id_) public pure override returns (string memory) {
    return string.concat("https://example.com/token/", Strings.toString(id_));
  }

  function setERC721TransferExempt(address account_, bool value_) external onlyOwner {
    _setERC721TransferExempt(account_, value_);
  }
}
