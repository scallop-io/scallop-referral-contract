import { SuiTxBlock } from '@scallop-io/sui-kit';
import { ScallopReferralTxBuilder } from './txBuilder';
import { adminSuiKit } from './suiElements';

updateReferralTiers().then(console.log);
async function updateReferralTiers() {
  const oldTiers = [
    { veSCA: 0, referralShare: 10, borrow_fee_discount: 10 },
    { veSCA: 100e9, referralShare: 15, borrow_fee_discount: 12 },
    { veSCA: 1000e9, referralShare: 20, borrow_fee_discount: 14 },
    { veSCA: 10000e9, referralShare: 25, borrow_fee_discount: 16 },
    { veSCA: 100000e9, referralShare: 30, borrow_fee_discount: 18 },
    { veSCA: 1000000e9, referralShare: 40, borrow_fee_discount: 20 },
  ];

  const newTiers = [
    { veSCA: 0, referralShare: 5, borrow_fee_discount: 5 },
    { veSCA: 100e9, referralShare: 6, borrow_fee_discount: 7 },
    { veSCA: 1000e9, referralShare: 9, borrow_fee_discount: 12 },
    { veSCA: 10000e9, referralShare: 18, borrow_fee_discount: 25 },
    { veSCA: 100000e9, referralShare: 32, borrow_fee_discount: 50 },
    { veSCA: 1000000e9, referralShare: 40, borrow_fee_discount: 60 },
  ];

  const tx = new SuiTxBlock();
  for (const tier of oldTiers) {
    ScallopReferralTxBuilder.removeReferralTierV2(tx, tier.veSCA);
  }
  for (const tier of newTiers) {
    ScallopReferralTxBuilder.addReferralTierV2(tx, tier.veSCA, tier.referralShare, tier.borrow_fee_discount);
  }

  return adminSuiKit.signAndSendTxn(tx);
}
