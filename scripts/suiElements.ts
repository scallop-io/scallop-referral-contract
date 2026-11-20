import dotenv from 'dotenv';
import { createRequire } from 'module';
import { getFullnodeUrl, SuiKit } from '@scallop-io/sui-kit';
import * as process from 'process';
import type { NetworkType } from '@scallop-io/sui-package-kit';

// `@scallop-io/sui-package-kit` is still CommonJS, so it cannot be `import`ed
// directly from these ESM scripts.
const require = createRequire(import.meta.url);
const { SuiAdvancePackagePublisher } =
  require('@scallop-io/sui-package-kit') as typeof import('@scallop-io/sui-package-kit');

dotenv.config();

const secretKey = process.env.SECRET_KEY || '';

// Everything in this repo (publish-result.production.json, the multisig, the
// upgrade cap) is mainnet, so the network is not configurable here.
export const networkType: NetworkType = 'mainnet';

// Public fullnodes dropped JSON-RPC, so sui-kit v2 talks gRPC instead: same
// host, different transport. Override with SUI_GRPC_URL to use a private node.
export const grpcUrl = process.env.SUI_GRPC_URL || getFullnodeUrl(networkType);

export const adminSuiKit = new SuiKit({ secretKey, networkType, fullnodeUrls: [grpcUrl] });

console.log(adminSuiKit.currentAddress);

export const packagePublisher = new SuiAdvancePackagePublisher({ networkType });
