import { SuiTxBlock } from '@scallop-io/sui-kit';
import { adminSuiKit } from './suiElements';
import { MULTI_SIG_ADDRESS } from './multiSig';
import Contract from '../publish-result.production.json';

migrateToMultiSig().then(console.log);
async function migrateToMultiSig() {

  const tx = new SuiTxBlock();

  const adminCap = '';
  tx.transferObjects([adminCap], MULTI_SIG_ADDRESS);

  return adminSuiKit.signAndSendTxn(tx);
}
