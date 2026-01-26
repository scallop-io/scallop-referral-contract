import { SuiTxBlock } from '@scallop-io/sui-kit';
import { adminSuiKit } from './suiElements';
import { ScallopReferralTxBuilder } from './txBuilder';
import { MULTI_SIG_ADDRESS } from './multiSig';

upgradeAdminCap().then(console.log);
async function upgradeAdminCap() {
  const tx = new SuiTxBlock();
  const adminCapV2 = ScallopReferralTxBuilder.upgradeAdminCap(tx);
  tx.transferObjects([adminCapV2], MULTI_SIG_ADDRESS);

  return adminSuiKit.signAndSendTxn(tx);
}
