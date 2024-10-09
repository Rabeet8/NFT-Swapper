// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTSwapper is ReentrancyGuard {
    // Struct to represent an order created by the NFT owner
    struct Order {
        address owner; // Address of the order creator
        address nftAddress; // Contract address of the NFT listed
        uint256 nftId; // Token ID of the NFT listed
        bool isActive; // Status of the order (active or not)
    }

    // Struct to represent an offer made on an order
    struct Offer {
        uint256 offerId;
        address proposer; // Address of the offer maker
        address[] nftOffered; // Contract addresses of the NFTs offered
        uint256[] offeredIds; // Token IDs of the offered NFTs
    }

    // Mappings for orders and offers
    mapping(uint256 => Order) public orders;
    mapping(uint256 => Offer) public offers;
    mapping(uint256 => uint256) public orderOfferCount;

    // Global counters
    uint256 public orderCounter;

    // Events
    event OrderCreated(
        uint256 indexed orderId,
        address indexed owner,
        address nftAddress,
        uint256 nftId
    );
    event OfferMade(
        uint256 indexed orderId,
        uint256 indexed offerId,
        address indexed proposer,
        address[] nftOffered,
        uint256[] offeredIds
    );
    event OfferAccepted(
        uint256 indexed orderId,
        uint256 indexed offerId,
        address indexed owner
    );
    event OrderCanceled(uint256 indexed orderId, address indexed owner);

    // Modifier to check order ownership
    modifier onlyOrderOwner(uint256 _orderId) {
        require(orders[_orderId].owner == msg.sender, "Not the order owner");
        _;
    }

    // Function to create an order
    function createOrder(
        address _nftAddress,
        uint256 _nftId
    ) external nonReentrant {
        // Transfer NFT from the owner to the contract for listing
        IERC721(_nftAddress).transferFrom(msg.sender, address(this), _nftId);

        // Increment the order counter and create a new order
        orderCounter++;
        orders[orderCounter] = Order({
            owner: msg.sender,
            nftAddress: _nftAddress,
            nftId: _nftId,
            isActive: true
        });

        emit OrderCreated(orderCounter, msg.sender, _nftAddress, _nftId);
    }

    // Function to make an offer on an order with multiple NFTs (each NFT can have different contract addresses)
    // Function to make an offer on an order with multiple NFTs (each NFT can have different contract addresses)
    function makeOffer(
        uint256 _orderId,
        address[] calldata _nftOffered,
        uint256[] calldata _offeredIds
    ) external nonReentrant returns (uint256) {
        // Cache the order in memory to avoid repeated storage access
        Order storage order = orders[_orderId];
        require(order.isActive, "Order is not active");

        // Ensure the length of NFT addresses and IDs are the same and non-zero
        uint256 nftCount = _nftOffered.length;
        require(
            nftCount > 0 && nftCount == _offeredIds.length,
            "Invalid offer data"
        );

        // Ensure the contract is approved for transferring NFTs
        for (uint256 i = 0; i < nftCount; ) {
            IERC721 nftContract = IERC721(_nftOffered[i]);
            require(
                nftContract.isApprovedForAll(msg.sender, address(this)) ||
                    nftContract.getApproved(_offeredIds[i]) == address(this),
                "Contract not approved for NFT"
            );
            unchecked {
                i++; // Using unchecked block to avoid gas overhead of safe increment
            }
        }

        // Cache the order's offer count to avoid multiple storage reads
        uint256 currentOfferCount = ++orderOfferCount[_orderId]; // Pre-increment saves gas

        // Store the offer using minimal writes
        offers[currentOfferCount] = Offer({
            offerId: currentOfferCount,
            proposer: msg.sender,
            nftOffered: _nftOffered,
            offeredIds: _offeredIds
        });

        // Emit the OfferMade event
        emit OfferMade(
            _orderId,
            currentOfferCount,
            msg.sender,
            _nftOffered,
            _offeredIds
        );

        return currentOfferCount;
    }

    // Function to accept an offer and perform the NFT transfer swap securely
    function acceptOffer(
        uint256 _orderId,
        uint256 _offerId
    ) external nonReentrant onlyOrderOwner(_orderId) {
        Offer storage offer = offers[_offerId];
        require(orders[_orderId].isActive, "Order is not active");

        // Ensure only the order owner (creator of the NFT listing) can accept the offer
        Order storage order = orders[_orderId];
        require(
            order.owner == msg.sender,
            "Only the owner can accept the offer"
        );

        // Transfer the offered NFTs from proposer (offer maker) to the order owner
        for (uint256 i = 0; i < offer.offeredIds.length; i++) {
            require(
                IERC721(offer.nftOffered[i]).ownerOf(offer.offeredIds[i]) ==
                    offer.proposer,
                "Proposer does not own the offered NFT"
            );
            IERC721(offer.nftOffered[i]).safeTransferFrom(
                offer.proposer,
                order.owner,
                offer.offeredIds[i]
            );
        }

        // Transfer the NFT listed in the order from the contract to the offer proposer
        require(
            IERC721(order.nftAddress).ownerOf(order.nftId) == address(this),
            "Order NFT not in contract"
        );
        IERC721(order.nftAddress).safeTransferFrom(
            address(this),
            offer.proposer,
            order.nftId
        );

        // Mark the order and offer as inactive
        order.isActive = false;

        // Emit event after successful acceptance
        emit OfferAccepted(_orderId, _offerId, msg.sender);
    }

    // Function to cancel an order (only by owner)
    function cancelOrder(
        uint256 _orderId
    ) external nonReentrant onlyOrderOwner(_orderId) {
        Order storage order = orders[_orderId];
        require(order.isActive, "Order is not active");

        // Return the listed NFT to the owner
        IERC721(order.nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            order.nftId
        );

        order.isActive = false; // Mark the order as inactive
        emit OrderCanceled(_orderId, msg.sender);
    }

    // Fallback to handle accidental ETH transfers
    receive() external payable {
        revert("Direct payments not accepted");
    }

    function getOrder() external view returns (uint256) {
        return orderCounter;
    }

    function getOrderDetails(uint256 id) external view returns (Order memory) {
        return orders[id];
    }

    function getOffers(
        uint256 _orderId
    ) external view returns (Offer[] memory) {
        // Retrieve the total number of offers for the order
        uint256 totalOffers = orderOfferCount[_orderId];

        // Allocate memory for the return array of Offer structs
        Offer[] memory offersArray = new Offer[](totalOffers);

        // Populate the array with all offers for the given order
        for (uint256 i = 0; i < totalOffers; i++) {
            offersArray[i] = offers[i + 1]; // Copy the offer struct directly, adjusting for the 1-based index
        }

        return offersArray; // Return the array of Offer structs
    }
}
