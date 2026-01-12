import * as dotenv from 'dotenv';
import { SuiKit } from '@scallop-io/sui-kit';
import * as process from "process";
import { SuiAdvancePackagePublisher } from '@scallop-io/sui-package-kit';
dotenv.config();

const secretKey = process.env.SECRET_KEY || '';
export const adminSuiKit = new SuiKit({ secretKey, networkType: 'mainnet' });

console.log(adminSuiKit.currentAddress);

// export const packagePublisher = new SuiAdvancePackagePublisher({ networkType: 'mainnet' });