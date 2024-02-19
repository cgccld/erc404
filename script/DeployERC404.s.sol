// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Migrate.s.sol";
import {Sample404} from "src/Sample404.sol";

contract ERC404Deployer is BaseMigrate {
  function run() external {
    deploySampleERC404();
    _postCheck();
  }

  function deploySampleERC404() public broadcast {
    deployUUPSProxy(
      "Sample404.sol:Sample404",
      abi.encodeCall(
        Sample404.initialize,
        (
          "404 Sample",
          "SYM",
          "https://metadata.keyring.app/nft/metadata/404sample/",
          18,
          100,
          0x58f5663cCb305366F584b5f4dF523728D5479396
        )
      )
    );
  }
}
