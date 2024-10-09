// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {NFTSwapper} from "../src/NFTSwapper.sol";
import {MockERC721} from "../src/mocks/MockERC721.sol";
//src/mocks/MockERC721.sol

contract NFTSwapperTest is Test {
    NFTSwapper public nftSwapper;
    MockERC721 public nft1;
    MockERC721 public nft2;

    address owner = address(0x123);
    address proposer = address(0x456);

    function setUp() public {
        // Deploy the swapper contract and the mock ERC721 tokens
        nftSwapper = new NFTSwapper();
        nft1 = new MockERC721("RABEET", "RAB");
        nft2 = new MockERC721("RABEET12", "RAB12");

        // Mint NFTs to owner and proposer
        nft1.mint(owner, 1);
        nft2.mint(proposer, 2);

        // Label addresses for easier readability in logs
        vm.label(owner, "Owner");
        vm.label(proposer, "Proposer");
    }

    function testCreateOrder() public {
        vm.startPrank(owner);

        // Approve the NFT for transfer to the swapper contract
        nft1.approve(address(nftSwapper), 1);

        // Create an order on the swapper contract
        nftSwapper.createOrder(address(nft1), 1);

        // Retrieve the order details from the contract
        NFTSwapper.Order memory order = nftSwapper.getOrderDetails(1);

        // Validate that the order was created successfully
        console.log(owner, "owner");
        assertEq(order.owner, owner);
        assertEq(order.nftAddress, address(nft1));
        console.log(order.nftId, "NFT ID");
        assertEq(order.nftId, 1);
        assertTrue(order.isActive);

        vm.stopPrank();
    }

    function testMakeOffer() public {
        // Setup: Create an order
        vm.startPrank(owner);
        nft1.approve(address(nftSwapper), 1);
        nftSwapper.createOrder(address(nft1), 1);
        vm.stopPrank();

        // Test: Make an offer
        vm.startPrank(proposer);
        nft2.setApprovalForAll(address(nftSwapper), true);

        address[] memory nftOffered = new address[](1);
        nftOffered[0] = address(nft2);
        uint256[] memory offeredIds = new uint256[](1);
        offeredIds[0] = 2;
        console.log("make offer created se pehle");

        uint256 offerId = nftSwapper.makeOffer(1, nftOffered, offeredIds);
        vm.stopPrank();
        console.log("make offer created");
        // Verify the offer was created correctly
        NFTSwapper.Offer[] memory offers = nftSwapper.getOffers(1);
        console.log("get offers");

        require(offers.length > 0, "No offers found");
        NFTSwapper.Offer memory offer = offers[0];

        assertEq(offer.proposer, proposer);
        assertEq(offer.nftOffered[0], address(nft2));
        assertEq(offer.offeredIds[0], 2);
    }

     function testAcceptOffer() public {
        // Setup: Create an order and make an offer
        vm.startPrank(owner);
        nft1.approve(address(nftSwapper), 1);
        nftSwapper.createOrder(address(nft1), 1);
        vm.stopPrank();

        vm.startPrank(proposer);
        nft2.setApprovalForAll(address(nftSwapper), true);
        address[] memory nftOffered = new address[](1);
        nftOffered[0] = address(nft2);
        uint256[] memory offeredIds = new uint256[](1);
        offeredIds[0] = 2;
        uint256 offerId = nftSwapper.makeOffer(1, nftOffered, offeredIds);
        console.log(offerId, "offerId");
        vm.stopPrank();

        // Test: Accept the offer
        vm.prank(owner);
        nftSwapper.acceptOffer(1, offerId);

        // Verify the NFTs have been swapped
        assertEq(nft1.ownerOf(1), proposer);
        assertEq(nft2.ownerOf(2), owner);

        // Verify the order is no longer active
        NFTSwapper.Order memory order = nftSwapper.getOrderDetails(1);
        assertFalse(order.isActive);
    }

    function testCancelOrder() public {
        vm.startPrank(owner);

        // Approve and create an order
        nft1.approve(address(nftSwapper), 1);
        nftSwapper.createOrder(address(nft1), 1);

        // Cancel the order
        nftSwapper.cancelOrder(1);

        // Verify that the order is no longer active
        NFTSwapper.Order memory orderDetails = nftSwapper.getOrderDetails(1);
        assertFalse(orderDetails.isActive); // Access the isActive field from the Order struct

        // Verify the NFT has been returned to the owner
        assertEq(nft1.ownerOf(1), owner);

        vm.stopPrank();
    }
}
