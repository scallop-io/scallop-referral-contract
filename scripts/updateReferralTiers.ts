import { SuiTxBlock } from '@scallop-io/sui-kit';
import { ScallopReferralTxBuilder } from './txBuilder';
import { adminSuiKit } from './suiElements';
import { buildMultiSigTx, MULTI_SIG_ADDRESS } from './multiSig';

updateReferralTiers().then(console.log);
async function updateReferralTiers() {
  const oldTiers = [
    { veSCA: 0, referralShare: 5, borrow_fee_discount: 5 },
    { veSCA: 100e9, referralShare: 6, borrow_fee_discount: 7 },
    { veSCA: 1000e9, referralShare: 9, borrow_fee_discount: 12 },
    { veSCA: 10000e9, referralShare: 18, borrow_fee_discount: 25 },
    { veSCA: 100000e9, referralShare: 32, borrow_fee_discount: 50 },
    { veSCA: 1000000e9, referralShare: 40, borrow_fee_discount: 60 },
  ];

  const newTiers = [
    { veSCA: 0, referralShare: 0, borrow_fee_discount: 0 },
    { veSCA: 1_000e9, referralShare: 5, borrow_fee_discount: 5 },
    { veSCA: 50_000e9, referralShare: 15, borrow_fee_discount: 15 },
    { veSCA: 100_000e9, referralShare: 25, borrow_fee_discount: 20 },
    { veSCA: 500_000e9, referralShare: 35, borrow_fee_discount: 35 },
    { veSCA: 1_000_000e9, referralShare: 50, borrow_fee_discount: 50 },
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
  const resp = await adminSuiKit.suiInteractor.currentClient.dryRunTransactionBlock({
    transactionBlock: txBytes
  });
  console.log('Dry run response:', resp);
  return txBytes;
}
