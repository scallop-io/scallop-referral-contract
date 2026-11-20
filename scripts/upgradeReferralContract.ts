import * as path from 'path';
import { fileURLToPath } from 'url';
import { Transaction, UpgradePolicy, toBase64 } from '@scallop-io/sui-kit';
import { adminSuiKit, packagePublisher } from './suiElements';
import publishResult from '../publish-result.production.json' with { type: 'json' };
import { MULTI_SIG_ADDRESS } from './multiSig';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const borrowReferralPkgPath = path.join(__dirname, '..');

// Gas is reserved from the multisig's own coins, so the budget has to be
// something it actually holds or the build fails during gas selection. An
// upgrade of this package simulates at ~0.073 SUI, so 0.3 SUI is ~4x headroom.
// sui-package-kit used to hardcode 1 SUI, which the multisig can no longer cover.
const GAS_BUDGET = Number(process.env.UPGRADE_GAS_BUDGET ?? 3 * 10 ** 8);

/**
 * Build the referral package upgrade transaction for the multisig to sign.
 *
 * The transaction is built here rather than through
 * `packagePublisher.createUpgradePackageTxWithDependencies`, because that helper
 * builds the transaction with sui-package-kit's own (JSON-RPC only) SDK copy,
 * and public fullnodes no longer serve JSON-RPC. Only the compile step comes
 * from sui-package-kit -- that one shells out to `sui move build` and needs no
 * network access.
 *
 * Every dependency in Move.toml is a pinned git dependency (see Move.lock), so
 * there are no local dependency packages whose Move.toml needs swapping first.
 */
export const buildUpgradeBorrowReferralTx = async () => {
  const { modules, dependencies, digest } =
    packagePublisher.packagePublisher.buildPackage(borrowReferralPkgPath);

  const tx = new Transaction();
  tx.setSender(MULTI_SIG_ADDRESS);
  tx.setGasBudget(GAS_BUDGET);

  const ticket = tx.moveCall({
    target: '0x2::package::authorize_upgrade',
    arguments: [
      tx.object(publishResult.upgradeCap),
      tx.pure.u8(UpgradePolicy.COMPATIBLE),
      tx.pure.vector('u8', digest),
    ],
  });

  const receipt = tx.upgrade({
    modules,
    dependencies,
    package: publishResult.packageId,
    ticket,
  });

  tx.moveCall({
    target: '0x2::package::commit_upgrade',
    arguments: [tx.object(publishResult.upgradeCap), receipt],
  });

  const txBytes = await tx.build({ client: adminSuiKit.client });
  return { txBytes, txBytesBase64: toBase64(txBytes) };
};

export const upgradeBorrowReferral = async () => {
  const { txBytes, txBytesBase64 } = await buildUpgradeBorrowReferralTx();

  // `dryRunTxn` goes through gRPC `simulateTransaction`; the old
  // `client.dryRunTransactionBlock` was JSON-RPC and no longer exists.
  // The result is a `{ $kind, Transaction | FailedTransaction }` union.
  const result = await adminSuiKit.dryRunTxn(txBytes);
  const simulated = result.Transaction ?? result.FailedTransaction;
  console.dir(simulated, { depth: null });

  if (!simulated.status.success) {
    throw new Error(`Dry run failed: ${JSON.stringify(simulated.status.error)}`);
  }

  return txBytesBase64;
};

upgradeBorrowReferral()
  .then(console.log)
  .catch(console.error)
  .finally(() => process.exit(0));
