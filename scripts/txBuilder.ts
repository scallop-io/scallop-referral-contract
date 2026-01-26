import { SuiTxBlock } from '@scallop-io/sui-kit';
import Contract from '../publish-result.production.json';

export class ScallopReferralTxBuilder {
  static addReferralTierV2(tx: SuiTxBlock, veSCA: number, referralShare: number, borrow_fee_discount: number) {
    tx.moveCall(
      `${Contract.packageId}::admin::add_referral_tier_v2`,
      [Contract.adminCapV2, Contract.referralTiers, veSCA, referralShare, borrow_fee_discount],
    )
  }

  static removeReferralTierV2(tx: SuiTxBlock, veSCA: number) {
    tx.moveCall(
      `${Contract.packageId}::admin::remove_referral_tier_v2`,
      [Contract.adminCapV2, Contract.referralTiers, veSCA],
    )
  }

  static setContractVersionV2(tx: SuiTxBlock, newVersion: number) {
    tx.moveCall(
      `${Contract.packageId}::admin::set_contract_version_v2`,
      [Contract.adminCapV2, Contract.versionObject,newVersion]
    )
  }

  static upgradeAdminCap(tx: SuiTxBlock) {
    const adminCapV2 = tx.moveCall(
      `${Contract.packageId}::admin::upgrade_admin_cap`,
      [Contract.adminCap],
    );
    return adminCapV2
  }
}
