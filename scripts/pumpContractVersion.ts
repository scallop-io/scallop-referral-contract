import { SuiTxBlock } from '@scallop-io/sui-kit';
import { ScallopReferralTxBuilder } from './txBuilder';
import { buildMultiSigTx } from './multiSig';

pumpContractVersion().then(console.log);
async function pumpContractVersion() {
  const newVersion = 5;

  const tx = new SuiTxBlock();
  ScallopReferralTxBuilder.setContractVersionV2(tx, newVersion);

  return buildMultiSigTx(tx);
}
