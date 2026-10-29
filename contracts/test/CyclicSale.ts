import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { network } from "hardhat";

describe("CyclicSale core", async () => {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [owner, treasury, participant] = await viem.getWalletClients();

  async function deploySale(genesisTime: bigint) {
    const noe = await viem.deployContract("NoesisToken", [owner.account.address]);
    const usdc = await viem.deployContract("MockUSDC");
    const sale = await viem.deployContract("CyclicSale", [
      noe.address,
      usdc.address,
      10_000n,
      100_000n * 10n ** 18n,
      genesisTime,
      36_000n,
      10_800n,
      1n * 10n ** 6n,
      200n * 10n ** 6n,
      treasury.account.address,
      owner.account.address,
    ]);
    return { noe, usdc, sale };
  }

  it("reports Upcoming before genesis and derives round dates", async () => {
    const block = await publicClient.getBlock();
    const genesis = block.timestamp + 3_600n;
    const { sale } = await deploySale(genesis);
    assert.equal(await sale.read.phase(), 0);
    assert.equal(await sale.read.currentRound(), 0n);

    const info = await sale.read.roundInfo([0n]);
    assert.equal(info[0], genesis);
    assert.equal(info[1], genesis + 36_000n);
    assert.equal(info[2], genesis + 46_800n);
  });

  it("accepts a valid commit and tracks one participant", async () => {
    const block = await publicClient.getBlock();
    const { usdc, sale } = await deploySale(block.timestamp - 60n);
    const amount = 25n * 10n ** 6n;
    await usdc.write.faucetMint([participant.account.address, amount]);
    await usdc.write.approve([sale.address, amount], { account: participant.account });
    await sale.write.commit([amount], { account: participant.account });

    const info = await sale.read.roundInfo([0n]);
    assert.equal(info[4], amount);
    assert.equal(info[5], 1n);
    const page = await sale.read.getParticipants([0n, 0n, 10n]);
    assert.deepEqual(page[0].map((address) => address.toLowerCase()), [participant.account.address.toLowerCase()]);
    assert.deepEqual(page[1], [amount]);
  });

  it("enforces the per-wallet maximum across multiple commits", async () => {
    const block = await publicClient.getBlock();
    const { usdc, sale } = await deploySale(block.timestamp - 60n);
    const amount = 201n * 10n ** 6n;
    await usdc.write.faucetMint([participant.account.address, amount]);
    await usdc.write.approve([sale.address, amount], { account: participant.account });
    await assert.rejects(sale.write.commit([amount], { account: participant.account }));
  });

  it("allows the owner to pause commits", async () => {
    const block = await publicClient.getBlock();
    const { usdc, sale } = await deploySale(block.timestamp - 60n);
    const amount = 1n * 10n ** 6n;
    await usdc.write.faucetMint([participant.account.address, amount]);
    await usdc.write.approve([sale.address, amount], { account: participant.account });
    await sale.write.pause();
    await assert.rejects(sale.write.commit([amount], { account: participant.account }));
  });
});
