import { fromBase64, SuiTxBlock } from '@scallop-io/sui-kit';
import { ScallopReferralTxBuilder } from './txBuilder';
import { adminSuiKit } from './suiElements';
import { buildMultiSigTx, MULTI_SIG_ADDRESS } from './multiSig';

updateReferralTiers().then(console.log);
async function updateReferralTiers() {
  const oldTiers = [
    { veSCA: 1_000_000e9, referralShare: 50, borrow_fee_discount: 50 },
  ];

  const newTiers = [
    { veSCA: 1_000_000e9, referralShare: 49, borrow_fee_discount: 50 },
  ];

  const tx = new SuiTxBlock();
  for (const tier of oldTiers) {
    ScallopReferralTxBuilder.removeReferralTierV2(tx, tier.veSCA);
  }
  for (const tier of newTiers) {
    ScallopReferralTxBuilder.addReferralTierV2(tx, tier.veSCA, tier.referralShare, tier.borrow_fee_discount);
  }

  tx.setSender(MULTI_SIG_ADDRESS);
  const txBytes = await buildMultiSigTx(tx);
  // gRPC `simulateTransaction` via sui-kit; `dryRunTransactionBlock` was
  // JSON-RPC, which public fullnodes no longer serve.
  const resp = await adminSuiKit.dryRunTxn(fromBase64(txBytes));
  console.log('Dry run response:', resp.Transaction ?? resp.FailedTransaction);
  return txBytes;
}
