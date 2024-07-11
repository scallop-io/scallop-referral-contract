import { SuiTxBlock } from '@scallop-io/sui-kit';
import { adminSuiKit } from './suiElements';
import { ScallopReferralTxBuilder } from './txBuilder';

pumpContractVersion().then(console.log);
async function pumpContractVersion() {
  const newVersion = 2;

  const tx = new SuiTxBlock();
  ScallopReferralTxBuilder.setContractVersion(tx, newVersion);

  return adminSuiKit.signAndSendTxn(tx);
}
