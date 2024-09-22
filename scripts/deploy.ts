import { viem } from "hardhat";

async function deployAuctionMarketplace() {
  const [owner, otherAccount] = await viem.getWalletClients();  // Get signers (owner and another account)
  const publicClient = await viem.getPublicClient();            // Get the public client (for interacting with RPC)

  // Deploy the AuctionMarketplace contract
  const AuctionMarketplaceContract = await viem.deployContract("AuctionMarketplace");

  console.log("AuctionMarketplace deployed at:", AuctionMarketplaceContract.address);

  return {
    publicClient,
    owner,
    otherAccount,
    AuctionMarketplaceContract,
  };
}

async function main() {
  // Deploy the AuctionMarketplace contract and retrieve relevant instances
  const { publicClient, owner, otherAccount, AuctionMarketplaceContract } = await deployAuctionMarketplace();

  // Convert values to `bigint` format for price (in wei) and expiry time (in seconds)
  const postTx = await AuctionMarketplaceContract.write.postItem(
  ["Laptop",                                      // Item name
    "A powerful gaming laptop",                    // Item description
    1000n,                          // starting price (in wei)
    BigInt(Math.floor(Date.now() / 1000) + 360000)]  // Expiry time in 1 hour (as bigint)
  );

  console.log("Item posted successfully!");

  // Log more details or interact further if needed
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
