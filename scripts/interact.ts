import { viem } from "hardhat";
import { parseEther } from "viem/utils";

async function main() {
  const contractAddress = "0xa436ab0397340f3459a66d67c80204b92219be2b";  // Replace with your deployed contract address

  // Get wallet clients (signers)
  const [owner] = await viem.getWalletClients();
  const publicClient = await viem.getPublicClient();

  // Get the deployed AuctionMarketplace contract instance
  const AuctionMarketplace = await viem.getContractAt(
    "AuctionMarketplace",
    contractAddress,
  );

  // Place a bid on itemId 1
  const bidTx = await AuctionMarketplace.write.placeBid([BigInt(1)], {
    value: parseEther("0.01"),  // Bid 1.5 ETH
  });       
  console.log("Bid placed!");

  console.log(bidTx);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
