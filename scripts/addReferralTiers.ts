import { SuiTxBlock } from '@scallop-io/sui-kit';
import { adminSuiKit } from './suiElements';
import { ScallopReferralTxBuilder } from './txBuilder';

addReferralTiers().then(console.log);
async function addReferralTiers() {
  const tiers = [
    { veSCA: 0, referralShare: 10, borrow_fee_discount: 10 },
    { veSCA: 100e9, referralShare: 15, borrow_fee_discount: 10 },
    { veSCA: 1000e9, referralShare: 20, borrow_fee_discount: 10 },
    { veSCA: 10000e9, referralShare: 30, borrow_fee_discount: 10 },
    { veSCA: 100000e9, referralShare: 40, borrow_fee_discount: 10 },
    { veSCA: 1000000e9, referralShare: 50, borrow_fee_discount: 10 },
  ];

  const tx = new SuiTxBlock();
  for (const tier of tiers) {
    ScallopReferralTxBuilder.add_referral_tier(tx, tier.veSCA, tier.referralShare, tier.borrow_fee_discount);
  }

  return adminSuiKit.signAndSendTxn(tx);
}
