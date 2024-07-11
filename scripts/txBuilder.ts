import { SuiTxBlock } from '@scallop-io/sui-kit';
import Contract from '../publish-result.production.json';

export class ScallopReferralTxBuilder {
  static add_referral_tier(tx: SuiTxBlock, veSCA: number, referralShare: number, borrow_fee_discount: number) {
    tx.moveCall(
      `${Contract.packageId}::admin::add_referral_tier`,
      [Contract.adminCap, Contract.referralTiers, veSCA, referralShare, borrow_fee_discount],
    )
  }

  static remove_referral_tier(tx: SuiTxBlock, veSCA: number) {
    tx.moveCall(
      `${Contract.packageId}::admin::remove_referral_tier`,
      [Contract.adminCap, Contract.referralTiers, veSCA],
    )
  }

  static setContractVersion(tx: SuiTxBlock, newVersion: number) {
    tx.moveCall(
      `${Contract.packageId}::admin::set_contract_version`,
      [Contract.adminCap, Contract.versionObject,newVersion]
    )
  }
}
