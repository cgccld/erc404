// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./mocks/ExampleERC404.sol";
import {IERC404} from "../src/interfaces/IERC404.sol";
import {ERC20Events} from "../src/libraries/ERC20Events.sol";
import {ERC721Events} from "../src/libraries/ERC721Events.sol";

contract Erc404Test is Test {
  SigUtils internal sigUtils;
  ERC404Example public simpleContract_;

  string name_ = "Example";
  string symbol_ = "EXM";
  uint8 decimals_ = 18;
  uint16 rate_ = 100;
  uint256 maxTotalSupplyNft_ = 100;
  uint256 units_ = 10 ** decimals_;

  address bob = makeAddr("bob");
  address alice = makeAddr("alice");
  address initialOwner_ = makeAddr("initialOwner");

  function setUp() public {
    simpleContract_ = new ERC404Example(name_, symbol_, decimals_, rate_, initialOwner_);
    sigUtils = new SigUtils(simpleContract_.DOMAIN_SEPARATOR());
  }

  function testConcrete_constructor_InitialDataIsCorrect() public {
    assertEq(simpleContract_.name(), name_);
    assertEq(simpleContract_.symbol(), symbol_);
    assertEq(simpleContract_.decimals(), decimals_);
    assertEq(simpleContract_.owner(), initialOwner_);
  }

  function testConcrete_mintERC20_WhenMinterIsExempt() public {
    vm.prank(initialOwner_, initialOwner_);
    simpleContract_.setERC721TransferExempt(bob, true);

    vm.prank(bob, bob);
    simpleContract_.mintERC20(bob, 100 ether);

    assertEq(simpleContract_.erc721BalanceOf(bob), 0, "erc721BalanceOf(bob) != 0");
    assertEq(simpleContract_.erc20BalanceOf(bob), 100 ether, "erc20BalanceOf(bob) != 100 ether");
  }

  function testConcrete_mintERC20_WhenMinterIsNotExempt() public {
    vm.prank(bob, bob);
    simpleContract_.mintERC20(bob, 100 ether);

    assertEq(simpleContract_.erc721BalanceOf(bob), 1, "erc721BalanceOf(bob) != 1");
    assertEq(simpleContract_.erc20BalanceOf(bob), 100 ether, "erc20BalanceOf(bob) != 100 ether");
  }

  function testConcrete_transfer_Token() public {
    vm.startPrank(bob, bob);
    simpleContract_.mintERC20(bob, 100 ether);

    vm.expectEmit(address(simpleContract_));
    emit ERC20Events.Transfer(bob, alice, 100 ether);
    simpleContract_.transfer(alice, 100 ether);
    assertEq(simpleContract_.erc20BalanceOf(alice), 100 ether, "erc20BalanceOf(alice) != 100 ether");
    assertEq(simpleContract_.erc721BalanceOf(alice), 1, "erc721BalanceOf(alice) != 1");
  }

  function testConcrete_safeTransferFrom_NFT() public {
    vm.startPrank(bob, bob);
    simpleContract_.mintERC20(bob, 100 ether);

    vm.expectEmit(address(simpleContract_));
    emit ERC721Events.Transfer(bob, alice, 1);
    simpleContract_.safeTransferFrom(bob, alice, 1);
    assertEq(simpleContract_.erc20BalanceOf(alice), 100 ether, "erc20BalanceOf(alice) != 100 ether");
    assertEq(simpleContract_.erc721BalanceOf(alice), 1, "erc721BalanceOf(alice) != 1");
  }

  function testConcrete_approve_WhenApproveToken() public {
    vm.startPrank(bob, bob);
    simpleContract_.mintERC20(bob, 100 ether);

    vm.expectEmit(address(simpleContract_));
    emit ERC20Events.Approval(bob, alice, 100 ether);
    simpleContract_.approve(alice, 100 ether);

    vm.startPrank(alice, alice);
    simpleContract_.erc20TransferFrom(bob, alice, 100 ether);
    assertEq(simpleContract_.erc20BalanceOf(alice), 100 ether, "erc20BalanceOf(alice) != 100 ether");
    assertEq(simpleContract_.erc721BalanceOf(alice), 1, "erc721BalanceOf(alice) != 1");
  }

  function testConcrete_approve_WhenApproveNFT() public {
    vm.startPrank(bob, bob);
    simpleContract_.mintERC20(bob, 100 ether);

    vm.expectEmit(address(simpleContract_));
    emit ERC721Events.Approval(bob, alice, 1);
    simpleContract_.approve(alice, 1);

    vm.startPrank(alice, alice);
    simpleContract_.safeTransferFrom(bob, alice, 1);
    assertEq(simpleContract_.erc20BalanceOf(alice), 100 ether, "erc20BalanceOf(alice) != 100 ether");
    assertEq(simpleContract_.erc721BalanceOf(alice), 1, "erc721BalanceOf(alice) != 1");
  }

  function testConcrete_setApproveAll() public {
    vm.startPrank(bob, bob);
    simpleContract_.mintERC20(bob, 1000 ether);

    vm.expectEmit(address(simpleContract_));
    emit ERC721Events.ApprovalForAll(bob, alice, true);
    simpleContract_.setApprovalForAll(alice, true);

    vm.startPrank(alice, alice);
    uint256 balance;
    for (uint256 i = 1; i <= 10; ++i) {
      balance += 100 ether;
      simpleContract_.safeTransferFrom(bob, alice, i);
      assertEq(simpleContract_.erc20BalanceOf(alice), balance, "erc20BalanceOf(alice) != balance");
      assertEq(simpleContract_.erc721BalanceOf(alice), i, "erc721BalanceOf(alice) != i");
    }
  }

  function testConcrete_permit() public {
    (, uint256 bobPk) = makeAddrAndKey("bob");

    vm.startPrank(bob, bob);
    simpleContract_.mintERC20(bob, 100 ether);

    SigUtils.Permit memory permit =
      SigUtils.Permit({owner: bob, spender: alice, value: 100 ether, nonce: 0, deadline: 1 days});
    bytes32 digest = sigUtils.getTypedDataHash(permit);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, digest);

    vm.expectEmit();
    emit ERC20Events.Approval(bob, alice, 100 ether);
    simpleContract_.permit(bob, alice, 100 ether, 1 days, v, r, s);

    vm.startPrank(alice, alice);
    simpleContract_.erc20TransferFrom(bob, alice, 100 ether);
    assertEq(simpleContract_.erc20BalanceOf(alice), 100 ether, "erc20BalanceOf(alice) != 100 ether");
    assertEq(simpleContract_.erc721BalanceOf(alice), 1, "erc721BalanceOf(alice) != 1");
  }

  // function test_tokenTransfer(uint8 nftToTransfer, address randomAddress) public {
  //   vm.skip(true);
  //   vm.assume(nftToTransfer <= 100);
  //   vm.assume(randomAddress != address(0));

  //   // Transfer some tokens to a non-whitelisted wallet to generate the NFTs.
  //   vm.prank(initialMintRecipient_);
  //   simpleContract_.transfer(randomAddress, nftToTransfer * units_);

  //   // Returns the correct total supply
  //   assertEq(simpleContract_.erc721TotalSupply(), nftToTransfer);
  //   assertEq(simpleContract_.totalSupply(), maxTotalSupplyNft_ * units_);
  //   assertEq(simpleContract_.erc20TotalSupply(), maxTotalSupplyNft_ * units_);

  //   // Reverts if the token ID is 0
  //   vm.expectRevert(IERC404.NotFound.selector);
  //   simpleContract_.ownerOf(0);

  //   // Reverts if the token ID is `nftToTransfer + 1` (does not exist)
  //   vm.expectRevert(IERC404.NotFound.selector);
  //   simpleContract_.ownerOf(nftToTransfer + 1);

  //   for (uint8 i = 1; i <= nftToTransfer; i++) {
  //     assertEq(simpleContract_.ownerOf(i), randomAddress);
  //   }
  // }
}

// contract Erc404MintingStorageAndRetrievalTest is Test {
//   MinimalERC404 public minimalContract_;

//   string name_ = "Example";
//   string symbol_ = "EXM";
//   uint8 decimals_ = 18;
//   uint256 units_ = 10 ** decimals_;
//   uint256 maxTotalSupplyNft_ = 100;
//   uint256 maxTotalSupplyCoin_ = maxTotalSupplyNft_ * units_;

//   address initialOwner_ = address(0x1);

//   event Transfer(address indexed from, address indexed to, uint256 indexed id);
//   event ERC20Transfer(address indexed from, address indexed to, uint256 amount);

//   function setUp() public {
//     minimalContract_ = new MinimalERC404(name_, symbol_, decimals_, initialOwner_);
//   }

//   function test_initializeMinimal() public {
//     assertEq(minimalContract_.name(), name_);
//     assertEq(minimalContract_.symbol(), symbol_);
//     assertEq(minimalContract_.decimals(), decimals_);
//     assertEq(minimalContract_.owner(), initialOwner_);
//   }

//   function test_mintFullSupply_20_721(address recipient) public {
//     vm.assume(recipient != address(0));

//     // Owner mints the full supply of ERC20 tokens (with the corresponding ERC721 tokens minted as well)
//     vm.prank(initialOwner_);
//     minimalContract_.mintERC20(recipient, maxTotalSupplyCoin_);

//     // Expect the total supply to be equal to the max total supply
//     assertEq(minimalContract_.totalSupply(), maxTotalSupplyCoin_);
//     assertEq(minimalContract_.erc20TotalSupply(), maxTotalSupplyCoin_);

//     // Expect the minted count to be equal to the max total supply
//     assertEq(minimalContract_.erc721TotalSupply(), maxTotalSupplyNft_);
//   }

//   function test_mintFullSupply_20_721_whitelistedRecipient(address recipient) public {
//     vm.assume(recipient != address(0));

//     assertFalse(minimalContract_.erc721TransferExempt(recipient));

//     vm.prank(initialOwner_);
//     minimalContract_.setERC721TransferExempt(recipient, true);

//     // Owner mints the full supply of ERC20 tokens (with the corresponding ERC721 tokens minted as well)
//     vm.prank(initialOwner_);
//     minimalContract_.mintERC20(recipient, maxTotalSupplyCoin_);

//     // Expect the total supply to be equal to the max total supply
//     assertEq(minimalContract_.totalSupply(), maxTotalSupplyCoin_);
//     assertEq(minimalContract_.erc20TotalSupply(), maxTotalSupplyCoin_);

//     // Expect the minted count to be equal to 0
//     assertEq(minimalContract_.erc721TotalSupply(), 0);
//   }

//   function test_mintFullSupply_20(address recipient) public {
//     vm.skip(true);
//     vm.assume(recipient != address(0));

//     // Owner mints the full supply of ERC20 tokens only
//     vm.prank(initialOwner_);
//     minimalContract_.mintERC20(recipient, maxTotalSupplyCoin_);

//     // Expect the total supply to be equal to the max total supply
//     assertEq(minimalContract_.totalSupply(), maxTotalSupplyCoin_);
//     assertEq(minimalContract_.erc20TotalSupply(), maxTotalSupplyCoin_);

//     // Expect the minted count to be equal to 0
//     assertEq(minimalContract_.erc721TotalSupply(), 0);
//   }

//   function test_erc721Storage_mintFrom0(uint8 nftQty, address recipient) public {
//     vm.skip(true);
//     vm.assume(nftQty < maxTotalSupplyNft_);
//     vm.assume(recipient != address(0) && recipient != initialOwner_ && recipient != address(minimalContract_));

//     // Total supply should be 0
//     assertEq(minimalContract_.erc721TotalSupply(), 0);

//     // Expect the contract's bank to be empty
//     assertEq(minimalContract_.balanceOf(address(minimalContract_)), 0);
//     assertEq(minimalContract_.getERC721QueueLength(), 0);

//     uint256 value = nftQty * units_;

//     // mint at the bottom, setup expected events first

//     // expect 1 erc20 transfer event
//     // Check for ERC20Transfer mint events (from 0x0 to the recipient)
//     vm.expectEmit(false, false, false, true);
//     emit ERC20Transfer(address(0), recipient, value);

//     // expect multiple erc721 transfers
//     for (uint8 i = 1; i <= nftQty; i++) {
//       // Check for ERC721Transfer mint events (from 0x0 to the recipient)
//       vm.expectEmit(true, true, true, true);
//       emit Transfer(address(0), recipient, i);
//     }

//     // mint as owner
//     vm.prank(initialOwner_);
//     minimalContract_.mintERC20(recipient, value);

//     // nft supply and balance
//     assertEq(minimalContract_.erc721TotalSupply(), nftQty);
//     assertEq(minimalContract_.erc721BalanceOf(recipient), nftQty);

//     // coin supply and balance
//     assertEq(minimalContract_.erc20TotalSupply(), value);
//     assertEq(minimalContract_.erc20BalanceOf(recipient), value);

//     assertEq(minimalContract_.totalSupply(), value);
//     assertEq(minimalContract_.balanceOf(recipient), value);
//   }

//   function test_erc721Storage_storeInBankOnBurn(uint8 nftQty, address recipient1, address recipient2) public {
//     vm.skip(true);
//     // TODO - handle recipient1 = recipient2
//     vm.assume(recipient1 != recipient2);

//     vm.assume(nftQty > 0 && nftQty < maxTotalSupplyNft_);
//     vm.assume(recipient1 != address(0) && recipient1 != initialOwner_ && recipient1 != address(minimalContract_));
//     vm.assume(recipient2 != address(0) && recipient2 != initialOwner_ && recipient2 != address(minimalContract_));
//     vm.assume(!minimalContract_.erc721TransferExempt(recipient1) && !minimalContract_.erc721TransferExempt(recipient2));

//     // Total supply should be 0
//     assertEq(minimalContract_.erc721TotalSupply(), 0);

//     // Expect the contract's bank to be empty
//     assertEq(minimalContract_.balanceOf(address(minimalContract_)), 0);
//     assertEq(minimalContract_.getERC721QueueLength(), 0);

//     uint256 value = nftQty * units_;

//     // mint as owner
//     vm.prank(initialOwner_);
//     minimalContract_.mintERC20(recipient1, value);

//     uint256 fractionalValueToTransferErc20 = units_ / 10;

//     // setup expected events
//     // ERC20 transfer
//     vm.expectEmit(false, false, false, false);
//     emit ERC20Transfer(recipient1, recipient2, fractionalValueToTransferErc20);

//     // // ERC721 burn (last token id = nftQty)
//     vm.expectEmit(false, false, false, false);
//     emit Transfer(recipient1, address(0), nftQty);

//     vm.prank(recipient1);
//     minimalContract_.transfer(recipient2, fractionalValueToTransferErc20);

//     // erc721 total supply stays the same
//     assertEq(minimalContract_.erc721TotalSupply(), nftQty);

//     // owner of NFT id nftQty should be 0x0
//     vm.expectRevert(IERC404.NotFound.selector);
//     minimalContract_.ownerOf(nftQty);

//     // sender nft balance is nftQty - 1
//     assertEq(minimalContract_.erc721BalanceOf(recipient1), nftQty - 1);

//     // contract balance = 0
//     // contract bank = 1 nft
//     assertEq(minimalContract_.balanceOf(address(minimalContract_)), 0);
//     assertEq(minimalContract_.getERC721QueueLength(), 1);
//   }

//   function test_erc721Storage_retrieveFromBank(uint8 nftQty, address recipient1, address recipient2) public {
//     vm.skip(true);
//     // TODO - handle recipient1 = recipient2
//     vm.assume(recipient1 != recipient2);

//     vm.assume(nftQty > 0 && nftQty < maxTotalSupplyNft_);
//     vm.assume(recipient1 != address(0) && recipient1 != initialOwner_ && recipient1 != address(minimalContract_));
//     vm.assume(recipient2 != address(0) && recipient2 != initialOwner_ && recipient2 != address(minimalContract_));
//     vm.assume(!minimalContract_.erc721TransferExempt(recipient1) && !minimalContract_.erc721TransferExempt(recipient2));

//     uint256 value = nftQty * units_;

//     // mint as owner
//     vm.prank(initialOwner_);
//     minimalContract_.mintERC20(recipient1, value);

//     uint256 fractionalValueToTransferErc20 = units_ / 10;
//     vm.prank(recipient1);
//     minimalContract_.transfer(recipient2, fractionalValueToTransferErc20);

//     assertEq(minimalContract_.balanceOf(address(minimalContract_)), 0);
//     assertEq(minimalContract_.getERC721QueueLength(), 1);

//     // reconstitute
//     // expected events
//     vm.expectEmit(false, false, false, false);
//     emit ERC20Transfer(recipient2, recipient1, fractionalValueToTransferErc20);

//     vm.expectEmit(false, false, false, false);
//     emit Transfer(address(0), recipient1, nftQty);

//     // tx
//     vm.prank(recipient2);
//     minimalContract_.transfer(recipient1, fractionalValueToTransferErc20);

//     // Original sender's ERC20 balance should be nftQty * units
//     // The owner of NFT `nftQty` should be the original sender's address
//     assertEq(minimalContract_.erc20BalanceOf(recipient1), nftQty * units_);
//     assertEq(minimalContract_.ownerOf(nftQty), recipient1);

//     // The sender's NFT balance should be 10
//     // The contract's NFT balance should be 0
//     // The contract's bank should contain 0 NFTs
//     assertEq(minimalContract_.erc721BalanceOf(recipient1), nftQty);
//     assertEq(minimalContract_.balanceOf(address(minimalContract_)), 0);
//     assertEq(minimalContract_.getERC721QueueLength(), 0);
//   }
// }

// contract ERC404TransferLogicTest is Test {
//   ERC404Example public simpleContract_;

//   string name_ = "Example";
//   string symbol_ = "EXM";
//   uint8 decimals_ = 18;
//   uint256 maxTotalSupplyNft_ = 100;
//   uint256 units_ = 10 ** decimals_;

//   address initialOwner_ = address(0x1);
//   address initialMintRecipient_ = address(0x2);

//   // alice is initial sender for all this test;
//   address alice = address(0xa);
//   address bob = address(0xb);

//   function setUp() public {
//     simpleContract_ =
//       new ERC404Example(name_, symbol_, decimals_, maxTotalSupplyNft_, initialOwner_, initialMintRecipient_);

//     // Add the owner to the whitelist
//     vm.prank(initialOwner_);
//     simpleContract_.setERC721TransferExempt(initialOwner_, true);

//     vm.prank(initialMintRecipient_);
//     simpleContract_.transfer(alice, maxTotalSupplyNft_ * units_);
//   }
//   //////// Fractional transfers (moving less than 1 full token) that trigger ERC721 transfers

//   function test_erc20TransferTriggering721Transfer_fractional_receiverGain() public {
//     // Bob starts with 0.9 tokens
//     uint256 bobInitialBalance = units_ * 9 / 10;
//     vm.prank(alice);
//     simpleContract_.transfer(bob, bobInitialBalance);

//     uint256 aliceInitialBalance = simpleContract_.balanceOf(alice);
//     uint256 aliceInitialNftBalance = (simpleContract_.erc721BalanceOf(alice));

//     // Ensure that the receiver has 0.9 tokens and 0 NFTs.
//     assertEq(simpleContract_.balanceOf(bob), bobInitialBalance);
//     assertEq(simpleContract_.erc20BalanceOf(bob), bobInitialBalance);
//     assertEq(simpleContract_.erc721BalanceOf(bob), 0);

//     uint256 fractionalValueToTransferErc20 = units_ / 10;
//     vm.prank(alice);

//     simpleContract_.transfer(bob, fractionalValueToTransferErc20);

//     // Verify ERC20 balances after transfer
//     assertEq(simpleContract_.balanceOf(alice), aliceInitialBalance - fractionalValueToTransferErc20);
//     assertEq(simpleContract_.balanceOf(bob), bobInitialBalance + fractionalValueToTransferErc20);

//     // Verify ERC721 balances after transfer
//     // Assuming the receiver should have gained 1 NFT due to the transfer completing a whole token
//     assertEq(simpleContract_.erc721BalanceOf(alice), aliceInitialNftBalance);
//     assertEq(simpleContract_.erc721BalanceOf(bob), 1);
//   }

//   function test_erc20TransferTriggering721Transfer_fractional_senderLose() public {
//     uint256 aliceStartingBalanceErc20 = simpleContract_.balanceOf(alice);
//     uint256 aliceStartingBalanceErc721 = simpleContract_.erc721BalanceOf(alice);

//     uint256 bobStartingBalanceErc20 = simpleContract_.balanceOf(bob);
//     uint256 bobStartingBalanceErc721 = simpleContract_.erc721BalanceOf(bob);

//     assertEq(aliceStartingBalanceErc20, maxTotalSupplyNft_ * units_);
//     // Sender starts with 100 tokens and sends 0.1, resulting in the loss of 1 NFT but no NFT transfer to the receiver.
//     uint256 initialFractionalAmount = units_ / 10;
//     vm.prank(alice);
//     simpleContract_.transfer(bob, initialFractionalAmount);

//     // Post-transfer balances
//     uint256 aliceAfterBalanceErc20 = simpleContract_.balanceOf(alice);
//     uint256 aliceAfterBalanceErc721 = simpleContract_.erc721BalanceOf(alice);

//     uint256 bobAfterBalanceErc20 = simpleContract_.balanceOf(bob);
//     uint256 bobAfterBalanceErc721 = simpleContract_.erc721BalanceOf(bob);

//     assertEq(aliceAfterBalanceErc20, aliceStartingBalanceErc20 - initialFractionalAmount);
//     assertEq(bobAfterBalanceErc20, bobStartingBalanceErc20 + initialFractionalAmount);

//     // Verify ERC721 balances after transfer
//     // Assuming the sender should lose 1 NFT due to the transfer causing a loss of a whole token.
//     // Sender loses an NFT
//     assertEq(aliceAfterBalanceErc721, aliceStartingBalanceErc721 - 1);
//     // No NFT gain for the receiver
//     assertEq(bobAfterBalanceErc721, bobStartingBalanceErc721);
//     // Contract gains an NFT (it's stored in the contract in this scenario).
//     // TODO - Verify this with the contract's balance.
//   }

//   //////// Moving one or more full tokens
//   function test_erc20TransferTriggering721Transfer_whole_noFractionalImpact() public {
//     // Transfers whole tokens without fractional impact correctly
//     uint256 aliceStartingBalanceErc20 = simpleContract_.balanceOf(alice);
//     uint256 aliceStartingBalanceErc721 = simpleContract_.erc721BalanceOf(alice);

//     uint256 bobStartingBalanceErc20 = simpleContract_.balanceOf(bob);
//     uint256 bobStartingBalanceErc721 = simpleContract_.erc721BalanceOf(bob);

//     // Transfer 2 whole tokens
//     uint256 erc721TokensToTransfer = 2;
//     uint256 valueToTransferERC20 = erc721TokensToTransfer * units_;

//     vm.prank(alice);
//     simpleContract_.transfer(bob, valueToTransferERC20);

//     // Post-transfer balances
//     uint256 aliceAfterBalanceErc20 = simpleContract_.balanceOf(alice);
//     uint256 aliceAfterBalanceErc721 = simpleContract_.erc721BalanceOf(alice);

//     uint256 bobAfterBalanceErc20 = simpleContract_.balanceOf(bob);
//     uint256 bobAfterBalanceErc721 = simpleContract_.erc721BalanceOf(bob);

//     // Verify ERC20 balances after transfer
//     assertEq(aliceAfterBalanceErc20, aliceStartingBalanceErc20 - valueToTransferERC20);
//     assertEq(bobAfterBalanceErc20, bobStartingBalanceErc20 + valueToTransferERC20);

//     // Verify ERC721 balances after transfer - Assuming 2 NFTs should have been transferred
//     assertEq(aliceAfterBalanceErc721, aliceStartingBalanceErc721 - erc721TokensToTransfer);
//     assertEq(bobAfterBalanceErc721, bobStartingBalanceErc721 + erc721TokensToTransfer);
//   }

//   function test_erc20TransferTriggering721Transfer_allCasesAtOnce() public {
//     // Handles the case of sending 3.2 tokens where the sender started out with 99.1 tokens and the receiver started with 0.9 tokens
//     // This test demonstrates all 3 cases in one scenario:
//     // - The sender loses a partial token, dropping it below a full token (99.1 - 3.2 = 95.9)
//     // - The receiver gains a whole new token (0.9 + 3.2 (3 whole, 0.2 fractional) = 4.1)
//     // - The sender transfers 3 whole tokens to the receiver (99.1 - 3.2 (3 whole, 0.2 fractional) = 95.9)

//     uint256 bobStartingBalanceErc20 = units_ * 9 / 10;

//     vm.prank(alice);
//     simpleContract_.transfer(bob, bobStartingBalanceErc20);

//     uint256 aliceStartingBalanceErc20 = simpleContract_.balanceOf(alice);
//     uint256 aliceStartingBalanceErc721 = simpleContract_.erc721BalanceOf(alice);
//     uint256 bobStartingBalanceErc721 = simpleContract_.erc721BalanceOf(bob);

//     assertEq(bobStartingBalanceErc721, 0);

//     // Transfer an amount that results in:
//     // - the receiver gaining a whole new token (0.9 + 0.2 + 3)
//     // - the sender losing a partial token, dropping it below a full token (99.1 - 3.2 = 95.9)
//     uint256 fractionalValueToTransferERC20 = units_ * 32 / 10;
//     vm.prank(alice);
//     simpleContract_.transfer(bob, fractionalValueToTransferERC20);

//     // post transfer
//     // ERC20
//     uint256 aliceAfterBalanceErc20 = simpleContract_.balanceOf(alice);
//     uint256 bobAfterBalanceErc20 = simpleContract_.balanceOf(bob);
//     assertEq(aliceAfterBalanceErc20, aliceStartingBalanceErc20 - fractionalValueToTransferERC20);
//     assertEq(bobAfterBalanceErc20, bobStartingBalanceErc20 + fractionalValueToTransferERC20);

//     // ERC721
//     uint256 aliceAfterBalanceErc721 = simpleContract_.erc721BalanceOf(alice);
//     uint256 bobAfterBalanceErc721 = simpleContract_.erc721BalanceOf(bob);

//     assertEq(aliceAfterBalanceErc721, aliceStartingBalanceErc721 - 4);
//     assertEq(bobAfterBalanceErc721, bobStartingBalanceErc721 + 4);
//   }
// }

// contract ERC404TransferFromTest is Test {
//   ERC404Example public simpleContract_;
//   MinimalERC404 public minimalContract_;

//   string name_ = "Example";
//   string symbol_ = "EXM";
//   uint8 decimals_ = 18;
//   uint256 maxTotalSupplyNft_ = 100;
//   uint256 units_ = 10 ** decimals_;
//   uint256 maxTotalSupplyCoin_ = maxTotalSupplyNft_ * units_;

//   address initialOwner_ = address(0x1);
//   address initialMintRecipient_ = initialOwner_;

//   function setUp() public {
//     simpleContract_ =
//       new ERC404Example(name_, symbol_, decimals_, maxTotalSupplyNft_, initialOwner_, initialMintRecipient_);
//     minimalContract_ = new MinimalERC404(name_, symbol_, decimals_, initialOwner_);
//   }

//   function test_revert_transferFrom_fromZero() public {
//     // Doesn't allow anyone to transfer from 0x0
//     vm.expectRevert(IERC404.InvalidSender.selector);
//     vm.prank(initialOwner_);
//     simpleContract_.transferFrom(address(0), initialMintRecipient_, 1);
//   }

//   function test_revert_transferFrom_toZero() public {
//     // Doesn't allow anyone to transferFrom to 0x0
//     vm.expectRevert(IERC404.InvalidRecipient.selector);
//     vm.prank(initialOwner_);
//     simpleContract_.transferFrom(initialMintRecipient_, address(0), 1);
//   }

//   function test_revert_transferFrom_ToAndFromZero() public {
//     // Doesn't allow anyone to transfer from 0x0 to 0x0
//     vm.expectRevert(IERC404.InvalidSender.selector);
//     vm.prank(initialOwner_);
//     simpleContract_.transferFrom(address(0), address(0), 1);
//   }

//   function test_mintFullSupply_20_721(address recipient) public {
//     vm.assume(recipient != address(0));

//     // Owner mints the full supply of ERC20 tokens (with the corresponding ERC721 tokens minted as well)
//     vm.prank(initialOwner_);
//     minimalContract_.mintERC20(recipient, maxTotalSupplyCoin_);

//     // Expect the total supply to be equal to the max total supply
//     assertEq(minimalContract_.totalSupply(), maxTotalSupplyCoin_);
//     assertEq(minimalContract_.erc20TotalSupply(), maxTotalSupplyCoin_);

//     // Expect the minted count to be equal to the max total supply
//     assertEq(minimalContract_.erc721TotalSupply(), maxTotalSupplyNft_);
//   }

//   // Context: Operator owns the token to be moved
//   function test_revert_transferNotOwnedByAlice() public {
//     vm.skip(true);
//     // mint all fixture
//     test_mintFullSupply_20_721(initialOwner_);

//     // Reverts when attempting to transfer a token that 'from' does not own
//     address alice = address(0xa);
//     address bob = address(0xb);

//     uint256 tokenId = 1;
//     address wrongFrom = alice;
//     address to = bob;

//     // Confirm that the target token exists, and that it has a non-0x0 owner.
//     assertNotEq(minimalContract_.ownerOf(tokenId), address(0));

//     // Confirm that the operator owns the token.
//     assertEq(minimalContract_.ownerOf(tokenId), initialOwner_);

//     // Confirm that the owner of the token is not the wrongFrom address.
//     assertNotEq(minimalContract_.ownerOf(tokenId), wrongFrom);

//     // Confirm that to address does not own the token either.
//     assertNotEq(minimalContract_.ownerOf(tokenId), to);

//     // Attempt to send 1 ERC-721.
//     vm.expectRevert(IERC404.Unauthorized.selector);
//     vm.prank(initialOwner_);
//     minimalContract_.transferFrom(wrongFrom, to, tokenId);
//   }

//   function test_transferOwnedByOperator() public {
//     vm.skip(true);
//     // mint all fixture
//     test_mintFullSupply_20_721(initialOwner_);

//     uint256 tokenId = 1;
//     address to = address(0xa);

//     // Confirm that the target token exists, and that it has a non-0x0 owner.
//     assertNotEq(minimalContract_.ownerOf(tokenId), address(0));

//     // Confirm that the operator owns the token.
//     assertEq(minimalContract_.ownerOf(tokenId), initialOwner_);

//     // Confirm that to address does not own the token either.
//     assertNotEq(minimalContract_.ownerOf(tokenId), to);

//     // Attempt to send 1 ERC-721.
//     vm.prank(initialOwner_);
//     minimalContract_.transferFrom(initialOwner_, to, tokenId);
//   }

//   // Context: Operator does not own the token to be moved
//   function test_revert_transferNotOwnedByOperator() public {
//     vm.skip(true);
//     // mint all fixture
//     test_mintFullSupply_20_721(initialOwner_);

//     address operator = address(0xa);
//     address wrongFrom = address(0xb);
//     address to = address(0xc);
//     uint256 tokenId = 1;

//     // Confirm that the target token exists, and that it has a non-0x0 owner.
//     assertNotEq(minimalContract_.ownerOf(tokenId), address(0));

//     // Confirm that the initial minter owns the token.
//     assertEq(minimalContract_.ownerOf(tokenId), initialOwner_);

//     // Confirm that the owner of the token is not the wrongFrom address.
//     assertNotEq(minimalContract_.ownerOf(tokenId), operator);

//     // Confirm that the owner of the token is not the wrongFrom address.
//     assertNotEq(minimalContract_.ownerOf(tokenId), wrongFrom);

//     // Confirm that to address does not own the token either.
//     assertNotEq(minimalContract_.ownerOf(tokenId), to);

//     // Attempt to send 1 ERC-721 as operator
//     vm.expectRevert(IERC404.Unauthorized.selector);
//     vm.prank(operator);
//     minimalContract_.transferFrom(wrongFrom, to, tokenId);
//   }

//   // TODO: Reverts when operator has not been approved to move 'from''s token
//   // TODO: Allows an approved operator to transfer a token owned by 'from'
// }

// contract ERC404TransferTest is Test {
//   ERC404Example public simpleContract_;

//   string name_ = "Example";
//   string symbol_ = "EXM";
//   uint8 decimals_ = 18;
//   uint256 maxTotalSupplyNft_ = 100;
//   uint256 units_ = 10 ** decimals_;

//   address initialOwner_ = address(0x1);
//   address initialMintRecipient_ = initialOwner_;

//   function setUp() public {
//     simpleContract_ =
//       new ERC404Example(name_, symbol_, decimals_, maxTotalSupplyNft_, initialOwner_, initialMintRecipient_);
//   }

//   function test_revert_transfer_toZero() public {
//     // Doesn't allow anyone to transfer to 0x0

//     // Attempt to send 1 ERC-721 to 0x0.
//     vm.expectRevert(IERC404.InvalidRecipient.selector);
//     vm.prank(initialOwner_);
//     simpleContract_.transfer(address(0), 1);

//     // Attempt to send 1 full token worth of ERC-20s to 0x0
//     vm.expectRevert(IERC404.InvalidRecipient.selector);
//     vm.prank(initialOwner_);
//     simpleContract_.transfer(address(0), units_);
//   }

//   // TODO(transfer) - more tests needed here, including testing that approvals work.
// }

// contract Erc404SetWhitelistTest is Test {
//   ERC404Example public simpleContract_;

//   string name_ = "Example";
//   string symbol_ = "EXM";
//   uint8 decimals_ = 18;
//   uint256 maxTotalSupplyNft_ = 100;
//   uint256 units_ = 10 ** decimals_;

//   address initialOwner_ = address(0x1);
//   address initialMintRecipient_ = initialOwner_;

//   function setUp() public {
//     simpleContract_ =
//       new ERC404Example(name_, symbol_, decimals_, maxTotalSupplyNft_, initialOwner_, initialMintRecipient_);
//   }

//   function test_setWhitelist_ownerAddAndRemove(address a) public {
//     vm.assume(a != initialMintRecipient_);
//     vm.assume(!simpleContract_.erc721TransferExempt(a));
//     assertFalse(simpleContract_.erc721TransferExempt(a));

//     // Add a random address to the whitelist
//     vm.prank(initialOwner_);
//     simpleContract_.setERC721TransferExempt(a, true);

//     assertTrue(simpleContract_.erc721TransferExempt(a));

//     // Remove the random address from the whitelist
//     vm.prank(initialOwner_);
//     simpleContract_.setERC721TransferExempt(a, false);

//     assertFalse(simpleContract_.erc721TransferExempt(a));
//   }

//   function test_revert_setWhitelist_removeAddressWithErc20Balance(address a) public {
//     vm.skip(true);
//     // An address cannot be removed from the whitelist while it has an ERC-20 balance >= 1 full token.

//     vm.assume(a != initialMintRecipient_);
//     vm.assume(a != initialOwner_);
//     vm.assume(a != address(0));
//     vm.assume(!simpleContract_.erc721TransferExempt(a));
//     assertFalse(simpleContract_.erc721TransferExempt(a));

//     // Transfer 1 full NFT worth of tokens to that address.
//     vm.prank(initialMintRecipient_);
//     simpleContract_.transfer(a, units_);

//     assertEq(simpleContract_.erc721BalanceOf(a), 1);

//     // Add a random address to the whitelist
//     vm.prank(initialOwner_);
//     simpleContract_.setERC721TransferExempt(a, true);

//     assertTrue(simpleContract_.erc721TransferExempt(a));

//     // Attempt to remove the random address from the whitelist
//     // vm.expectRevert(IERC404.CannotRemoveFromERC721TransferExempt.selector);
//     vm.prank(initialOwner_);
//     simpleContract_.setERC721TransferExempt(a, false);

//     assertTrue(simpleContract_.erc721TransferExempt(a));
//   }
// }

// contract Erc404Erc721BalanceOfTest is Test {
//   ERC404Example public simpleContract_;

//   string name_ = "Example";
//   string symbol_ = "EXM";
//   uint8 decimals_ = 18;
//   uint256 maxTotalSupplyNft_ = 100;
//   uint256 units_ = 10 ** decimals_;

//   address initialOwner_ = address(0x1);
//   address initialMintRecipient_ = initialOwner_;

//   function setUp() public {
//     simpleContract_ =
//       new ERC404Example(name_, symbol_, decimals_, maxTotalSupplyNft_, initialOwner_, initialMintRecipient_);
//   }

//   function test_0_9_balance() public {
//     // The address has 0.9 ERC-20 balance
//     // Returns the correct balance (0 ERC-721)
//     address alice = address(0xa);
//     uint256 transferAmount = units_ * 9 / 10;

//     vm.prank(initialOwner_);
//     simpleContract_.transfer(alice, transferAmount);

//     assertEq(simpleContract_.erc20BalanceOf(alice), transferAmount);
//     assertEq(simpleContract_.erc721BalanceOf(alice), 0);
//   }

//   function test_exactly1Balance() public {
//     // The address has exactly 1.0 ERC-20 balance
//     // Returns the correct balance (1 ERC-721)
//     address alice = address(0xa);
//     uint256 transferAmount = units_;

//     vm.prank(initialOwner_);
//     simpleContract_.transfer(alice, transferAmount);

//     assertEq(simpleContract_.erc20BalanceOf(alice), transferAmount);
//     assertEq(simpleContract_.erc721BalanceOf(alice), 1);
//   }

//   function test_1_1_balance() public {
//     // The address has 1.1 ERC-20 balance
//     // Returns the correct balance (1 ERC-721)
//     address alice = address(0xa);
//     uint256 transferAmount = units_ * 11 / 10;

//     vm.prank(initialOwner_);
//     simpleContract_.transfer(alice, transferAmount);

//     assertEq(simpleContract_.erc20BalanceOf(alice), transferAmount);
//     assertEq(simpleContract_.erc721BalanceOf(alice), 1);
//   }
// }

// contract Erc404Erc20BalanceOfTest is Test {
//   ERC404Example public simpleContract_;

//   string name_ = "Example";
//   string symbol_ = "EXM";
//   uint8 decimals_ = 18;
//   uint256 maxTotalSupplyNft_ = 100;
//   uint256 units_ = 10 ** decimals_;

//   address initialOwner_ = address(0x1);
//   address initialMintRecipient_ = initialOwner_;

//   function setUp() public {
//     simpleContract_ =
//       new ERC404Example(name_, symbol_, decimals_, maxTotalSupplyNft_, initialOwner_, initialMintRecipient_);
//   }

//   function test_balanceOf() public {
//     address alice = address(0xa);
//     uint256 transferAmount = units_ * 9 / 10;

//     vm.prank(initialOwner_);
//     simpleContract_.transfer(alice, transferAmount);

//     assertEq(simpleContract_.erc20BalanceOf(alice), transferAmount);

//     vm.prank(initialOwner_);
//     simpleContract_.transfer(alice, transferAmount);

//     assertEq(simpleContract_.erc20BalanceOf(alice), transferAmount * 2);
//   }
// }

// contract Erc404SetApprovalForAllTest is Test {
//   ERC404Example public simpleContract_;

//   string name_ = "Example";
//   string symbol_ = "EXM";
//   uint8 decimals_ = 18;
//   uint256 maxTotalSupplyNft_ = 100;
//   uint256 units_ = 10 ** decimals_;

//   address initialOwner_ = address(0x1);
//   address initialMintRecipient_ = initialOwner_;

//   event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

//   function setUp() public {
//     simpleContract_ =
//       new ERC404Example(name_, symbol_, decimals_, maxTotalSupplyNft_, initialOwner_, initialMintRecipient_);
//   }

//   // Granting approval to a valid address besides themselves
//   function test_approvalOperator_setApprovalForAll(address intendedOperator) public {
//     vm.assume(intendedOperator != address(0));
//     // Allows a user to set an operator who has approval for all their ERC-721 tokens
//     assertEq(simpleContract_.isApprovedForAll(initialOwner_, intendedOperator), false);

//     // Approve for all
//     // Expected Events
//     vm.expectEmit(false, false, false, false);
//     emit ApprovalForAll(initialOwner_, intendedOperator, true);
//     // Tx
//     vm.prank(initialOwner_);
//     simpleContract_.setApprovalForAll(intendedOperator, true);
//   }

//   function test_approvalOperator_removeOperatorApprovalForAll(address intendedOperator) public {
//     test_approvalOperator_setApprovalForAll(intendedOperator);
//     vm.prank(initialOwner_);
//     simpleContract_.setApprovalForAll(intendedOperator, false);

//     assertEq(simpleContract_.isApprovedForAll(initialOwner_, intendedOperator), false);
//   }

//   // Granting approval to themselves
//   function test_approvalSelf_all721() public {
//     // Allows a user to set themselves as an operator who has approval for all their ERC-721 tokens
//     assertFalse(simpleContract_.isApprovedForAll(initialOwner_, initialOwner_));
//     vm.prank(initialOwner_);
//     simpleContract_.setApprovalForAll(initialOwner_, true);
//     assertTrue(simpleContract_.isApprovedForAll(initialOwner_, initialOwner_));
//   }

//   function test_approvalSelf_removeApproval() public {
//     // Allows a user to remove their own approval for all
//     test_approvalSelf_all721();
//     vm.prank(initialOwner_);
//     simpleContract_.setApprovalForAll(initialOwner_, false);
//     assertFalse(simpleContract_.isApprovedForAll(initialOwner_, initialOwner_));
//   }

//   // Granting approval to 0x0
//   function test_reverts_approvalZero() public {
//     // Reverts if the user attempts to grant or revoke approval for all to 0x0
//     vm.expectRevert(IERC404.InvalidOperator.selector);
//     vm.prank(initialOwner_);
//     simpleContract_.setApprovalForAll(address(0), true);

//     vm.expectRevert(IERC404.InvalidOperator.selector);
//     vm.prank(initialOwner_);
//     simpleContract_.setApprovalForAll(address(0), false);
//   }
// }

// contract Erc404RetrieveOrMint721Test is Test {
//   MinimalERC404 public minimalContract_;

//   string name_ = "Example";
//   string symbol_ = "EXM";
//   uint8 decimals_ = 18;
//   uint256 units_ = 10 ** decimals_;

//   address initialOwner_ = address(0x1);

//   function setUp() public {
//     minimalContract_ = new MinimalERC404(name_, symbol_, decimals_, initialOwner_);
//   }

//   // When the contract has no tokens in the queue

//   // - Contract ERC-721 balance is 0

//   function test_balanceZero_mintFull20And721() public {
//     // Mints a new full ERC-20 token + corresponding ERC-721 token
//     assertEq(minimalContract_.balanceOf(address(minimalContract_)), 0);
//     assertEq(minimalContract_.getERC721QueueLength(), 0);
//     assertEq(minimalContract_.erc721TotalSupply(), 0);

//     vm.prank(initialOwner_);
//     minimalContract_.mintERC20(initialOwner_, units_);

//     assertEq(minimalContract_.erc721TotalSupply(), 1);
//   }

//   // - Contract ERC-721 balance is > 0
//   function test_balanceGtZero_mintFull20And721() public {
//     vm.skip(true);
//     // Mints a new full ERC-20 token + corresponding ERC-721 token
//     test_balanceZero_mintFull20And721();

//     // Transfer the factional token to the contract
//     vm.prank(initialOwner_);
//     minimalContract_.transferFrom(initialOwner_, address(minimalContract_), 1);

//     assertEq(minimalContract_.erc721BalanceOf(address(minimalContract_)), 1);

//     // Expect the contract to have 0 ERC-721 token in the queue
//     assertEq(minimalContract_.getERC721QueueLength(), 0);

//     // Expect the contract to own token 1
//     assertEq(minimalContract_.ownerOf(1), address(minimalContract_));

//     // Mint a new full ERC-20 token + corresponding ERC-721 token
//     vm.prank(initialOwner_);
//     minimalContract_.mintERC20(initialOwner_, units_);

//     assertEq(minimalContract_.erc721TotalSupply(), 2);

//     // Expect the contract to still own token 1
//     assertEq(minimalContract_.ownerOf(1), address(minimalContract_));
//     // Expect the mint recipient to have have a balance of 1 ERC-721 token        assertEq(minimalContract_.erc721BalanceOf(address(minimalContract_)), 1);
//     assertEq(minimalContract_.erc721BalanceOf(address(initialOwner_)), 1);

//     // Expect the contract to have an ERC-20 balance of 1 full token
//     assertEq(minimalContract_.erc20BalanceOf(address(minimalContract_)), units_);

//     // Expect the mint recipient to be the owner of token 2
//     assertEq(minimalContract_.ownerOf(2), address(initialOwner_));
//   }
// }

// contract Erc404SetApprovalTest is Test {
//   MinimalERC404 public minimalContract_;

//   string name_ = "Example";
//   string symbol_ = "EXM";
//   uint8 decimals_ = 18;
//   uint256 units_ = 10 ** decimals_;
//   uint256 maxTotalSupplyNft_ = 100;
//   uint256 maxTotalSupplyCoin_ = maxTotalSupplyNft_ * units_;

//   address initialOwner_ = address(0x1);

//   event ERC721Approval(address indexed owner, address indexed spender, uint256 indexed id);
//   event ERC20Approval(address owner, address spender, uint256 value);

//   function setUp() public {
//     minimalContract_ = new MinimalERC404(name_, symbol_, decimals_, initialOwner_);
//     vm.prank(initialOwner_);
//     minimalContract_.mintERC20(initialOwner_, maxTotalSupplyCoin_);
//   }

//   // Granting approval for ERC-721 tokens
//   function test_grantSpecific721Approval(address intendedOperator) public {
//     vm.skip(true);
//     vm.assume(
//       intendedOperator != address(0) && intendedOperator != address(minimalContract_)
//         && intendedOperator != initialOwner_
//     );
//     assertEq(minimalContract_.ownerOf(1), initialOwner_);
//     // Approve ERC721
//     // Expected events
//     vm.expectEmit();
//     emit ERC721Approval(initialOwner_, intendedOperator, 1);
//     // Tx
//     vm.prank(initialOwner_);
//     minimalContract_.approve(intendedOperator, 1);

//     assertEq(minimalContract_.getApproved(1), intendedOperator);

//     // Confirm that a corresponding ERC-20 approval for the ERC-721 token was not set.
//     assertEq(minimalContract_.allowance(initialOwner_, intendedOperator), 0);

//     // assertEq(minimalContract_.allowance(initialOwner_, intendedOperator), 0);

//     // uint256 minted = minimalContract_.erc721TotalSupply();
//     // uint256 allowanceToSet = minted + 1;

//     // assertGe(minimalContract_.balanceOf(initialOwner_), allowanceToSet);

//     // // Approve ERC20
//     // // Expected events
//     // vm.expectEmit();
//     // emit ERC20Approval(initialOwner_, intendedOperator, allowanceToSet);
//     // // Tx
//     // // Set an allowance. Must be greater than minted to be considered an ERC-20 allowance.
//     // vm.prank(initialOwner_);
//     // minimalContract_.approve(intendedOperator, allowanceToSet);

//     // assertEq(minimalContract_.allowance(initialOwner_, intendedOperator), allowanceToSet);
//     // assertEq(minimalContract_.getApproved(allowanceToSet), address(0));
//   }

//   function test_revokeSpecific721Approval(address intendedOperator) public {
//     vm.skip(true);
//     test_grantSpecific721Approval(intendedOperator);
//     vm.prank(initialOwner_);
//     minimalContract_.approve(address(0), 1);
//     assertEq(minimalContract_.getApproved(1), address(0));
//   }

//   // Having already granted approval for all to a valid address
//   function test_operatorGrantSpecificAfterApprovalForAll() public {
//     vm.skip(true);
//     // Allows an approved operator to grant specific approval for any ERC-721 token owned by the grantor
//     address intendedOperator = address(0xa);
//     address secondOperator = address(0xb);
//     vm.prank(initialOwner_);
//     minimalContract_.setApprovalForAll(intendedOperator, true);

//     // Confirm that the token is owned by the grantor
//     assertEq(minimalContract_.ownerOf(1), initialOwner_);
//     vm.prank(intendedOperator);
//     minimalContract_.approve(secondOperator, 1);

//     assertEq(minimalContract_.getApproved(1), secondOperator);
//   }

//   function test_grant20Approval() public {
//     vm.skip(true);
//     // Allows a user to grant an operator an ERC-20 token allowance
//     address intendedOperator = address(0xa);
//     assertEq(minimalContract_.allowance(initialOwner_, intendedOperator), 0);

//     uint256 minted = minimalContract_.erc721TotalSupply();
//     uint256 allowanceToSet = minted + 1;

//     vm.expectEmit(false, false, false, true);
//     emit ERC20Approval(initialOwner_, intendedOperator, allowanceToSet);

//     vm.prank(initialOwner_);
//     minimalContract_.approve(intendedOperator, minted + 1);

//     assertEq(minimalContract_.allowance(initialOwner_, intendedOperator), allowanceToSet);

//     // Confirm that a corresponding ERC-721 approval for the allowanceToSet value was not set.
//     assertEq(minimalContract_.getApproved(allowanceToSet), address(0));
//   }

//   function test_reverts_grantAddressZeroAllowance() public {
//     // Reverts if a user attempts to grant 0x0 an ERC-20 token allowance
//     uint256 minted = minimalContract_.erc721TotalSupply();
//     uint256 allowanceToSet = minted + 1;

//     vm.expectRevert(IERC404.InvalidSpender.selector);
//     vm.prank(initialOwner_);
//     minimalContract_.approve(address(0), allowanceToSet);
//   }
// }

// contract Erc404PermitTest is Test {
//   MinimalERC404 public minimalContract_;
//   SigUtils internal sigUtils;

//   string name_ = "Example";
//   string symbol_ = "EXM";
//   uint8 decimals_ = 18;
//   uint256 units_ = 10 ** decimals_;
//   uint256 maxTotalSupplyNft_ = 100;
//   uint256 maxTotalSupplyCoin_ = maxTotalSupplyNft_ * units_;

//   uint256 ownerPrivateKey = 0xA11CE;
//   address initialOwner_ = vm.addr(ownerPrivateKey);

//   // event ERC721Transfer(address indexed from, address indexed to, uint256 indexed id);
//   event ERC20Approval(address from, address to, uint256 value);

//   function setUp() public {
//     minimalContract_ = new MinimalERC404(name_, symbol_, decimals_, initialOwner_);
//     vm.prank(initialOwner_);
//     minimalContract_.mintERC20(initialOwner_, maxTotalSupplyCoin_);
//     sigUtils = new SigUtils(minimalContract_.DOMAIN_SEPARATOR());
//   }

//   function test_revert_permit721() public {
//     vm.skip(true);
//     address spender = vm.addr(0xB0B);
//     assertEq(minimalContract_.ownerOf(1), initialOwner_);

//     SigUtils.Permit memory permit =
//       SigUtils.Permit({owner: initialOwner_, spender: spender, value: 1, nonce: 0, deadline: 1 days});
//     bytes32 digest = sigUtils.getTypedDataHash(permit);

//     (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

//     vm.expectRevert(IERC404.InvalidApproval.selector);
//     vm.prank(initialOwner_);
//     minimalContract_.permit(initialOwner_, spender, 1, 1 days, v, r, s);
//   }

//   function test_revert_permit20AddressZero() public {
//     vm.skip(true);
//     // Should revert when 0x0 spender
//     address spender = address(0);
//     assertEq(minimalContract_.ownerOf(1), initialOwner_);

//     SigUtils.Permit memory permit =
//       SigUtils.Permit({owner: initialOwner_, spender: spender, value: 1, nonce: 0, deadline: 1 days});
//     bytes32 digest = sigUtils.getTypedDataHash(permit);

//     (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

//     vm.expectRevert();
//     vm.prank(initialOwner_);
//     minimalContract_.permit(initialOwner_, spender, 1, 1 days, v, r, s);
//   }

//   function test_revert_deadlineExpired() public {
//     vm.skip(true);
//     address spender = vm.addr(0xB0B);
//     assertEq(minimalContract_.ownerOf(1), initialOwner_);
//     assertGt(minimalContract_.balanceOf(initialOwner_), units_);

//     SigUtils.Permit memory permit =
//       SigUtils.Permit({owner: initialOwner_, spender: spender, value: units_, nonce: 0, deadline: 0});
//     bytes32 digest = sigUtils.getTypedDataHash(permit);

//     (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

//     vm.expectRevert(IERC404.PermitDeadlineExpired.selector);
//     vm.prank(initialOwner_);
//     minimalContract_.permit(initialOwner_, spender, units_, 0 days, v, r, s);
//   }

//   function test_setApprovalFromPermit() public {
//     vm.skip(true);
//     address spender = vm.addr(0xB0B);
//     assertEq(minimalContract_.ownerOf(1), initialOwner_);
//     assertGt(minimalContract_.balanceOf(initialOwner_), units_);

//     SigUtils.Permit memory permit =
//       SigUtils.Permit({owner: initialOwner_, spender: spender, value: units_, nonce: 0, deadline: 1 days});
//     bytes32 digest = sigUtils.getTypedDataHash(permit);

//     (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

//     vm.expectEmit();
//     emit ERC20Approval(initialOwner_, spender, units_);

//     vm.prank(initialOwner_);
//     minimalContract_.permit(initialOwner_, spender, units_, 1 days, v, r, s);
//   }
// }

// contract Erc404E2ETest is Test {
//   MinimalERC404 public minimalContract_;

//   string name_ = "Example";
//   string symbol_ = "EXM";
//   uint8 decimals_ = 18;
//   uint256 units_ = 10 ** decimals_;
//   uint256 maxTotalSupplyNft_ = 100;
//   uint256 maxTotalSupplyCoin_ = maxTotalSupplyNft_ * units_;

//   address initialOwner_ = address(0x1);

//   // event ERC721Transfer(address indexed from, address indexed to, uint256 indexed id);
//   // event ERC20Transfer(address indexed from, address indexed to, uint256 amount);

//   function setUp() public {
//     minimalContract_ = new MinimalERC404(name_, symbol_, decimals_, initialOwner_);
//   }

//   function test_mintFull_transfer20_transfer721_bankRetrieve_setRemoveWhitelist() public {
//     vm.skip(true);
//     address alice = address(0xa);
//     vm.prank(initialOwner_);
//     minimalContract_.mintERC20(alice, maxTotalSupplyCoin_);

//     assertEq(minimalContract_.erc721TotalSupply(), maxTotalSupplyNft_);

//     assertEq(minimalContract_.totalSupply(), maxTotalSupplyCoin_);

//     vm.prank(initialOwner_);
//     minimalContract_.mintERC20(alice, 1);

//     assertEq(minimalContract_.erc20BalanceOf(alice), maxTotalSupplyCoin_ + 1);

//     assertEq(minimalContract_.erc721BalanceOf(alice), maxTotalSupplyNft_);
//     for (uint256 i = 1; i <= 100; i++) {
//       assertEq(minimalContract_.ownerOf(i), alice);
//     }

//     // transfer 5 as erc20
//     address bob = address(0xb);
//     vm.prank(alice);
//     minimalContract_.transfer(bob, 5 * units_);

//     assertEq(minimalContract_.erc20BalanceOf(alice), maxTotalSupplyCoin_ - (5 * units_) + 1);

//     assertEq(minimalContract_.erc721BalanceOf(alice), maxTotalSupplyNft_ - 5);
//     for (uint256 i = 1; i <= 95; i++) {
//       assertEq(minimalContract_.ownerOf(i), alice);
//     }
//     // Expect the recipient to have 5 * units ERC-20 tokens and 5 ERC-721 tokens
//     assertEq(minimalContract_.erc20BalanceOf(bob), 5 * units_);
//     assertEq(minimalContract_.erc721BalanceOf(bob), 5);
//     // Expect the recipient to be the owner of token ids 96-100.
//     for (uint256 i = 96; i <= 100; i++) {
//       assertEq(minimalContract_.ownerOf(i), bob);
//     }

//     // Transfer a fraction of a token to another address to break apart a full NFT.
//     uint256 fractionalValue1 = units_ * 1 / 10;
//     address charlie = address(0xc);

//     vm.prank(bob);
//     minimalContract_.transfer(charlie, fractionalValue1);

//     assertEq(minimalContract_.erc20BalanceOf(charlie), fractionalValue1);
//     assertEq(minimalContract_.erc721BalanceOf(charlie), 0);

//     // Expect the sender to have 4.9 * units ERC-20 tokens and 4 ERC-721 tokens
//     assertEq(minimalContract_.erc20BalanceOf(bob), 5 * units_ - fractionalValue1);
//     assertEq(minimalContract_.erc721BalanceOf(bob), 4);

//     // Expect that the sender holds token ids 97-99 (96 popped off)
//     for (uint256 i = 97; i <= 99; i++) {
//       assertEq(minimalContract_.ownerOf(i), bob);
//     }

//     // Expect the contract to have 0 ERC-721 token
//     assertEq(minimalContract_.erc721BalanceOf(address(minimalContract_)), 0);
//     // Expect the contract to hold token id 96
//     vm.expectRevert(IERC404.NotFound.selector);
//     minimalContract_.ownerOf(96);

//     // The sender has 4.9 tokens now. Transfer 0.9 tokens to a different address, leaving 4 tokens. This should not break apart any new tokens. The contract hsould still hold 1, the sender should hold 4 and 4 NFTs, and the new receiver should hold 0.9 and no NFTs
//     uint256 fractionalValue2 = units_ * 9 / 10;
//     address david = address(0xd);

//     vm.prank(bob);
//     minimalContract_.transfer(david, fractionalValue2);

//     // Expect the sender to have 4 * units ERC-20 tokens and 4 ERC-721 tokens
//     assertEq(minimalContract_.erc20BalanceOf(bob), 4 * units_);
//     assertEq(minimalContract_.erc721BalanceOf(bob), 4);

//     assertEq(minimalContract_.erc20BalanceOf(david), fractionalValue2);
//     assertEq(minimalContract_.erc721BalanceOf(david), 0);

//     // Break apart another full token so the contract holds 2 (to test the FIFO queue)
//     // Transfer 0.1 tokens to the contract from the same sender, so he now has 3.9 tokens and 3 NFTs, and the contract has 2 NFTs.
//     address emily = address(0xe);
//     vm.prank(bob);
//     minimalContract_.transfer(emily, fractionalValue1);

//     // Expect the sender to have 3/9 * units ERC-20 tokens and 3 ERC-721 tokens
//     assertEq(minimalContract_.erc20BalanceOf(bob), 4 * units_ - fractionalValue1);
//     assertEq(minimalContract_.erc721BalanceOf(bob), 3);

//     assertEq(minimalContract_.erc20BalanceOf(emily), fractionalValue1);
//     assertEq(minimalContract_.erc721BalanceOf(emily), 0);

//     // Expect the recipient to be the owner of token ids 96-100.
//     for (uint256 i = 98; i <= 100; i++) {
//       assertEq(minimalContract_.ownerOf(i), bob);
//     }
//     // Expect the contract to have 0 ERC-721 token
//     assertEq(minimalContract_.erc721BalanceOf(address(minimalContract_)), 0);
//     // Expect the contract to hold token id 96, 97
//     vm.expectRevert(IERC404.NotFound.selector);
//     minimalContract_.ownerOf(96);
//     vm.expectRevert(IERC404.NotFound.selector);
//     minimalContract_.ownerOf(97);

//     address foobar = address(0xf);

//     // Transfer two full tokens to a new address, leaving the sender with 1.9 tokens and 1 NFT, the new recipient with 2 tokens and 2 NFTs, and the contract with 0 tokens and 2 NFTs.
//     vm.prank(bob);
//     minimalContract_.transfer(foobar, 2 * units_);

//     // Expect the sender to have
//     assertEq(minimalContract_.erc20BalanceOf(bob), 2 * units_ - fractionalValue1);
//     assertEq(minimalContract_.erc721BalanceOf(bob), 1);

//     assertEq(minimalContract_.erc20BalanceOf(foobar), 2 * units_);
//     assertEq(minimalContract_.erc721BalanceOf(foobar), 2);

//     assertEq(minimalContract_.ownerOf(100), bob);
//     // Expect the contract to hold token id 96, 97
//     vm.expectRevert(IERC404.NotFound.selector);
//     minimalContract_.ownerOf(96);
//     vm.expectRevert(IERC404.NotFound.selector);
//     minimalContract_.ownerOf(97);

//     assertEq(minimalContract_.erc20BalanceOf(emily), fractionalValue1);
//     assertEq(minimalContract_.erc721BalanceOf(emily), 0);

//     vm.prank(bob);
//     minimalContract_.transfer(emily, fractionalValue2);

//     assertEq(minimalContract_.erc20BalanceOf(bob), 1 * units_);
//     assertEq(minimalContract_.erc721BalanceOf(bob), 1);

//     assertEq(minimalContract_.erc20BalanceOf(emily), 1 * units_);
//     assertEq(minimalContract_.erc721BalanceOf(emily), 1);

//     assertEq(minimalContract_.ownerOf(96), emily);
//     assertEq(minimalContract_.ownerOf(100), bob);
//     // Expect the zero address to still hold token id 97
//     vm.expectRevert(IERC404.NotFound.selector);
//     minimalContract_.ownerOf(97);
//   }
// }

contract SigUtils {
  bytes32 internal DOMAIN_SEPARATOR;

  constructor(bytes32 _DOMAIN_SEPARATOR) {
    DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
  }

  // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
  bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

  struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
  }

  // computes the hash of a permit
  function getStructHash(Permit memory _permit) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(PERMIT_TYPEHASH, _permit.owner, _permit.spender, _permit.value, _permit.nonce, _permit.deadline)
    );
  }

  // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
  function getTypedDataHash(Permit memory _permit) public view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_permit)));
  }
}
