import { SuiTxBlock } from '@scallop-io/sui-kit';
import { adminSuiKit } from './suiElements';
import { MULTI_SIG_ADDRESS } from './multiSig';
import Contract from '../publish-result.production.json';

migrateToMultiSig().then(console.log);
async function migrateToMultiSig() {

  const tx = new SuiTxBlock();

  const object = '0xc5dc06b9074291259f2cac460c940012c781c4430e42125c541cc43101c3bcbd';
  tx.transferObjects([object], tx.pure(MULTI_SIG_ADDRESS));

  return adminSuiKit.signAndSendTxn(tx);
}
