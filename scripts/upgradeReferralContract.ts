import * as path from "path";
import { PackageBatch } from "@scallop-io/sui-package-kit";
import { adminSuiKit, packagePublisher } from "./suiElements";
import publishResult from "../publish-result.production.json";
import { MULTI_SIG_ADDRESS } from "./multiSig";
import { SuiClient } from "@mysten/sui/client";

const lendingContractsPath = "../../sui-lending-protocol/contracts";

/**
 * Oracle related dependencies
 */
const xOraclePath = path.join(__dirname, `${lendingContractsPath}/sui_x_oracle/x_oracle`);
const wormholePath = path.join(__dirname, `${lendingContractsPath}/sui_x_oracle/pyth_rule/vendors/wormhole`);
const pythOraclePath = path.join(__dirname, `${lendingContractsPath}/sui_x_oracle/pyth_rule/vendors/pyth`);
const pythRulePath = path.join(__dirname, `${lendingContractsPath}/sui_x_oracle/pyth_rule`);

/**
 * Protocol related dependencies
 */
const mathPkgPath = path.join(__dirname, `${lendingContractsPath}/libs/math`);
const xPkgPath = path.join(__dirname, `${lendingContractsPath}/libs/x`);
const decimalPkgPath = path.join(__dirname, `${lendingContractsPath}/libs/x`);
const whitelistPkgPath = path.join(__dirname, `${lendingContractsPath}/libs/whitelist`);
const coinDecimalsRegistryPath = path.join(__dirname, `${lendingContractsPath}/libs/coin_decimals_registry`);

const borrowReferralPkgPath = path.join(__dirname, "../");
const protocolPkgPath = path.join(__dirname, `${lendingContractsPath}/protocol`);
const veScaPkgPath = path.join(__dirname, "../../ve-sca");
const scaPkgPath = path.join(__dirname, "../../scallop-token/sca");

const borrowReferralPackageList: PackageBatch = [
    // Oracle related dependencies
    { packagePath: xOraclePath },
    { packagePath: wormholePath },
    { packagePath: pythOraclePath },
    { packagePath: pythRulePath },

    // Protocol related dependencies
    { packagePath: mathPkgPath },
    { packagePath: xPkgPath },
    { packagePath: decimalPkgPath },
    { packagePath: whitelistPkgPath },
    { packagePath: coinDecimalsRegistryPath },
    { packagePath: protocolPkgPath },

    { packagePath: scaPkgPath },
    { packagePath: veScaPkgPath },
];

export const upgradeBorrowReferral = async (
    client: SuiClient
) => {
    const upgradeTx = await packagePublisher.createUpgradePackageTxWithDependencies(
        borrowReferralPkgPath,
        publishResult.packageId,
        publishResult.upgradeCap,
        borrowReferralPackageList,
        client,
        MULTI_SIG_ADDRESS
    );
    const result = await client.dryRunTransactionBlock({
        transactionBlock: upgradeTx?.txBytesBase64!
    })
    console.log(result)
    return upgradeTx?.txBytesBase64
}

upgradeBorrowReferral(adminSuiKit.client()).then(console.log).catch(console.error).finally(() => process.exit(0));