import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { network } from "hardhat";

describe("NOESIS tokens", async () => {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [admin, alice, stranger] = await viem.getWalletClients();

  it("mints NOE only for an account with MINTER_ROLE", async () => {
    const token = await viem.deployContract("NoesisToken", [admin.account.address]);
    const minterRole = await token.read.MINTER_ROLE();
    await token.write.grantRole([minterRole, admin.account.address]);
    await token.write.mint([alice.account.address, 25n * 10n ** 18n]);

    assert.equal(await token.read.balanceOf([alice.account.address]), 25n * 10n ** 18n);
    await assert.rejects(
      token.write.mint([stranger.account.address, 1n], { account: stranger.account }),
    );
    assert.equal(await publicClient.getChainId(), 31337);
  });

  it("uses six decimals and caps each faucet call at 10,000 mUSDC", async () => {
    const token = await viem.deployContract("MockUSDC");
    assert.equal(await token.read.decimals(), 6);
    await token.write.faucetMint([alice.account.address, 10_000n * 10n ** 6n]);
    assert.equal(await token.read.balanceOf([alice.account.address]), 10_000n * 10n ** 6n);
    await assert.rejects(token.write.faucetMint([alice.account.address, 10_001n * 10n ** 6n]));
  });

  it("exposes EIP-2612 permit support on mUSDC", async () => {
    const token = await viem.deployContract("MockUSDC");
    assert.equal(await token.read.nonces([alice.account.address]), 0n);
    assert.equal(await token.read.name(), "Mock USDC");
  });
});
