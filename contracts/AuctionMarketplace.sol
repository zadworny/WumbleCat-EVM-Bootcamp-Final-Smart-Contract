// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol"; // ETH/USD
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AuctionMarketplace is AutomationCompatibleInterface, ReentrancyGuard {
    
    // Struct representing an auction item
    struct AuctionItem {
        uint256 itemId;               // Unique ID for the item
        address payable owner;        // Current owner of the item
        //address payable creator;      // Creator of the item
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
    event AuctionExtended(uint256 indexed itemId, uint256 newExpiryDate);
    event ETHUSDPriceFetched(uint256 ethUsdPrice);
    event FinalizeAuctionAttempt(uint256 indexed itemId, uint256 currentTime, uint256 expiryDate, bool isSold, address highestBidder);
    //event AuctionReturnedToCreator(uint256 indexed itemId);

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
        require(_expiryDate > block.timestamp, "Expiry date must be in the future");
        itemCount++; // Increment the item counter to generate a new itemId
        items[itemCount] = AuctionItem({
            itemId: itemCount,
            owner: payable(msg.sender),
            //creator: payable(msg.sender), // Set creator as msg.sender
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
            (bool refundSuccess, ) = item.highestBidder.call{value: item.highestBidPrice}("");
            require(refundSuccess, "Refund to previous bidder failed");
        }

        // Update highest bid and bidder
        item.highestBidder = msg.sender;
        item.highestBidPrice = msg.value;

        emit NewHighestBid(_itemId, msg.sender, msg.value);
    }

    // Function that Chainlink Keepers will call to check if an auction needs finalizing
    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory performData) {
        for (uint256 i = 1; i <= itemCount; i++) {
            AuctionItem storage item = items[i];
            if (block.timestamp >= item.expiryDate && !item.isSold) {
                return (true, abi.encode(i));
            }
        }
        return (false, "");
    }

    // Function that Chainlink Keepers will call to perform the upkeep (finalize the auction)
    function performUpkeep(bytes calldata performData) external override {
        uint256 itemId = abi.decode(performData, (uint256));
        _finalizeAuction(itemId);
    }

    // Internal function to finalize an auction and transfer ownership
    function _finalizeAuction(uint256 _itemId) internal nonReentrant {
        AuctionItem storage item = items[_itemId];
        emit FinalizeAuctionAttempt(_itemId, block.timestamp, item.expiryDate, item.isSold, item.highestBidder);
        
        require(block.timestamp >= item.expiryDate, "Auction has not expired yet");
        require(!item.isSold, "Auction is already finalized");

        item.isSold = true;

        if(item.highestBidder != address(0)) {
            (bool success, ) = item.owner.call{value: item.highestBidPrice}("");
            require(success, "Transfer to owner failed");
            item.owner = payable(item.highestBidder);
            emit AuctionFinalized(_itemId, item.highestBidder, item.highestBidPrice);
        } else {
            // No bids were placed; ownership remains with the creator
            //emit AuctionReturnedToCreator(_itemId);
        }
    }

    // External function to allow the auction creator to manually finalize the auction
    function finalizeAuctionManual(uint256 _itemId) external nonReentrant {
        AuctionItem storage item = items[_itemId];
        //require(msg.sender == item.creator, "Only the creator can finalize the auction");
        require(msg.sender == item.owner, "Only the creator can finalize the auction");
        _finalizeAuction(_itemId);
    }

    // Function to extend the auction's expiry date
    function extendAuction(uint256 _itemId, uint256 _newExpiryDate) public {
        AuctionItem storage item = items[_itemId];
        //require(msg.sender == item.creator, "Only the creator can extend the auction");
        require(msg.sender == item.owner, "Only the creator can extend the auction");
        require(block.timestamp < item.expiryDate, "Auction has already expired");
        require(!item.isSold, "Auction has already been finalized");
        require(_newExpiryDate > block.timestamp, "New expiry date must be in the future");
        require(_newExpiryDate > item.expiryDate, "New expiry date must be after current expiry date");

        // Update the expiry date
        item.expiryDate = _newExpiryDate;

        emit AuctionExtended(_itemId, _newExpiryDate);
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
