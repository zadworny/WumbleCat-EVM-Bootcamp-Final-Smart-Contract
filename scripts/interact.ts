import { ethers } from "hardhat";

async function main() {
  const contractAddress = "YOUR_DEPLOYED_CONTRACT_ADDRESS";  // Replace with your deployed contract address
  const AuctionMarketplace = await ethers.getContractAt("AuctionMarketplace", contractAddress);

  // Post an item
  const postTx = await AuctionMarketplace.postItem(
    "Laptop", 
    "A powerful gaming laptop", 
    ethers.utils.parseEther("1"),  // 1 ETH as starting price
    Math.floor(Date.now() / 1000) + 3600 // Expiry in one hour
  );
  await postTx.wait();
  console.log("Item posted!");

  // Place a bid on itemId 1
  const bidTx = await AuctionMarketplace.placeBid(1, {
    value: ethers.utils.parseEther("1.5"),  // Bid 1.5 ETH
  });
  await bidTx.wait();
  console.log("Bid placed!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
