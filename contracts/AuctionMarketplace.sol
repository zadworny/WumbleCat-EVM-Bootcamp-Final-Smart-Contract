// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol"; // ETH/USD

contract AuctionMarketplace is AutomationCompatibleInterface {
    
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
        string imageUrl;              // IPFS - New field for IPFS image URL
    }

    mapping(uint256 => AuctionItem) public items; // Mapping of item IDs to Auction Items
    uint256 public itemCount;

    AggregatorV3Interface internal priceFeed; // ETH/USD

    event ItemPosted(uint256 indexed itemId, address indexed owner, uint256 price);
    event NewHighestBid(uint256 indexed itemId, address indexed bidder, uint256 bidAmount);
    event AuctionFinalized(uint256 indexed itemId, address indexed newOwner, uint256 finalPrice);
    event ETHUSDPriceFetched(uint256 ethUsdPrice); // ETH/USD

    // ETH/USD
    constructor(address _priceFeedAddress) {
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    // Function to post a new item for auction
    function postItem(
        string memory _name, 
        string memory _description, 
        uint256 _price, 
        uint256 _expiryDate,
        string memory _imageUrl // IPFS
    ) public {
        itemCount++; // Increment the item counter to generate a new itemId
        items[itemCount] = AuctionItem({
            itemId: itemCount,
            owner: payable(msg.sender),
            name: _name,
            description: _description,
            price: _price,
            highestBidder: address(0),
            highestBidPrice: _price,
            expiryDate: _expiryDate,
            isSold: false,
            imageUrl: _imageUrl // IPFS
        });
        emit ItemPosted(itemCount, msg.sender, _price);
    }

    // Function to place a bid on an auction item
    function placeBid(uint256 _itemId) public payable {
        AuctionItem storage item = items[_itemId];
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

        emit NewHighestBid(_itemId, msg.sender, msg.value);
    }

    // Function that Chainlink Keepers will call to check if an auction needs finalizing
    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        for (uint256 i = 1; i <= itemCount; i++) {
            if (block.timestamp >= items[i].expiryDate && !items[i].isSold) {
                return (true, abi.encode(i)); // Perform upkeep on item i
            }
        }
        return (false, "");
    }

    // Function that Chainlink Keepers will call to perform the upkeep (finalize the auction)
    function performUpkeep(bytes calldata performData) external override {
        uint256 itemId = abi.decode(performData, (uint256));
        finalizeAuction(itemId);  // Call the existing finalizeAuction function
    }

    // Function to finalize an auction and transfer ownership
    function finalizeAuction(uint256 _itemId) public {
        AuctionItem storage item = items[_itemId];
        require(block.timestamp >= item.expiryDate, "Auction has not expired yet");
        require(!item.isSold, "Auction is already finalized");
        require(item.highestBidder != address(0), "No bids have been placed");

        item.isSold = true;
        item.owner.transfer(item.highestBidPrice);  // Transfer funds to the owner
        item.owner = payable(item.highestBidder);   // Transfer ownership to the highest bidder

        emit AuctionFinalized(_itemId, item.highestBidder, item.highestBidPrice);
    }

    // ETH/USD
    function getLatestETHUSDPrice() public view returns (int256 price) {
        (
            , 
            int256 answer,
            ,
            ,
            
        ) = priceFeed.latestRoundData();
        require(answer > 0, "Invalid price data");
    
        return answer; // Price with 8 decimals (e.g., 2500.00 is returned as 250000000)
    }
}
