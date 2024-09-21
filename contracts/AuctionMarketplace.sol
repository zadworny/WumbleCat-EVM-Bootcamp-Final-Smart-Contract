// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract AuctionMarketplace {
    
    // Struct representing an auction item
    struct AuctionItem {
        uint256 itemId;               // Unique ID for the item
        address payable owner;        // Owner of the item
        string name;                  // Name of the item
        string description;           // Description of the item
        uint256 price;                // Starting price of the item
        address highestBidder;        // Address of the highest bidder
        uint256 highestBidPrice;      // Highest bid amount
        uint256 expiryDate;           // Expiration date of the auction
        bool isSold;                  // Whether the item is sold
    }

    // State variables
    mapping(uint256 => AuctionItem) public items; // Mapping of item IDs to Auction Items
    mapping(uint256 => address) public itemOwners; // Mapping of item IDs to owner addresses
    uint256 public itemCount;  // Counter to generate unique item IDs

    // Events
    event ItemPosted(uint256 indexed itemId, address indexed owner, uint256 price);
    event NewHighestBid(uint256 indexed itemId, address indexed bidder, uint256 bidAmount);
    event AuctionFinalized(uint256 indexed itemId, address indexed newOwner, uint256 finalPrice);

    // Function to post a new item for auction
    function postItem(
        string memory _name, 
        string memory _description, 
        uint256 _price, 
        uint256 _expiryDate
    ) public {
        itemCount++; // Increment the item counter to generate a new itemId

        // Create a new AuctionItem and assign the owner to the caller (msg.sender)
        items[itemCount] = AuctionItem({
            itemId: itemCount,
            owner: payable(msg.sender),
            name: _name,
            description: _description,
            price: _price,
            highestBidder: address(0),
            highestBidPrice: _price,
            expiryDate: _expiryDate,
            isSold: false
        });

        // Record the ownership
        itemOwners[itemCount] = msg.sender;

        // Emit event for item posted
        emit ItemPosted(itemCount, msg.sender, _price);
    }

    // Function to place a bid on an auction item
    function placeBid(uint256 _itemId) public payable {
        AuctionItem storage item = items[_itemId];
        
        // Ensure the auction is still active and the bid is higher than the current highest bid
        require(block.timestamp < item.expiryDate, "Auction has expired");
        require(msg.value > item.highestBidPrice, "Bid must be higher than the current bid");
        require(!item.isSold, "Item has already been sold");

        // Refund the previous highest bidder
        if (item.highestBidder != address(0)) {
            payable(item.highestBidder).transfer(item.highestBidPrice);
        }

        // Update highest bid and bidder
        item.highestBidder = msg.sender;
        item.highestBidPrice = msg.value;

        // Emit event for the new highest bid
        emit NewHighestBid(_itemId, msg.sender, msg.value);
    }

    // Function to finalize an auction and transfer ownership
    function finalizeAuction(uint256 _itemId) public {
        AuctionItem storage item = items[_itemId];
        
        // Ensure the auction has expired and item has not been sold
        require(block.timestamp >= item.expiryDate, "Auction has not expired yet");
        require(!item.isSold, "Auction is already finalized");
        require(item.highestBidder != address(0), "No bids have been placed");

        // Mark the item as sold
        item.isSold = true;

        // Transfer the funds to the owner
        item.owner.transfer(item.highestBidPrice);

        // Transfer ownership to the highest bidder
        itemOwners[_itemId] = item.highestBidder;
        item.owner = payable(item.highestBidder);

        // Emit event for auction finalized
        emit AuctionFinalized(_itemId, item.highestBidder, item.highestBidPrice);
    }

    // Function to get the owner of an item
    function getItemOwner(uint256 _itemId) public view returns (address) {
        return itemOwners[_itemId];
    }

    // Function to check if an address is the owner of an item
    function isOwner(address _address, uint256 _itemId) public view returns (bool) {
        return itemOwners[_itemId] == _address;
    }
}
