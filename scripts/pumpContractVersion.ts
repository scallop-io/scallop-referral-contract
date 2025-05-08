import { SuiTxBlock } from '@scallop-io/sui-kit';
import { adminSuiKit } from './suiElements';
import { ScallopReferralTxBuilder } from './txBuilder';
import { buildMultiSigTx } from './multiSig';

pumpContractVersion().then(console.log);
async function pumpContractVersion() {
  const newVersion = 4;

  const tx = new SuiTxBlock();
  ScallopReferralTxBuilder.setContractVersion(tx, newVersion);

  return buildMultiSigTx(tx);
}
