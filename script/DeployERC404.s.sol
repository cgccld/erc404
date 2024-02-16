// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Migrate.s.sol";
import {MinimalERC404} from "src/MinimalERC404.sol";

contract ERC404Deployer is BaseMigrate {
  function run() external {
    deployMinimalERC404();
    _postCheck();
  }

  function deployMinimalERC404() public broadcast {
    deployContract(
      "MinimalERC404.sol:MinimalERC404", abi.encode("404 Sample", "SYM", 18, 0x58f5663cCb305366F584b5f4dF523728D5479396)
    );
  }
}
